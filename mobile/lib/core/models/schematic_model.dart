// mobile/lib/core/models/schematic_model.dart
import 'package:flutter/painting.dart';

enum LabelSide { above, below, left, right }

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

  /// Returns stations for [lineCode] in the order defined by SchematicLine.stationIds.
  List<SchematicStation> stationsForLine(String lineCode) {
    final line = lines.where((l) => l.lineCode == lineCode).firstOrNull;
    if (line == null) return [];
    return line.stationIds
        .map((id) => stationById(id))
        .whereType<SchematicStation>()
        .toList();
  }
}
