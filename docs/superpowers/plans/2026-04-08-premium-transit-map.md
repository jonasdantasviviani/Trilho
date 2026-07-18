# Premium Transit Map — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesenhar o mapa esquemático do app Trilho com geometria fiel ao mapa oficial CPTM/Metro SP (todas as 16 linhas), labels rotacionados por linha, dark mode adaptativo, chips centralizados flutuando sobre o mapa, e design premium em todas as telas.

**Architecture:** Atualizar `SchematicStation`/`SchematicLine` com novos campos (`name`, `isInterchange`, `lineCodes`, `labelSide`, `maxCapacity`), reescrever `sao_paulo_schematic.dart` com todas as 16 linhas e geometria fiel, refatorar `TransitMapPainter` para renderizar labels rotacionados + interchanges + dark mode, redesenhar `TransitMapScreen` com chips flutuantes centralizados, e redesenhar `LoginScreen`, `SettingsScreen`, `WelcomeScreen` com o novo design system.

**Tech Stack:** Flutter 3.x, Dart, Riverpod, CustomPainter, `dart:math` (atan2), Inter font (google_fonts), GoRouter, Hive

---

## Chunk 1: Design System + Modelo de dados

### Task 1: Adicionar `google_fonts` ao pubspec e criar `app_theme.dart`

**Files:**
- Modify: `mobile/pubspec.yaml`
- Create: `mobile/lib/core/widgets/app_theme.dart`
- Modify: `mobile/main.dart`

- [ ] **Step 1: Adicionar google_fonts ao pubspec**

```yaml
# Em dependencies, adicionar:
  google_fonts: ^6.2.1
```

- [ ] **Step 2: Rodar pub get**

```bash
cd mobile && flutter pub get
```
Expected: saída sem erros.

- [ ] **Step 3: Escrever teste que verifica o tema light tem fundo branco e dark tem #121212**

Criar `mobile/test/core/widgets/app_theme_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/widgets/app_theme.dart';

void main() {
  test('lightTheme scaffold background is white', () {
    expect(
      AppTheme.light().scaffoldBackgroundColor,
      const Color(0xFFFFFFFF),
    );
  });

  test('darkTheme scaffold background is #121212', () {
    expect(
      AppTheme.dark().scaffoldBackgroundColor,
      const Color(0xFF121212),
    );
  });

  test('lightTheme uses Inter font family', () {
    expect(AppTheme.light().textTheme.bodyMedium?.fontFamily, contains('Inter'));
  });

  test('darkTheme uses Inter font family', () {
    expect(AppTheme.dark().textTheme.bodyMedium?.fontFamily, contains('Inter'));
  });
}
```

- [ ] **Step 4: Rodar teste para ver falhar**

```bash
cd mobile && flutter test test/core/widgets/app_theme_test.dart
```
Expected: FAIL — `app_theme.dart` não existe.

- [ ] **Step 5: Criar `mobile/lib/core/widgets/app_theme.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── Paleta ────────────────────────────────────────────────────────────────
  static const Color _seed       = Color(0xFF0455A1);

  // Light
  static const Color _bgLight      = Color(0xFFFFFFFF);
  static const Color _surfaceLight  = Color(0xFFF8F9FA);
  static const Color _surfaceAltL   = Color(0xFFF0F2F5);
  static const Color _borderLight   = Color(0xFFE0E4EA);
  static const Color _textPrimL     = Color(0xFF111111);
  static const Color _textSecL      = Color(0xFF666666);

  // Dark
  static const Color _bgDark        = Color(0xFF121212);
  static const Color _surfaceDark   = Color(0xFF1E1E1E);
  static const Color _surfaceAltD   = Color(0xFF2A2A2A);
  static const Color _borderDark    = Color(0xFF3A3A3A);
  static const Color _textPrimD     = Color(0xFFEEEEEE);
  static const Color _textSecD      = Color(0xFFAAAAAA);

  // ── Text themes ───────────────────────────────────────────────────────────
  static TextTheme _textTheme(Color primary, Color secondary) {
    return GoogleFonts.interTextTheme().copyWith(
      displayLarge : GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: primary, letterSpacing: -0.5),
      titleLarge   : GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: primary),
      titleMedium  : GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: primary),
      bodyMedium   : GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: primary),
      bodySmall    : GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: secondary, letterSpacing: 0.3),
    );
  }

  // ── Light ─────────────────────────────────────────────────────────────────
  static ThemeData light() {
    final cs = ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.light).copyWith(
      surface: _surfaceLight,
      onSurface: _textPrimL,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: _bgLight,
      textTheme: _textTheme(_textPrimL, _textSecL),
      dividerColor: _borderLight,
      cardTheme: CardThemeData(
        color: _bgLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _borderLight),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _bgLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: _textPrimL),
        iconTheme: const IconThemeData(color: _textPrimL),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _borderLight, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _borderLight, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _seed, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: _textSecL),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _seed,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // ── Dark ──────────────────────────────────────────────────────────────────
  static ThemeData dark() {
    const darkSeed = Color(0xFF2979FF);
    final cs = ColorScheme.fromSeed(seedColor: darkSeed, brightness: Brightness.dark).copyWith(
      surface: _surfaceDark,
      onSurface: _textPrimD,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: _bgDark,
      textTheme: _textTheme(_textPrimD, _textSecD),
      dividerColor: _borderDark,
      cardTheme: CardThemeData(
        color: _surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _borderDark),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _surfaceDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: _textPrimD),
        iconTheme: const IconThemeData(color: _textPrimD),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceAltD,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _borderDark, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _borderDark, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkSeed, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: _textSecD),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkSeed,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // ── Elevation helpers ─────────────────────────────────────────────────────
  static BoxDecoration cardDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? _surfaceDark : _bgLight,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: isDark ? _borderDark : _borderLight),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06), blurRadius: 3, offset: const Offset(0, 1)),
      ],
    );
  }
}
```

- [ ] **Step 6: Atualizar `main.dart` para usar `AppTheme`**

Substituir as chamadas de `ThemeData` em `main.dart`:
```dart
// Adicionar import:
import 'core/widgets/app_theme.dart';

// Substituir no MaterialApp.router:
theme: AppTheme.light(),
darkTheme: AppTheme.dark(),
themeMode: ThemeMode.system,
```

- [ ] **Step 7: Rodar testes**

```bash
cd mobile && flutter test test/core/widgets/app_theme_test.dart
```
Expected: 4 PASS.

- [ ] **Step 8: Commit**

```bash
git add mobile/pubspec.yaml mobile/pubspec.lock mobile/lib/core/widgets/app_theme.dart mobile/lib/main.dart mobile/test/core/widgets/app_theme_test.dart
git commit -m "feat: add AppTheme with Inter font, light/dark design system"
```

---

### Task 2: Atualizar modelo `SchematicStation` e `SchematicLine`

**Files:**
- Modify: `mobile/lib/core/models/schematic_model.dart`
- Modify: `mobile/test/core/models/schematic_model_test.dart`

- [ ] **Step 1: Escrever testes novos**

Adicionar ao final de `mobile/test/core/models/schematic_model_test.dart`:
```dart
  group('SchematicStation extended fields', () {
    test('has name field', () {
      const s = SchematicStation(
        stationId: 1,
        name: 'Luz',
        position: Offset(100, 100),
        isInterchange: true,
        lineCodes: ['L1', 'L3'],
        labelSide: LabelSide.above,
      );
      expect(s.name, 'Luz');
      expect(s.isInterchange, true);
      expect(s.lineCodes, ['L1', 'L3']);
      expect(s.labelSide, LabelSide.above);
      expect(s.maxCapacity, 1200); // default
    });

    test('LabelSide enum has above and below', () {
      expect(LabelSide.values.length, 2);
      expect(LabelSide.values, containsAll([LabelSide.above, LabelSide.below]));
    });
  });

  group('TransitSchematic.stationsForLine with name', () {
    test('returns stations with names', () {
      const schematic = TransitSchematic(
        canvasSize: Size(1000, 800),
        lines: [
          SchematicLine(lineCode: 'L1', points: [Offset(0,0), Offset(100,0)], stationIds: [1, 2]),
        ],
        stations: [
          SchematicStation(stationId: 1, name: 'Tucuruvi', position: Offset(10, 0), labelSide: LabelSide.above),
          SchematicStation(stationId: 2, name: 'Parada Inglesa', position: Offset(50, 0), labelSide: LabelSide.below),
        ],
      );
      final stations = schematic.stationsForLine('L1');
      expect(stations.map((s) => s.name).toList(), ['Tucuruvi', 'Parada Inglesa']);
    });
  });
```

- [ ] **Step 2: Rodar para ver falhar**

```bash
cd mobile && flutter test test/core/models/schematic_model_test.dart
```
Expected: FAIL — `name`, `isInterchange`, `lineCodes`, `labelSide`, `LabelSide` não existem.

- [ ] **Step 3: Atualizar `schematic_model.dart`**

```dart
// mobile/lib/core/models/schematic_model.dart
import 'package:flutter/painting.dart';

enum LabelSide { above, below }

class SchematicStation {
  final int stationId;
  final String name;
  final Offset position;
  final int maxCapacity;
  final bool isInterchange;
  final List<String> lineCodes;
  final LabelSide labelSide;

  const SchematicStation({
    required this.stationId,
    required this.name,
    required this.position,
    this.maxCapacity = 1200,
    this.isInterchange = false,
    this.lineCodes = const [],
    this.labelSide = LabelSide.above,
  });
}

class SchematicLine {
  final String lineCode;
  final List<Offset> points;
  final List<int> stationIds;

  const SchematicLine({
    required this.lineCode,
    required this.points,
    required this.stationIds,
  });
}

class TransitSchematic {
  final Size canvasSize;
  final List<SchematicLine> lines;
  final List<SchematicStation> stations;

  const TransitSchematic({
    required this.canvasSize,
    required this.lines,
    required this.stations,
  });

  SchematicStation? stationById(int id) {
    for (final s in stations) {
      if (s.stationId == id) return s;
    }
    return null;
  }

  List<SchematicStation> stationsForLine(String lineCode) {
    final line = lines.where((l) => l.lineCode == lineCode).firstOrNull;
    if (line == null) return [];
    return line.stationIds
        .map((id) => stationById(id))
        .whereType<SchematicStation>()
        .toList();
  }
}
```

- [ ] **Step 4: Rodar todos os testes do modelo**

```bash
cd mobile && flutter test test/core/models/schematic_model_test.dart
```
Expected: todos PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/core/models/schematic_model.dart mobile/test/core/models/schematic_model_test.dart
git commit -m "feat: extend SchematicStation with name, isInterchange, lineCodes, labelSide"
```

---

## Chunk 2: Dados do mapa — São Paulo completo

### Task 3: Reescrever `sao_paulo_schematic.dart` com todas as 16 linhas

**Files:**
- Modify: `mobile/lib/core/data/sao_paulo_schematic.dart`
- Modify: `mobile/lib/core/models/city_model.dart` (verificar import)
- Test: `mobile/test/core/data/sao_paulo_schematic_test.dart`

> **Nota:** O canvas é `Size(2400, 1800)`. Coordenadas calibradas proporcionalmente ao mapa oficial. Cada linha tem polyline multi-segmento. Estações de integração têm `isInterchange: true` e `lineCodes` listando todas as linhas que passam.

- [ ] **Step 1: Escrever testes de validação estrutural**

Criar `mobile/test/core/data/sao_paulo_schematic_test.dart`:
```dart
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/data/sao_paulo_schematic.dart';
import 'package:trilho/core/models/schematic_model.dart';

