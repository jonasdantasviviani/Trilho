# Trilho — Roadmap

## Legenda
- ✅ Concluído
- 🚧 Em progresso
- ⏳ Pendente
- ❌ Bloqueado

---

## Fase 0 — Fundação (Backend MVP)

- ✅ Solução .NET 8 criada (`Trilho.sln` com Domain / Infrastructure / API / Tests)
- ✅ Domain entities + enums + interfaces
- ✅ EF Core + PostGIS + AppDbContext + DesignTimeFactory
- ✅ Seed de todas as linhas de SP (Metrô + CPTM)
- ✅ Seed de estações com coordenadas reais
- ✅ Seed histórico de demanda (curva horária sintética por tipo de dia)
- ✅ Docker Compose funcional (API + PostGIS 16 + Redis 7)
- ✅ Worker scraping Metrô SP (status das linhas, a cada 2 min)
- ✅ Worker scraping CPTM (status das linhas, a cada 2 min)
- ✅ Worker OlhoVivo polling ônibus (a cada 30 s) → Redis cache
- ✅ Worker inferência de lotação CrowdInferenceEngine (a cada 1 min)
- ✅ Worker limpeza de UserPings (TTL 10 min)
- ✅ Endpoints REST (stations/crowd, stations/forecast, lines, lines/status, lines/vehicles)
- ✅ SignalR hub CrowdHub (subscribe por lineCode)
- ✅ JWT auth anônimo (UUID sem PII — LGPD compliant)
- ✅ Polly retry (3 tentativas, backoff exponencial) em todos os HTTP clients
- ✅ EF Migrations aplicadas (InitialCreate + 4 migrations subsequentes)
- ✅ Build .NET sem warnings
- ✅ Token OlhoVivo configurado

## Fase 1 — App Flutter

- ✅ Scaffold Flutter (`mobile/`) com pubspec.yaml
- ✅ Models (Line, Station, Crowd, Usage, City)
- ✅ ApiService (Dio) + AuthService (JWT + SecureStorage)
- ✅ UsageTracker (Hive — 3 queries/dia gratuitas)
- ✅ RevenueCatService (purchase + restore)
- ✅ AdMobService (banner + interstitial)
- ✅ Riverpod providers (lines, crowd, usage, SignalR)
- ✅ go_router com 5 rotas
- ✅ MapScreen com line chips e Google Maps
- ✅ LineDetailScreen (status banner + lista de estações com densidade)
- ✅ StationDetailScreen (gate freemium + CrowdChart fl_chart + AdMob banner)
- ✅ PaywallScreen (RevenueCat + restore)
- ✅ SettingsScreen (usage + premium status + privacidade LGPD)
- ✅ LoginScreen + WelcomeScreen + CityPicker
- ✅ AndroidManifest.xml criado com permissões e placeholder Google Maps API key
- ✅ Info.plist criado com permissões iOS e placeholder Google Maps API key
- ✅ Estrutura Android build.gradle.kts criada
- ✅ Estrutura iOS Runner criada
- ✅ Google Maps API Key configurada (Android + iOS)
- ⏳ Executar `flutter pub get` após instalar Flutter SDK
- ⏳ Executar `flutter build` para gerar apps nativos
- ⏳ Configurar AdMob IDs reais
- ⏳ Configurar RevenueCat API keys

## Fase 2 — Crowdsourcing GPS

- ✅ Ping endpoint (`POST /api/users/pings`) com geofencing
- ✅ Endpoint de estações próximas (`GET /api/stations/nearby`)
- ✅ CrowdDensityWorker - ajuste de lotação com base em densidade de pings
- ✅ GeofenceService no mobile (integração com `geofence_service`, pings por ENTER, testes unitários)
- ⏳ Ajuste fino do boost de pings baseado emvalidação real

## Fase 3 — Qualidade de Dados

- ✅ GtfsImportWorker (download semanal GTFS estático SPTrans)
- ✅ Entidades GTFS (Agency, Route, Stop, Trip, StopTime, Calendar)
- ✅ CsvHelper para parsing de arquivos GTFS
- ✅ CitamobiProvider com mock e estrutura para API real
- ✅ TrainPositionWorker (busca posições a cada 30s → Redis cache)
- ✅ Endpoints train positions (`/api/trains/positions`, `/api/lines/{code}/vehicles`)
- ✅ Script mitmproxy para captura de requests (`scripts/cittamobi_capture.py`)
- ✅ Documentação de reverse engineering (`docs/CITTAMOBI_INTEGRATION.md`)
- ⏳ Descobrir endpoints reais via mitmproxy
- ⏳ GTFS-Realtime SPTrans (feed em tempo real)

## Monetização — AbacatePay

