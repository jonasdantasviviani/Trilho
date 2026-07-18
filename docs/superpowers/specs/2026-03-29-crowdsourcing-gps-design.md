# Spec: Crowdsourcing GPS — Trilho

**Data:** 2026-03-29
**Status:** Aprovado
**Milestone:** 2 — Crowdsourcing + Pagamentos

---

## Visão Geral

Usuários do app Trilho (autenticados ou anônimos) contribuem passivamente com dados de ocupação ao entrar em estações de metrô/CPTM. O app detecta a proximidade via geofencing em background e envia as coordenadas GPS ao backend. O backend resolve a estação mais próxima via PostGIS e registra o ping. O `CrowdDensityWorker` consolida os pings periodicamente e ajusta o `crowdScore`.

---

## Estado Atual — O que já existe

### Backend (implementado)

| Componente | Arquivo | Estado |
|-----------|---------|--------|
| Entidade `UserPing` | `Trilho.Domain/Entities/UserPing.cs` | ✅ Existe |
| `POST /api/users/pings` | `Trilho.API/Endpoints/PingEndpoints.cs` | ✅ Existe |
| `GET /api/stations/nearby` | `Trilho.API/Endpoints/PingEndpoints.cs` | ✅ Existe |
| `CrowdDensityWorker` | `Trilho.Infrastructure/Workers/CrowdDensityWorker.cs` | ✅ Existe |
| `UserPingCleanupWorker` | `Trilho.Infrastructure/Workers/UserPingCleanupWorker.cs` | ✅ Existe |
| Migration `user_pings` | Migrations iniciais | ✅ Existe |

### Flutter (a implementar)

| Componente | Estado |
|-----------|--------|
| Pacote `geofence_service: ^5.0.0` | ✅ Em `pubspec.yaml` |
| `GeofenceService` (classe Flutter) | ❌ Não existe |
| `ApiService.postPing()` | ❌ Não existe |
| Inicialização em `main.dart` | ❌ Não existe |
| Permissões de localização (Android/iOS) | ❌ Não configuradas |

---

## Arquitetura

```
Flutter (background geofence)
  → detecta entrada no raio configurado (default 300 m)
  → POST /api/users/pings  { lat, lng, timestamp }  (JWT obrigatório)
      → backend resolve estação via PostGIS (raio 200 m)
      → persiste UserPing { UserId, StationId, CreatedAt }

UserPingCleanupWorker (a cada 5 min)
  → deleta pings com CreatedAt < agora - 10 min

CrowdDensityWorker (a cada 2 min)
  → conta pings dos últimos 15 min por estação
  → calcula pingBoost e grava novo CrowdSnapshot { Source = UserPing }
```

**Separação entre os dois workers:**

| Worker | Frequência | Responsabilidade |
|--------|-----------|-----------------|
| `CrowdInferenceWorker` | 1 min | Grava snapshots históricos a partir de GTFS + OperationalStatus. Source = Historical |
| `CrowdDensityWorker` | 2 min | Lê pings recentes e grava snapshots ajustados. Source = UserPing |
| `UserPingCleanupWorker` | 5 min | Limpa pings expirados (TTL = 10 min) |

---

## Modelo de Dados

### Entidade `UserPing` (já existe)

```csharp
public class UserPing {
    public long Id { get; set; }
    public Guid UserId { get; set; }
    public User User { get; set; } = null!;
    public int StationId { get; set; }
    public Station Station { get; set; } = null!;
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
```

Não é necessária nova migration. A tabela `user_pings` já existe.

---

## Endpoint: POST /api/users/pings (já existe)

### Request
```
POST /api/users/pings
Authorization: Bearer <jwt>
Content-Type: application/json

{
  "lat": -23.5505,
  "lng": -46.6333,
  "timestamp": "2026-03-29T14:00:00Z"
}
```

O backend resolve a estação mais próxima via PostGIS dentro de **200 m**. Se nenhuma estação for encontrada, retorna `200 OK` com `{ "registered": false }` — ping ignorado silenciosamente.

### Respostas

| Status | Cenário |
|--------|---------|
| `200 OK { stationId, stationName, registered: true }` | Ping registrado |
| `200 OK { registered: false }` | Nenhuma estação no raio de 200 m |
| `401 Unauthorized` | JWT ausente ou expirado |

---

## Fórmula de Ajuste (CrowdDensityWorker)

Abordagem **C — pings ajustam o score aditivamente**: o score base vem do snapshot histórico mais recente (`CrowdSource.Historical`), pings adicionam um boost proporcional à contagem.

```csharp
// CalculatePingBoost(int pingCount)
if (pingCount < 5) return 0;
double normalizedPings = pingCount / 10.0;
double densityBoost = normalizedPings * 0.05;
return Math.Min(densityBoost, MaxPingBoost);  // MaxPingBoost = 0.15

// Aplicação
decimal adjustedDensity = Math.Min(baseDensity + (decimal)pingBoost, 1.0m);
```

**Exemplos práticos:**

| pingCount (15 min) | pingBoost | Efeito no score |
|---------------------|-----------|-----------------|
| 0–4 | 0 | Sem mudança |
| 5 | +2.5% | Leve |
| 10 | +5% | Moderado |
| 20 | +10% | Alto |
| 30+ | +15% (máximo) | Saturação |

O resultado é um novo `CrowdSnapshot` com `Source = CrowdSource.UserPing`. O `CrowdInferenceWorker` continua gravando snapshots `Historical` independentemente — são tipos de snapshot distintos.

---

## Flutter — GeofenceService (a implementar)

### Responsabilidades