void main() {
  group('saoPauloSchematic', () {
    test('canvas size is 2400x1800', () {
      expect(saoPauloSchematic.canvasSize, const Size(2400, 1800));
    });

    test('has all 16 lines', () {
      final codes = saoPauloSchematic.lines.map((l) => l.lineCode).toSet();
      for (final code in ['L1','L2','L3','L4','L5','L15','L7','L8','L9','L10','L11','L12','L13','L17','LA','LB']) {
        expect(codes, contains(code), reason: 'Missing line $code');
      }
    });

    test('all lines have at least 2 points', () {
      for (final line in saoPauloSchematic.lines) {
        expect(line.points.length, greaterThanOrEqualTo(2), reason: '${line.lineCode} has < 2 points');
      }
    });

    test('all lines have at least 2 stationIds', () {
      for (final line in saoPauloSchematic.lines) {
        expect(line.stationIds.length, greaterThanOrEqualTo(2), reason: '${line.lineCode} has < 2 stations');
      }
    });

    test('all stations have non-empty names', () {
      for (final st in saoPauloSchematic.stations) {
        expect(st.name.trim().isNotEmpty, true, reason: 'Station ${st.stationId} has empty name');
      }
    });

    test('all station positions within canvas bounds', () {
      for (final st in saoPauloSchematic.stations) {
        expect(st.position.dx, inInclusiveRange(0, 2400), reason: '${st.name} x out of bounds');
        expect(st.position.dy, inInclusiveRange(0, 1800), reason: '${st.name} y out of bounds');
      }
    });

    test('interchange stations have isInterchange true and multiple lineCodes', () {
      final luz = saoPauloSchematic.stations.where((s) => s.name == 'Luz').firstOrNull;
      expect(luz, isNotNull);
      expect(luz!.isInterchange, true);
      expect(luz.lineCodes.length, greaterThanOrEqualTo(2));
    });

    test('all stationIds in lines resolve to existing stations', () {
      final ids = saoPauloSchematic.stations.map((s) => s.stationId).toSet();
      for (final line in saoPauloSchematic.lines) {
        for (final id in line.stationIds) {
          expect(ids, contains(id), reason: 'Line ${line.lineCode} references unknown stationId $id');
        }
      }
    });
  });
}
```

- [ ] **Step 2: Rodar para ver falhar**

```bash
cd mobile && flutter test test/core/data/sao_paulo_schematic_test.dart
```
Expected: FAIL — linhas CPTM não existem.

- [ ] **Step 3: Reescrever `sao_paulo_schematic.dart`**

```dart
// mobile/lib/core/data/sao_paulo_schematic.dart
// ignore_for_file: non_constant_identifier_names
import 'package:flutter/painting.dart';
import '../models/schematic_model.dart';

// Canvas: 2400 × 1800 px — proporcional ao mapa oficial CPTM/Metro SP

const TransitSchematic saoPauloSchematic = TransitSchematic(
  canvasSize: Size(2400, 1800),
  lines: _lines,
  stations: _stations,
);

// ══════════════════════════════════════════════════════════════════════════════
// LINHAS — polylines com múltiplos segmentos
// ══════════════════════════════════════════════════════════════════════════════
const List<SchematicLine> _lines = [
  // Metro SP ─────────────────────────────────────────────────────────────────
  SchematicLine( // L1 Azul — vertical centro-norte/sul
    lineCode: 'L1',
    points: [Offset(1100,100), Offset(1100,900), Offset(1100,1700)],
    stationIds: [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17],
  ),
  SchematicLine( // L2 Verde — diagonal NO-SE
    lineCode: 'L2',
    points: [Offset(600,700), Offset(900,900), Offset(1100,900), Offset(1400,1100), Offset(1600,1300)],
    stationIds: [25,26,27,28,29,30,31,32,33,34,35],
  ),
  SchematicLine( // L3 Vermelha — horizontal leste-oeste
    lineCode: 'L3',
    points: [Offset(400,900), Offset(700,900), Offset(1100,900), Offset(1500,900), Offset(1900,900)],
    stationIds: [36,37,38,39,40,41,42,43,44,45,46,47,48,49],
  ),
  SchematicLine( // L4 Amarela — diagonal SO para centro
    lineCode: 'L4',
    points: [Offset(500,1500), Offset(700,1300), Offset(900,1100), Offset(1100,900)],
    stationIds: [50,51,52,53,54,55],
  ),
  SchematicLine( // L5 Lilás — horizontal sul
    lineCode: 'L5',
    points: [Offset(400,1400), Offset(700,1400), Offset(1000,1400), Offset(1200,1400), Offset(1400,1300)],
    stationIds: [60,62,64,66,68,70,72,73,75,76],
  ),
  SchematicLine( // L15 Prata — monotrilho, leste
    lineCode: 'L15',
    points: [Offset(1100,900), Offset(1300,1100), Offset(1500,1200), Offset(1700,1300)],
    stationIds: [101,102,103,104,105,106,107,108,109,110,111],
  ),

  // CPTM ─────────────────────────────────────────────────────────────────────
  SchematicLine( // L7 Rubi — noroeste
    lineCode: 'L7',
    points: [Offset(1100,900), Offset(900,700), Offset(700,500), Offset(500,300), Offset(300,150)],
    stationIds: [201,202,203,204,205,206,207,208,209,210,211,212,213],
  ),
  SchematicLine( // L8 Diamante — oeste
    lineCode: 'L8',
    points: [Offset(1100,950), Offset(800,950), Offset(500,950), Offset(200,950)],
    stationIds: [220,221,222,223,224,225,226,227,228,229,230,231,232],
  ),
  SchematicLine( // L9 Esmeralda — sul-oeste
    lineCode: 'L9',
    points: [Offset(1100,900), Offset(900,1100), Offset(700,1200), Offset(500,1300), Offset(300,1400)],
    stationIds: [240,241,242,243,244,245,246,247,248,249],
  ),
  SchematicLine( // L10 Turquesa — sul ABC
    lineCode: 'L10',
    points: [Offset(1100,900), Offset(1200,1100), Offset(1300,1300), Offset(1400,1500), Offset(1500,1650)],
    stationIds: [260,261,262,263,264,265,266,267,268],
  ),
  SchematicLine( // L11 Coral — leste
    lineCode: 'L11',
    points: [Offset(1100,900), Offset(1300,900), Offset(1600,850), Offset(1900,800), Offset(2200,750)],
    stationIds: [280,281,282,283,284,285,286,287,288,289,290,291],
  ),
  SchematicLine( // L12 Safira — leste-sudeste
    lineCode: 'L12',
    points: [Offset(1100,950), Offset(1300,1000), Offset(1600,1050), Offset(1900,1100), Offset(2100,1200)],
    stationIds: [300,301,302,303,304,305,306,307,308,309,310],
  ),
  SchematicLine( // L13 Jade — Guarulhos / aeroporto
    lineCode: 'L13',
    points: [Offset(1100,900), Offset(1200,700), Offset(1400,500), Offset(1600,350), Offset(1900,200)],
    stationIds: [320,321,322,323,324],
  ),
  SchematicLine( // L17 Ouro — monotrilho sul aeroporto
    lineCode: 'L17',
    points: [Offset(900,1400), Offset(1000,1300), Offset(1100,1200), Offset(1200,1100)],
    stationIds: [340,341,342,343,344,345],
  ),
  SchematicLine( // LA Santos-Jundiaí — diagonal leste
    lineCode: 'LA',
    points: [Offset(1100,900), Offset(1350,1050), Offset(1600,1200), Offset(1850,1350), Offset(2100,1500)],
    stationIds: [360,361,362,363,364,365,366],
  ),
  SchematicLine( // LB Diamante Expresso — oeste expresso
    lineCode: 'LB',
    points: [Offset(1100,850), Offset(800,850), Offset(500,850), Offset(250,850)],
    stationIds: [380,381,382,383,384],
  ),
];

