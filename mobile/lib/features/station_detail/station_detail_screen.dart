// mobile/lib/features/station_detail/station_detail_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/models/station_arrivals_model.dart';
import '../../core/models/city_model.dart';
import '../../core/providers/crowd_provider.dart';
import '../../core/providers/usage_provider.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/station_arrivals_provider.dart';
import '../../core/services/admob_service.dart';
import '../../core/widgets/app_error.dart';
import '../../core/widgets/app_loading.dart';
import '../../core/widgets/app_colors.dart';
import '../../core/widgets/app_theme.dart';
import '../../core/widgets/app_theme_constants.dart';
import '../station_detail/crowd_chart.dart';

class StationDetailScreen extends ConsumerStatefulWidget {
  final int stationId;
  const StationDetailScreen({super.key, required this.stationId});

  @override
  ConsumerState<StationDetailScreen> createState() => _StationDetailScreenState();
}

class _StationDetailScreenState extends ConsumerState<StationDetailScreen>
    with SingleTickerProviderStateMixin {
  BannerAd? _bannerAd;
  bool _bannerLoaded = false;
  late AnimationController _countCtrl;
  late Animation<double> _countAnim;
  double _lastDensity = 0.0;

  @override
  void initState() {
    super.initState();
    _countCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _countAnim = CurvedAnimation(parent: _countCtrl, curve: Curves.easeOut);
    _init();
  }

  Future<void> _init() async {
    final tracker  = ref.read(usageTrackerProvider);
    final anon     = await tracker.isAnonymous();
    final canQuery = await tracker.canQuery();
    if (!canQuery) return;

    await tracker.recordQuery();
    if (anon) {
      await AdMobService.showAnonymousQueryAd();
    } else {
      await AdMobService.showInterstitial();
    }
    _loadBanner();
  }

  void _loadBanner() {
    if (kIsWeb) return;
    _bannerAd = BannerAd(
      adUnitId: AdMobService.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _bannerLoaded = true),
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    )..load();
  }

  void _startCountUp(double density) {
    if ((density - _lastDensity).abs() > 0.01) {
      _lastDensity = density;
      _countCtrl.forward(from: 0.0);
    }
  }

  int _estimatePeople(double density, int stationId) {
    final schematic = CityRegistry.getSchematic('sao-paulo-sp');
    final capacity = schematic?.stationById(stationId)?.maxCapacity ?? 1200;
    return (density * capacity).round();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _countCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usageAsync = ref.watch(usageProvider);

    return Scaffold(
      backgroundColor: AppTheme.isDark(context) ? AppTheme.bgDark : AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Estação'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Compartilhar',
            onPressed: () {
              final crowdAsync = ref.read(crowdProvider(widget.stationId));
              crowdAsync.whenData((crowd) {
                if (!crowd.hasData) return;
                _shareStatus(crowd.stationName, crowd.densityLevel, crowd.density);
              });
            },
          ),
        ],
      ),
      body: usageAsync.when(
        loading: () => const AppLoading.spinner(),
        error: (e, _) => const AppError(message: 'Não foi possível verificar seu acesso'),
        data: (usage) =>
            usage.canQuery ? _buildDetail() : _buildGate(context, usage.isAnonymous),
      ),
    );
  }

  Widget _buildDetail() {
    final crowdAsync    = ref.watch(crowdProvider(widget.stationId));
    final arrivalsAsync = ref.watch(stationArrivalsProvider(widget.stationId));

    return fadeSwitch(crowdAsync.when(
      loading: () => const AppLoading.spinner(key: ValueKey('loading')),
      error: (e, _) => AppError(
        message: 'Não foi possível carregar a lotação',
        onRetry: () => ref.invalidate(crowdProvider(widget.stationId)),
      ),
      data: (crowd) {
        if (crowd.hasData) _startCountUp(crowd.density);
        final color    = _colorForLevel(crowd.densityLevel);
        final estimate = _estimatePeople(crowd.density, widget.stationId);

        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── People estimate card ─────────────────────────
                  if (!crowd.hasData)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: (AppTheme.isDark(context) ? AppTheme.surfaceDark : AppTheme.surfaceLight),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.isDark(context) ? AppTheme.borderDark : AppTheme.borderLight,
                        ),
                      ),
                      child: Column(children: [
                        Icon(Icons.people_outline,
                            size: 40,
                            color: AppTheme.isDark(context) ? AppTheme.textSecDark : AppTheme.textSecLight),
                        const SizedBox(height: 8),
                        Text(
                          'Ainda sem dados de lotação',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.isDark(context) ? AppTheme.textPrimDark : AppTheme.textPrimLight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Os dados são coletados em tempo real. Tente novamente em alguns minutos.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.isDark(context) ? AppTheme.textSecDark : AppTheme.textSecLight,
                          ),
                        ),
                      ]),
                    )
                  else
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: color, width: 1.5),
                    ),
                    child: Column(children: [
                      AnimatedBuilder(
                        animation: _countAnim,
                        builder: (_, __) {
                          final displayCount = (estimate * _countAnim.value).round();
                          return Text(
                            '~$displayCount pessoas',
                            style: TextStyle(
                              color: color,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: crowd.density,
                            color: color,
                            backgroundColor: color.withValues(alpha: 0.2),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${(crowd.density * 100).toStringAsFixed(0)}% — ${_labelForLevel(crowd.densityLevel)}',
                        style: TextStyle(
                          color: AppTheme.isDark(context) ? AppTheme.textSecDark : AppTheme.textSecLight,
                          fontSize: 13,
                        ),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 24),

                  // ── Direction cards ──────────────────────────────
                  Text('Próximos trens',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _buildDirectionCards(arrivalsAsync),

                  const SizedBox(height: 24),

                  // ── 3h history ────────────────────────────────────
                  if (crowd.history.isNotEmpty) ...[
                    Text('Últimas 3 horas',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    SizedBox(height: 160, child: CrowdChart(history: crowd.history)),
                    const SizedBox(height: 8),
                  ],

                  if (crowd.hasData)
                    _buildDataFreshness(context, crowd.source, crowd.capturedAt),
                ],
              ),
            ),

            // ── Banner ad ────────────────────────────────────────────
            if (_bannerLoaded && _bannerAd != null)
              SafeArea(
                top: false,
                child: SizedBox(
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
              ),
          ],
        );
      },
    ));
  }

  Widget _buildDirectionCards(AsyncValue<StationArrivals> arrivalsAsync) {
    return arrivalsAsync.when(
      loading: () => Row(
        children: [
          Expanded(child: _shimmerCard()),
          const SizedBox(width: 8),
          Expanded(child: _shimmerCard()),
        ],
      ),
      error: (_, __) => Center(
        child: Text('Dados indisponíveis',
          style: TextStyle(
            color: AppTheme.isDark(context) ? AppTheme.textSecDark : AppTheme.textSecLight,
          )),
      ),
      data: (arrivals) {
        if (arrivals.directions.isEmpty) {
          return Center(
            child: Text('Dados indisponíveis',
              style: TextStyle(
                color: AppTheme.isDark(context) ? AppTheme.textSecDark : AppTheme.textSecLight,
              )),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: arrivals.directions.asMap().entries.map((e) {
            final isFirst = e.key == 0;
            final dir = e.value;
            return Expanded(
              child: GestureDetector(
                onTap: dir.lineCode != null
                    ? () {
                        ref.read(pendingLineSelectionProvider.notifier).state = dir.lineCode;
                        context.go('/');
                      }
                    : null,
                child: Container(
                margin: EdgeInsets.only(right: isFirst ? 4 : 0, left: isFirst ? 0 : 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${isFirst ? '→' : '←'} ${dir.terminus}',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(height: 8),
                    ...dir.arrivals.take(3).map((a) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Text('🚆 ', style: TextStyle(fontSize: 13)),
                              Text(
                                '${a.isEstimated ? '~' : ''}${a.estimatedMinutes} min',
                                style: TextStyle(
                                  fontWeight: a == dir.arrivals.first
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: a == dir.arrivals.first
                                      ? _arrivalColor(a.estimatedMinutes)
                                      : (AppTheme.isDark(context) ? AppTheme.textSecDark : AppTheme.textSecLight),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _shimmerCard() => Container(
        height: 90,
        decoration: BoxDecoration(
          color: AppTheme.isDark(context) ? AppTheme.surfRaisedDark : AppTheme.surfRaisedLight,
          borderRadius: BorderRadius.circular(12),
        ),
      );

  Color _arrivalColor(int minutes) {
    if (minutes <= 2) return AppColors.success;
    if (minutes <= 5) return AppColors.warning;
    return AppTheme.textSecDark;
  }

  Color _colorForLevel(String level) => switch (level) {
        'Low'    => AppColors.crowdLow,
        'Medium' => AppColors.crowdModerate,
        'High'   => AppColors.crowdHigh,
        'Packed' => AppColors.crowdFull,
        _        => AppTheme.isDark(context) ? AppTheme.textSecDark : AppTheme.textSecLight,
      };

  String _labelForLevel(String level) => switch (level) {
        'Low'    => 'Tranquilo',
        'Medium' => 'Moderado',
        'High'   => 'Cheio',
        'Packed' => 'Lotado',
        _        => '—',
      };

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'agora';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    return 'há ${diff.inHours}h';
  }

  void _shareStatus(String stationName, String densityLevel, double density) {
    final emoji = switch (densityLevel) {
      'Low'    => '🟢',
      'Medium' => '🟡',
      'High'   => '🟠',
      'Packed' => '🔴',
      _        => '⚪',
    };
    final label = _labelForLevel(densityLevel);
    final pct   = (density * 100).toStringAsFixed(0);
    Share.share(
      '$emoji $stationName está $label agora ($pct% de ocupação)\n'
      'Veja em tempo real pelo Trilho — trilho.app',
      subject: 'Trilho: lotação em $stationName',
    );
  }

  Widget _buildDataFreshness(BuildContext context, String source, DateTime capturedAt) {
    final staleness = DateTime.now().difference(capturedAt);
    final isStale = staleness.inMinutes >= 5;
    final timeLabel = _formatTime(capturedAt);

    if (!isStale) {
      return Text(
        'Fonte: $source • $timeLabel',
        style: Theme.of(context).textTheme.bodySmall,
        textAlign: TextAlign.center,
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.warning),
              const SizedBox(width: 6),
              Text(
                'Dado com ${staleness.inMinutes} min de atraso',
                style: const TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Fonte: $source • $timeLabel',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildGate(BuildContext context, bool isAnonymous) {
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;
    // Registered (gratuito) users always canQuery — this gate is only for anonymous users
    // who hit the 10/day limit.
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle),
              child: const Icon(Icons.login_rounded, size: 36, color: AppTheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Você consultou 10 vezes hoje',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Crie uma conta gratuita para consultas ilimitadas.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.isDark(context) ? AppTheme.textSecDark : AppTheme.textSecLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity, height: 52,
              child: FilledButton.icon(
                icon: const Icon(Icons.login_rounded),
                label: const Text('Criar conta gratuita'),
                onPressed: () => context.push('/login'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.push('/paywall'),
              child: const Text('Ou assine o Premium →'),
            ),
          ],
        ),
      ),
    );
  }
}
