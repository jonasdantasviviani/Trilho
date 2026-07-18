import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/subscription_service.dart';
import '../../core/widgets/app_colors.dart';
import '../../core/widgets/app_error.dart';
import '../../core/widgets/app_loading.dart';
import '../../core/widgets/app_theme.dart';

final subscriptionServiceProvider = Provider((ref) => SubscriptionService());

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  SubscriptionStatus? _status;
  List<SubscriptionHistoryItem> _history = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = ref.read(subscriptionServiceProvider);
      final results = await Future.wait([
        service.getStatus(),
        service.getHistory(),
      ]);

      if (mounted) {
        setState(() {
          _status = results[0] as SubscriptionStatus;
          _history = results[1] as List<SubscriptionHistoryItem>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _cancelSubscription() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar Assinatura'),
        content: const Text(
          'Tem certeza que deseja cancelar sua assinatura?\n\n'
          'Você ainda terá acesso até o fim do período pago.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final service = ref.read(subscriptionServiceProvider);
      final result = await service.cancel();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? AppColors.success : AppColors.danger,
          ),
        );
        if (result.success) {
          _loadData();
        }
      }
    }
  }

  Future<void> _reactivateSubscription() async {
    final service = ref.read(subscriptionServiceProvider);
    final result = await service.reactivate();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? AppColors.success : AppColors.danger,
        ),
      );
      if (result.success) {
        _loadData();
      }
    }
  }

  Future<void> _changePlan() async {
    final selectedPlan = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => const _ChangePlanSheet(),
    );

    if (selectedPlan != null) {
      final service = ref.read(subscriptionServiceProvider);
      final result = await service.changePlan(selectedPlan);

      if (mounted && result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Plano alterado para ${result.planName}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Assinatura'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: isDark ? AppTheme.textSecDark : AppTheme.textSecLight,
          tabs: const [
            Tab(text: 'Plano Atual'),
            Tab(text: 'Histórico'),
          ],
        ),
      ),
      body: _loading
          ? const AppLoading.spinner()
          : _error != null
              ? AppError(
                  message: 'Não foi possível carregar sua assinatura',
                  onRetry: _loadData,
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCurrentPlanTab(),
                    _buildHistoryTab(),
                  ],
                ),
    );
  }

  Widget _buildCurrentPlanTab() {
    if (_status == null) return const SizedBox();

    final status = _status!;
    final isDark = AppTheme.isDark(context);

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Hero card ─────────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: status.isActive
                      ? [AppTheme.primary, AppTheme.accent]
                      : [
                          isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                          isDark ? AppTheme.surfRaisedDark : AppTheme.surfRaisedLight,
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Icon(
                    status.isActive ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    status.planName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status.formattedPrice,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: status.isActive
                          ? Colors.white.withValues(alpha: 0.2)
                          : AppColors.danger.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.isActive ? 'Assinatura Ativa' : 'Assinatura Inativa',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Detalhes card ───────────────────────────────��─────────────────
            Container(
              decoration: AppTheme.cardDecoration(context),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DETALHES',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.6,
                          color: isDark ? AppTheme.textSecDark : AppTheme.textSecLight,
                        ),
                  ),
                  const Divider(),
                  _buildDetailRow(
                    Icons.calendar_today,
                    'Próxima Cobrança',
                    status.isPremiumUntil != null ? status.formattedDate : '-',
                  ),
                  _buildDetailRow(
                    Icons.payment,
                    'Método de Pagamento',
                    status.paymentMethod,
                  ),
                  _buildDetailRow(
                    Icons.autorenew,
                    'Renovação Automática',
                    status.autoRenew ? 'Ativada' : 'Desativada',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Ações card ────────────────────────────────────────────────────
            Container(
              decoration: AppTheme.cardDecoration(context),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ações', style: Theme.of(context).textTheme.titleMedium),
                  const Divider(),
                  if (status.canChangePlan) ...[
                    ListTile(
                      leading: Icon(Icons.swap_horiz,
                          color: isDark ? AppTheme.textSecDark : AppTheme.textSecLight),
                      title: const Text('Trocar Plano'),
                      subtitle: const Text('Escolha outro plano'),
                      trailing: Icon(Icons.chevron_right,
                          color: isDark ? AppTheme.textSecDark : AppTheme.textSecLight),
                      onTap: _changePlan,
                    ),
                  ],
                  if (status.isActive && status.canCancel) ...[
                    ListTile(
                      leading: const Icon(Icons.cancel, color: AppColors.danger),
                      title: const Text(
                        'Cancelar Assinatura',
                        style: TextStyle(color: AppColors.danger),
                      ),
                      subtitle: Text('Válido até ${status.formattedDate}'),
                      trailing: const Icon(Icons.chevron_right, color: AppColors.danger),
                      onTap: _cancelSubscription,
                    ),
                  ],
                  if (!status.isActive) ...[
                    ListTile(
                      leading: const Icon(Icons.refresh, color: AppColors.success),
                      title: const Text(
                        'Reativar Assinatura',
                        style: TextStyle(color: AppColors.success),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: AppColors.success),
                      onTap: _reactivateSubscription,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    final isDark = AppTheme.isDark(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20,
              color: isDark ? AppTheme.textSecDark : AppTheme.textSecLight),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                  color: isDark ? AppTheme.textSecDark : AppTheme.textSecLight),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isDark ? AppTheme.textPrimDark : AppTheme.textPrimLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    final isDark = AppTheme.isDark(context);
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64,
                color: isDark ? AppTheme.textSecDark : AppTheme.textSecLight),
            const SizedBox(height: 16),
            Text(
              'Nenhum histórico encontrado',
              style: TextStyle(
                  color: isDark ? AppTheme.textSecDark : AppTheme.textSecLight),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final item = _history[index];
        final isPaid = item.status == 'paid';
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: AppTheme.cardDecoration(context),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isPaid
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.warning.withValues(alpha: 0.1),
              child: Icon(
                isPaid ? Icons.check : Icons.warning,
                color: isPaid ? AppColors.success : AppColors.warning,
              ),
            ),
            title: Text(item.description),
            subtitle: Text(
              item.formattedDate,
              style: TextStyle(
                  color: isDark ? AppTheme.textSecDark : AppTheme.textSecLight),
            ),
            trailing: Text(
              item.formattedPrice,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDark ? AppTheme.textPrimDark : AppTheme.textPrimLight,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChangePlanSheet extends StatelessWidget {
  const _ChangePlanSheet();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.bgDark : AppTheme.bgLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Escolha um Plano',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildPlanOption(context, 'monthly', 'Mensal', 'R\$ 9,90/mês', null),
          const SizedBox(height: 8),
          _buildPlanOption(
              context, 'quarterly', 'Trimestral', 'R\$ 24,90/trimestre', 'Economia de 16%'),
          const SizedBox(height: 8),
          _buildPlanOption(
              context, 'annual', 'Anual', 'R\$ 99,00/ano', 'Economia de 17%'),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanOption(
    BuildContext context,
    String value,
    String name,
    String price,
    String? badge,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => Navigator.pop(context, value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: 'monthly',
              onChanged: (_) => Navigator.pop(context, value),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    price,
                    style: TextStyle(
                        color: isDark ? AppTheme.textSecDark : AppTheme.textSecLight),
                  ),
                ],
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Economia',
                  style: TextStyle(
                    color: AppTheme.textPrimDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