// ══════════════════════════════════════════════════════════════════════════════
// ESTAÇÕES
// ══════════════════════════════════════════════════════════════════════════════
const List<SchematicStation> _stations = [
  // ── L1 Azul ───────────────────────────────────────────────────────────────
  SchematicStation(stationId: 1,  name: 'Tucuruvi',                   position: Offset(1100, 130),  labelSide: LabelSide.above),
  SchematicStation(stationId: 2,  name: 'Parada Inglesa',             position: Offset(1100, 220),  labelSide: LabelSide.below),
  SchematicStation(stationId: 3,  name: 'Jd. São Paulo-Ayrton Senna', position: Offset(1100, 310),  labelSide: LabelSide.above),
  SchematicStation(stationId: 4,  name: 'Santana',                    position: Offset(1100, 400),  labelSide: LabelSide.below),
  SchematicStation(stationId: 5,  name: 'Carandiru',                  position: Offset(1100, 480),  labelSide: LabelSide.above),
  SchematicStation(stationId: 6,  name: 'Portuguesa-Tietê',           position: Offset(1100, 560),  labelSide: LabelSide.below),
  SchematicStation(stationId: 7,  name: 'Armênia',                    position: Offset(1100, 640),  labelSide: LabelSide.above),
  SchematicStation(stationId: 8,  name: 'Tiradentes',                 position: Offset(1100, 720),  labelSide: LabelSide.below),
  SchematicStation(stationId: 9,  name: 'Luz',                        position: Offset(1100, 900),  isInterchange: true, lineCodes: ['L1','L3','L7','L13'], maxCapacity: 3000, labelSide: LabelSide.above),
  SchematicStation(stationId: 10, name: 'São Bento',                  position: Offset(1100, 980),  labelSide: LabelSide.below),
  SchematicStation(stationId: 11, name: 'Sé',                         position: Offset(1100, 1060), isInterchange: true, lineCodes: ['L1','L3'], maxCapacity: 2500, labelSide: LabelSide.above),
  SchematicStation(stationId: 12, name: 'Liberdade',                  position: Offset(1100, 1140), labelSide: LabelSide.below),
  SchematicStation(stationId: 13, name: 'São Joaquim',                position: Offset(1100, 1220), labelSide: LabelSide.above),
  SchematicStation(stationId: 14, name: 'Vergueiro',                  position: Offset(1100, 1310), labelSide: LabelSide.below),
  SchematicStation(stationId: 15, name: 'Paraíso',                    position: Offset(1100, 1390), isInterchange: true, lineCodes: ['L1','L2'], maxCapacity: 2000, labelSide: LabelSide.above),
  SchematicStation(stationId: 16, name: 'Ana Rosa',                   position: Offset(1100, 1470), isInterchange: true, lineCodes: ['L1','L2'], maxCapacity: 2000, labelSide: LabelSide.below),
  SchematicStation(stationId: 17, name: 'Vila Mariana',               position: Offset(1100, 1560), labelSide: LabelSide.above),

  // ── L2 Verde ───────────────────────────────────────────────────────────────
  SchematicStation(stationId: 25, name: 'Vila Madalena',              position: Offset(620, 720),   labelSide: LabelSide.above),
  SchematicStation(stationId: 26, name: 'Sumaré',                     position: Offset(700, 800),   labelSide: LabelSide.below),
  SchematicStation(stationId: 27, name: 'Clínicas',                   position: Offset(780, 855),   labelSide: LabelSide.above),
  SchematicStation(stationId: 28, name: 'Consolação',                 position: Offset(860, 900),   labelSide: LabelSide.below),
  SchematicStation(stationId: 29, name: 'Trianon-Masp',               position: Offset(940, 900),   labelSide: LabelSide.above),
  SchematicStation(stationId: 30, name: 'Brigadeiro',                 position: Offset(1000, 900),  labelSide: LabelSide.below),
  SchematicStation(stationId: 31, name: 'Paraíso',                    position: Offset(1100, 1390), isInterchange: true, lineCodes: ['L1','L2'], maxCapacity: 2000, labelSide: LabelSide.above),
  SchematicStation(stationId: 32, name: 'Ana Rosa',                   position: Offset(1100, 1470), isInterchange: true, lineCodes: ['L1','L2'], maxCapacity: 2000, labelSide: LabelSide.below),
  SchematicStation(stationId: 33, name: 'Chácara Klabin',             position: Offset(1200, 1200), labelSide: LabelSide.above),
  SchematicStation(stationId: 34, name: 'Santos-Imigrantes',          position: Offset(1300, 1250), labelSide: LabelSide.below),
  SchematicStation(stationId: 35, name: 'Vila Prudente',              position: Offset(1400, 1300), labelSide: LabelSide.above),

  // ── L3 Vermelha ───────────────────────────────────────────────────────────
  SchematicStation(stationId: 36, name: 'Palmeiras-Barra Funda',      position: Offset(420, 900),   isInterchange: true, lineCodes: ['L3','L8','LB'], maxCapacity: 2500, labelSide: LabelSide.above),
  SchematicStation(stationId: 37, name: 'Marechal Deodoro',           position: Offset(530, 900),   labelSide: LabelSide.below),
  SchematicStation(stationId: 38, name: 'Santa Cecília',              position: Offset(640, 900),   labelSide: LabelSide.above),
  SchematicStation(stationId: 39, name: 'República',                  position: Offset(750, 900),   labelSide: LabelSide.below),
  SchematicStation(stationId: 40, name: 'Anhangabaú',                 position: Offset(860, 900),   labelSide: LabelSide.above),
  SchematicStation(stationId: 41, name: 'Sé',                         position: Offset(970, 900),   isInterchange: true, lineCodes: ['L1','L3'], maxCapacity: 2500, labelSide: LabelSide.below),
  SchematicStation(stationId: 42, name: 'Pedro II',                   position: Offset(1080, 900),  labelSide: LabelSide.above),
  SchematicStation(stationId: 43, name: 'Brás',                       position: Offset(1200, 900),  isInterchange: true, lineCodes: ['L3','L10','L11','L12','LA'], maxCapacity: 3000, labelSide: LabelSide.below),
  SchematicStation(stationId: 44, name: 'Bresser-Mooca',              position: Offset(1320, 900),  labelSide: LabelSide.above),
  SchematicStation(stationId: 45, name: 'Belém',                      position: Offset(1430, 900),  labelSide: LabelSide.below),
  SchematicStation(stationId: 46, name: 'Tatuapé',                    position: Offset(1540, 900),  isInterchange: true, lineCodes: ['L3','L11','L12'], maxCapacity: 2000, labelSide: LabelSide.above),
  SchematicStation(stationId: 47, name: 'Carrão',                     position: Offset(1640, 900),  labelSide: LabelSide.below),
  SchematicStation(stationId: 48, name: 'Penha',                      position: Offset(1740, 900),  labelSide: LabelSide.above),
  SchematicStation(stationId: 49, name: 'Corinthians-Itaquera',       position: Offset(1880, 900),  isInterchange: true, lineCodes: ['L3','L11'], maxCapacity: 2500, labelSide: LabelSide.below),

  // ── L4 Amarela ────────────────────────────────────────────────────────────
  SchematicStation(stationId: 50, name: 'Vila Sônia',                 position: Offset(520, 1480),  labelSide: LabelSide.above),
  SchematicStation(stationId: 51, name: 'São Paulo-Morumbi',          position: Offset(620, 1390),  labelSide: LabelSide.below),
  SchematicStation(stationId: 52, name: 'Butantã',                    position: Offset(720, 1290),  labelSide: LabelSide.above),
  SchematicStation(stationId: 53, name: 'Pinheiros',                  position: Offset(820, 1190),  isInterchange: true, lineCodes: ['L4','L9'], maxCapacity: 2000, labelSide: LabelSide.below),
  SchematicStation(stationId: 54, name: 'Faria Lima',                 position: Offset(920, 1090),  labelSide: LabelSide.above),
  SchematicStation(stationId: 55, name: 'Luz',                        position: Offset(1100, 900),  isInterchange: true, lineCodes: ['L1','L3','L7','L13'], maxCapacity: 3000, labelSide: LabelSide.above),

  // ── L5 Lilás ──────────────────────────────────────────────────────────────
  SchematicStation(stationId: 60, name: 'Capão Redondo',              position: Offset(420, 1400),  labelSide: LabelSide.above),
  SchematicStation(stationId: 62, name: 'Campo Limpo',                position: Offset(560, 1400),  labelSide: LabelSide.below),
  SchematicStation(stationId: 64, name: 'Vila das Belezas',           position: Offset(700, 1400),  labelSide: LabelSide.above),
  SchematicStation(stationId: 66, name: 'Giovanni Gronchi',           position: Offset(840, 1400),  labelSide: LabelSide.below),
  SchematicStation(stationId: 68, name: 'Socorro',                    position: Offset(980, 1400),  labelSide: LabelSide.above),
  SchematicStation(stationId: 70, name: 'Adolfo Pinheiro',            position: Offset(1080, 1400), labelSide: LabelSide.below),
  SchematicStation(stationId: 72, name: 'Alto da Boa Vista',          position: Offset(1160, 1370), labelSide: LabelSide.above),
  SchematicStation(stationId: 73, name: 'Brooklin',                   position: Offset(1240, 1340), labelSide: LabelSide.below),
  SchematicStation(stationId: 75, name: 'Eucaliptos',                 position: Offset(1320, 1310), labelSide: LabelSide.above),
  SchematicStation(stationId: 76, name: 'Moema',                      position: Offset(1400, 1300), isInterchange: true, lineCodes: ['L5','L17'], maxCapacity: 1800, labelSide: LabelSide.below),

  // ── L15 Prata ─────────────────────────────────────────────────────────────
  SchematicStation(stationId: 101, name: 'São Mateus',                position: Offset(1700, 1300), labelSide: LabelSide.above),
  SchematicStation(stationId: 102, name: 'São Lucas',                 position: Offset(1620, 1240), labelSide: LabelSide.below),
  SchematicStation(stationId: 103, name: 'Camilo Haddad',             position: Offset(1540, 1180), labelSide: LabelSide.above),
  SchematicStation(stationId: 104, name: 'Vila Tolstói',              position: Offset(1460, 1130), labelSide: LabelSide.below),
  SchematicStation(stationId: 105, name: 'Vila União',                position: Offset(1380, 1090), labelSide: LabelSide.above),
  SchematicStation(stationId: 106, name: 'Jardim Planalto',           position: Offset(1300, 1060), labelSide: LabelSide.below),
  SchematicStation(stationId: 107, name: 'Sapopemba',                 position: Offset(1220, 1020), labelSide: LabelSide.above),
  SchematicStation(stationId: 108, name: 'Fazenda da Juta',           position: Offset(1180, 980),  labelSide: LabelSide.below),
  SchematicStation(stationId: 109, name: 'São Paulo-Morumbi',         position: Offset(1150, 960),  labelSide: LabelSide.above),
  SchematicStation(stationId: 110, name: 'Vila Prudente',             position: Offset(1400, 1300), isInterchange: true, lineCodes: ['L2','L15'], maxCapacity: 1500, labelSide: LabelSide.below),
  SchematicStation(stationId: 111, name: 'Oratório',                  position: Offset(1550, 1190), labelSide: LabelSide.above),

  // ── L7 Rubi ───────────────────────────────────────────────────────────────
  SchematicStation(stationId: 201, name: 'Luz',                       position: Offset(1100, 900),  isInterchange: true, lineCodes: ['L1','L3','L7','L13'], maxCapacity: 3000, labelSide: LabelSide.above),
  SchematicStation(stationId: 202, name: 'Palmeiras-Barra Funda',     position: Offset(420, 900),   isInterchange: true, lineCodes: ['L3','L7','L8'], maxCapacity: 2500, labelSide: LabelSide.above),
  SchematicStation(stationId: 203, name: 'Lapa',                      position: Offset(780, 680),   labelSide: LabelSide.below),
  SchematicStation(stationId: 204, name: 'Pirituba',                  position: Offset(640, 530),   labelSide: LabelSide.above),
  SchematicStation(stationId: 205, name: 'Perus',                     position: Offset(500, 380),   labelSide: LabelSide.below),
  SchematicStation(stationId: 206, name: 'Caieiras',                  position: Offset(400, 290),   labelSide: LabelSide.above),
  SchematicStation(stationId: 207, name: 'Franco da Rocha',           position: Offset(320, 220),   labelSide: LabelSide.below),
  SchematicStation(stationId: 208, name: 'Francisco Morato',          position: Offset(250, 170),   labelSide: LabelSide.above),
  SchematicStation(stationId: 209, name: 'Botujuru',                  position: Offset(180, 150),   labelSide: LabelSide.below),
  SchematicStation(stationId: 210, name: 'Campo Limpo Paulista',      position: Offset(120, 160),   labelSide: LabelSide.above),
  SchematicStation(stationId: 211, name: 'Várzea Paulista',           position: Offset(90, 175),    labelSide: LabelSide.below),
  SchematicStation(stationId: 212, name: 'Jundiaí',                   position: Offset(60, 195),    labelSide: LabelSide.above),
  SchematicStation(stationId: 213, name: 'Baltazar Fidélis',          position: Offset(860, 600),   labelSide: LabelSide.below),

  // ── L8 Diamante ───────────────────────────────────────────────────────────
  SchematicStation(stationId: 220, name: 'Amador Bueno',              position: Offset(220, 950),   labelSide: LabelSide.above),
  SchematicStation(stationId: 221, name: 'Antônio João',              position: Offset(340, 950),   labelSide: LabelSide.below),
  SchematicStation(stationId: 222, name: 'Palmeiras-Barra Funda',     position: Offset(420, 900),   isInterchange: true, lineCodes: ['L3','L7','L8'], maxCapacity: 2500, labelSide: LabelSide.above),
  SchematicStation(stationId: 223, name: 'Lapa',                      position: Offset(780, 680),   isInterchange: true, lineCodes: ['L7','L8'], maxCapacity: 1800, labelSide: LabelSide.below),
  SchematicStation(stationId: 224, name: 'Imperatriz Leopoldina',     position: Offset(660, 950),   labelSide: LabelSide.above),
  SchematicStation(stationId: 225, name: 'Pinheiros',                 position: Offset(820, 1190),  isInterchange: true, lineCodes: ['L4','L8','L9'], maxCapacity: 2000, labelSide: LabelSide.below),
  SchematicStation(stationId: 226, name: 'Osasco',                    position: Offset(580, 950),   labelSide: LabelSide.above),
  SchematicStation(stationId: 227, name: 'Presidente Altino',         position: Offset(460, 950),   labelSide: LabelSide.below),
  SchematicStation(stationId: 228, name: 'Carapicuíba',               position: Offset(360, 950),   labelSide: LabelSide.above),
  SchematicStation(stationId: 229, name: 'General Miguel Costa',      position: Offset(290, 950),   labelSide: LabelSide.below),
  SchematicStation(stationId: 230, name: 'Barueri',                   position: Offset(230, 950),   labelSide: LabelSide.above),
  SchematicStation(stationId: 231, name: 'Júlio Prestes',             position: Offset(1000, 950),  isInterchange: true, lineCodes: ['L8','L3'], maxCapacity: 2000, labelSide: LabelSide.below),
  SchematicStation(stationId: 232, name: 'Luz',                       position: Offset(1100, 900),  isInterchange: true, lineCodes: ['L1','L3','L7','L13'], maxCapacity: 3000, labelSide: LabelSide.above),

  // ── L9 Esmeralda ──────────────────────────────────────────────────────────
  SchematicStation(stationId: 240, name: 'Osasco',                    position: Offset(580, 950),   labelSide: LabelSide.above),
  SchematicStation(stationId: 241, name: 'Presidente Altino',         position: Offset(460, 950),   labelSide: LabelSide.below),
  SchematicStation(stationId: 242, name: 'Ceasa',                     position: Offset(700, 1050),  labelSide: LabelSide.above),
  SchematicStation(stationId: 243, name: 'Villa Lobos-Jaguaré',       position: Offset(760, 1100),  labelSide: LabelSide.below),
  SchematicStation(stationId: 244, name: 'Cidade Universitária',      position: Offset(810, 1140),  labelSide: LabelSide.above),
  SchematicStation(stationId: 245, name: 'Pinheiros',                 position: Offset(820, 1190),  isInterchange: true, lineCodes: ['L4','L8','L9'], maxCapacity: 2000, labelSide: LabelSide.below),
  SchematicStation(stationId: 246, name: 'Hebraica-Rebouças',         position: Offset(900, 1250),  labelSide: LabelSide.above),
  SchematicStation(stationId: 247, name: 'Cidade Jardim',             position: Offset(920, 1310),  labelSide: LabelSide.below),
  SchematicStation(stationId: 248, name: 'Vila Olímpia',              position: Offset(940, 1370),  labelSide: LabelSide.above),
  SchematicStation(stationId: 249, name: 'Grajaú',                    position: Offset(320, 1400),  labelSide: LabelSide.below),

  // ── L10 Turquesa ──────────────────────────────────────────────────────────
  SchematicStation(stationId: 260, name: 'Brás',                      position: Offset(1200, 900),  isInterchange: true, lineCodes: ['L3','L10','L11','L12','LA'], maxCapacity: 3000, labelSide: LabelSide.above),
  SchematicStation(stationId: 261, name: 'Tamanduateí',               position: Offset(1250, 1000), isInterchange: true, lineCodes: ['L10','L2'], maxCapacity: 1800, labelSide: LabelSide.below),
  SchematicStation(stationId: 262, name: 'Utinga',                    position: Offset(1300, 1100), labelSide: LabelSide.above),
  SchematicStation(stationId: 263, name: 'Prefeito Saladino',         position: Offset(1350, 1200), labelSide: LabelSide.below),
  SchematicStation(stationId: 264, name: 'Santo André',               position: Offset(1400, 1350), labelSide: LabelSide.above),
  SchematicStation(stationId: 265, name: 'Capuava',                   position: Offset(1430, 1430), labelSide: LabelSide.below),
  SchematicStation(stationId: 266, name: 'Mauá',                      position: Offset(1450, 1510), labelSide: LabelSide.above),
  SchematicStation(stationId: 267, name: 'Guapituba',                 position: Offset(1470, 1580), labelSide: LabelSide.below),
  SchematicStation(stationId: 268, name: 'Ribeirão Pires',            position: Offset(1490, 1650), labelSide: LabelSide.above),

  // ── L11 Coral ─────────────────────────────────────────────────────────────
  SchematicStation(stationId: 280, name: 'Luz',                       position: Offset(1100, 900),  isInterchange: true, lineCodes: ['L1','L3','L7','L13'], maxCapacity: 3000, labelSide: LabelSide.above),
  SchematicStation(stationId: 281, name: 'Brás',                      position: Offset(1200, 900),  isInterchange: true, lineCodes: ['L3','L10','L11','L12','LA'], maxCapacity: 3000, labelSide: LabelSide.below),
  SchematicStation(stationId: 282, name: 'Tatuapé',                   position: Offset(1540, 900),  isInterchange: true, lineCodes: ['L3','L11','L12'], maxCapacity: 2000, labelSide: LabelSide.above),
  SchematicStation(stationId: 283, name: 'Corinthians-Itaquera',      position: Offset(1880, 900),  isInterchange: true, lineCodes: ['L3','L11'], maxCapacity: 2500, labelSide: LabelSide.below),
  SchematicStation(stationId: 284, name: 'Dom Bosco',                 position: Offset(1960, 870),  labelSide: LabelSide.above),
  SchematicStation(stationId: 285, name: 'José Bonifácio',            position: Offset(2040, 840),  labelSide: LabelSide.below),
  SchematicStation(stationId: 286, name: 'Guaianases',                position: Offset(2120, 810),  labelSide: LabelSide.above),
  SchematicStation(stationId: 287, name: 'Antônio Gianetti Neto',     position: Offset(2180, 785),  labelSide: LabelSide.below),
  SchematicStation(stationId: 288, name: 'Ferraz de Vasconcelos',     position: Offset(2220, 770),  labelSide: LabelSide.above),
  SchematicStation(stationId: 289, name: 'Poá',                       position: Offset(2240, 760),  labelSide: LabelSide.below),
  SchematicStation(stationId: 290, name: 'Suzano',                    position: Offset(2260, 755),  labelSide: LabelSide.above),
  SchematicStation(stationId: 291, name: 'Jundiapeba',                position: Offset(2290, 750),  labelSide: LabelSide.below),

  // ── L12 Safira ────────────────────────────────────────────────────────────
  SchematicStation(stationId: 300, name: 'Brás',                      position: Offset(1200, 900),  isInterchange: true, lineCodes: ['L3','L10','L11','L12','LA'], maxCapacity: 3000, labelSide: LabelSide.above),
  SchematicStation(stationId: 301, name: 'Tatuapé',                   position: Offset(1540, 900),  isInterchange: true, lineCodes: ['L3','L11','L12'], maxCapacity: 2000, labelSide: LabelSide.below),
  SchematicStation(stationId: 302, name: 'Engenheiro Goulart',        position: Offset(1620, 950),  labelSide: LabelSide.above),
  SchematicStation(stationId: 303, name: 'USP Leste',                 position: Offset(1700, 990),  labelSide: LabelSide.below),
  SchematicStation(stationId: 304, name: 'Itaim Paulista',            position: Offset(1800, 1040), labelSide: LabelSide.above),
  SchematicStation(stationId: 305, name: 'Jardim Romano',             position: Offset(1880, 1080), labelSide: LabelSide.below),
  SchematicStation(stationId: 306, name: 'Engenheiro Manoel Feio',    position: Offset(1950, 1110), labelSide: LabelSide.above),
  SchematicStation(stationId: 307, name: 'Aracaré',                   position: Offset(2020, 1140), labelSide: LabelSide.below),
  SchematicStation(stationId: 308, name: 'Calmon Viana',              position: Offset(2080, 1170), labelSide: LabelSide.above),
  SchematicStation(stationId: 309, name: 'Mogi das Cruzes',           position: Offset(2140, 1200), labelSide: LabelSide.below),
  SchematicStation(stationId: 310, name: 'Estudantes',                position: Offset(2180, 1220), labelSide: LabelSide.above),

  // ── L13 Jade ──────────────────────────────────────────────────────────────
  SchematicStation(stationId: 320, name: 'Luz',                       position: Offset(1100, 900),  isInterchange: true, lineCodes: ['L1','L3','L7','L13'], maxCapacity: 3000, labelSide: LabelSide.above),
  SchematicStation(stationId: 321, name: 'Eng. Trindade',             position: Offset(1230, 720),  labelSide: LabelSide.below),
  SchematicStation(stationId: 322, name: 'Cecap',                     position: Offset(1430, 520),  labelSide: LabelSide.above),
  SchematicStation(stationId: 323, name: 'Parada Rodoviária',         position: Offset(1620, 370),  labelSide: LabelSide.below),
  SchematicStation(stationId: 324, name: 'Aeroporto-Guarulhos',       position: Offset(1880, 200),  labelSide: LabelSide.above),

  // ── L17 Ouro ──────────────────────────────────────────────────────────────
  SchematicStation(stationId: 340, name: 'Jabaquara',                 position: Offset(900, 1560),  isInterchange: true, lineCodes: ['L1','L17'], maxCapacity: 1500, labelSide: LabelSide.above),
  SchematicStation(stationId: 341, name: 'Brooklin Paulista',         position: Offset(950, 1460),  labelSide: LabelSide.below),
  SchematicStation(stationId: 342, name: 'AACD-Servidor',             position: Offset(1000, 1370), labelSide: LabelSide.above),
  SchematicStation(stationId: 343, name: 'Hospital São Paulo',        position: Offset(1060, 1270), labelSide: LabelSide.below),
  SchematicStation(stationId: 344, name: 'Aeroporto de Congonhas',    position: Offset(1100, 1200), labelSide: LabelSide.above),
  SchematicStation(stationId: 345, name: 'Morumbi',                   position: Offset(1150, 1120), isInterchange: true, lineCodes: ['L5','L17'], maxCapacity: 1800, labelSide: LabelSide.below),

  // ── LA Santos-Jundiaí ─────────────────────────────────────────────────────
  SchematicStation(stationId: 360, name: 'Brás',                      position: Offset(1200, 900),  isInterchange: true, lineCodes: ['L3','L10','L11','L12','LA'], maxCapacity: 3000, labelSide: LabelSide.above),
  SchematicStation(stationId: 361, name: 'Ipiranga',                  position: Offset(1340, 980),  labelSide: LabelSide.below),
  SchematicStation(stationId: 362, name: 'São Caetano do Sul',        position: Offset(1480, 1060), labelSide: LabelSide.above),
  SchematicStation(stationId: 363, name: 'Rio Grande da Serra',       position: Offset(1620, 1140), labelSide: LabelSide.below),
  SchematicStation(stationId: 364, name: 'Ribeirão Pires',            position: Offset(1760, 1220), labelSide: LabelSide.above),
  SchematicStation(stationId: 365, name: 'Piraporinha',               position: Offset(1900, 1300), labelSide: LabelSide.below),
  SchematicStation(stationId: 366, name: 'Diadema',                   position: Offset(2040, 1380), labelSide: LabelSide.above),

  // ── LB Diamante Expresso ──────────────────────────────────────────────────
  SchematicStation(stationId: 380, name: 'Luz',                       position: Offset(1100, 900),  isInterchange: true, lineCodes: ['L1','L3','L7','L13'], maxCapacity: 3000, labelSide: LabelSide.above),
  SchematicStation(stationId: 381, name: 'Lapa',                      position: Offset(780, 680),   isInterchange: true, lineCodes: ['L7','L8','LB'], maxCapacity: 1800, labelSide: LabelSide.below),
  SchematicStation(stationId: 382, name: 'Osasco',                    position: Offset(580, 850),   isInterchange: true, lineCodes: ['L8','L9','LB'], maxCapacity: 1500, labelSide: LabelSide.above),
  SchematicStation(stationId: 383, name: 'Carapicuíba',               position: Offset(360, 850),   labelSide: LabelSide.below),
  SchematicStation(stationId: 384, name: 'Amador Bueno',              position: Offset(220, 850),   labelSide: LabelSide.above),
];
```

- [ ] **Step 4: Rodar testes**

```bash
cd mobile && flutter test test/core/data/sao_paulo_schematic_test.dart
```
Expected: todos PASS.

- [ ] **Step 5: Verificar que o app compila**

```bash
cd mobile && flutter build apk --debug 2>&1 | tail -5
```

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/core/data/sao_paulo_schematic.dart mobile/test/core/data/sao_paulo_schematic_test.dart
git commit -m "feat: rewrite SP schematic with all 16 lines, polylines, interchanges, station names"
```