- ✅ AbacatePayModels.cs (DTOs para billing, customer, webhook)
- ✅ AbacatePayService.cs (create billing, get billing, mock mode)
- ✅ PaymentEndpoints.cs (`POST /api/payments/create-billing`, `POST /api/payments/webhook`, `GET /api/payments/billing/{id}`)
- ✅ User entity: TaxId, ActiveBillingId, IsPremiumUntil
- ✅ AbacatePayService DI registration
- ✅ Flutter abacate_pay_service.dart
- ✅ PaymentService unificado (RevenueCat + AbacatePay)
- ✅ PaywallScreen com fluxo de pagamento e polling
- ✅ usage_provider e usage_tracker atualizados
- ✅ Gerenciamento de assinatura (cancelar, reativar, trocar plano)
- ✅ Admin Dashboard: Página de assinaturas com stats e ações
- ✅ Flutter: SubscriptionScreen com histórico e ações
- ✅ SubscriptionService com endpoints completos
- ⏳ Testar webhook localmente (ngrok)
- ⏳ Configurar AbacatePay API key real

## Fase 4 — Expansão

- ✅ Entidade City para suporte multi-cidade
- ✅ Seed de 4 cidades (SP, RJ, BH, Curitiba)
- ✅ Cidade SP ativa, demais marcadas como `IsActive = false`
- ⏳ Ônibus municipais completo (OlhoVivo full)
- ✅ Notificações push (FCM) - backend completo
- ✅ Widget iOS/Android - estrutura criada
- ⏳ Ativar RJ, BH, Curitiba quando dados disponíveis

## FCM - Notificações Push

- ✅ FcmService.cs (backend) - Firebase Admin SDK
- ✅ NotificationWorker.cs - envia alertas quando status muda
- ✅ NotificationEndpoints.cs - registrar/descartar tokens
- ✅ UserDeviceToken entity - múltiplos dispositivos
- ✅ fcm_service.dart (Flutter) - receber notificações
- ✅ Endpoint subscribe/unsubscribe linhas
- ⏳ Configurar Firebase credentials (google-services.json)
- ⏳ Configurar APNs iOS

## Widgets Mobile

- ✅ Widget Android - TrilhoWidgetProvider (Kotlin)
- ✅ Layout e recursos Android (xml, drawable)
- ✅ Widget iOS - WidgetKit (Swift)
- ✅ TrilhoWidgetBundle.swift
- ✅ widget_service.dart (Flutter)
- ✅ home_widget package
- ⏳ App Groups configurados (iOS)
- ⏳ Testar widget no dispositivo

## Milestone 3 — UX Polish

- ✅ AppLoading.spinner() e AppLoading.skeleton() com shimmer animado
- ✅ AppError com mensagem amigável e botão de retry
- ✅ AppEmpty com ícone + título + subtítulo opcional
- ✅ app_theme_constants: kAnimFast, kAnimNormal, fadeSwitch()
- ✅ AnimatedSwitcher com FadeTransition em todas as telas (LineDetail, StationDetail, Settings, Map)
- ✅ ScaleTransition + FadeTransition na confirmação de pagamento (PaywallScreen)
- ✅ Nenhum `Text('Erro: $e')` exposto ao usuário
- ✅ Nenhum `SizedBox.shrink()` em posição de erro (falha silenciosa eliminada)
- ✅ 13 testes de widget (AppLoading, AppError, AppEmpty)

---

## Status do Projeto

| Fase | Status | Testes |
|------|--------|--------|
| Fase 0 - Backend MVP | ✅ Concluída | 27/27 ✅ |
| Fase 1 - App Flutter | ✅ Concluída | — |
| Fase 2 - Crowdsourcing | ✅ Concluída | — |
| Fase 3 - Qualidade Dados | 🚧 85% | — |
| Fase 4 - Expansão | 🚧 60% | — |
| Milestone 3 - UX Polish | ✅ Concluída | 13/13 ✅ |

---

## Fase 5 — Observabilidade e Resiliência de Dados

> **Motivação:** Scrapers quebram sem aviso. Redis pode conter dados stale. O app precisa ser transparente sobre a qualidade dos dados que exibe — confiabilidade *é* o produto.

- ⏳ `DataSourceHealthStatus` por fonte (Healthy / Degraded / Stale / Down) — exposto no admin
- ⏳ Timestamp de coleta explícito em todo dado cacheado no Redis (TTL + `capturedAt`)
- ⏳ Circuit breaker por scraper (Polly `CircuitBreakerAsync`) — em adição ao retry existente
- ⏳ Dead letter queue + alerta (Telegram bot) quando circuit abre
- ⏳ Throttling defensivo OlhoVivo (máx X req/min; rate limits não são documentados publicamente)
- ⏳ Stack de observabilidade: OpenTelemetry + Prometheus + Grafana no docker-compose
- ⏳ Métricas: `trilho.data.freshness_seconds` por linha, `scraper.success_rate`, SignalR connections, Redis hit rate
- ⏳ Alertas: dado sem atualização >10 min → alerta; worker com falha >3x → alerta crítico
- ⏳ SignalR Redis backplane configurado para suporte multi-instância (`AddStackExchangeRedis`)
- ✅ App Flutter exibe "Dado com X min de atraso" quando `capturedAt` >5 min

