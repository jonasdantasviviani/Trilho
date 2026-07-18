# UX Overhaul — Bugs funcionais + polish visual + redesign de telas

## Contexto

O app passou por uma migração completa de design system (tokens, temas, widgets). Este spec cobre a camada seguinte: bugs funcionais que impedem o uso correto do app, polish visual das telas pós-login que ainda usam cores hardcoded, e um redesign visual da SubscriptionScreen.

Todas as mudanças são no app Flutter (mobile). O web não é afetado.

---

## Escopo

### Bugs funcionais
1. **Dark mode** — o switch em Configurações não faz nada (callback vazio, sem provider)
2. **Tap nas estações do mapa** — toque no mapa não abre a tela de detalhe da estação
3. **Tap na linha (StationDetailScreen)** — cartões de direção não têm ação

### Visual
4. **TransitMapPainter** — cores hardcoded devem usar tokens do AppTheme

### UX pós-login
5. **Polish** — TransitMapScreen, EmailAuthScreen, AnonymousGateSheet
6. **Redesign** — SubscriptionScreen

---

## Design

### 1. Dark Mode

**Causa raiz:** `main.dart` tem `themeMode: ThemeMode.system` hardcoded. `SettingsScreen` tem `onChanged: (_) {}` vazio — nunca notifica nada.

**Solução:**

Adicionar `themeModeProvider` em `mobile/lib/core/providers/app_providers.dart`:

```dart
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
```

`main.dart` passa a observar o provider (o widget raiz vira `ConsumerWidget`):

```dart
themeMode: ref.watch(themeModeProvider),
```

`SettingsScreen` lê e escreve:

```dart
Switch(
  value: isDark,
  onChanged: (val) => ref.read(themeModeProvider.notifier).state =
      val ? ThemeMode.dark : ThemeMode.light,
)
```

**Persistência:** em `main()`, antes de `runApp()`, ler `SharedPreferences` (chave `theme_mode`) e inicializar o `ProviderScope` com override:

```dart
final prefs = await SharedPreferences.getInstance();
final saved = prefs.getString('theme_mode');
final initialMode = saved == 'dark'
    ? ThemeMode.dark
    : saved == 'light'
        ? ThemeMode.light
        : ThemeMode.system;

runApp(ProviderScope(
  overrides: [
    themeModeProvider.overrideWith((ref) => initialMode),
  ],
  child: const TrilhoApp(),
));
```

Ao mudar em `SettingsScreen`, persistir após atualizar o provider:
```dart
onChanged: (val) {
  final mode = val ? ThemeMode.dark : ThemeMode.light;
  ref.read(themeModeProvider.notifier).state = mode;
  SharedPreferences.getInstance().then(
    (p) => p.setString('theme_mode', val ? 'dark' : 'light'),
  );
},
```

**Teste:** montar `SettingsScreen` em dark → tap no switch → `themeModeProvider` muda para `ThemeMode.light`.

---

### 2. Tap nas estações do mapa

**Causa raiz:** o `CustomPaint` está dentro de um `InteractiveViewer` sem nenhum `GestureDetector` que faça hit-testing nas estações.

**Solução:**

`TransitMapScreen` envolve o `InteractiveViewer` com um `GestureDetector`:

```dart
GestureDetector(
  onTapUp: (details) {
    final scenePoint = _transformController.toScene(details.localPosition);
    final station = _findStationAt(scenePoint, radius: 24.0);
    if (station != null) context.push('/station/${station.id}');
  },
  child: InteractiveViewer(
    transformationController: _transformController,
    child: CustomPaint(painter: _painter),
  ),
)
```

`_findStationAt` itera as estações da linha atualmente selecionada (obtidas do `selectedCityProvider` + `CityRegistry.getSchematic`) e retorna a mais próxima do ponto de toque dentro do raio de 24px em coordenadas de cena. O painter já recebe a lista de estações com suas posições calculadas — `TransitMapScreen` deve usar a mesma lista que passa ao painter, armazenada em um campo `_stations` no estado do widget.

**Coordenadas:** `_transformController.toScene()` converte da viewport (coordenadas de tela após zoom/pan) para o espaço do canvas — necessário porque o `InteractiveViewer` aplica uma transformação Matrix4 ao filho.

**Teste:** simular `onTapUp` com `localPosition` nas coordenadas de cena de uma estação conhecida → verifica navegação para `/station/:id`.

---

### 3. Tap na linha (StationDetailScreen → mapa)

**Causa raiz:** `_buildDirectionCards` cria cards sem `onTap`.