---

## Chunk 3: Painter atualizado

### Task 4: Refatorar `TransitMapPainter` com labels, interchanges e dark mode

**Files:**
- Modify: `mobile/lib/features/transit_map/transit_map_painter.dart`
- Modify: `mobile/test/features/transit_map/transit_map_painter_test.dart`

- [ ] **Step 1: Escrever testes**

```dart
// Adicionar ao transit_map_painter_test.dart

group('TransitMapPainter label angle calculation', () {
  test('_segmentAngle returns 0 for horizontal segment', () {
    const p1 = Offset(0, 100);
    const p2 = Offset(100, 100);
    final angle = TransitMapPainter.segmentAngle(p1, p2);
    expect(angle, closeTo(0.0, 0.001));
  });

  test('_segmentAngle returns pi/2 for vertical segment going down', () {
    const p1 = Offset(100, 0);
    const p2 = Offset(100, 100);
    final angle = TransitMapPainter.segmentAngle(p1, p2);
    expect(angle, closeTo(1.5708, 0.001)); // pi/2
  });

  test('_segmentAngleForStation finds correct segment', () {
    final points = [const Offset(0, 0), const Offset(100, 0), const Offset(200, 50)];
    final angle = TransitMapPainter.segmentAngleForStation(const Offset(50, 0), points);
    expect(angle, closeTo(0.0, 0.001)); // horizontal segment
  });

  test('_interchangeTickAngle returns angle opposite to mean of crossing angles', () {
    import 'dart:math';
    // Two lines crossing at 0° and 90° — mean = 45°, opposite = 45° + pi = 225°
    final angle = TransitMapPainter.interchangeTickAngle([0.0, pi / 2]);
    expect(angle, closeTo(pi / 4 + pi, 0.01));
  });
});

group('TransitMapPainter brightness', () {
  test('accepts Brightness.dark without throwing', () {
    final painter = TransitMapPainter(
      schematic: _minimalSchematic(),
      crowdState: {},
      lineColors: {'L1': const Color(0xFF0455A1)},
      selectedLineCode: null,
      zoomProgress: 0,
      barProgress: 0,
      trainEstimate: null,
      trainPulse: 0,
      brightness: Brightness.dark,
      currentScale: 1.0,
    );
    expect(painter, isNotNull);
  });
});
```

