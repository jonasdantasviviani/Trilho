# Trilho

Trilho é um app Flutter + .NET 8 que indica em tempo real o nível de lotação de trens, metrô e ônibus. Inicialmente focado em São Paulo, projetado para funcionar em qualquer cidade com transporte público.

## Status do Projeto

| Fase | Status |
|------|--------|
| Fase 0 - Backend MVP | ✅ Concluída |
| Fase 1 - App Flutter | ✅ Concluída (configuração pendente) |
| Fase 2 - Crowdsourcing GPS | ⏳ Pendente |
| Fase 3 - Qualidade de Dados | ⏳ Pendente |
| Fase 4 - Expansão | ⏳ Pendente |

## Stack

| Camada | Tecnologia |
|--------|-----------|
| Mobile | Flutter 3.x + Riverpod + go_router |
| Maps | Google Maps Flutter |
| Real-time | SignalR (`signalr_netcore`) |
| Monetização | RevenueCat + AdMob |
| Storage local | Hive + flutter_secure_storage |
| Backend | ASP.NET Core 8 Minimal API |
| ORM | EF Core 8 + PostgreSQL/PostGIS |
| Cache | Redis |
| Workers | .NET BackgroundService |
| Infra | Docker Compose |
| Web/Admin | Next.js 14 (opcional) |

## Pré-requisitos

- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8)
- [Flutter SDK 3.19+](https://flutter.dev/docs/get-started/install) (opcional para backend-only)
- [Docker Desktop](https://docker.com/products/docker-desktop)

## Quick Start

### Setup Automático (Windows)

```powershell
.\scripts\setup.ps1
```

### Setup Manual

#### 1. Configurar variáveis de ambiente

```bash
# Windows
copy .env.example .env

# Edite .env:
# OLHOVIVO_TOKEN — cadastre em sptrans.com.br/desenvolvedores (gratuito)
# JWT_SECRET     — string aleatória 32+ chars
```

#### 2. Iniciar infraestrutura

```bash
docker-compose up -d db redis
```

#### 3. Backend (.NET)

```bash
cd backend
dotnet run --project Trilho.API
```

API: `http://localhost:5000` | Swagger: `http://localhost:5000/swagger` | Health: `http://localhost:5000/health`

#### 4. Flutter App

```bash
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000
```

> `10.0.2.2` é o localhost do emulador Android. Para iOS Simulator use `127.0.0.1`.

#### 5. Stack completa com Docker

```bash
docker-compose up --build
```

## Testes

### Backend

```bash
cd backend
dotnet test
```

**27 testes** cobrindo:
- CrowdInferenceEngine (11 testes)
- Seed de linhas e estações (8 testes)
- Endpoints admin (4 testes)
- Firebase auth (1 teste)
- VIP access (3 testes)

### Carga (TODO)

```bash
# Locust
locust -f tests/load/stations.js --host=http://localhost:5000
```

## Checklist de Configuração

### Obrigatório

- [ ] Token OlhoVivo: [sptrans.com.br/desenvolvedores](https://www.sptrans.com.br/desenvolvedores)
- [ ] Gerar JWT_SECRET: `openssl rand -base64 32`

### Google Cloud Console

- [ ] Criar projeto
- [ ] Habilitar Maps SDK Android
- [ ] Habilitar Maps SDK iOS
- [ ] Criar API key com restrições
- [ ] Copiar key para:
  - `mobile/android/app/src/main/AndroidManifest.xml`
  - `mobile/ios/Runner/Info.plist`

### AdMob

- [ ] Criar app Android
- [ ] Criar app iOS
- [ ] Criar unidade de banner
- [ ] Criar unidade de interstitial
- [ ] Atualizar `mobile/lib/core/constants.dart`

### RevenueCat

- [ ] Criar app Android
- [ ] Criar app iOS
- [ ] Criar produto `trilho_premium_monthly` (R$9,90/mês)
- [ ] Atualizar `mobile/lib/core/constants.dart`

### Firebase (opcional - social login)

- [ ] Criar projeto
- [ ] Adicionar Android e iOS apps
- [ ] Configurar Google Sign-in
- [ ] Configurar Apple Sign-in
- [ ] Baixar google-services.json e GoogleService-Info.plist

## Arquitetura

```
Trilho/
├── backend/
│   ├── Trilho.sln
│   ├── Trilho.Domain/           # Entities, enums, interfaces
│   ├── Trilho.Infrastructure/    # EF Core, scrapers, workers, seeds
│   ├── Trilho.API/              # Minimal API + SignalR hub
│   └── Trilho.Tests/            # xUnit + FluentAssertions
├── mobile/
│   ├── android/                 # Configuração Android
│   ├── ios/                     # Configuração iOS
│   └── lib/
│       ├── core/                # models, services, providers, constants
│       └── features/            # map, line_detail, station_detail, paywall, settings
├── web/                         # Next.js landing page (opcional)
├── admin/                       # Next.js admin dashboard (opcional)
├── docker-compose.yml
├── scripts/                     # setup.ps1, setup.bat, deploy.sh
├── ROADMAP.md
└── README.md
```

## API Endpoints

### Autenticação

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| POST | `/api/auth/register` | Registro anônimo |
| POST | `/api/auth/firebase` | Auth via Firebase token |
| POST | `/api/auth/social` | Marcar como social auth |

### Usuário

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| GET | `/api/users/me/usage` | Usage do usuário (queries/dia) |
| POST | `/api/users/premium/verify` | Verificar subscription premium |

### Linhas

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| GET | `/api/lines` | Lista todas as linhas |
| GET | `/api/lines/{code}/status` | Status operacional |
| GET | `/api/lines/{code}/stations` | Estações da linha |
| GET | `/api/lines/{code}/vehicles` | Posição dos veículos |

### Estações

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| GET | `/api/stations` | Lista todas as estações |
| GET | `/api/stations/{id}/crowd` | Lotação atual + histórico |
| GET | `/api/stations/{id}/forecast` | Previsão próxima hora |

### SignalR Hub

| Event | Descrição |
|-------|-----------|
| `SubscribeToLine` | Inscreve em atualizações de linha |
| `UnsubscribeFromLine` | Cancela inscrição |
| `OnCrowdUpdate` | Recebe atualização de lotação |

## Fontes de Dados

| Fonte | Dados | Intervalo |
|-------|-------|-----------|
| SPTrans OlhoVivo API | Posição ônibus em tempo real | 30s |
| Metrô SP (scraping) | Status linhas 1–5, 15 | 2 min |
| CPTM (scraping) | Status linhas 7–13 | 2 min |
| Cittamobi (TODO) | Posição trens CPTM | 30s |
| PDFs Metrô SP (seed) | Histórico de passageiros | — |

## Inferência de Lotação

```
crowdScore = (historical_avg_passengers / station_capacity) × operational_weight

operational_weight:
  Normal        → 1.0
  ReducedSpeed  → 1.4
  Partial       → 1.8
  Suspended     → 2.5

score → level:
  < 0.30 → Low     (Tranquilo)
  < 0.60 → Medium  (Moderado)
  < 0.85 → High    (Cheio)
  ≥ 0.85 → Packed  (Lotado)
```

## Monetização

| Plano | Consultas/dia | Anúncios |
|-------|--------------|----------|
| Anônimo | 5 total | Banner + interstitial |
| Gratuito | 3/dia | Banner + interstitial |
| Premium (R$9,90/mês) | Ilimitado | Sem anúncios |

## Variáveis de Ambiente

| Variável | Descrição | Obrigatório |
|----------|-----------|-------------|
| `OLHOVIVO_TOKEN` | Token SPTrans OlhoVivo API | Sim |
| `JWT_SECRET` | Chave JWT (min 32 chars) | Sim |
| `POSTGRES_HOST` | Host PostgreSQL | Dev local |
| `POSTGRES_PORT` | Porta PostgreSQL | Dev local |
| `REDIS_HOST` | Host Redis | Dev local |
| `REDIS_PORT` | Porta Redis | Dev local |

## Deploy

### Vercel (Web/Admin)

```bash
vercel --prod
```

### Docker

```bash
docker-compose -f docker-compose.prd.yml up -d
```

## Licença

MIT