**Solução:**

Criar provider compartilhado em `app_providers.dart`:

```dart
final pendingLineSelectionProvider = StateProvider<String?>((ref) => null);
```

Em `StationDetailScreen._buildDirectionCards`, adicionar `onTap` no `InkWell`/`GestureDetector` do card:

```dart
onTap: () {
  ref.read(pendingLineSelectionProvider.notifier).state = dir.lineId;
  context.go('/');
},
```

Em `TransitMapScreen.build`, observar e consumir o provider:

```dart
ref.listen(pendingLineSelectionProvider, (_, lineId) {
  if (lineId != null) {
    _onLineTapped(lineId);
    ref.read(pendingLineSelectionProvider.notifier).state = null;
  }
});
```

> **Pré-condição:** `DirectionArrivals` precisa de um campo `lineId`. Se não existir, adicioná-lo ao model e ao parsing da API antes desta tarefa.

**Teste:** montar `StationDetailScreen` com arrivals mockadas (com `lineId`) → tap no card → `pendingLineSelectionProvider` recebe o `lineId`.

---

### 4. TransitMapPainter — visual dark metro clean

**Causa raiz:** `TransitMapPainter` define cores com hexcodes que não seguem os tokens do AppTheme.

**Solução:**

```dart
// Antes
Color get _bgColor    => _isDark ? const Color(0xFF121212) : Colors.white;
Color get _labelColor => _isDark ? const Color(0xFFEEEEEE) : const Color(0xFF111111);

// Depois
Color get _bgColor    => _isDark ? AppTheme.bgDark    : AppTheme.bgLight;
Color get _labelColor => _isDark ? AppTheme.textPrimDark : AppTheme.textPrimLight;
```

Substituições adicionais:
- Estação selecionada highlight → `AppTheme.accent`
- Grid/linhas de fundo → `AppTheme.borderDark` / `AppTheme.borderLight` com alpha 0.3
- `TransitMapScreen` Scaffold `backgroundColor` → `AppTheme.bgDark / AppTheme.bgLight`

**Estilo visual aprovado:** dark metro clean — fundo escuro (`#0A0A14`), estações como círculos vazados com borda na cor da linha, labels em branco.

**Teste:** instanciar `TransitMapPainter(isDark: true)` → `bgColor == AppTheme.bgDark`. Com `isDark: false` → `bgColor == AppTheme.bgLight`.

---

### 5. Polish — EmailAuthScreen, AnonymousGateSheet, TransitMapScreen

#### EmailAuthScreen (`mobile/lib/features/auth/email_auth_screen.dart`)

Já usa `Theme.of(context).colorScheme` corretamente. Duas correções pontuais:

- Adicionar `backgroundColor` explícito no `Scaffold`:
  ```dart
  backgroundColor: AppTheme.isDark(context) ? AppTheme.bgDark : AppTheme.bgLight,
  ```
- `CircularProgressIndicator(color: Colors.white)` → `color: AppTheme.textPrimDark`

#### AnonymousGateSheet (`mobile/lib/features/auth/anonymous_gate_sheet.dart`)

Já bem estruturado com `cs.primaryContainer`, `cs.onSurfaceVariant`. Nenhuma mudança de código necessária — herda corretamente do tema após `themeModeProvider` ser wired. **Sem alterações neste arquivo.**

#### TransitMapScreen (`mobile/lib/features/transit_map/transit_map_screen.dart`)

- `backgroundColor` do Scaffold coberto na Seção 4
- Chips de linha no topo: qualquer `Color(0xFF...)` hardcoded nas chips deve ser substituído por `AppTheme.borderDark/Light` (borda) e `AppTheme.surfaceDark/Light` (fundo). A cor do texto da linha vem de `line.color` (dinâmico, mantém).
- `FloatingActionButton` se presente: `backgroundColor` → `AppTheme.primary`, `foregroundColor` → `AppTheme.textPrimDark`.

---

### 6. Redesign — SubscriptionScreen (`mobile/lib/features/subscription/subscription_screen.dart`)

**Mantém:** estrutura de abas (Plano Atual / Histórico), lógica de negócio, métodos `_cancelSubscription`, `_reactivateSubscription`, `_changePlan`.

**Muda:** camada visual completa.

#### Scaffold e AppBar
```dart
backgroundColor: AppTheme.isDark(context) ? AppTheme.bgDark : AppTheme.bgLight,
```
AppBar herda do tema. `TabBar` indicador → `AppTheme.accent`.

