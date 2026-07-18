# Trilho — Plataforma Web: Spec de Design
**Data:** 2026-03-21
**Status:** Aprovado pelo usuário
**Escopo:** `web/` (trilho.app) + `admin/` (admin.trilho.app) + extensões ao backend .NET 8

---

## 1. Visão Geral

Adicionar dois novos frontends Next.js ao monorepo Transit para complementar o app Flutter existente:

- **`web/`** — trilho.app: landing page pública (SEO + download CTA + preview de status das linhas) e app web completo com paridade funcional ao mobile para usuários premium
- **`admin/`** — admin.trilho.app: painel administrativo com gestão de usuários VIP e dashboards financeiro e operacional

O backend .NET 8 existente recebe novas rotas e colunas para suportar ambos os frontends.

---

## 2. Arquitetura

### 2.1 Estrutura do Monorepo

```
Transit/
├── backend/          (existente — .NET 8)
├── mobile/           (existente — Flutter)
├── web/              (NOVO — trilho.app)
│   ├── app/
│   │   ├── (public)/         # landing, login, pricing — sem auth
│   │   │   ├── page.tsx      # /
│   │   │   ├── login/page.tsx
│   │   │   └── pricing/page.tsx
│   │   └── (app)/            # app premium — requer auth + premium
│   │       ├── app/page.tsx          # /app — mapa
│   │       ├── app/line/[code]/page.tsx
│   │       ├── app/station/[id]/page.tsx
│   │       └── app/settings/page.tsx
│   ├── middleware.ts         # guarda de rota por estado de auth
│   ├── lib/
│   │   ├── auth.ts           # helpers Firebase + JWT cookie
│   │   └── api.ts            # cliente HTTP com cookie JWT
│   └── components/
└── admin/            (NOVO — admin.trilho.app)
    ├── app/
    │   ├── (auth)/
    │   │   └── login/page.tsx
    │   └── (panel)/          # requer sessão NextAuth
    │       ├── page.tsx              # / — overview
    │       ├── users/page.tsx
    │       ├── financial/page.tsx
    │       └── operational/page.tsx
    ├── auth.ts               # configuração NextAuth credentials
    └── lib/
        └── admin-api.ts      # cliente HTTP com X-Admin-Key
```

### 2.2 Stack Tecnológica

| Camada | Tecnologia |
|--------|-----------|
| Framework | Next.js 14 (App Router) + TypeScript |
| Estilo | Tailwind CSS |
| Auth `web/` | Firebase Auth (Google/Apple/email) + JWT httpOnly cookie |
| Auth `admin/` | NextAuth.js v5 — credentials provider (email/senha) |
| Fetch / cache | TanStack Query v5 (client-side); `fetch` nativo com `revalidate` (server-side) |
| Mapas | `@vis.gl/react-google-maps` |
| Testes unitários/integração | Vitest + Testing Library |
| Testes E2E | Playwright |
| Testes de contrato | Pact (consumer-driven) |
| Testes de carga | k6 |

---

## 3. Rotas e Páginas

### 3.1 `web/` — Zona Pública

| Rota | Renderização | Descrição |
|------|-------------|-----------|
| `/` | SSR + revalidate 60s | Hero com download CTA (App Store / Google Play) + ticker de status das linhas em tempo quase-real |
| `/login` | CSR | Login Firebase: Google, Apple, email/senha. Redireciona para `/app` em sucesso |
| `/pricing` | SSG | Comparativo de planos. Link para checkout RevenueCat ou deep link para o app |

### 3.2 `web/` — Zona App (Premium)

Middleware verifica cookie JWT. Ausência → `/login`. Usuário free → `/pricing?reason=premium_required`.

| Rota | Descrição |
|------|-----------|
| `/app` | Mapa interativo com marcadores de densidade por estação |
| `/app/line/[code]` | Banner de status + lista de estações com pontos coloridos |
| `/app/station/[id]` | Card de densidade + gráfico histórico de 3h. Sem ads, sem limite de consultas |
| `/app/settings` | Info da conta, status do plano, logout |

### 3.3 `admin/` — Zona Auth

| Rota | Descrição |
|------|-----------|
| `/login` | Formulário email/senha via NextAuth credentials |

### 3.4 `admin/` — Zona Panel

Middleware NextAuth bloqueia todas as rotas sem sessão ativa.

