// mobile/lib/features/transit_map/transit_map_painter.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/models/schematic_model.dart';
import '../../core/utils/line_colors.dart';
import '../../core/widgets/app_colors.dart';
import '../../core/widgets/app_theme.dart';
import 'train_estimator.dart';

class TransitMapPainter extends CustomPainter {
  final TransitSchematic schematic;
  final Map<int, double> crowdState;        // stationId → density 0.0–1.0
  final Map<String, Color> lineColors;      // lineCode → Color
  final String? selectedLineCode;           // null = overview
  final double zoomProgress;               // 0.0–1.0 (used for fade)
  final double barProgress;                // 0.0–1.0 (used for bar height)
  final TrainEstimate? trainEstimate;
  final double trainPulse;                 // 0.0–1.0 (sinusoidal pulse)
  final Brightness brightness;             // light or dark mode
  final double currentScale;              // current map zoom scale

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

  Color get _bgColor            => _isDark ? AppTheme.bgDark     : AppTheme.bgLight;
  Color get _labelColor         => _isDark ? AppTheme.textPrimDark : AppTheme.textPrimLight;
  Color get _tickColor          => _isDark ? AppTheme.borderDark  : AppTheme.borderLight;
  Color get _ringColor          => _isDark ? AppTheme.borderDark  : AppTheme.borderLight;
  Color get _nucleusColor       => _isDark ? AppTheme.bgDark      : AppTheme.bgLight;
  Color get _nucleusBorderColor => _isDark ? AppTheme.textSecDark : AppTheme.textSecLight;

  @visibleForTesting
  Color get bgColorForTest => _bgColor;

  /// Label opacity based on zoom scale.
  /// With constrained:false the painter scale is always 1.0; the
  /// InteractiveViewer handles visual zoom, and currentScale reflects
  /// the TransformationController's total scale factor.
  /// Labels fade in from scale≈0.35 (readable) to scale≈0.65 (clear).
  double get _labelOpacity => ((currentScale - 0.35) / (0.65 - 0.35)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width  / schematic.canvasSize.width;
    final scaleY = size.height / schematic.canvasSize.height;

    // ── Background ────────────────────────────────────────────────────────────
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = _bgColor);

    // ── 1. Lines ──────────────────────────────────────────────────────────────
    for (final line in schematic.lines) {
      final isSelected = selectedLineCode == line.lineCode;
      final opacity = selectedLineCode == null
          ? 1.0
          : isSelected ? 1.0 : 0.15 + (0.85 * (1.0 - zoomProgress));

      // Prefer LineColors dark palette for dark mode; fallback to backend color
      final rawColor = lineColors[line.lineCode] ?? Colors.grey;
      final baseColor = _isDark
          ? LineColors.forLine(line.lineCode, Brightness.dark)
          : rawColor;
      final color = baseColor.withValues(alpha: opacity);
      final isMetro = ['L1','L2','L3','L4','L5','L15'].contains(line.lineCode);
      final strokeWidth = (isMetro ? 10.0 : 8.0) * scaleX * (isSelected ? 1.15 : 1.0);

      final paint = Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
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

      final baseRadius = station.isInterchange ? 8.0 : 5.0;
      final radius = (isOnSelectedLine ? baseRadius * 1.4 : baseRadius) * scaleX;

      if (station.isInterchange) {
        // Outer ring
        final ringRadius = radius * 1.6;
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
        final lineColor = _firstLineColor(station);
        canvas.drawCircle(pos, radius, Paint()..color = _nucleusColor.withValues(alpha: dotOpacity));
        canvas.drawCircle(pos, radius,
          Paint()
            ..color = (density > 0.05 ? dotColor : lineColor).withValues(alpha: dotOpacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0 * scaleX,
        );
      }

      // Capacity bar (only on selected line)
      if (isOnSelectedLine && barProgress > 0) {
        _drawCapacityBar(canvas, pos, density, barProgress, dotColor, dotOpacity, scaleX, scaleY);
      }

      // Labels
      if (_labelOpacity > 0) {
        _drawLabel(canvas, station, pos, scaleX, scaleY, dotOpacity * _labelOpacity);
      }
    }

    // ── 3. Train icon ─────────────────────────────────────────────────────────
    if (trainEstimate != null && selectedLineCode != null && barProgress > 0) {
      _drawTrainIcon(canvas, scaleX, scaleY);
    }
  }