#### Hero card (aba "Plano Atual")
Substituir o `Card` com ícone simples por um container com gradiente:

```dart
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: status.isActive
          ? [AppTheme.primary, AppTheme.accent]
          : [AppTheme.surfaceDark, AppTheme.surfRaisedDark],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(20),
  ),
  padding: const EdgeInsets.all(24),
  child: Column(
    children: [
      Icon(status.isActive ? Icons.star_rounded : Icons.star_border_rounded,
           size: 40, color: Colors.white),
      // planName, price, status badge
    ],
  ),
)
```

Status badge: fundo `rgba(255,255,255,0.2)`, texto branco, quando ativa. Inativa: `AppColors.danger` com alpha.

#### Card "Detalhes"
Usar `AppTheme.cardDecoration(context)`. Labels: `AppTheme.textSecDark/Light`. Valores: `AppTheme.textPrimDark/Light`. Ícones: `AppTheme.textSecDark/Light`.

#### Ações (cancelar, reativar, trocar plano)
- Cancelar: borda `AppColors.danger` com alpha 0.4, texto `AppColors.danger`
- Reativar: borda `AppColors.success` com alpha 0.4, texto `AppColors.success`
- Trocar plano: borda `AppTheme.borderDark/Light`

#### `_buildDetailRow`
`Colors.grey` → `AppTheme.isDark(context) ? AppTheme.textSecDark : AppTheme.textSecLight`

#### `_buildHistoryTab`
- `Colors.green` → `AppColors.success`
- `Colors.orange` → `AppColors.warning`
- `Colors.grey` → `AppTheme.textSecDark/Light`
- `Card` → usar `AppTheme.cardDecoration(context)`

#### `_ChangePlanSheet`
- Container badge verde → `AppColors.success`
- `Colors.white` texto badge → `AppTheme.textPrimDark`
- Borda dos planos → `AppTheme.borderDark/Light`
- Fundo do sheet → `AppTheme.bgDark/Light`

**Teste:** montar `SubscriptionScreen` em dark mode com status ativo mockado → verificar que scaffold bg == `AppTheme.bgDark` e que não há `Colors.green/red/grey` hardcoded na árvore de widgets.

---

## Arquivos afetados

| Arquivo | Tipo de mudança |
|---|---|
| `mobile/lib/core/providers/app_providers.dart` | Adicionar `themeModeProvider`, `pendingLineSelectionProvider` |
| `mobile/lib/main.dart` | Observar `themeModeProvider` |
| `mobile/lib/features/settings/settings_screen.dart` | Wiring do switch dark mode |
| `mobile/lib/features/transit_map/transit_map_screen.dart` | GestureDetector + station tap + listen to pendingLine + bg token |
| `mobile/lib/features/transit_map/transit_map_painter.dart` | Cores hardcoded → AppTheme tokens |
| `mobile/lib/features/station_detail/station_detail_screen.dart` | onTap nos cartões de direção |
| `mobile/lib/core/models/station_arrivals_model.dart` | Adicionar `lineId` em `DirectionArrivals` (se ausente) |
| `mobile/lib/features/auth/email_auth_screen.dart` | Scaffold bg + spinner color |
| `mobile/lib/features/auth/anonymous_gate_sheet.dart` | Nenhuma alteração necessária |
| `mobile/lib/features/subscription/subscription_screen.dart` | Redesign visual completo |

---

## Testes

Cada bug tem um teste unitário ou de widget que verifica o comportamento correto:

1. **Dark mode:** `SettingsScreen` widget test → tap no switch → provider muda
2. **Station tap:** `TransitMapScreen` unit test para `_findStationAt` → retorna estação correta dadas coordenadas de cena
3. **Line tap:** `StationDetailScreen` widget test → tap no card → `pendingLineSelectionProvider` atualizado
4. **Painter:** unit test → `TransitMapPainter(isDark: true).bgColor == AppTheme.bgDark`
5. **SubscriptionScreen:** widget test → dark mode → scaffold bg == `AppTheme.bgDark`

---

## Decisões tomadas

- `StateProvider<ThemeMode>` preferido sobre `StateNotifier` — escopo simples, YAGNI
- Provider de comunicação (`pendingLineSelectionProvider`) preferido sobre GoRouter extras — mais idiomático com Riverpod
- `AnonymousGateSheet` não precisa de alterações — já usa colorScheme corretamente
- `EmailAuthScreen` recebe apenas dois fixes pontuais — estrutura já é boa
- Abordagem cirúrgica por área (não big-bang por tela) — menor superfície de mudança, riscos isolados