---

## Fase 6 — Engajamento e Crescimento Orgânico

> **Motivação:** Produto sem distribuição é hobby. Crescimento orgânico é o canal mais eficiente para apps de utilidade pública.

- ⏳ Notificações proativas inteligentes: "Sua linha vai lotar em 20 min — saia agora" (lógica de triggers baseada em histórico do usuário + horário habitual + estação favorita)
- ⏳ Estação/linha favorita por usuário (persisted via Hive + backend)
- ⏳ Compartilhamento social: card "Linha 3-Vermelha está um caos agora 🔴" compartilhável no WhatsApp/X
- ⏳ Mapa de calor histórico: "Qual o melhor horário para pegar a Linha 2 sem lotação?" (dados já existem)
- ⏳ Feedback do crowdsourcing: "Sua avaliação ajudou X pessoas hoje" + badge simples
- ⏳ Widget configurável por linha favorita (estrutura já existe, falta configuração)
- ⏳ Onboarding: mostrar mapa funcionando *antes* de pedir cadastro
- ⏳ Widget com timestamp visível (dado stale no widget é pior que não ter widget)

---

## Fase 7 — Integração CPTM e Dados de Qualidade

> **Motivação:** CPTM carrega ~800k passageiros/dia e cobre Grande SP. Sem posição real dos trens CPTM, o app é incompleto para metade dos usuários.

- ⏳ Contato formal com CPTM para API oficial (precedente: OlhoVivo da SPTrans). Tentar parceria antes de reverse engineering.
- ⏳ Fallback: triangulação por crowdsourcing GPS de usuários ativos nas linhas CPTM
- ⏳ Cittamobi: **consultar advogado sobre ToS antes de qualquer reverse engineering** (risco legal: Lei 9.609/98 + concorrência desleal)
- ⏳ GTFS-Realtime SPTrans (feed em tempo real)
- ⏳ Antifraude no crowdsourcing: rejeitar reports com velocidade >30 km/h (não está na estação), duplicatas em <2 min, outliers >2σ da média recente, sistema de reputação por usuário

---

## Riscos Legais e de Compliance

> **Status: não endereçados. Resolver antes de qualquer lançamento público com monetização ativa.**

### LGPD (Lei 13.709/2018)
- ⏳ Privacy Policy pública (URL acessível antes do cadastro)
- ⏳ Consentimento granular e revogável para coleta de GPS
- ⏳ Endpoint `DELETE /api/users/me` para exclusão de todos os dados do usuário
- ⏳ Exportação de dados pessoais (`GET /api/users/me/data`)
- ✅ Diálogo de privacidade atualizado no app com direitos LGPD
- ✅ Pings de GPS com TTL de 10 min (exclusão automática)
- ✅ UUID anônimo sem PII

### Scraping e APIs de Terceiros
- ⏳ Verificar Termos de Uso da OlhoVivo API para uso comercial
- ⏳ Tentar formalizar parceria com Metrô SP e CPTM para dados (argumento: reduz sobrecarga nas centrais, melhora percepção do serviço, custo zero para eles)
- ⚠️ Scraping de Metrô SP e CPTM: verificar ToS. Parceria formal é preferível.
- ⚠️ Cittamobi reverse engineering: consultar advogado antes de executar.

---

## KPIs de Sucesso

> **Sem métricas, você não sabe se está progredindo ou se deve pivotar.**

### Métricas de produto
| KPI | Meta inicial | Meta crescimento |
|-----|-------------|-----------------|
| DAU (usuários ativos/dia) | 500 | 10.000 |
| Sessões por DAU | ≥ 2 | ≥ 3 |
| Retenção D7 | ≥ 25% | ≥ 40% |
| Retenção D30 | ≥ 10% | ≥ 20% |
| Anônimo → Cadastro (conversão) | ≥ 15% | ≥ 25% |
| Cadastro → Premium (conversão) | ≥ 2% | ≥ 5% |

### Métricas de negócio
| KPI | Meta sustentabilidade |
|-----|----------------------|
| Assinantes premium ativos | ≥ 1.000 (cobre infra + 1 pessoa) |
| MRR líquido (após take rate 30%) | ≥ R$ 6.930/mês |
| Churn mensal | ≤ 8% |

### Métricas de dados
| KPI | Meta |
|-----|------|
| Freshness média por linha | < 3 min |
| Uptime dos scrapers | ≥ 95% |
| Reports de crowdsourcing por dia | ≥ 200 (para Linha 3-Vermelha) |

