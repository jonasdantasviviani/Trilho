import 'package:flutter/material.dart';

class AppError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AppError({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      liveRegion: true,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: onRetry,
                  child: const Text('Tentar novamente'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
