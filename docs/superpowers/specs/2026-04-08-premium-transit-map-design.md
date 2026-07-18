# Premium Transit Map — Design Spec
**Data:** 2026-04-08  
**Status:** Aprovado

---

## Objetivo

Redesenhar o mapa de transporte e todo o app Trilho com experiência premium, fidelidade visual ao mapa oficial CPTM/Metro SP, todas as linhas funcionais, e suporte completo a dark mode.

---

## 1. Mapa Esquemático

### 1.1 Dados — Todas as linhas

Implementar geometria fiel ao mapa oficial impresso. Cada linha é uma polyline com múltiplos segmentos (não apenas 2 pontos).

| Linha | Nome | Cor (light) | Cor (dark — mais clara) | Espessura |
|-------|------|-------------|------------------------|-----------|
| L1 | Azul | `#0455A1` | `#2979FF` | 10px |
| L2 | Verde | `#007E5E` | `#00BFA5` | 10px |
| L3 | Vermelha | `#EF4136` | `#FF5252` | 10px |
| L4 | Amarela | `#FFD900` | `#FFE57F` | 10px |
| L5 | Lilás | `#9B2990` | `#CE93D8` | 10px |
| L15 | Prata | `#808285` | `#B0BEC5` | 10px |
| L7 | Rubi | `#CF202E` | `#EF5350` | 8px |
| L8 | Diamante | `#97999B` | `#CFD8DC` | 8px |
| L9 | Esmeralda | `#00945A` | `#69F0AE` | 8px |
| L10 | Turquesa | `#007A87` | `#80DEEA` | 8px |
| L11 | Coral | `#F26522` | `#FF9E80` | 8px |
| L12 | Safira | `#133A8F` | `#448AFF` | 8px |
| L13 | Jade | `#00A859` | `#B9F6CA` | 8px |
| L17 | Ouro | `#BE9B2F` | `#FFD740` | 8px |
| L-A | Santos-Jundiaí | `#6B3A2A` | `#A1887F` | 8px |
| L-B | Diamante | `#005A8B` | `#4FC3F7` | 8px |

> Regra: cores dark são sempre mais claras/brilhantes que o light para manter contraste sobre fundo `#121212`.

Canvas: `Size(2400, 1800)` — proporcional ao mapa oficial.

Todas as linhas devem ter dados reais do backend e exibir lotação em tempo real via SignalR.

### 1.2 Marcadores de estação

**Estação simples:**
- Círculo: raio 5px (canvas), borda = cor da linha
- Interior: cor da densidade (verde → amarelo → laranja → vermelho)
- Estação selecionada: raio 8px

**Estação de integração (2+ linhas):**
- Anel externo: raio 10–13px, borda cinza `#ccc`
- Núcleo: raio 6–7px, borda escura `#444`
- Destaque por peso de fonte no label (800)

### 1.3 Labels das estações

**Regra universal:** label sempre paralelo à linha, tick perpendicular à linha, usando `transform="translate(x,y) rotate(ângulo)"`.

- **Estações simples:** ângulo = `atan2(dy, dx)` calculado a partir do **segmento local** onde a estação se encontra (não um ângulo único por linha). Para linhas com múltiplos segmentos, o painter identifica entre quais dois pontos consecutivos a estação se localiza e usa o ângulo daquele segmento. Tick parte do marcador no eixo-y do grupo rotacionado (perpendicular ao segmento). Texto no eixo-x (paralelo). Alternância acima/abaixo ao longo da linha.
- **Estações de integração em cruzamento:** tick na direção da **bissetriz oposta à média dos ângulos das linhas que cruzam** — garantindo que o tick aponte para o quadrante com mais espaço livre. Implementado como: `avgAngle = mean(lineAngles)`, `tickAngle = avgAngle + π` (oposto).
- Offset mínimo marcador → texto: **18px** simples · **22px** integração.
- Tracejado: `strokeWidth=1.2`, `dashArray=[3,3]`, cor `#bbb` (light) / `#555` (dark).
- Tipografia: Inter/SF Pro, 9–11px, `fontWeight=600` simples · `fontWeight=700` integração.
- Labels desaparecem gradualmente conforme zoom-out. Fórmula exata:
  ```
  opacity = ((scale - 0.8) / (1.5 - 0.8)).clamp(0.0, 1.0)
  ```
  Abaixo de `scale=0.8`: opacity=0, labels não desenhados. Acima de `scale=1.5`: opacity=1.0 pleno.