- [ ] **Step 2: Rodar para ver falhar**

```bash
cd mobile && flutter test test/features/transit_map/transit_map_painter_test.dart
```
Expected: FAIL — `brightness`, `currentScale`, `segmentAngle` não existem.

- [ ] **Step 3: Reescrever `transit_map_painter.dart`**

```dart
// mobile/lib/features/transit_map/transit_map_painter.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/models/schematic_model.dart';
import 'train_estimator.dart';

class TransitMapPainter extends CustomPainter {
  final TransitSchematic schematic;
  final Map<int, double> crowdState;
  final Map<String, Color> lineColors;
  final String? selectedLineCode;
  final double zoomProgress;
  final double barProgress;
  final TrainEstimate? trainEstimate;
  final double trainPulse;
  final Brightness brightness;
  final double currentScale;

  const TransitMapPainter({
    required this.schematic,
    required this.crowdState,
    required this.lineColors,
    required this.selectedLineCode,
    required this.zoomProgress,
    required this.barProgress,
    required this.trainEstimate,
    required this.trainPulse,
    required this.brightness,
    required this.currentScale,
  });

  bool get _isDark => brightness == Brightness.dark;

  Color get _bgColor     => _isDark ? const Color(0xFF121212) : Colors.white;
  Color get _labelColor  => _isDark ? const Color(0xFFEEEEEE) : const Color(0xFF111111);
  Color get _tickColor   => _isDark ? const Color(0xFF555555) : const Color(0xFFBBBBBB);
  Color get _ringColor   => _isDark ? const Color(0xFF555555) : const Color(0xFFCCCCCC);
  Color get _nucleusColor => _isDark ? const Color(0xFF1E1E1E) : Colors.white;
  Color get _nucleusBorderColor => _isDark ? const Color(0xFFDDDDDD) : const Color(0xFF444444);

  // ── Label opacity based on zoom scale ─────────────────────────────────────
  double get _labelOpacity => ((currentScale - 0.8) / (1.5 - 0.8)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width  / schematic.canvasSize.width;
    final scaleY = size.height / schematic.canvasSize.height;

    // ── 1. Lines ─────────────────────────────────────────────────────────────
    for (final line in schematic.lines) {
      final isSelected = selectedLineCode == line.lineCode;
      final opacity = selectedLineCode == null
          ? 1.0
          : isSelected ? 1.0 : 0.15 + (0.85 * (1.0 - zoomProgress));

      final baseColor = lineColors[line.lineCode] ?? Colors.grey;
      final color = baseColor.withValues(alpha: opacity);
      final isMetro = ['L1','L2','L3','L4','L5','L15'].contains(line.lineCode);
      final strokeWidth = (isMetro ? 10.0 : 8.0) * scaleX * (isSelected ? 1.15 : 1.0);

      final paint = Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      for (int i = 0; i < line.points.length; i++) {
        final p = Offset(line.points[i].dx * scaleX, line.points[i].dy * scaleY);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }

    // ── 2. Stations ───────────────────────────────────────────────────────────
    for (final station in schematic.stations) {
      final pos = Offset(station.position.dx * scaleX, station.position.dy * scaleY);
      final density = crowdState[station.stationId] ?? 0.0;
      final dotColor = _colorForDensity(density);

      final isOnSelectedLine = selectedLineCode != null &&
          schematic.stationsForLine(selectedLineCode!).any((s) => s.stationId == station.stationId);
      final dotOpacity = selectedLineCode == null
          ? 1.0
          : isOnSelectedLine ? 1.0 : 0.20 + (0.80 * (1.0 - zoomProgress));

      final isSelected = isOnSelectedLine && selectedLineCode != null;
      final baseRadius = station.isInterchange ? 8.0 : 5.0;
      final radius = (isSelected ? baseRadius * 1.4 : baseRadius) * scaleX;

      if (station.isInterchange) {
        // Outer ring
        final ringRadius = radius * 1.5;
        canvas.drawCircle(pos, ringRadius,
          Paint()
            ..color = _ringColor.withValues(alpha: dotOpacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5 * scaleX,
        );
        // Nucleus fill
        canvas.drawCircle(pos, radius, Paint()..color = _nucleusColor.withValues(alpha: dotOpacity));
        // Nucleus border
        canvas.drawCircle(pos, radius,
          Paint()
            ..color = _nucleusBorderColor.withValues(alpha: dotOpacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0 * scaleX,
        );
      } else {
        // Simple station: fill = bgColor, stroke = line color tinted by density
        final lineColor = _firstLineColor(station);
        canvas.drawCircle(pos, radius, Paint()..color = _nucleusColor.withValues(alpha: dotOpacity));
        canvas.drawCircle(pos, radius,
          Paint()
            ..color = (density > 0.05 ? dotColor : lineColor).withValues(alpha: dotOpacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0 * scaleX,
        );
      }

      // Capacity bar
      if (isOnSelectedLine && barProgress > 0) {
        _drawCapacityBar(canvas, pos, density, barProgress, dotColor, dotOpacity, scaleX, scaleY);
      }

      // Label
      if (_labelOpacity > 0) {
        _drawLabel(canvas, station, pos, scaleX, scaleY, dotOpacity * _labelOpacity);
      }
    }

    // ── 3. Train icon ────────────────────────────────────────────────────────
    if (trainEstimate != null && selectedLineCode != null && barProgress > 0) {
      _drawTrainIcon(canvas, scaleX, scaleY);
    }
  }

  void _drawLabel(Canvas canvas, SchematicStation station, Offset pos,
      double scaleX, double scaleY, double opacity) {
    if (opacity <= 0) return;

    // Find line to get angle
    final line = schematic.lines
        .where((l) => l.stationIds.contains(station.stationId))
        .firstOrNull;

    double angle = 0.0;
    if (line != null && line.points.length >= 2) {
      angle = segmentAngleForStation(station.position, line.points);
    }

    // For interchanges at line crossings, use bisector tick
    double tickAngle;
    if (station.isInterchange && station.lineCodes.length >= 2) {
      final angles = station.lineCodes.map((code) {
        final l = schematic.lines.where((ln) => ln.lineCode == code).firstOrNull;
        if (l == null || l.points.length < 2) return 0.0;
        return segmentAngleForStation(station.position, l.points);
      }).toList();
      tickAngle = interchangeTickAngle(angles);
    } else {
      // Perpendicular to line: labelSide above = tick goes negative y in rotated group
      tickAngle = angle + (station.labelSide == LabelSide.above ? -pi / 2 : pi / 2);
    }

    final markerRadius = (station.isInterchange ? 8.0 * 1.5 : 5.0) * scaleX;
    final tickLength = (station.isInterchange ? 22.0 : 18.0) * scaleX;

    // Tick start at edge of marker
    final tickStart = pos + Offset(cos(tickAngle) * markerRadius, sin(tickAngle) * markerRadius);
    final tickEnd   = pos + Offset(cos(tickAngle) * (markerRadius + tickLength), sin(tickAngle) * (markerRadius + tickLength));

    // Draw dashed tick
    _drawDashedLine(canvas, tickStart, tickEnd,
      Paint()
        ..color = _tickColor.withValues(alpha: opacity)
        ..strokeWidth = 1.2 * scaleX
        ..style = PaintingStyle.stroke,
      dashLen: 3.0 * scaleX, gap: 3.0 * scaleX,
    );

    // Draw label text — rotated with line angle
    final fontSize = (station.isInterchange ? 11.0 : 9.5) * scaleX.clamp(0.8, 2.0);
    final fontWeight = station.isInterchange ? FontWeight.w700 : FontWeight.w600;

    canvas.save();
    canvas.translate(tickEnd.dx, tickEnd.dy);
    canvas.rotate(angle);

    final tp = TextPainter(
      text: TextSpan(
        text: station.name,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: _labelColor.withValues(alpha: opacity),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 200 * scaleX);

    // Center text on the tick endpoint
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  void _drawCapacityBar(Canvas canvas, Offset pos, double density,
      double barProgress, Color dotColor, double opacity, double scaleX, double scaleY) {
    const barWidth = 5.0;
    const maxBarHeight = 24.0;
    final barHeight = maxBarHeight * density * barProgress * scaleY;
    final barX = pos.dx + 10.0 * scaleX;
    final barY = pos.dy + (maxBarHeight * scaleY) / 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, barY - maxBarHeight * scaleY, barWidth * scaleX, maxBarHeight * scaleY),
        const Radius.circular(2),
      ),
      Paint()..color = dotColor.withValues(alpha: 0.15 * opacity),
    );
    if (barHeight > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(barX, barY - barHeight, barWidth * scaleX, barHeight),
          const Radius.circular(2),
        ),
        Paint()..color = dotColor.withValues(alpha: opacity),
      );
    }
  }

  void _drawTrainIcon(Canvas canvas, double scaleX, double scaleY) {
    final ids = trainEstimate!.betweenStationIds;
    final stA = schematic.stationById(ids[0]);
    final stB = ids.length > 1 ? schematic.stationById(ids[1]) : null;
    if (stA == null) return;

    final posA = Offset(stA.position.dx * scaleX, stA.position.dy * scaleY);
    final posB = stB != null ? Offset(stB.position.dx * scaleX, stB.position.dy * scaleY) : posA;
    final trainPos = Offset.lerp(posA, posB, 0.5)!;
    final pulseScale = 1.0 + 0.15 * trainPulse;

    canvas.drawCircle(trainPos, 14.0 * scaleX * pulseScale,
      Paint()
        ..color = Colors.blue.shade700.withValues(alpha: 0.3 * barProgress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: trainPos, width: 22 * scaleX, height: 16 * scaleY),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.blue.shade700.withValues(alpha: barProgress),
    );
    if (trainEstimate!.isEstimated) {
      _drawDashedRect(canvas, trainPos, 22 * scaleX, 16 * scaleY,
        Colors.lightBlue.shade200.withValues(alpha: barProgress));
    }

    final tp = TextPainter(
      text: const TextSpan(text: '🚆', style: TextStyle(fontSize: 10)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, trainPos - Offset(tp.width / 2, tp.height / 2));
  }

  // ── Static helpers (accessible from tests) ────────────────────────────────

  static double segmentAngle(Offset p1, Offset p2) =>
      atan2(p2.dy - p1.dy, p2.dx - p1.dx);

  static double segmentAngleForStation(Offset stationPos, List<Offset> points) {
    if (points.length < 2) return 0.0;
    // Find closest segment
    double minDist = double.infinity;
    int bestIdx = 0;
    for (int i = 0; i < points.length - 1; i++) {
      final mid = Offset((points[i].dx + points[i+1].dx) / 2,
                         (points[i].dy + points[i+1].dy) / 2);
      final d = (stationPos - mid).distance;
      if (d < minDist) { minDist = d; bestIdx = i; }
    }
    return segmentAngle(points[bestIdx], points[bestIdx + 1]);
  }

  static double interchangeTickAngle(List<double> lineAngles) {
    if (lineAngles.isEmpty) return -pi / 2;
    final mean = lineAngles.reduce((a, b) => a + b) / lineAngles.length;
    return mean + pi; // opposite direction
  }

  Color _firstLineColor(SchematicStation station) {
    if (station.lineCodes.isEmpty) return Colors.grey;
    return lineColors[station.lineCodes.first] ?? Colors.grey;
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint,
      {required double dashLen, required double gap}) {
    final total = (end - start).distance;
    final dir = (end - start) / total;
    double dist = 0;
    while (dist < total) {
      final s = start + dir * dist;
      final e = start + dir * (dist + dashLen).clamp(0, total);
      canvas.drawLine(s, e, paint);
      dist += dashLen + gap;
    }
  }

  void _drawDashedRect(Canvas canvas, Offset center, double w, double h, Color color) {
    final paint = Paint()..color = color..strokeWidth = 1.0..style = PaintingStyle.stroke;
    final rect = Rect.fromCenter(center: center, width: w, height: h);
    final path = Path()..addRect(rect);
    final metrics = path.computeMetrics().first;
    double dist = 0;
    const dashLen = 4.0;
    const gap = 3.0;
    while (dist < metrics.length) {
      canvas.drawPath(metrics.extractPath(dist, dist + dashLen), paint);
      dist += dashLen + gap;
    }
  }

  Color _colorForDensity(double density) {
    if (density < 0.35) return Colors.green;
    if (density < 0.60) return Colors.amber.shade700;
    if (density < 0.80) return Colors.orange;
    return Colors.red;
  }

  @override
  bool shouldRepaint(TransitMapPainter old) =>
      old.crowdState != crowdState ||
      old.selectedLineCode != selectedLineCode ||
      old.zoomProgress != zoomProgress ||
      old.barProgress != barProgress ||
      old.trainEstimate != trainEstimate ||
      old.trainPulse != trainPulse ||
      old.brightness != brightness ||
      old.currentScale != currentScale;
}
```