| Rota | Conteúdo Principal |
|------|-------------------|
| `/` | Cards de resumo: total de usuários, premium ativos, consultas hoje, incidentes de linha |
| `/users` | Tabela paginada: email, plano, toggle VIP, contagem de consultas, último acesso. Busca e filtros |
| `/financial` | MRR, novos assinantes, churn — alimentado por dados do RevenueCat armazenados no banco |
| `/operational` | Gráfico de consultas/hora, top 10 estações, status atual das linhas, taxa de erros da API |

---

## 4. Autenticação e Sessão

### 4.1 Fluxo `web/` (usuário final)

```
1. Usuário faz login via Firebase SDK no browser
2. Frontend obtém idToken (JWT Firebase, válido 1h)
3. POST /api/auth/firebase { idToken }
   └── Backend valida com Firebase Admin SDK
   └── Busca ou cria User no banco
   └── Retorna JWT próprio (payload: userId, email, isPremium, isVip)
4. Next.js Route Handler salva JWT em cookie httpOnly (SameSite=Strict)
5. Middleware lê cookie em cada requisição para /app/*
6. Firebase SDK renova idToken silenciosamente; frontend chama rota de refresh quando necessário
```

### 4.2 Fluxo `admin/` (administrador)

```
1. Formulário POST email/senha → NextAuth credentials provider
2. NextAuth verifica hash bcrypt contra tabela admin_users
3. Sessão JWT NextAuth armazenada em cookie httpOnly
4. Middleware NextAuth bloqueia todas as rotas sem sessão
```

---

## 5. Backend — Extensões

### 5.1 Novas Colunas

