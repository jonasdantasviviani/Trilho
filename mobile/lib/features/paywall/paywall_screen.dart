import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/payment_service.dart';
import '../../core/providers/usage_provider.dart';
import '../../core/widgets/app_theme_constants.dart';
import '../../core/widgets/app_theme.dart';
import '../../core/widgets/app_colors.dart';

final paymentServiceProvider = Provider<PaymentService>((ref) {
  final service = PaymentService();
  ref.onDispose(() {});
  return service;
});

class PaywallScreen extends ConsumerStatefulWidget {
  final String? email;
  final String? name;

  const PaywallScreen({
    super.key,
    this.email,
    this.name,
  });

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _loading = false;
  bool _restoring = false;
  String? _errorMessage;

  Future<void> _purchase() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final paymentService = ref.read(paymentServiceProvider);
      final email = widget.email ?? 'usuario@trilho.app';
      final name = widget.name ?? 'Usuário Trilho';

      final result = await paymentService.purchase(
        email: email,
        name: name,
      );

      if (!mounted) return;

      if (result.success) {
        ref.invalidate(usageProvider);
        ref.invalidate(canQueryProvider);

        if (result.devMode) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Premium ativado! (modo dev)'),
              backgroundColor: AppColors.success,
            ),
          );
          context.pop();
        } else if (result.hasPix) {
          _showPixDialog(result);
        } else {
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        setState(() => _errorMessage = result.message);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showPixDialog(PaymentResult result) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PixPaymentDialog(
        result: result,
        paymentService: ref.read(paymentServiceProvider),
      ),
    );

    if (confirmed == true && mounted) {
      ref.invalidate(usageProvider);
      ref.invalidate(canQueryProvider);
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Pagamento confirmado! Premium ativado.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _restore() async {
    setState(() {
      _restoring = true;
      _errorMessage = null;
    });

    try {
      final paymentService = ref.read(paymentServiceProvider);
      final result = await paymentService.restore();

      if (!mounted) return;

      if (result.success) {
        ref.invalidate(usageProvider);
        ref.invalidate(canQueryProvider);
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        setState(() => _errorMessage = result.message);
      }
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.isDark(context) ? AppTheme.bgDark : AppTheme.bgLight,
      appBar: AppBar(title: const Text('Premium')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(Icons.train, size: 80, color: AppTheme.primary),
              const SizedBox(height: 16),
              Text(
                'Trilho Premium',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'R\$9,90/mês',
                style: TextStyle(
                  fontSize: 22,
                  color: AppTheme.accent,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Você já tem acesso gratuito ilimitado.\nO Premium desbloqueia superpoderes.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecDark.withValues(alpha: 0.8),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              const _Feature(
                icon: Icons.notifications_active,
                label: 'Alertas proativos — "sua linha vai lotar em 20 min"',
              ),
              const _Feature(
                icon: Icons.bar_chart,
                label: 'Histórico e previsão de lotação por horário',
              ),
              const _Feature(
                icon: Icons.block,
                label: 'Zero anúncios',
              ),
              const _Feature(
                icon: Icons.widgets,
                label: 'Widget configurável por linha favorita',
              ),
              const Spacer(),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.danger),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              FilledButton(
                onPressed: _loading ? null : _purchase,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.textPrimDark,
                        ),
                      )
                    : const Text('Assinar por R\$9,90/mês'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _restoring ? null : _restore,
                child: _restoring
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Restaurar compras'),
              ),
              const SizedBox(height: 8),
              Text(
                'Pagamento via PIX ou cartão. Cancele a qualquer momento.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Feature({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(icon, color: AppTheme.accent),
          const SizedBox(width: 14),
          Text(label, style: const TextStyle(fontSize: 15)),
        ]),
      );
}

// ── PIX payment dialog ─────────────────────────────────────────────────────────

class _PixPaymentDialog extends StatefulWidget {
  final PaymentResult result;
  final PaymentService paymentService;

  const _PixPaymentDialog({
    required this.result,
    required this.paymentService,
  });

  @override
  State<_PixPaymentDialog> createState() => _PixPaymentDialogState();
}

class _PixPaymentDialogState extends State<_PixPaymentDialog> {
  bool _confirmed = false;
  bool _polling   = false;
  bool _copied    = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  Future<void> _startPolling() async {
    if (widget.result.pixId == null) return;
    setState(() => _polling = true);

    final paid = await widget.paymentService.waitForPayment(widget.result.pixId!);

    if (!mounted) return;
    setState(() {
      _polling   = false;
      _confirmed = paid;
    });

    if (paid) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  Future<void> _copyBrCode() async {
    final code = widget.result.brCode;
    if (code == null || code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AnimatedSwitcher(
          duration: kAnimNormal,
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: anim,
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: _confirmed ? _buildConfirmed() : _buildPix(context),
        ),
      ),
    );
  }

  Widget _buildConfirmed() => const Column(
        key: ValueKey('confirmed'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: AppColors.success, size: 64),
          SizedBox(height: 16),
          Text(
            'Pagamento confirmado!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text('Bem-vindo ao Trilho Premium 🚆', textAlign: TextAlign.center),
        ],
      );

  Widget _buildPix(BuildContext context) {
    final brCodeBase64 = widget.result.brCodeBase64;
    final brCode       = widget.result.brCode;

    return Column(
      key: const ValueKey('pix'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Row(
          children: [
            const Icon(Icons.pix, color: Color(0xFF32BCAD), size: 28),
            const SizedBox(width: 10),
            Text(
              'Pague com PIX',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'R\$9,90 · Trilho Premium Mensal',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 20),

        // QR code
        if (brCodeBase64 != null && brCodeBase64.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              base64Decode(brCodeBase64),
              width: 200,
              height: 200,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox(
                width: 200,
                height: 200,
                child: Center(child: Icon(Icons.qr_code, size: 80)),
              ),
            ),
          )
        else
          const SizedBox(
            width: 200,
            height: 200,
            child: Center(child: Icon(Icons.qr_code, size: 80, color: Colors.grey)),
          ),

        const SizedBox(height: 16),

        // Copia-e-cola
        if (brCode != null && brCode.isNotEmpty)
          OutlinedButton.icon(
            onPressed: _copyBrCode,
            icon: Icon(
              _copied ? Icons.check : Icons.copy,
              size: 18,
              color: _copied ? AppColors.success : null,
            ),
            label: Text(
              _copied ? 'Copiado!' : 'Copiar código PIX',
              style: TextStyle(color: _copied ? AppColors.success : null),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
            ),
          ),

        const SizedBox(height: 16),

        // Polling status
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_polling) ...[
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              _polling
                  ? 'Aguardando confirmação do pagamento…'
                  : 'Escaneie o QR code ou use o código acima',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Cancel
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
