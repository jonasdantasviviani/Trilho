# Trilho — Design System Spec
**Data:** 2026-04-25
**Status:** Aprovado pelo usuário

---

## 1. Brand

### Identidade
| Atributo | Decisão |
|---|---|
| Nome | Trilho |
| Slogan | Mobilidade em tempo real |
| Personalidade | Tech / Futurista — preciso, confiável, moderno |
| Referências | Citymapper, Transit App |

### Logo
- **Símbolo:** Rede de metrô — ícone SVG com nós e conexões (interseção de linhas em cruz + dois terminais horizontais)
- **Wordmark:** `TRILHO` em caixa alta, Inter ExtraBold, letter-spacing 3px, cor `--color-accent` (#00C8FF)
- **Lockup principal:** símbolo + wordmark horizontal
- **Ícone de app:** símbolo isolado em container quadrado 56×56, fundo `#0A0A14`, borda 2px `--color-accent`, border-radius 12px

### SVG do símbolo (referência)
```svg
<svg viewBox="0 0 36 36" fill="none">
  <circle cx="8"  cy="18" r="4" fill="#00C8FF"/>
  <circle cx="28" cy="18" r="4" fill="#00C8FF"/>
  <line x1="12" y1="18" x2="24" y2="18" stroke="#00C8FF" stroke-width="2.5"/>
  <circle cx="18" cy="10" r="3" fill="#0055FF"/>
  <line x1="18" y1="13" x2="18" y2="17" stroke="#0055FF" stroke-width="2"/>
  <circle cx="18" cy="26" r="3" fill="#0055FF"/>
  <line x1="18" y1="19" x2="18" y2="23" stroke="#0055FF" stroke-width="2"/>
</svg>
```

---

## 2. Tokens

### 2.1 Cores base
| Token | Dark (#0A0A14) | Light (#F5F5F7) |
|---|---|---|
| `--color-bg` | #0A0A14 | #F5F5F7 |
| `--color-surface` | #13131F | #FFFFFF |
| `--color-surface-raised` | #1C1C2E | #EFEFEF |
| `--color-border` | #2A2A3A | #E0E0E8 |
| `--color-text-primary` | #FFFFFF | #0A0A14 |
| `--color-text-secondary` | #8888AA | #555566 |
| `--color-text-disabled` | #444455 | #AAAABC |

### 2.2 Cores de marca
| Token | Valor |
|---|---|
| `--color-primary` | #0055FF (azul elétrico) |
| `--color-accent` | #00C8FF (cyan) |
| `--color-primary-dim` | rgba(0, 85, 255, 0.15) |
| `--color-accent-dim` | rgba(0, 200, 255, 0.15) |

### 2.3 Cores semânticas
| Token | Dark | Light |
|---|---|---|
| `--color-success` | #22CC88 | #1A9966 |
| `--color-warning` | #FFB800 | #CC9200 |
| `--color-danger` | #FF4455 | #CC2233 |
| `--color-info` | `--color-accent` | `--color-primary` |

### 2.4 Lotação (crowd density)
| Nível | Token | Cor |
|---|---|---|
| Vazio | `--crowd-empty` | #22CC88 |
| Baixo | `--crowd-low` | #88DD44 |
| Moderado | `--crowd-moderate` | #FFB800 |
| Alto | `--crowd-high` | #FF7722 |
| Lotado | `--crowd-full` | #FF4455 |

### 2.5 Tipografia
| Token | Valor |
|---|---|
| `--font-family` | Inter, -apple-system, sans-serif |
| `--font-size-xs` | 10px |
| `--font-size-sm` | 12px |
| `--font-size-md` | 14px |
| `--font-size-lg` | 16px |
| `--font-size-xl` | 20px |
| `--font-size-2xl` | 24px |
| `--font-size-3xl` | 32px |
| `--font-weight-regular` | 400 |
| `--font-weight-medium` | 500 |
| `--font-weight-bold` | 700 |
| `--font-weight-extrabold` | 800 |

### 2.6 Espaçamento
| Token | Valor |
|---|---|
| `--space-1` | 4px |
| `--space-2` | 8px |
| `--space-3` | 12px |
| `--space-4` | 16px |
| `--space-5` | 20px |
| `--space-6` | 24px |
| `--space-8` | 32px |
| `--space-10` | 40px |
| `--space-12` | 48px |

### 2.7 Bordas e elevação
| Token | Valor |
|---|---|
| `--radius-sm` | 8px |
| `--radius-md` | 12px |
| `--radius-lg` | 16px |
| `--radius-xl` | 24px |
| `--radius-full` | 9999px |
| `--shadow-sm` | 0 2px 8px rgba(0,0,0,0.3) |
| `--shadow-md` | 0 4px 16px rgba(0,0,0,0.4) |
| `--shadow-glow-primary` | 0 0 16px rgba(0,85,255,0.3) |
| `--shadow-glow-accent` | 0 0 16px rgba(0,200,255,0.2) |

### 2.8 Motion
| Token | Valor |
|---|---|
| `--timing-fast` | 150ms ease-out |
| `--timing-smooth` | 300ms ease-out |
| `--timing-slow` | 500ms ease-in-out |

---

## 3. App Flutter

### Tema geral
- Modo padrão: dark
- Cor de fundo scaffold: `--color-bg` (#0A0A14 → `Color(0xFF0A0A14)`)
- AppBar: transparente, título em Inter ExtraBold
- ThemeData: `ColorScheme.dark()` com primary=`--color-primary`, secondary=`--color-accent`

### 3.1 Tela de Login
```
bg: --color-bg
  Logo símbolo SVG (64×64) + wordmark "TRILHO"
  Subtítulo: "Mobilidade em tempo real" (--color-text-secondary)
  ─────────────────────────────────
  [Campo e-mail]  borda --color-border, foco --color-accent
  [Campo senha]   idem + ícone olho
  [Entrar]        bg gradient primary→accent, radius-lg
  [Esqueceu?]     link text --color-accent
  ─────────────────────────────────
  [Continuar sem conta]  ghost button, borda --color-border
  ─────────────────────────────────
  Ou entrar com:
  [Google]  [Apple]   surface buttons com ícone
```

### 3.2 Mapa de Transporte (tela principal)
```
bg: --color-bg
AppBar: cidade selecionada + ícone settings
  ┌──────────────────────────────────────────────┐
  │  [chips das linhas — backdrop blur]           │
  │  L1 L2 L3 L4 L5 …  (scroll horizontal)       │
  ├──────────────────────────────────────────────┤
  │                                              │
  │   MAPA ESQUEMÁTICO INTERATIVO                │
  │   - InteractiveViewer, constrained: false    │
  │   - Canvas 2400×1800                         │
  │   - Pinch/pan livre                          │
  │   - Linha selecionada: zoom animado          │
  │   - Estações: círculos coloridos             │
  │   - Labels: aparecem ao zoom (scale ≥ 0.35) │
  │                                              │
  └──────────────────────────────────────────────┘
Estado zoomed-in (linha selecionada):
  - Outras linhas ficam opacas (30%)
  - Barra de capacidade aparece em cada estação
  - Ícone de trem pulsante na posição estimada
```

### 3.3 Detalhe de Estação (bottom sheet)
```
Bottom sheet (drag handle, --color-surface, radius-xl no topo)
  Nome da estação (--font-size-xl, bold)
  Linha: chip colorido com nome
  ──────────────────────────────────────
  Lotação agora
  [████░░░] Moderada  (cor crowd-moderate)
  ──────────────────────────────────────
  Próximo trem
  Sentido Vila Prudente: ~4 min
  Sentido Tucuruvi:      ~7 min
  ──────────────────────────────────────
  Conexões
  [chip L2] [chip L4]  (se for estação de transferência)
  ──────────────────────────────────────
  [Notificar quando lotar]  (botão ghost, --color-accent)
```

### 3.4 Settings
```
bg: --color-surface
  Seção: Conta
    Avatar + nome + e-mail
    [Gerenciar assinatura]
  ──────────────────────────────────────
  Seção: Preferências
    Cidade padrão          [São Paulo ▼]
    Tema                   [Escuro | Claro | Auto]
    Notificações           [toggle]
  ──────────────────────────────────────
  Seção: Sobre
    Versão do app
    Política de privacidade
    Termos de uso
  ──────────────────────────────────────
  [Sair da conta]  (texto danger)
```

### 3.5 Paywall (Premium)
```
bg: gradiente --color-bg → #0D1228
  Logo + "Trilho Premium"
  ──────────────────────────────────────
  Benefícios (lista com ícones --color-accent):
  ✦ Estimativa de chegada do trem
  ✦ Alertas de lotação em tempo real
  ✦ Acesso web completo
  ✦ Histórico de rotas
  ──────────────────────────────────────
  Planos:
  [ Mensal  R$ 9,90 ]   [ Anual  R$ 79,90 ← Melhor valor ]
  ──────────────────────────────────────
  [Assinar agora]  bg gradient primary→accent
  [Continuar grátis]  link --color-text-secondary
  Renovação automática · Cancele quando quiser
```

### 3.6 City Picker
```
bg: --color-bg
AppBar: "Escolher cidade" + [X]
  [Buscar cidade...]  (search field, --color-surface)
  ──────────────────────────────────────
  Recentes
  ● São Paulo    metrô + CPTM
  ──────────────────────────────────────
  Disponíveis
  ● São Paulo    metrô + CPTM
  ● Rio de Janeiro  metrô (em breve)  (--color-text-disabled)
  ● Brasília     metrô (em breve)     (--color-text-disabled)
```

---

## 4. Website Next.js

### Stack e estrutura
- Framework: Next.js App Router
- Styling: Tailwind CSS + CSS custom properties (tokens acima)
- Modo padrão: dark; suporte a light via `prefers-color-scheme` ou toggle manual

### 4.1 Landing Page (zona pública)

**Nav:**
- Logo (símbolo + wordmark) à esquerda
- Links: Funcionalidades · Preços
- Botão "Entrar" ghost à direita

**Hero (full-viewport):**
- Background: `--color-bg` com mapa esquemático SVG animado (linhas pulsando via CSS keyframes)
- H1: "Mobilidade em tempo real." — Inter ExtraBold, 48px desktop / 32px mobile
- Subtítulo: "Saiba antes de sair de casa se o metrô está lotado."
- CTAs: [Baixar iOS] [Baixar Android] [Abrir na web]

**Status Ticker:**
- Faixa horizontal `--color-surface`
- Status de cada linha em tempo real (SSE ou polling 30s)
- Rolagem automática horizontal

**Features (3 colunas):**
- Ícone SVG + título + descrição curta
- Lotação ao vivo · Próximo trem · Alertas de incidentes

**Mapa Preview:**
- Screenshot estático do mapa de São Paulo em dark mode
- Caption: "Veja todas as linhas num relance"

**Preços (2 cards):**
| Gratuito | Premium R$ 9,90/mês |
|---|---|
| Lotação ao vivo | Tudo do grátis + |
| Mapa esquemático | Estimativa de chegada |
| Alertas básicos | Notificações push |
| — | Acesso web completo |
| [Baixar grátis] | [Assinar agora] |

Card Premium: borda `--color-accent`, badge "Mais popular"

**Footer:**
- Logo + links legais + redes sociais

### 4.2 Web App (zona premium autenticada)

**Layout desktop (sidebar + mapa):**
- Sidebar 240px: lista de linhas com chips coloridos, filtro, status geral
- Área principal: mapa SVG interativo (React, zoom/pan via transform)
- Detail panel (slide-in): detalhe da estação clicada — lotação, próximo trem, conexões

**Layout mobile:**
- Sidebar vira bottom sheet
- Mapa ocupa 100vw
- Detail panel substitui o mapa com animação slide-up

**Autenticação:**
- Rota protegida via middleware Next.js
- Redirect para `/login` se sem sessão
- Login: Firebase Auth (e-mail + Google + Apple)

---

## 5. Componentes compartilhados

| Componente | Flutter | Web |
|---|---|---|
| CrowdBar | `CrowdBarWidget` | `<CrowdBar />` |
| LineChip | `LineChipWidget` | `<LineChip />` |
| StationDot | via `TransitMapPainter` | SVG circle |
| StatusBadge | `StatusBadge` | `<StatusBadge />` |
| PrimaryButton | `ElevatedButton` customizado | `<Button variant="primary" />` |
| GhostButton | `OutlinedButton` customizado | `<Button variant="ghost" />` |

---

## 6. Acessibilidade

- Contraste mínimo WCAG AA em todos os textos sobre fundos (`--color-text-primary` sobre `--color-bg`: 15:1)
- Chips de linha incluem label de texto (não apenas cor)
- Bottom sheets e modais acessíveis via `Semantics` no Flutter e `role="dialog"` na web
- Modo claro disponível para usuários com `prefers-color-scheme: light`

---

## 7. Fora de escopo

- Animações Lottie / Rive (fase posterior)
- Onboarding tutorial
- Modo offline completo
- Tema por linha de metrô individual