```sql
-- Tabela users (existente)
ALTER TABLE users
  ADD COLUMN is_vip BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN vip_email TEXT;

-- Nova tabela
CREATE TABLE admin_users (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email        TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

Migrações criadas via Entity Framework: `AddVipToUser` e `AddAdminUsers`.

### 5.2 Novas Rotas de API

| Método | Rota | Auth | Descrição |
|--------|------|------|-----------|
| `POST` | `/api/auth/firebase` | Pública | Valida idToken Firebase; retorna JWT próprio |
| `GET` | `/api/admin/users` | X-Admin-Key | Lista usuários com paginação (`?page=&size=&search=&filter=`) |
| `PATCH` | `/api/admin/users/{id}/vip` | X-Admin-Key | Toggle `IsVip`; define ou limpa `VipEmail` |
| `GET` | `/api/admin/stats/financial` | X-Admin-Key | MRR, novos assinantes, churn do período |
| `GET` | `/api/admin/stats/operational` | X-Admin-Key | Consultas/hora, top estações, status das linhas, taxa de erros |

Rotas admin autenticadas via header `X-Admin-Key` (variável de ambiente `ADMIN_API_KEY`). JWT de usuário não é aceito nessas rotas.

### 5.3 Lógica VIP

Usuários VIP (`IsVip = true`) têm as mesmas permissões que usuários Premium, sem necessidade de assinatura. O campo `VipEmail` serve como referência de auditoria (o email que foi adicionado à whitelist). A verificação de acesso no backend segue: `IsPremium || IsVip`.

---

## 6. Fluxo de Dados

### 6.1 Landing Page (`/`)

- SSR com `revalidate: 60` — rebuilda o HTML a cada 60 segundos
- Chama `GET /api/lines` publicamente (sem auth)
- Exibe apenas: nome da linha, cor, status (Normal/Parcial/Paralisada) — **sem dados de lotação**
- Falha no fetch → componente de status exibe "Dados temporariamente indisponíveis"; landing não quebra

### 6.2 Mapa Web (`/app`)

- Client-side com TanStack Query, polling a cada 30s
- Mesmo endpoint do mobile: `GET /api/stations` com cookie JWT no header
- Marcadores coloridos por nível de densidade (reutiliza lógica de cores do mobile)

### 6.3 Dashboards Admin

- Server-side fetch com `X-Admin-Key` no build inicial (SSR)
- TanStack Query no client para ações mutativas (toggle VIP com optimistic update)
- Cada card de stats é independente: falha de um não afeta os demais

---

## 7. Tratamento de Erros

### 7.1 `web/`

| Cenário | Comportamento |
|---------|--------------|
| Token Firebase expirado | Middleware redireciona para `/login`; cookie limpo |
| Usuário free em `/app/*` | Redireciona para `/pricing?reason=premium_required` |
| Falha em `POST /api/auth/firebase` | Login exibe mensagem genérica; erro logado no servidor |
| Falha em fetch do app | TanStack Query: 2 retentativas com backoff exponencial; depois exibe `error.tsx` com botão "Tentar novamente" |
| Falha no ticker da landing | Componente oculta o ticker; restante da página funciona normalmente |

### 7.2 `admin/`

| Cenário | Comportamento |
|---------|--------------|
| Sessão NextAuth expirada | Middleware redireciona para `/login` |
| Falha no toggle VIP | Optimistic update revertido; toast de erro exibido |
| Falha em card de dashboard | Card exibe estado de erro isolado; outros cards não são afetados |
| `X-Admin-Key` inválida | Backend retorna 403; frontend exibe erro de autenticação |

---

## 8. Estratégia de Testes

### 8.1 Testes Unitários (Vitest)

**`web/` e `admin/`:**

| O que testar | Arquivo-alvo |
|---|---|
| `middleware.ts` — lógica de redirecionamento por estado de auth | `middleware.test.ts` |
| `lib/auth.ts` — parse e validação de JWT cookie | `auth.test.ts` |
| `lib/api.ts` — montagem de headers, tratamento de 401/403 | `api.test.ts` |
| Componentes puros (cards de stats, tabela de usuários) | `*.test.tsx` com Testing Library |
| Helpers de formatação (ex: MRR em BRL, tempo relativo) | `formatters.test.ts` |

**Backend (.NET):**

| O que testar |
|---|
| Lógica de verificação `IsPremium \|\| IsVip` no handler de usage |
| Hash bcrypt de senha na criação de `admin_users` |
| Cálculo de MRR no stats handler |
| Parsing e validação do idToken Firebase (mockado) |

### 8.2 Testes de Integração (Vitest + MSW / WebApplicationFactory)

**`web/` e `admin/` — com MSW interceptando chamadas HTTP:**

| Cenário |
|---|
| Login Firebase bem-sucedido → cookie JWT criado → acesso a `/app` liberado |
| Login Firebase com token inválido → cookie não criado → erro exibido |
| Toggle VIP no admin → `PATCH /api/admin/users/{id}/vip` chamado → UI atualizada |
| Polling do mapa a cada 30s → TanStack Query dispara refetch automaticamente |
| Falha no fetch de stats → card exibe erro sem afetar outros cards |

**Backend (.NET) — com `WebApplicationFactory` e banco in-memory:**

| Cenário |
|---|
| `POST /api/auth/firebase` com idToken válido (mockado) → cria usuário, retorna JWT |
| `POST /api/auth/firebase` com idToken inválido → 401 |
| `GET /api/admin/users` sem `X-Admin-Key` → 403 |
| `GET /api/admin/users` com `X-Admin-Key` válida → lista paginada |
| `PATCH /api/admin/users/{id}/vip` → `IsVip` toggled no banco |
| `GET /api/admin/users/{id_inexistente}/vip` → 404 |
| Usuário VIP chama endpoint de usage → `canQuery = true` independente de `IsPremium` |

### 8.3 Testes Funcionais / E2E (Playwright)

Ambiente: Next.js dev server + backend dockerizado + banco PostgreSQL de teste.

**Fluxos críticos `web/`:**

| # | Fluxo |
|---|-------|
| F1 | Visitante acessa `/` → vê status das linhas → clica em "Baixar app" → link correto |
| F2 | Usuário faz login com Google → redirecionado para `/app` → mapa carrega com marcadores |
| F3 | Usuário free tenta acessar `/app` → redirecionado para `/pricing?reason=premium_required` |
| F4 | Usuário premium acessa `/app/station/[id]` → card de densidade exibido → sem ads |
| F5 | Token expirado durante sessão → middleware redireciona para `/login` |

**Fluxos críticos `admin/`:**

| # | Fluxo |
|---|-------|
| A1 | Admin faz login com email/senha corretos → acessa `/` → cards de overview carregados |
| A2 | Admin faz login com senha errada → mensagem de erro exibida |
| A3 | Admin em `/users` → busca por email → resultado filtrado → toggle VIP → mudança persistida |
| A4 | Admin acessa `/financial` → MRR exibido → dados coerentes com banco de teste |
| A5 | Sessão admin expira → redireciona para `/login` sem dados visíveis |

### 8.4 Testes de Carga (k6)

Scripts em `tests/load/` executados contra ambiente de staging.

**Cenários:**

| Cenário | VUs | Duração | Critério de aceite |
|---------|-----|---------|-------------------|
| Landing page (SSR) | 200 | 5 min | p95 < 500ms; error rate < 1% |
| Login Firebase (`POST /api/auth/firebase`) | 50 | 3 min | p95 < 800ms; error rate < 0.5% |
| Mapa polling (`GET /api/stations` a cada 30s) | 100 | 10 min | p95 < 300ms; error rate < 0.5% |
| Toggle VIP simultâneo (`PATCH /api/admin/users`) | 10 | 2 min | p99 < 1s; zero race conditions |
| Dashboard admin (`GET /api/admin/stats/*`) | 20 | 5 min | p95 < 1s; error rate < 1% |

**Estrutura do script base:**

```javascript
// tests/load/landing.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: 200,
  duration: '5m',
  thresholds: {
    http_req_duration: ['p(95)<500'],
    http_req_failed: ['rate<0.01'],
  },
};

export default function () {
  const res = http.get('https://staging.trilho.app/');
  check(res, { 'status 200': (r) => r.status === 200 });
  sleep(1);
}
```

### 8.5 Testes de Contrato (Pact — Consumer-Driven)

Garante que o frontend não quebra silenciosamente quando o backend muda.

**Consumers:** `web/` e `admin/`
**Provider:** backend .NET 8

**Contratos definidos:**

| Consumer | Endpoint | Contrato |
|----------|---------|---------|
| `web/` | `POST /api/auth/firebase` | Request: `{ idToken: string }` → Response: `{ token: string, user: { id, email, isPremium, isVip } }` |
| `web/` | `GET /api/stations` | Response: array de `{ id, name, densityLevel, density, lines }` |
| `web/` | `GET /api/lines` | Response: array de `{ code, name, status, statusMessage }` |
| `web/` | `GET /api/crowd/{stationId}` | Response: `{ stationName, densityLevel, density, history[], source, capturedAt }` |
| `admin/` | `GET /api/admin/users` | Response: `{ items: User[], total, page, size }` |
| `admin/` | `PATCH /api/admin/users/{id}/vip` | Request: `{ isVip: boolean }` → Response: `{ id, isVip, vipEmail }` |
| `admin/` | `GET /api/admin/stats/financial` | Response: `{ mrr, newSubscribers, churn, period }` |
| `admin/` | `GET /api/admin/stats/operational` | Response: `{ queriesPerHour[], topStations[], lineStatuses[], errorRate }` |

**Fluxo Pact:**
1. Testes consumer (Vitest) geram arquivos de pacto em `pacts/`
2. CI publica pactos no Pact Broker
3. Pipeline do backend verifica os contratos antes de fazer deploy
4. Falha de contrato bloqueia o merge

---

## 9. Variáveis de Ambiente

### `web/`
```env
NEXT_PUBLIC_FIREBASE_API_KEY=
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=
NEXT_PUBLIC_FIREBASE_PROJECT_ID=
NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=
BACKEND_URL=https://api.trilho.app
JWT_SECRET=
NEXT_PUBLIC_APP_URL=https://trilho.app
```

### `admin/`
```env
NEXTAUTH_SECRET=
NEXTAUTH_URL=https://admin.trilho.app
BACKEND_URL=https://api.trilho.app
ADMIN_API_KEY=
```

### Backend (.NET) — novas variáveis
```env
FIREBASE_PROJECT_ID=
FIREBASE_SERVICE_ACCOUNT_JSON=   # base64
ADMIN_API_KEY=
```

---

## 10. Critérios de Aceite do MVP

- [ ] Landing exibe status das linhas em tempo quase-real (≤60s de atraso)
- [ ] Usuário premium consegue fazer login e acessar o mapa no browser sem instalar o app
- [ ] Usuário free ou não-autenticado é bloqueado em `/app/*` e direcionado corretamente
- [ ] Admin consegue adicionar/remover VIP de qualquer usuário via toggle
- [ ] Dashboards financeiro e operacional carregam dados reais do banco
- [ ] Todos os fluxos E2E críticos (F1–F5, A1–A5) passam no CI
- [ ] Testes de carga: landing e mapa atendem thresholds de p95 em staging
- [ ] Nenhum contrato Pact falha no pipeline de deploy do backend

---

## 11. Fora do Escopo (MVP)

- Notificações push no browser (web push)
- Internacionalização (i18n) — MVP apenas em português
- PWA / instalação offline
- Dark mode no web (mobile já tem; web em versão posterior)
- Autenticação de dois fatores no admin
- Export de dados (CSV/Excel) nos dashboards