- [ ] **Step 4: Rodar testes**

```bash
cd mobile && flutter test test/features/transit_map/transit_map_painter_test.dart
```
Expected: todos PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/transit_map/transit_map_painter.dart mobile/test/features/transit_map/transit_map_painter_test.dart
git commit -m "feat: refactor TransitMapPainter with labels, interchanges, dark mode, currentScale"
```

---

## Chunk 4: TransitMapScreen com chips flutuantes

### Task 5: Redesenhar `TransitMapScreen` com chips centralizados flutuantes

**Files:**
- Modify: `mobile/lib/features/transit_map/transit_map_screen.dart`
- Modify: `mobile/test/features/transit_map/transit_map_screen_test.dart`

- [ ] **Step 1: Escrever testes**

```dart
// Adicionar ao transit_map_screen_test.dart

testWidgets('chips are rendered in a floating centered pill above the map', (tester) async {
  // setup com schematic e lines providers...
  await tester.pumpWidget(/* ... */);
  // O pill container deve existir como Stack filho
  expect(find.byType(Stack), findsWidgets);
  // Chips devem estar em SingleChildScrollView horizontal
  expect(find.byType(SingleChildScrollView), findsOneWidget);
});
```

- [ ] **Step 2: Rodar para ver falhar**

```bash
cd mobile && flutter test test/features/transit_map/transit_map_screen_test.dart
```

- [ ] **Step 3: Redesenhar `transit_map_screen.dart`**

```dart
// mobile/lib/features/transit_map/transit_map_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/line_model.dart';
import '../../core/models/schematic_model.dart';
import '../../core/providers/city_provider.dart';
import '../../core/providers/lines_provider.dart';
import '../../core/providers/signalr_provider.dart';
import '../../core/providers/transit_map_provider.dart';
import '../../core/providers/train_estimate_provider.dart';
import '../../core/widgets/app_error.dart';
import '../../core/widgets/app_loading.dart';
import 'transit_map_painter.dart';
import 'line_zoom_controller.dart';

class TransitMapScreen extends ConsumerStatefulWidget {
  const TransitMapScreen({super.key});

  @override
  ConsumerState<TransitMapScreen> createState() => _TransitMapScreenState();
}