---

## Unit Economics

> **Premissas conservadoras para verificar sustentabilidade.**

| Item | Valor |
|------|-------|
| Preço Premium | R$ 9,90/mês |
| Take rate (RevenueCat + Apple/Google) | ~30% |
| Receita líquida por assinante | ~R$ 6,93/mês |
| Infra mínima (VPS + banco + Redis + workers) | R$ 600–900/mês |
| Break-even infra | ~130 assinantes |
| Sustentabilidade (1 pessoa, salário mínimo) | ~1.000 assinantes |
| Conversão freemium típica (br) | 2–5% |
| MAU necessário para 1.000 pagantes | 20.000–50.000 |

---

## Go-to-Market — Primeiros 10.000 Usuários

> **Produto sem distribuição é hobby. A estratégia de crescimento é trabalho tão importante quanto o produto.**

### Fase 0 — Seed users (pré-lançamento)
- Recrutar 50–100 "embaixadores" em grupos de commuters SP no Telegram/WhatsApp por linha (ex: "Grupo Linha 3-Vermelha", "Grupo CPTM Linha 7")
- Objetivo: validar dados e gerar primeiros reports de crowdsourcing
- Argumento para adesão: "ajude a calibrar os dados, você recebe Premium grátis"

### Fase 1 — Lançamento orgânico
- Reddit r/saopaulo + r/brasil: post honesto "fiz um app de lotação de metrô SP"
- Twitter/X: thread semanal "situação das linhas em SP" (conteúdo gratuito que demonstra o produto)
- Compartilhamento social no app (card de linha compartilhável)
- Google Play / App Store: ASO para "metrô SP", "lotação trem SP", "transporte público São Paulo"

### Fase 2 — Parcerias
- Blogs e canais de transporte urbano (Mobilidade Sampa, SPUrbanismo)
- Grupos de commuters nas redes sociais com >5k membros
- Prefeitura SP / SPTrans: parceria de dados em troca de distribuição orgânica

### Fase 3 — B2B (explorar como canal de receita adicional)
- Dados de mobilidade para empresas com VT (onde funcionários moram, picos de uso)
- Incorporadoras e fundos imobiliários (acessibilidade real por bairro em horário de pico)
- Operadoras de transporte (SPTrans, Metrô SP pagam por analytics de demanda)
- Potencial: 3–5x a receita B2C com 10% do CAC

---

## Configuração Necessária (Antes de Rodar)

### 1. Variáveis de Ambiente
```bash
# Backend (.env)
OLHOVIVO_TOKEN=seu_token_sptrans
JWT_SECRET=sua_chave_32_chars_min
```

### 2. Google Cloud Console
- Habilitar Maps SDK Android e iOS
- Criar API key com restrições
- Adicionar ao AndroidManifest.xml e Info.plist

### 3. AdMob Console
- Criar app para Android e iOS
- Criar unidades de anúncio (banner, interstitial)
- Substituir IDs em `mobile/lib/core/constants.dart`

### 4. RevenueCat Dashboard
- Criar app para Android e iOS
- Criar produto `trilho_premium_monthly` (R$9,90/mês)
- Substituir API keys em `mobile/lib/core/constants.dart`

### 5. Firebase Console (opcional)
- Criar projeto para social login

---

## Sessões de Trabalho

### Sessão 1 — 2026-03-21
- Nome definido: **Trilho**
- Backend completo gerado
- Flutter app completo gerado
- Docker Compose configurado

### Sessão 2 — 2026-03-22
- Migrations EF Core verificadas
- FirebaseTokenValidator corrigido
- AndroidManifest.xml e Info.plist criados
- Estrutura Android/iOS criada

### Sessão 3 — 2026-03-22 (Continuação)
- **Backend:**
  - ✅ Ping endpoints (`POST /api/users/pings`, `GET /api/stations/nearby`)
  - ✅ CrowdDensityWorker - ajuste de lotação com pings
  - ✅ GtfsImportWorker - import GTFS estático SPTrans
  - ✅ Entidades GTFS (Agency, Route, Stop, Trip, StopTime, Calendar)
  - ✅ Entidade City para multi-cidade
  - ✅ Seed de 4 cidades (SP, RJ, BH, Curitiba)
  - ✅ Migration `AddCities` criada
  - ✅ Build sem warnings, 27/27 testes passando

- **Pendências:**
  1. Instalar Flutter SDK
  2. Cadastrar token OlhoVivo
  3. Configurar Google Maps API key
  4. Configurar AdMob e RevenueCat
  5. Integração Cittamobi (reverse engineering)
  6. GTFS-Realtime
  7. Dashboard admin
  8. FCM notifications
  9. Widgets iOS/Android
