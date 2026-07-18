// mobile/lib/features/transit_map/line_zoom_controller.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/models/schematic_model.dart';

/// Orchestrates the multi-step line zoom animation.
///
/// Designed for use with [InteractiveViewer] in `constrained: false` mode,
/// where the canvas renders at its natural [canvasSize] and the
/// [TransformationController] maps canvas coords → viewport coords.
///
/// Owned by TransitMapScreen (TickerProviderStateMixin).
class LineZoomController {
  final AnimationController _ctrl;
  final TransformationController _transform;
  final Size canvasSize;

  Matrix4Tween? _currentTween;
  AnimationController? _pulseCtrl;

  LineZoomController({
    required TickerProvider vsync,
    required TransformationController transformController,
    required this.canvasSize,
  })  : _ctrl = AnimationController(vsync: vsync),
        _transform = transformController {
    // Single persistent listener — drives transform from the current tween.
    _ctrl.addListener(() {
      if (_currentTween != null) {
        _transform.value = _currentTween!.evaluate(_ctrl);
      }
    });
  }

  // ── Public animations ──────────────────────────────────────────────────────

  /// Opacity / focus fade: 0 → 1 during the first 31 % of zoom-in.
  Animation<double> get fadeProgress =>
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.31, curve: Curves.easeIn));

  /// Capacity bars: appear in the last 54 % of zoom-in, vanish first on zoom-out.
  Animation<double> get barProgress =>
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.46, 1.0, curve: Curves.easeOut));

  /// Sinusoidal pulse for the train icon (repeating).
  Animation<double> get trainPulse =>
      _pulseCtrl ?? const AlwaysStoppedAnimation(0.0);

  void initPulse(TickerProvider vsync) {
    _pulseCtrl = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  // ── Zoom operations ────────────────────────────────────────────────────────

  /// Zoom into the bounding box of [lineCode]'s stations.
  ///
  /// [screenSize] should be the body area of the visible viewport
  /// (excluding AppBar / status bar).
  Future<void> zoomIn(
    String lineCode,
    TransitSchematic schematic,
    Size screenSize,
  ) async {
    final stations = schematic.stationsForLine(lineCode);
    if (stations.isEmpty) return;

    _ctrl.duration = const Duration(milliseconds: 1300);
    _currentTween = Matrix4Tween(
      begin: _transform.value,                          // start from current view
      end: _zoomMatrix(_boundingBox(stations), screenSize),
    );
    _ctrl.value = 0.0;
    await _ctrl.animateTo(1.0, curve: Curves.linear);
  }

  /// Animate back to the overview (fit-width) transform.
  ///
  /// Uses [animateBack] so that [fadeProgress] / [barProgress] reverse
  /// naturally — bars disappear first, then opacity is restored.
  Future<void> zoomOut(Size screenSize) async {
    _ctrl.duration = const Duration(milliseconds: 800);
    // Tween: begin = overview (t=0), end = current zoomed view (t=1).
    // animateBack drives t from 1.0 → 0.0, so display goes zoomed → overview.
    _currentTween = Matrix4Tween(
      begin: _overviewMatrix(screenSize),
      end: _transform.value,
    );
    await _ctrl.animateBack(0.0, curve: Curves.easeInOut);
  }

  Future<void> switchLine(
    String newCode,
    TransitSchematic schematic,
    Size screenSize,
  ) async {
    await zoomOut(screenSize);
    await zoomIn(newCode, schematic, screenSize);
  }

  // ── Matrix helpers ─────────────────────────────────────────────────────────

  /// Returns the matrix that fits the canvas width into [screenSize].
  /// Vertically centers the canvas if it is shorter than the viewport.
  Matrix4 _overviewMatrix(Size screenSize) {
    final scale = screenSize.width / canvasSize.width;
    final dy = max(0.0, (screenSize.height - canvasSize.height * scale) / 2);
    return Matrix4.identity()
      ..translateByDouble(0.0, dy, 0, 1)
      ..scaleByDouble(scale, scale, 1.0, 1.0);
  }

  /// Returns the matrix that zooms into [bbox] (in canvas coords),
  /// fitting it into [screenSize] with padding.
  Matrix4 _zoomMatrix(Rect bbox, Size screenSize) {
    const paddingFraction = 0.10; // 10 % of canvas dimensions as breathing room
    final padW = canvasSize.width * paddingFraction;
    final padH = canvasSize.height * paddingFraction;
    final padded = Rect.fromLTRB(
      (bbox.left  - padW).clamp(0.0, canvasSize.width),
      (bbox.top   - padH).clamp(0.0, canvasSize.height),
      (bbox.right + padW).clamp(0.0, canvasSize.width),
      (bbox.bottom + padH).clamp(0.0, canvasSize.height),
    );

    final scaleX = screenSize.width  / padded.width;
    final scaleY = screenSize.height / padded.height;
    final scale  = min(scaleX, scaleY);

    // Center the padded bbox on screen.
    // Transform convention (Flutter): screen_pos = M * canvas_pos
    // M = translate(tx, ty) * scale(s)  →  screen = s * canvas + (tx, ty)
    final tx = -padded.left  * scale + (screenSize.width  - padded.width  * scale) / 2;
    final ty = -padded.top   * scale + (screenSize.height - padded.height * scale) / 2;

    return Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(scale, scale, 1.0, 1.0);
  }

  /// Returns the tight bounding box of [stations] in canvas coordinates.
  Rect _boundingBox(List<SchematicStation> stations) {
    double minX = double.infinity,  minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final s in stations) {
      if (s.position.dx < minX) minX = s.position.dx;
      if (s.position.dy < minY) minY = s.position.dy;
      if (s.position.dx > maxX) maxX = s.position.dx;
      if (s.position.dy > maxY) maxY = s.position.dy;
    }
    // Guard against a single-station line (point bbox)
    if (maxX <= minX) { minX -= 50; maxX += 50; }
    if (maxY <= minY) { minY -= 50; maxY += 50; }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  void dispose() {
    _ctrl.dispose();
    _pulseCtrl?.dispose();
  }
}