class _TransitMapScreenState extends ConsumerState<TransitMapScreen>
    with SingleTickerProviderStateMixin {
  late final TransformationController _transformCtrl;
  LineZoomController? _zoomCtrl;
  String? _activeLineCode;
  bool _isSwitching = false;
  double _currentScale = 1.0;

  @override
  void initState() {
    super.initState();
    _transformCtrl = TransformationController();
    _transformCtrl.addListener(_onTransformChanged);
  }

  void _onTransformChanged() {
    final scale = _transformCtrl.value.getMaxScaleOnAxis();
    if ((scale - _currentScale).abs() > 0.01) {
      setState(() => _currentScale = scale);
    }
  }

  @override
  void dispose() {
    _transformCtrl.removeListener(_onTransformChanged);
    _transformCtrl.dispose();
    _zoomCtrl?.dispose();
    super.dispose();
  }

  void _onLineTapped(String lineCode, TransitSchematic schematic) async {
    if (_isSwitching) return;
    if (_activeLineCode == lineCode) {
      setState(() => _isSwitching = true);
      await _zoomCtrl!.zoomOut();
      if (mounted) {
        ref.read(lineZoomProvider.notifier).state = null;
        setState(() { _activeLineCode = null; _isSwitching = false; });
      }
    } else if (_activeLineCode != null) {
      setState(() => _isSwitching = true);
      await _zoomCtrl!.switchLine(lineCode, schematic, context.size ?? const Size(400, 700));
      if (mounted) {
        ref.read(lineZoomProvider.notifier).state = lineCode;
        setState(() { _activeLineCode = lineCode; _isSwitching = false; });
      }
    } else {
      _ensureZoomController(schematic);
      setState(() => _isSwitching = true);
      ref.read(lineZoomProvider.notifier).state = lineCode;
      await _zoomCtrl!.zoomIn(lineCode, schematic, context.size ?? const Size(400, 700));
      if (mounted) {
        setState(() { _activeLineCode = lineCode; _isSwitching = false; });
      }
    }
  }

  void _ensureZoomController(TransitSchematic schematic) {
    _zoomCtrl ??= LineZoomController(
      vsync: this,
      transformController: _transformCtrl,
      canvasSize: schematic.canvasSize,
    )..initPulse(this);
  }

  @override
  Widget build(BuildContext context) {
    final schematicAsync = ref.watch(transitMapProvider);
    final linesAsync     = ref.watch(linesProvider);
    final crowdState     = ref.watch(signalRProvider);
    final cityName       = ref.watch(selectedCityProvider)?.name ?? 'Trilho';
    final brightness     = Theme.of(context).brightness;
    final isDark         = brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        title: Text(cityName),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: schematicAsync.when(
        loading: () => const AppLoading.spinner(),
        error: (e, _) => AppError(
          message: 'Não foi possível carregar o mapa',
          onRetry: () => ref.invalidate(transitMapProvider),
        ),
        data: (schematic) {
          if (schematic == null) return _buildNoSchematic(linesAsync);
          return _buildMap(schematic, crowdState, linesAsync, brightness, isDark);
        },
      ),
    );
  }

  Widget _buildMap(
    TransitSchematic schematic,
    Map<int, SignalRCrowdEntry> crowdState,
    AsyncValue<List<LineModel>> linesAsync,
    Brightness brightness,
    bool isDark,
  ) {
    final densityMap = crowdState.map((k, v) => MapEntry(k, v.density));
    final lineColors = linesAsync.valueOrNull?.fold<Map<String, Color>>(
      {}, (map, l) => map..[l.code] = Color(l.colorValue),
    ) ?? {};

    final stationIds = _activeLineCode != null
        ? (linesAsync.valueOrNull
              ?.where((l) => l.code == _activeLineCode)
              .firstOrNull?.stationIds ?? [])
        : <int>[];
    final trainEstimate = stationIds.isNotEmpty
        ? ref.watch(trainEstimateProvider(stationIds)).valueOrNull
        : null;

    final zoomProgress = _zoomCtrl?.fadeProgress.value ?? 0.0;
    final barProgress  = _zoomCtrl?.barProgress.value ?? 0.0;
    final trainPulse   = _zoomCtrl?.trainPulse.value ?? 0.0;

    return Stack(
      children: [
        // ── Map ──────────────────────────────────────────────────────────────
        Positioned.fill(
          child: InteractiveViewer(
            transformationController: _transformCtrl,
            minScale: 0.5,
            maxScale: 8.0,
            child: AnimatedBuilder(
              animation: _transformCtrl,
              builder: (ctx, _) => CustomPaint(
                painter: TransitMapPainter(
                  schematic: schematic,
                  crowdState: densityMap,
                  lineColors: lineColors,
                  selectedLineCode: _activeLineCode,
                  zoomProgress: zoomProgress,
                  barProgress: barProgress,
                  trainEstimate: trainEstimate,
                  trainPulse: trainPulse,
                  brightness: brightness,
                  currentScale: _currentScale,
                ),
                size: schematic.canvasSize,
              ),
            ),
          ),
        ),

        // ── Floating chips — centered at top ─────────────────────────────────
        Positioned(
          top: 12,
          left: 0,
          right: 0,
          child: Center(
            child: _buildLineChips(linesAsync, schematic, isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildLineChips(
    AsyncValue<List<LineModel>> linesAsync,
    TransitSchematic schematic,
    bool isDark,
  ) {
    return linesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (lines) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xE1121212)   // rgba(18,18,18,0.88)
                    : const Color(0xE6FFFFFF),  // rgba(255,255,255,0.90)
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.13),
                    blurRadius: 8, offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: lines.map((line) {
                    final color = Color(line.colorValue);
                    final isSelected = _activeLineCode == line.code;
                    // Determine text color (dark label for yellow/light lines)
                    final luminance = color.computeLuminance();
                    final labelColor = luminance > 0.5 ? Colors.black : Colors.white;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: GestureDetector(
                        onTap: _isSwitching ? null : () => _onLineTapped(line.code, schematic),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(10),
                            border: isSelected
                                ? Border.all(
                                    color: isDark
                                        ? const Color(0xFF90CAF9)
                                        : Colors.black,
                                    width: 2,
                                  )
                                : null,
                            boxShadow: isSelected
                                ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0,2))]
                                : null,
                          ),
                          child: Text(
                            '● ${line.code.replaceAll('L', '')}',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: labelColor,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoSchematic(AsyncValue<List<LineModel>> linesAsync) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.amber.shade100,
          padding: const EdgeInsets.all(12),
          child: const Text(
            'Mapa esquemático em breve para esta cidade',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.brown),
          ),
        ),
        Expanded(
          child: linesAsync.when(
            loading: () => const AppLoading.spinner(),
            error: (e, _) => const AppError(message: 'Não foi possível carregar as linhas'),
            data: (lines) => ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: lines.length,
              itemBuilder: (ctx, i) {
                final line = lines[i];
                return ListTile(
                  leading: CircleAvatar(backgroundColor: Color(line.colorValue), radius: 14),
                  title: Text(line.name),
                  subtitle: Text(line.currentStatus),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Rodar testes e compilar**

```bash
cd mobile && flutter test test/features/transit_map/transit_map_screen_test.dart && flutter build apk --debug 2>&1 | tail -5
```

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/transit_map/transit_map_screen.dart mobile/test/features/transit_map/transit_map_screen_test.dart
git commit -m "feat: TransitMapScreen with floating centered chips, Stack layout, currentScale tracking"
```

---

## Chunk 5: Telas redesenhadas

### Task 6: Redesenhar `LoginScreen`

**Files:**
- Modify: `mobile/lib/features/auth/login_screen.dart`

> A lógica de autenticação (Google, Apple, Facebook, anonymous) é preservada. Apenas o layout e estilo são atualizados.

- [ ] **Step 1: Escrever teste visual mínimo**

```dart
// Adicionar ao mobile/test/features/auth/login_screen_test.dart (criar se não existir)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trilho/features/auth/login_screen.dart';

void main() {
  testWidgets('LoginScreen shows email field and social buttons', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('Entrar'), findsWidgets);
    expect(find.text('Continuar sem conta'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Rodar para ver passar (ou falhar se layout mudou)**

```bash
cd mobile && flutter test test/features/auth/login_screen_test.dart
```

- [ ] **Step 3: Redesenhar o layout do `LoginScreen`**

Preservar toda lógica de auth (`_signInWithGoogle`, `_signInWithApple`, `_signInWithFacebook`, `_continueAnonymously`, `_ensureFirebase`, `_navigateAfterAuth`). Substituir apenas o `build` e o widget de loading `_socialButton`:

```dart
// Substituir o método build e helpers de UI em login_screen.dart

@override
Widget build(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            // ── Hero gradient ──────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF1565C0), const Color(0xFF0D47A1)]
                      : [const Color(0xFF0455A1), const Color(0xFF0277BD)],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(child: Text('🚇', style: TextStyle(fontSize: 30))),
                  ),
                  const SizedBox(height: 12),
                  const Text('Trilho',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                        color: Colors.white, letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Text('Transporte em tempo real',
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.65))),
                ],
              ),
            ),

            // ── Form ────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Entrar na sua conta',
                    style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 20),

                  // Email
                  _fieldLabel(context, 'E-MAIL'),
                  TextFormField(
                    decoration: const InputDecoration(hintText: 'seu@email.com'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),

                  // Senha
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _fieldLabel(context, 'SENHA'),
                      GestureDetector(
                        onTap: () {}, // TODO: forgot password
                        child: Text('Esqueceu?',
                          style: TextStyle(fontSize: 10,
                            color: isDark ? const Color(0xFF90CAF9) : const Color(0xFF0455A1),
                            fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    obscureText: true,
                    decoration: const InputDecoration(hintText: '••••••••'),
                  ),
                  const SizedBox(height: 20),

                  // Botão entrar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {}, // TODO: email login
                      child: const Text('Entrar'),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Divisor
                  Row(children: [
                    Expanded(child: Divider(color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE0E4EA))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('ou entre com',
                        style: TextStyle(fontSize: 10,
                          color: isDark ? const Color(0xFF444444) : const Color(0xFFBBBBBB),
                          fontWeight: FontWeight.w500)),
                    ),
                    Expanded(child: Divider(color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE0E4EA))),
                  ]),
                  const SizedBox(height: 14),

                  // Social icons row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _socialIcon(
                        isDark: isDark,
                        bg: isDark ? Colors.white : Colors.black,
                        onTap: _loadingApple ? null : _signInWithApple,
                        loading: _loadingApple,
                        child: Text('', style: TextStyle(
                          fontSize: 20,
                          color: isDark ? Colors.black : Colors.white,
                        )),
                      ),
                      const SizedBox(width: 12),
                      _socialIcon(
                        isDark: isDark,
                        bg: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                        border: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE0E4EA),
                        onTap: _loadingGoogle ? null : _signInWithGoogle,
                        loading: _loadingGoogle,
                        child: _googleLogo(),
                      ),
                      const SizedBox(width: 12),
                      _socialIcon(
                        isDark: isDark,
                        bg: const Color(0xFF1877F2),
                        onTap: _loadingFacebook ? null : _signInWithFacebook,
                        loading: _loadingFacebook,
                        child: const Text('f',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Criar conta
                  Center(
                    child: GestureDetector(
                      onTap: () => context.push('/login/email'),
                      child: RichText(text: TextSpan(
                        style: const TextStyle(fontSize: 12),
                        children: [
                          TextSpan(text: 'Não tem conta? ',
                            style: TextStyle(color: isDark ? const Color(0xFF666666) : const Color(0xFF888888))),
                          TextSpan(text: 'Criar conta',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF90CAF9) : const Color(0xFF0455A1),
                              fontWeight: FontWeight.w700)),
                        ],
                      )),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Continuar sem conta
                  Center(
                    child: GestureDetector(
                      onTap: _loadingAnonymous ? null : _continueAnonymously,
                      child: Text('Continuar sem conta',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF444444) : const Color(0xFFBBBBBB),
                          decoration: TextDecoration.underline,
                        )),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _fieldLabel(BuildContext context, String label) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(label,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5,
          color: Color(0xFF888888))),
  );
}

Widget _socialIcon({
  required bool isDark,
  required Color bg,
  Color? border,
  required VoidCallback? onTap,
  required bool loading,
  required Widget child,
}) {
  return GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(13),
        border: border != null ? Border.all(color: border, width: 1.5) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 8, offset: const Offset(0,2))],
      ),
      child: loading
          ? const Center(child: SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey)))
          : Center(child: child),
    ),
  );
}

Widget _googleLogo() {
  return SizedBox(width: 20, height: 20,
    child: CustomPaint(painter: _GoogleLogoPainter()));
}
```

Adicionar `_GoogleLogoPainter` no arquivo (versão simplificada com as 4 cores):
```dart
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    // Simplified: draw circle with G colors
    final paints = [
      Paint()..color = const Color(0xFFEA4335), // red top-right
      Paint()..color = const Color(0xFF34A853), // green bottom-right
      Paint()..color = const Color(0xFFFBBC05), // yellow bottom-left
      Paint()..color = const Color(0xFF4285F4), // blue top-left
    ];
    for (int i = 0; i < 4; i++) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r),
          (i * 1.5708) - 0.3927, 1.5708, true, paints[i]);
    }
    canvas.drawCircle(c, r * 0.55, Paint()..color = Colors.white);
  }
  @override bool shouldRepaint(_) => false;
}
```

- [ ] **Step 4: Rodar testes**

```bash
cd mobile && flutter test test/features/auth/login_screen_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/auth/login_screen.dart mobile/test/features/auth/login_screen_test.dart
git commit -m "feat: redesign LoginScreen with hero gradient, slim social icons, premium layout"
```

---

### Task 7: Redesenhar `SettingsScreen`

**Files:**
- Modify: `mobile/lib/features/settings/settings_screen.dart`
- Test: `mobile/test/features/settings/settings_screen_test.dart`

- [ ] **Step 1: Escrever teste mínimo**

Criar `mobile/test/features/settings/settings_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trilho/features/settings/settings_screen.dart';
import 'package:trilho/core/providers/usage_provider.dart';
import 'package:trilho/core/models/usage_model.dart';

void main() {
  testWidgets('SettingsScreen shows sections APARÊNCIA and CONTA', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          usageProvider.overrideWith((ref) => Stream.value(
            UsageModel(isPremium: false, isAnonymous: false, remaining: 5),
          )),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('APARÊNCIA'), findsOneWidget);
    expect(find.text('CONTA'), findsOneWidget);
    expect(find.text('Modo escuro'), findsOneWidget);
    expect(find.text('Sair'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Rodar para ver falhar**

```bash
cd mobile && flutter test test/features/settings/settings_screen_test.dart
```

- [ ] **Step 3: Redesenhar `settings_screen.dart`**

```dart
// mobile/lib/features/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/usage_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usageAsync = ref.watch(usageProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor      = isDark ? const Color(0xFF121212) : const Color(0xFFF0F2F5);
    final cardColor    = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor  = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F2F5);
    final labelColor   = isDark ? const Color(0xFF555555) : const Color(0xFF888888);
    final textPrimary  = isDark ? const Color(0xFFEEEEEE) : const Color(0xFF111111);
    final textRed      = isDark ? const Color(0xFFEF5350) : const Color(0xFFEF4136);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Configurações'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── APARÊNCIA ────────────────────────────────────────────────────
          _sectionLabel('APARÊNCIA', labelColor),
          _card(isDark, cardColor, borderColor, [
            _settingRow(
              icon: '🌙',
              iconBg: isDark ? const Color(0xFF1A237E) : const Color(0xFFEEF2FF),
              title: 'Modo escuro',
              subtitle: 'Tema escuro',
              textPrimary: textPrimary,
              trailing: Switch(
                value: isDark,
                onChanged: (_) {}, // controlled by system / future preference
                activeColor: isDark ? const Color(0xFF2979FF) : const Color(0xFF0455A1),
              ),
              borderColor: borderColor,
            ),
            _settingRow(
              icon: '🌍',
              iconBg: isDark ? const Color(0xFF1B3A1B) : const Color(0xFFF1F8E9),
              title: 'Idioma',
              subtitle: 'Português (BR)',
              textPrimary: textPrimary,
              trailing: Icon(Icons.chevron_right, color: labelColor),
              borderColor: Colors.transparent,
              onTap: () {},
            ),
          ]),

          const SizedBox(height: 20),

          // ── ASSINATURA ───────────────────────────────────────────────────
          _sectionLabel('ASSINATURA', labelColor),
          _card(isDark, cardColor, borderColor, [
            usageAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (_, __) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Erro ao carregar', style: TextStyle(color: labelColor)),
              ),
              data: (usage) => Column(children: [
                _settingRow(
                  icon: usage.isPremium ? '⭐' : '🆓',
                  iconBg: isDark ? const Color(0xFF2A1A00) : const Color(0xFFFFF8E1),
                  title: usage.isPremium ? 'Trilho Premium' : 'Plano Gratuito',
                  subtitle: usage.isPremium
                      ? 'Obrigado por apoiar!'
                      : '${usage.remaining} consultas restantes',
                  textPrimary: textPrimary,
                  trailing: usage.isPremium
                      ? Icon(Icons.check_circle, color: Colors.green.shade400, size: 20)
                      : Icon(Icons.chevron_right, color: labelColor),
                  borderColor: borderColor,
                  onTap: usage.isPremium ? null : () => context.push('/paywall'),
                ),
                if (usage.isPremium)
                  _settingRow(
                    icon: '💳',
                    iconBg: isDark ? const Color(0xFF1A1A3E) : const Color(0xFFE8EAF6),
                    title: 'Gerenciar Assinatura',
                    subtitle: 'Cancelar ou trocar plano',
                    textPrimary: textPrimary,
                    trailing: Icon(Icons.chevron_right, color: labelColor),
                    borderColor: Colors.transparent,
                    onTap: () => context.push('/subscription'),
                  ),
              ]),
            ),
          ]),

          const SizedBox(height: 20),

          // ── CONTA ────────────────────────────────────────────────────────
          _sectionLabel('CONTA', labelColor),
          _card(isDark, cardColor, borderColor, [
            _settingRow(
              icon: '👤',
              iconBg: isDark ? const Color(0xFF2A1A2E) : const Color(0xFFF3E5F5),
              title: 'Perfil',
              subtitle: null,
              textPrimary: textPrimary,
              trailing: Icon(Icons.chevron_right, color: labelColor),
              borderColor: borderColor,
              onTap: () {},
            ),
            _settingRow(
              icon: '🔒',
              iconBg: isDark ? const Color(0xFF1A2E1A) : const Color(0xFFE8F5E9),
              title: 'Privacidade & LGPD',
              subtitle: null,
              textPrimary: textPrimary,
              trailing: Icon(Icons.chevron_right, color: labelColor),
              borderColor: borderColor,
              onTap: () => _showPrivacy(context),
            ),
            _settingRow(
              icon: '🚪',
              iconBg: isDark ? const Color(0xFF3E0000) : const Color(0xFFFFEBEE),
              title: 'Sair',
              subtitle: null,
              textPrimary: textRed,
              trailing: Icon(Icons.chevron_right, color: textRed, size: 18),
              borderColor: Colors.transparent,
              onTap: () {}, // TODO: sign out
            ),
          ]),

          const SizedBox(height: 20),

          // Version
          Center(child: Text('Trilho v1.0.0 · © 2026',
            style: TextStyle(fontSize: 11, color: labelColor))),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, Color color) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(text, style: TextStyle(
      fontSize: 10, fontWeight: FontWeight.w700,
      letterSpacing: 0.8, color: color)),
  );

  Widget _card(bool isDark, Color bg, Color border, List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
        blurRadius: 3, offset: const Offset(0, 1),
      )],
    ),
    child: Column(children: children),
  );

  Widget _settingRow({
    required String icon,
    required Color iconBg,
    required String title,
    required String? subtitle,
    required Color textPrimary,
    required Widget trailing,
    required Color borderColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: borderColor, width: 1)),
        ),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 16))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
              if (subtitle != null) Text(subtitle,
                style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
            ],
          )),
          trailing,
        ]),
      ),
    );
  }

  void _showPrivacy(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Privacidade'),
        content: const SingleChildScrollView(
          child: Text(
            'O Trilho não coleta dados pessoais identificáveis.\n\n'
            'Seu usuário é identificado por um UUID anônimo.\n\n'
            'Conformidade com a LGPD.',
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }
}
```

- [ ] **Step 4: Rodar testes**

```bash
cd mobile && flutter test test/features/settings/settings_screen_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/settings/settings_screen.dart mobile/test/features/settings/settings_screen_test.dart
git commit -m "feat: redesign SettingsScreen with grouped cards, icons, dark mode"
```

---

### Task 8: Verificar compilação completa e rodar todos os testes

- [ ] **Step 1: Rodar todos os testes**

```bash
cd mobile && flutter test
```
Expected: todos PASS (sem regressões).

- [ ] **Step 2: Compilar APK debug**

```bash
cd mobile && flutter build apk --debug 2>&1 | tail -10
```
Expected: `✓ Built build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **Step 3: Commit final se houver ajustes**

```bash
git add -A
git commit -m "fix: resolve any compilation warnings post-redesign"
```

---

## Chunk 6: `city_model.dart` — cores dark das linhas

### Task 9: Adicionar mapa de cores dark ao `LineModel` / `CityRegistry`

> As cores dark das linhas (mais claras) precisam ser acessíveis para que o `TransitMapPainter` possa adaptar ao dark mode. A abordagem mais limpa é uma função utilitária `lineColorForBrightness(code, brightness)`.

**Files:**
- Create: `mobile/lib/core/utils/line_colors.dart`
- Test: `mobile/test/core/utils/line_colors_test.dart`

- [ ] **Step 1: Escrever testes**

```dart
// mobile/test/core/utils/line_colors_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/utils/line_colors.dart';

void main() {
  group('LineColors', () {
    test('light color for L1 is #0455A1', () {
      expect(LineColors.forLine('L1', Brightness.light), const Color(0xFF0455A1));
    });

    test('dark color for L1 is #2979FF (lighter)', () {
      expect(LineColors.forLine('L1', Brightness.dark), const Color(0xFF2979FF));
    });

    test('dark colors are always brighter than light counterparts', () {
      for (final code in LineColors.allCodes) {
        final light = LineColors.forLine(code, Brightness.light);
        final dark  = LineColors.forLine(code, Brightness.dark);
        expect(dark.computeLuminance(), greaterThanOrEqualTo(light.computeLuminance() - 0.01),
          reason: '$code dark should be >= light luminance');
      }
    });

    test('unknown line returns grey', () {
      expect(LineColors.forLine('UNKNOWN', Brightness.light), Colors.grey);
    });
  });
}
```

- [ ] **Step 2: Rodar para ver falhar**

```bash
cd mobile && flutter test test/core/utils/line_colors_test.dart
```

- [ ] **Step 3: Criar `line_colors.dart`**

```dart
// mobile/lib/core/utils/line_colors.dart
import 'package:flutter/material.dart';

class LineColors {
  LineColors._();

  static const List<String> allCodes = [
    'L1','L2','L3','L4','L5','L15',
    'L7','L8','L9','L10','L11','L12','L13','L17','LA','LB',
  ];

  static const Map<String, Color> _light = {
    'L1':  Color(0xFF0455A1),
    'L2':  Color(0xFF007E5E),
    'L3':  Color(0xFFEF4136),
    'L4':  Color(0xFFFFD900),
    'L5':  Color(0xFF9B2990),
    'L15': Color(0xFF808285),
    'L7':  Color(0xFFCF202E),
    'L8':  Color(0xFF97999B),
    'L9':  Color(0xFF00945A),
    'L10': Color(0xFF007A87),
    'L11': Color(0xFFF26522),
    'L12': Color(0xFF133A8F),
    'L13': Color(0xFF00A859),
    'L17': Color(0xFFBE9B2F),
    'LA':  Color(0xFF6B3A2A),
    'LB':  Color(0xFF005A8B),
  };

  static const Map<String, Color> _dark = {
    'L1':  Color(0xFF2979FF),
    'L2':  Color(0xFF00BFA5),
    'L3':  Color(0xFFFF5252),
    'L4':  Color(0xFFFFE57F),
    'L5':  Color(0xFFCE93D8),
    'L15': Color(0xFFB0BEC5),
    'L7':  Color(0xFFEF5350),
    'L8':  Color(0xFFCFD8DC),
    'L9':  Color(0xFF69F0AE),
    'L10': Color(0xFF80DEEA),
    'L11': Color(0xFFFF9E80),
    'L12': Color(0xFF448AFF),
    'L13': Color(0xFFB9F6CA),
    'L17': Color(0xFFFFD740),
    'LA':  Color(0xFFA1887F),
    'LB':  Color(0xFF4FC3F7),
  };

  static Color forLine(String code, Brightness brightness) {
    final map = brightness == Brightness.dark ? _dark : _light;
    return map[code] ?? Colors.grey;
  }
}
```

- [ ] **Step 4: Atualizar `TransitMapPainter` para usar `LineColors`**

No `transit_map_painter.dart`, substituir a cor que vinha de `lineColors[line.lineCode]` pela versão adaptada:

```dart
// No método paint, ao calcular baseColor:
final rawColor = lineColors[line.lineCode] ?? Colors.grey;
// Prefer LineColors table for dark mode adaptation
final baseColor = _isDark
    ? LineColors.forLine(line.lineCode, Brightness.dark)
    : rawColor;
```

Adicionar import: `import '../../core/utils/line_colors.dart';`

- [ ] **Step 5: Rodar todos os testes**

```bash
cd mobile && flutter test
```
Expected: todos PASS.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/core/utils/line_colors.dart mobile/test/core/utils/line_colors_test.dart mobile/lib/features/transit_map/transit_map_painter.dart
git commit -m "feat: add LineColors utility with light/dark color map for all 16 lines"
```

---

### Task 10: PR e merge final

- [ ] **Step 1: Push da branch**

```bash
git push origin main
```

- [ ] **Step 2: Verificação final**

```bash
cd mobile && flutter test && flutter build apk --debug 2>&1 | tail -5
```
Expected: todos PASS + APK gerado com sucesso.