1. Solicitar permissão de localização `Always` (background)
2. Carregar estações via `ApiService.getStations()` no boot
3. Criar geofences com raio de **300 m** por estação (margem acima dos 200 m do backend)
4. Escutar `GeofenceStatus.ENTER`
5. Chamar `ApiService.postPing(lat, lng)` ao entrar

### Por que 300 m no Flutter vs. 200 m no backend?

O Flutter detecta a entrada com 300 m para garantir que o usuário ainda esteja dentro dos 200 m do backend quando o ping for processado, compensando latência de GPS em background e delay de rede.

### Permissões

| Plataforma | Permissão necessária |
|-----------|---------------------|
| Android | `ACCESS_BACKGROUND_LOCATION` + `ACCESS_FINE_LOCATION` |
| iOS | `NSLocationAlwaysAndWhenInUseUsageDescription` (modo Always) |

Se a permissão não for concedida, o `GeofenceService` não inicia. Nenhuma mensagem de erro é exibida ao usuário (feature silenciosa).

### Background Isolate

O pacote `geofence_service` gerencia o background isolate nativamente. O app pode estar fechado — o sistema operacional acorda o isolate ao detectar a entrada no geofence.

---

## Regras de Negócio

### RN-01 — Contribuição universal
Todo usuário com JWT válido (anônimo ou autenticado via Firebase) pode enviar pings. Não há distinção de nível de assinatura.

### RN-02 — Resolução por proximidade no backend
O cliente envia apenas coordenadas GPS. O backend é responsável por identificar a estação correta via PostGIS. O cliente não conhece o `stationId`.

### RN-03 — Raio backend = 200 m
Se o usuário estiver a mais de 200 m de qualquer estação, o ping é aceito (200 OK) mas descartado sem registro (`registered: false`).

### RN-04 — Raio Flutter = 300 m
O geofence no app é criado com raio 300 m para garantir sobreposição com os 200 m do backend, compensando imprecisão de GPS em background.

### RN-05 — Janela de relevância = 15 min
O `CrowdDensityWorker` contabiliza apenas pings criados nos últimos **15 minutos**. Pings mais antigos existem na tabela mas não influenciam o score.

### RN-06 — TTL de pings = 10 min
O `UserPingCleanupWorker` deleta pings com mais de 10 minutos a cada 5 min. Isso limita o crescimento da tabela.

### RN-07 — Threshold mínimo = 5 pings
Pings de 1 a 4 usuários na mesma estação em 15 min não geram nenhum boost. O boost começa apenas a partir de 5 pings.

### RN-08 — Boost máximo = +15%
O boost de pings nunca pode elevar o `InferredDensity` em mais de +15 pontos percentuais acima do score histórico base. Valor final nunca ultrapassa 1.0.

### RN-09 — Pings só aumentam o score
A fórmula é monotonicamente crescente. A ausência de pings não penaliza o histórico. Score mínimo = score histórico do momento.

### RN-10 — Sem rate-limit por usuário (comportamento atual)
O backend não aplica rate-limit por usuário. Um usuário pode enviar múltiplos pings na mesma estação dentro de 15 min e todos serão contados. Isso é tolerado pela abordagem estatística: o boost é limitado pelo `MaxPingBoost` independente de quantos pings existam.

### RN-11 — Feature silenciosa
O usuário não vê notificações, alertas ou confirmações quando um ping é enviado. A coleta é totalmente transparente.

### RN-12 — Falhas no cliente são silenciosas
Se o ping falhar por falta de conexão ou qualquer erro de rede, é descartado sem retry. A natureza estatística do crowdsourcing tolera perda ocasional de pings.

### RN-13 — Sem snapshot histórico = ping ignorado no score
Se o `CrowdDensityWorker` não encontrar um `CrowdSnapshot` histórico (`Source = Historical`) para a estação, o ping é ignorado no cálculo do score. O ping é registrado na tabela, mas não gera novo snapshot ajustado.

### RN-14 — Recarregamento de estações
As estações são carregadas uma vez no boot do app. Atualizações no cadastro de estações refletem na próxima inicialização do app.

---

## Error Handling

| Cenário | Comportamento |
|---------|--------------|
| Usuário fora de qualquer estação (> 200 m) | Backend retorna `200 OK { registered: false }`, Flutter ignora |
| Sem conexão no momento do ping | Descartado (sem fila local de retry) |
| Token JWT expirado | Backend retorna 401, interceptor do `ApiService` faz refresh automático (mecanismo existente) |
| App sem permissão de localização Always | `GeofenceService` não inicia, sem feedback ao usuário |
| Estação sem snapshot histórico | Ping registrado, boost não aplicado naquela rodada do Worker |

---

## Testes

### Backend — Unitários

- `CalculatePingBoost(0)` → 0
- `CalculatePingBoost(4)` → 0
- `CalculatePingBoost(5)` → 0.025
- `CalculatePingBoost(10)` → 0.05
- `CalculatePingBoost(30)` → 0.15 (máximo)
- `CalculatePingBoost(100)` → 0.15 (saturado)
- `adjustedDensity` com `baseDensity = 0.9` e `pingBoost = 0.15` → 1.0 (não ultrapassa)

### Backend — Integração

- `POST /api/users/pings` com coords válidas dentro de 200 m → 200 OK, `registered: true`, ping gravado
- `POST /api/users/pings` com coords fora de 200 m → 200 OK, `registered: false`, nenhum ping gravado
- `POST /api/users/pings` sem JWT → 401
- `GET /api/stations/nearby` retorna estações ordenadas por distância

### Flutter

- Mock de `GeofenceService`: simula `ENTER` em estação conhecida → verifica chamada a `ApiService.postPing(lat, lng)`
- Simula falha de rede no `postPing` → verifica que nenhuma exceção se propaga ao usuário
- Verifica que `GeofenceService` não inicia quando permissão negada