  void _drawLabel(Canvas canvas, SchematicStation station, Offset pos,
      double scaleX, double scaleY, double opacity) {
    if (opacity <= 0) return;

    // Find primary line for angle
    final line = schematic.lines
        .where((l) => l.stationIds.contains(station.stationId))
        .firstOrNull;

    double angle = 0.0;
    if (line != null && line.points.length >= 2) {
      angle = segmentAngleForStation(station.position, line.points);
    }

    // Tick direction
    double tickAngle;
    if (station.isInterchange && station.lineCodes.length >= 2) {
      final angles = station.lineCodes.map((code) {
        final l = schematic.lines.where((ln) => ln.lineCode == code).firstOrNull;
        if (l == null || l.points.length < 2) return 0.0;
        return segmentAngleForStation(station.position, l.points);
      }).toList();
      tickAngle = interchangeTickAngle(angles);
    } else {
      tickAngle = angle + (station.labelSide == LabelSide.above ? -pi / 2 : pi / 2);
    }

    final markerRadius = (station.isInterchange ? 8.0 * 1.6 : 5.0) * scaleX;
    final tickLength   = (station.isInterchange ? 22.0 : 18.0) * scaleX;

    final tickStart = pos + Offset(cos(tickAngle) * markerRadius, sin(tickAngle) * markerRadius);
    final tickEnd   = pos + Offset(cos(tickAngle) * (markerRadius + tickLength), sin(tickAngle) * (markerRadius + tickLength));

    // Dashed tick perpendicular to line
    _drawDashedLine(canvas, tickStart, tickEnd,
      Paint()
        ..color = _tickColor.withValues(alpha: opacity)
        ..strokeWidth = 1.2 * scaleX
        ..style = PaintingStyle.stroke,
      dashLen: 3.0 * scaleX, gap: 3.0 * scaleX,
    );

    // Rotated label text — parallel to line
    final fontSize   = (station.isInterchange ? 11.0 : 9.5) * scaleX.clamp(0.8, 2.0);
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
          fontFamily: 'Inter',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 200 * scaleX);

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
    final trainPos = Offset.lerp(posA, posB, trainEstimate!.t)!;
    final pulseScale = 1.0 + 0.15 * trainPulse;

    canvas.drawCircle(trainPos, 14.0 * scaleX * pulseScale,
      Paint()
        ..color = AppTheme.primary.withValues(alpha: 0.3 * barProgress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: trainPos, width: 22 * scaleX, height: 16 * scaleY),
        const Radius.circular(4),
      ),
      Paint()..color = AppTheme.primary.withValues(alpha: barProgress),
    );
    if (trainEstimate!.isEstimated) {
      _drawDashedRect(canvas, trainPos, 22 * scaleX, 16 * scaleY,
        AppTheme.accent.withValues(alpha: barProgress));
    }

    final tp = TextPainter(
      text: const TextSpan(text: '🚆', style: TextStyle(fontSize: 10)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, trainPos - Offset(tp.width / 2, tp.height / 2));
  }

  // ── Static helpers (accessible from tests) ────────────────────────────────

  /// Angle in radians of segment from p1 to p2.
  static double segmentAngle(Offset p1, Offset p2) =>
      atan2(p2.dy - p1.dy, p2.dx - p1.dx);

  /// Angle of the line segment closest to [stationPos] within [points].
  static double segmentAngleForStation(Offset stationPos, List<Offset> points) {
    if (points.length < 2) return 0.0;
    double minDist = double.infinity;
    int bestIdx = 0;
    for (int i = 0; i < points.length - 1; i++) {
      final mid = Offset(
        (points[i].dx + points[i + 1].dx) / 2,
        (points[i].dy + points[i + 1].dy) / 2,
      );
      final d = (stationPos - mid).distance;
      if (d < minDist) {
        minDist = d;
        bestIdx = i;
      }
    }
    return segmentAngle(points[bestIdx], points[bestIdx + 1]);
  }

  /// Tick angle for interchange: opposite direction of the mean of all crossing line angles.
  static double interchangeTickAngle(List<double> lineAngles) {
    if (lineAngles.isEmpty) return -pi / 2;
    final mean = lineAngles.reduce((a, b) => a + b) / lineAngles.length;
    return mean + pi;
  }

  Color _firstLineColor(SchematicStation station) {
    if (station.lineCodes.isEmpty) {
      // Fallback: find the first line that contains this station
      for (final line in schematic.lines) {
        if (line.stationIds.contains(station.stationId)) {
          return lineColors[line.lineCode] ?? Colors.grey;
        }
      }
      return Colors.grey;
    }
    return lineColors[station.lineCodes.first] ?? Colors.grey;
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint,
      {required double dashLen, required double gap}) {
    final total = (end - start).distance;
    if (total <= 0) return;
    final dir = (end - start) / total;
    double dist = 0;
    while (dist < total) {
      final s = start + dir * dist;
      final e = start + dir * (dist + dashLen).clamp(0.0, total);
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
    if (density < 0.35) return AppColors.crowdLow;
    if (density < 0.60) return AppColors.crowdModerate;
    if (density < 0.80) return AppColors.crowdHigh;
    return AppColors.crowdFull;
  }

  @override
  bool shouldRepaint(TransitMapPainter old) =>
      old.crowdState != crowdState ||
      old.selectedLineCode != selectedLineCode ||
      old.zoomProgress != zoomProgress ||
      old.barProgress != barProgress ||
      old.trainEstimate != trainEstimate ||
      old.trainPulse != trainPulse ||
      old.lineColors != lineColors ||
      old.brightness != brightness ||
      old.currentScale != currentScale;
}