- `InteractiveViewer`: `minScale=0.5`, `maxScale=8.0` (mantido do impl atual).
- Enum `LabelSide { above, below }` — definido em `schematic_model.dart`.

### 1.4 Dark mode do mapa

- Fundo: `#121212`
- Cores das linhas: mais claras (tabela acima)
- Labels: `#EEEEEE`
- Tracejado: `#555`
- **Estação simples** — interior: `#121212`, borda: cor da linha (dark)
- **Integração** — núcleo interior: `#1E1E1E`, borda núcleo: `#DDDDDD`, anel externo: borda `#555555`

---

## 2. Chips de linha

- Posição: **flutuando centralizados sobre o mapa**, no topo da área do mapa
- Container pill: `background rgba(255,255,255,0.90)` com `backdropFilter: blur(10px)` · dark: `rgba(18,18,18,0.88)`
- Shadow: `0 1px 8px rgba(0,0,0,.13)`
- Scroll horizontal quando overflow
- Chip individual: padding `2px vertical × 7px horizontal`, `fontSize=9`, `fontWeight=700`, `borderRadius=10px`
- Chip selecionado: `outline: 2px solid #000` light / `2px solid #90caf9` dark, `outlineOffset=1px`
- Conteúdo: `● N` (número da linha)

---

## 3. Design System — App completo

### 3.1 Tipografia

Fonte primária: **Inter** (Google Fonts). Fallback: SF Pro / Segoe UI / system-ui.

| Token | Tamanho | Peso | Uso |
|-------|---------|------|-----|
| Display | 28px | 800 | Títulos de cidade/tela |
| Title | 20px | 700 | Nome da linha/estação |
| Subtitle | 15px | 600 | Info secundária |
| Body | 14px | 400 | Textos gerais |
| Caption | 11px | 500 | Labels, timestamps |

### 3.2 Paleta

**Light:**
- Background: `#FFFFFF`
- Surface: `#F8F9FA`
- Background alt: `#F0F2F5`
- Border: `#E0E4EA`
- Text primary: `#111111`
- Text secondary: `#666666`

**Dark:**
- Background: `#121212`
- Surface: `#1E1E1E`
- Surface alt: `#2A2A2A`
- Border: `#3A3A3A`
- Text primary: `#EEEEEE`
- Text secondary: `#AAAAAA`

### 3.3 Espaçamento

Scale: `4 · 8 · 12 · 16 · 20 · 24 · 32 · 48px`

- Border radius cards: `16px`
- Border radius chips: `20px` (pill container) / `10px` (chip individual)
- Border radius botões: `12px`

### 3.4 Elevação (shadows)

- Nível 1 (cards, chips): `0 1px 3px rgba(0,0,0,.06)`
- Nível 2 (bottom sheets): `0 4px 12px rgba(0,0,0,.10)`
- Nível 3 (modals, detalhe): `0 8px 28px rgba(0,0,0,.16)`

---

## 4. Telas redesenhadas

### 4.1 Tela do Mapa (`TransitMapScreen`)

- AppBar slim com título da cidade e ícone de settings
- Mapa ocupa 100% da tela (sem padding lateral)
- Chips flutuando centralizados no topo do mapa (posição absoluta)
- `InteractiveViewer` com pan/zoom
- Bottom bar com status de lotação em tempo real (compacto)
- Suporte completo a light/dark via `Theme.of(context).brightness`

### 4.2 Tela de Detalhe da Estação (`StationDetailScreen`)

- Header com cor da linha como fundo
  - Nome da linha (caption, opacidade 70%)
  - Nome da estação (Display 800)
  - Integrações (body)
  - Barra de lotação animada (count-up 600ms)
- Cards de próximos trens por direção com tempos destacados
- Gráfico de histórico 3h (barras)
- Elevação nível 3

### 4.3 Welcome / City Picker

- Design premium com tipografia Display
- Cards de cidade com sombra nível 2
- Suporte dark mode

### 4.4 Settings (`SettingsScreen`)

Seções agrupadas em cards com ícones coloridos:

**APARÊNCIA**
- Toggle "Modo escuro" (ícone 🌙, fundo `#EEF2FF` / dark `#1A237E`)
- Row "Idioma" com chevron

