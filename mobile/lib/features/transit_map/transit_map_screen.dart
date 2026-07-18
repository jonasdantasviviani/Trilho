// mobile/lib/features/transit_map/transit_map_screen.dart
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/line_model.dart';
import '../../core/models/schematic_model.dart';
import '../../core/providers/lines_provider.dart';
import '../../core/providers/signalr_provider.dart';
import '../../core/providers/train_estimate_provider.dart';
import '../../core/providers/train_position_provider.dart';
import 'train_estimator.dart';
import '../../core/providers/transit_map_provider.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/favorite_line_provider.dart';
import '../../core/utils/line_colors.dart';
import '../../core/widgets/app_colors.dart';
import '../../core/widgets/app_error.dart';
import '../../core/widgets/app_loading.dart';
import '../../core/widgets/app_theme.dart';
import 'line_zoom_controller.dart';
import 'transit_map_painter.dart';

/// Finds the nearest [SchematicStation] to [point] within [radius] canvas units.
/// Returns null if no station is within radius.
SchematicStation? findStationAt(
  List<SchematicStation> stations,
  Offset point,
  double radius,
) {
  SchematicStation? closest;
  double closestDist = double.infinity;
  for (final station in stations) {
    final dist = (station.position - point).distance;
    if (dist < radius && dist < closestDist) {
      closestDist = dist;
      closest = station;
    }
  }
  return closest;
}

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
  bool _mapFitApplied = false;

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
    final screenSize = _bodySize;

    if (_activeLineCode == lineCode) {
      // Deselect
      setState(() => _isSwitching = true);
      await _zoomCtrl!.zoomOut(screenSize);
      if (mounted) {
        ref.read(lineZoomProvider.notifier).state = null;
        setState(() {
          _activeLineCode = null;
          _isSwitching = false;
        });
      }
    } else if (_activeLineCode != null) {
      // Switch line
      setState(() => _isSwitching = true);
      await _zoomCtrl!.switchLine(lineCode, schematic, screenSize);
      if (mounted) {
        ref.read(lineZoomProvider.notifier).state = lineCode;
        setState(() {
          _activeLineCode = lineCode;
          _isSwitching = false;
        });
      }
    } else {
      // Zoom in
      _ensureZoomController(schematic);
      setState(() => _isSwitching = true);
      ref.read(lineZoomProvider.notifier).state = lineCode;
      await _zoomCtrl!.zoomIn(lineCode, schematic, screenSize);
      if (mounted) {
        setState(() {
          _activeLineCode = lineCode;
          _isSwitching = false;
        });
      }
    }
  }

  /// Approximate body area (viewport minus AppBar and status bar).
  Size get _bodySize {
    final size = context.size ?? const Size(400, 700);
    final top = MediaQuery.paddingOf(context).top;
    return Size(size.width, size.height - kToolbarHeight - top);
  }

  void _ensureZoomController(TransitSchematic schematic) {
    _zoomCtrl ??= LineZoomController(
      vsync: this,
      transformController: _transformCtrl,
      canvasSize: schematic.canvasSize,
    )..initPulse(this);
  }

  /// Builds the lineColors map: static fallbacks + backend overrides for light mode.
  Map<String, Color> _buildLineColors(
    AsyncValue<List<LineModel>> linesAsync,
    Brightness brightness,
  ) {
    final map = <String, Color>{};
    // Seed with static colors (fallback for any line not yet returned by backend)
    for (final code in LineColors.allCodes) {
      map[code] = LineColors.forLine(code, brightness);
    }
    // In light mode, override with the canonical backend hex colors
    if (brightness == Brightness.light) {
      linesAsync.valueOrNull?.forEach((line) {
        map[line.code] = Color(line.colorValue);
      });
    }
    return map;
  }

  /// Finds the [LineModel] for [code] in [lines], or null if not found.
  LineModel? _findLine(List<LineModel>? lines, String code) {
    if (lines == null) return null;
    for (final l in lines) {
      if (l.code == code) return l;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final schematicAsync = ref.watch(transitMapProvider);
    final linesAsync = ref.watch(linesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Line selection triggered from StationDetailScreen
    ref.listen<String?>(pendingLineSelectionProvider, (_, lineId) {
      if (lineId == null) return;
      final schematic = ref.read(transitMapProvider).valueOrNull;
      if (schematic != null) _onLineTapped(lineId, schematic);
      ref.read(pendingLineSelectionProvider.notifier).state = null;
    });

    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('São Paulo'),
        actions: [
          // ⭐ Favoritar linha ativa
          if (_activeLineCode != null) ...[
            Consumer(builder: (ctx, ref, _) {
              final isFav = ref.watch(favoriteLineProvider) == _activeLineCode;
              return IconButton(
                icon: Icon(
                  isFav ? Icons.star_rounded : Icons.star_border_rounded,
                  color: isFav ? const Color(0xFFFFC107) : null,
                ),
                tooltip: isFav ? 'Remover favorita' : 'Favoritar linha',
                onPressed: () =>
                    ref.read(favoriteLineProvider.notifier).toggle(_activeLineCode!),
              );
            }),
          ],
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
          return _buildMap(schematic, linesAsync, isDark);
        },
      ),
    );
  }

  Widget _buildMap(
    TransitSchematic schematic,
    AsyncValue<List<LineModel>> linesAsync,
    bool isDark,
  ) {
    // One-time fit: scale the canvas to fill the screen width on first render.
    if (!_mapFitApplied) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _mapFitApplied) return;
        _mapFitApplied = true;
        final bs = _bodySize;
        final scale = bs.width / schematic.canvasSize.width;
        final dy =
            max(0.0, (bs.height - schematic.canvasSize.height * scale) / 2);
        _transformCtrl.value = Matrix4.identity()
          ..translateByDouble(0.0, dy, 0, 1)
          ..scaleByDouble(scale, scale, 1.0, 1.0);
      });
    }

    // Crowd state from SignalR (stationId → density 0.0–1.0)
    final crowdState = ref.watch(signalRProvider).map(
          (id, entry) => MapEntry(id, entry.density),
        );

    final brightness = isDark ? Brightness.dark : Brightness.light;
    final lineColors = _buildLineColors(linesAsync, brightness);

    // Train estimate for the active line — GPS positions first, crowd fallback
    final activeLine = _activeLineCode != null
        ? _findLine(linesAsync.valueOrNull, _activeLineCode!)
        : null;
    final activeStationIds = activeLine?.stationIds;

    final trainPositions =
        ref.watch(trainPositionProvider).valueOrNull ?? const [];
    final stationsGps = ref.watch(stationsGpsProvider).valueOrNull;

    TrainEstimate? trainEstimate;
    if (activeStationIds != null && _activeLineCode != null) {
      // 1. GPS — real position, accurate
      if (stationsGps != null && trainPositions.isNotEmpty) {
        for (final pos in trainPositions
            .where((p) => p.lineCode == _activeLineCode)) {
          final est = TrainEstimate.fromGps(
            lat: pos.lat,
            lng: pos.lng,
            stationIds: activeStationIds,
            stationGps: stationsGps,
          );
          if (est != null) {
            trainEstimate = est;
            break;
          }
        }
      }
      // 2. Crowd estimate (SignalR) — fallback when no GPS data available
      trainEstimate ??=
          ref.watch(trainEstimateProvider(activeStationIds)).valueOrNull;
    }

    // Merged Listenable so CustomPaint repaints on every animation frame.
    // Empty merge (when no line is selected) never fires — no wasted frames.
    final animationListenable = Listenable.merge([
      if (_zoomCtrl != null) _zoomCtrl!.fadeProgress,
      if (_zoomCtrl != null) _zoomCtrl!.barProgress,
      if (_zoomCtrl != null) _zoomCtrl!.trainPulse,
    ]);

    return Stack(
      children: [
        // ── Programmatic map (lines + stations + labels) ───────────────────
        Positioned.fill(
          child: GestureDetector(
            onTapUp: (details) {
              final scenePoint =
                  _transformCtrl.toScene(details.localPosition);
              final radius = 24.0 / _currentScale;
              final station =
                  findStationAt(schematic.stations, scenePoint, radius);
              if (station != null && mounted) {
                context.push('/station/${station.stationId}');
              }
            },
            child: InteractiveViewer(
              transformationController: _transformCtrl,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              minScale: 0.05,
              maxScale: 6.0,
              child: SizedBox(
                width: schematic.canvasSize.width,
                height: schematic.canvasSize.height,
                child: AnimatedBuilder(
                  animation: animationListenable,
                  builder: (context, _) => CustomPaint(
                    size: schematic.canvasSize,
                    painter: TransitMapPainter(
                      schematic: schematic,
                      crowdState: crowdState,
                      lineColors: lineColors,
                      selectedLineCode: _activeLineCode,
                      zoomProgress:
                          _zoomCtrl?.fadeProgress.value ?? 0.0,
                      barProgress:
                          _zoomCtrl?.barProgress.value ?? 0.0,
                      trainEstimate: trainEstimate,
                      trainPulse:
                          _zoomCtrl?.trainPulse.value ?? 0.0,
                      brightness: brightness,
                      currentScale: _currentScale,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── Floating line chips ────────────────────────────────────────────
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.bgDark.withValues(alpha: 0.88)
                    : AppTheme.bgLight.withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: isDark ? 0.5 : 0.13),
                    blurRadius: 8,
                    offset: const Offset(0, 1),
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
                    final luminance = color.computeLuminance();
                    final labelColor =
                        luminance > 0.5 ? Colors.black : Colors.white;
                    final isStale = line.isStale;

                    return Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 1.5),
                      child: GestureDetector(
                        onTap: _isSwitching
                            ? null
                            : () => _onLineTapped(line.code, schematic),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(10),
                            border: isSelected
                                ? Border.all(
                                    color: AppTheme.accent,
                                    width: 2,
                                  )
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color:
                                          color.withValues(alpha: 0.4),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '● ${line.code.replaceAll('L', '')}',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: labelColor,
                                  height: 1.4,
                                ),
                              ),
                              if (isStale) ...[
                                const SizedBox(width: 2),
                                const Text(
                                  '⚠',
                                  style: TextStyle(
                                    fontSize: 7,
                                    color: Color(0xFFFFC107),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ],
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
          color: AppColors.warning.withValues(alpha: 0.15),
          padding: const EdgeInsets.all(12),
          child: const Text(
            'Mapa não disponível',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.warning),
          ),
        ),
        Expanded(
          child: linesAsync.when(
            loading: () => const AppLoading.spinner(),
            error: (e, _) =>
                const AppError(message: 'Não foi possível carregar as linhas'),
            data: (lines) => ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: lines.length,
              itemBuilder: (ctx, i) {
                final line = lines[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(line.colorValue),
                    radius: 14,
                  ),
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
