import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bottom sheet shown when an anonymous user exhausts their 5 free queries.
/// Prompts them to log in to continue using the freemium tier.
Future<void> showAnonymousGateSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _AnonymousGateContent(),
  );
}

class _AnonymousGateContent extends StatelessWidget {
  const _AnonymousGateContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_outline_rounded, size: 32, color: cs.primary),
          ),
          const SizedBox(height: 16),

          // Title
          Semantics(
            header: true,
            child: Text(
              'Suas 5 consultas gratuitas acabaram',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),

          // Subtitle
          Text(
            'Crie uma conta gratuitamente para continuar consultando a lotação todos os dias.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 28),

          // Primary CTA — go to login
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              icon: const Icon(Icons.login_rounded),
              label: const Text('Criar conta / Entrar'),
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/login');
              },
            ),
          ),
          const SizedBox(height: 12),

          // Secondary CTA — go premium
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.star_rounded),
              label: const Text('Assinar Premium — consultas ilimitadas'),
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/paywall');
              },
            ),
          ),
        ],
      ),
    );
  }
}