**NOTIFICAÇÕES**
- Toggle "Alertas de lotação" (ícone 🔔, fundo `#E8F5E9` / dark `#1B3A1B`)
- Row "Atualizações" com valor atual e chevron

**CONTA**
- Row "Perfil" com chevron
- Row "Sair" em vermelho (`#EF4136` light / `#EF5350` dark)

Estrutura visual: AppBar com `←` + título "Configurações" · cards com `borderRadius=14px` · `padding=0 14px` · shadow nível 1 · seções separadas por label uppercase `#888`.

### 4.5 Login (`LoginScreen` + `EmailAuthScreen`)

**Tela principal de login** (`LoginScreen`):
- Hero com gradiente `#0455A1 → #0277BD` (light) / `#1565C0 → #0D47A1` (dark)
- Logo 🚇 em card translúcido `rgba(255,255,255,.15)`, `borderRadius=20px`
- Título "Trilho" Display 800 branco + subtítulo opacidade 65%
- Campos e-mail e senha com label uppercase acima, `background=Surface`, `border=Border`
- Link "Esqueceu?" alinhado à direita do label SENHA
- Botão "Entrar" primário com shadow colorida
- Divisor "ou entre com" + **3 ícones sociais pequenos** (40×40px, `borderRadius=12px`):
  - Apple: fundo preto (light) / branco (dark)
  - Google: logo SVG oficial, fundo Surface
  - Facebook: fundo `#1877F2`
- Link "Não tem conta? **Criar conta**"
- Link "Continuar sem conta" discreto, `color=TextSecondary`, underline

**Tela de criar conta** (`EmailAuthScreen`) — abre ao clicar "Criar conta":
- AppBar com `←` + título "Criar conta"
- Campos: Nome, E-mail, Senha
- Botão "Criar conta" primário
- Footer com links "Termos de uso" e "Privacidade"

---

## 5. Modelo de dados atualizado

### `LabelSide` (enum)
```dart
enum LabelSide { above, below }
```

### `SchematicLine`
```dart
SchematicLine {
  String lineCode,
  List<Offset> points,     // polyline completa: N pontos = N-1 segmentos
  List<int> stationIds,
  // Sem angleRadians global — ângulo calculado por estação via segmento local
}
```

### `SchematicStation`
```dart
SchematicStation {
  int stationId,
  String name,             // nome de exibição no mapa (ex: "Luz", "Palmeiras-Barra Funda")
  Offset position,         // posição calibrada no canvas 2400×1800
  int maxCapacity,         // capacidade máxima em pessoas (estático, ex: 1200)
                           // A lotação em tempo real (0.0–1.0) vem do SignalR via signalRProvider
                           // Cor do marcador = f(densityLevel do SignalRCrowdEntry)
  bool isInterchange,      // true se 2+ linhas passam
  List<String> lineCodes,  // linhas que passam (para anel colorido e tick)
  LabelSide labelSide,     // above / below (alternado ao longo da linha)
}
```

### Ângulo por estação (painter)
```
Para cada estação S na linha L com pontos [p0, p1, ..., pN]:
  1. Encontrar segmento local: o par (pi, pi+1) mais próximo de S.position
  2. angle = atan2(pi+1.dy - pi.dy, pi+1.dx - pi.dx)
  3. Usar angle no transform do grupo de label
```

---

## 6. Painter atualizado (`TransitMapPainter`)

Novos parâmetros vs atual:
- `brightness: Brightness` — para adaptar cores light/dark
- Suporte a polylines multi-segmento (List<Offset> com N pontos)
- Renderização de labels com `canvas.save() / rotate() / restore()`
- Marcadores de integração com anel duplo
- Tracejado de conexão label ↔ marcador

---

## 7. Escopo das telas

**Redesign com wireframe detalhado (seção 4):**
- `TransitMapScreen`
- `StationDetailScreen`
- `WelcomeScreen` / City Picker
- `SettingsScreen`

**Design system apenas** (sem wireframe específico — aplicar tipografia, cores e espaçamento definidos nas seções 3.1–3.4):
- `PaywallScreen` / `SubscriptionScreen`

---

## 8. Fora de escopo

- Mudança na lógica de negócio (SignalR, TrainEstimator, providers)
- Novo backend / novas APIs
- Navegação (GoRouter mantido)
