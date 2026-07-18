import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/favorite_line_provider.dart';
import '../../core/providers/usage_provider.dart';
import '../../core/services/usage_tracker.dart';
import '../../core/widgets/app_theme.dart';
import '../../core/widgets/app_colors.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor     = isDark ? AppTheme.bgDark       : AppTheme.bgLight;
    final cardColor   = isDark ? AppTheme.surfaceDark   : AppTheme.surfaceLight;
    final borderColor = isDark ? AppTheme.borderDark    : AppTheme.borderLight;
    final labelColor  = isDark ? AppTheme.textSecDark   : AppTheme.textSecLight;
    final textPrimary = isDark ? AppTheme.textPrimDark  : AppTheme.textPrimLight;
    const textRed     = AppColors.danger;

    final usageAsync = ref.watch(usageProvider);

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
          // ── Plano ─────────────────────────────────────────────────────────
          usageAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (usage) {
              if (usage.isPremium) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('PLANO', labelColor),
                  _card(isDark, cardColor, [
                    _settingRow(
                      icon: '⭐',
                      iconBg: isDark ? const Color(0xFF2C2500) : const Color(0xFFFFFDE7),
                      title: 'Assinar Premium',
                      subtitle: 'R\$9,90/mês • sem anúncios',
                      textPrimary: textPrimary,
                      borderColor: Colors.transparent,
                      trailing: Icon(Icons.chevron_right, color: labelColor),
                      subtitleColor: labelColor,
                      onTap: () => context.push('/paywall'),
                    ),
                  ]),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),

          // ── Comunidade ────────────────────────────────────────────────────
          _sectionLabel('COMUNIDADE', labelColor),
          Builder(builder: (ctx) {
            final favLine = ref.watch(favoriteLineProvider);
            return _card(isDark, cardColor, [
              _settingRow(
                icon: '⭐',
                iconBg: isDark ? const Color(0xFF2C2500) : const Color(0xFFFFFDE7),
                title: 'Linha favorita',
                subtitle: favLine != null
                    ? 'Linha $favLine — toque ⭐ no mapa para alterar'
                    : 'Nenhuma — toque ⭐ no mapa ao selecionar uma linha',
                textPrimary: textPrimary,
                borderColor: Colors.transparent,
                trailing: favLine != null
                    ? GestureDetector(
                        onTap: () =>
                            ref.read(favoriteLineProvider.notifier).toggle(favLine),
                        child: const Icon(Icons.star_rounded,
                            color: Color(0xFFFFC107), size: 20),
                      )
                    : Icon(Icons.star_border_rounded, color: labelColor),
                subtitleColor: labelColor,
              ),
            ]);
          }),
          const SizedBox(height: 12),
          FutureBuilder<int>(
            future: UsageTracker().pingsTodayCount(),
            builder: (ctx, snap) {
              final count = snap.data ?? 0;
              final impactLabel = count == 0
                  ? 'Nenhuma contribuição hoje ainda'
                  : count == 1
                      ? 'Sua contribuição de hoje ajudou outros usuários 🙌'
                      : 'Suas $count contribuições de hoje ajudaram outros usuários 🙌';
              return _card(isDark, cardColor, [
                _settingRow(
                  icon: '🤝',
                  iconBg: isDark ? const Color(0xFF0A2E1A) : const Color(0xFFE8F5E9),
                  title: 'Impacto hoje',
                  subtitle: impactLabel,
                  textPrimary: textPrimary,
                  borderColor: Colors.transparent,
                  trailing: count > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00C853),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : Icon(Icons.group_outlined, color: labelColor),
                  subtitleColor: labelColor,
                ),
              ]);
            },
          ),

          const SizedBox(height: 20),

          // ── Aparência ─────────────────────────────────────────────────────
          _sectionLabel('APARÊNCIA', labelColor),
          _card(isDark, cardColor, [
            _settingRow(
              icon: '🌙',
              iconBg: isDark ? const Color(0xFF1A237E) : const Color(0xFFEEF2FF),
              title: 'Modo escuro',
              subtitle: 'Tema escuro',
              textPrimary: textPrimary,
              borderColor: borderColor,
              trailing: Switch(
                value: isDark,
                onChanged: (val) {
                  final mode = val ? ThemeMode.dark : ThemeMode.light;
                  ref.read(themeModeProvider.notifier).state = mode;
                  // Persist preference; box is always open in production (main.dart).
                  // Gracefully skip if unavailable (e.g., in widget tests).
                  try {
                    Hive.box('app_prefs').put('theme_mode', val ? 'dark' : 'light');
                  } catch (_) {}
                },
                activeThumbColor: isDark ? const Color(0xFF2979FF) : const Color(0xFF0455A1),
              ),
              subtitleColor: labelColor,
            ),
            _settingRow(
              icon: '🌍',
              iconBg: isDark ? const Color(0xFF1B3A1B) : const Color(0xFFF1F8E9),
              title: 'Idioma',
              subtitle: 'Português (BR)',
              textPrimary: textPrimary,
              borderColor: Colors.transparent,
              trailing: Icon(Icons.chevron_right, color: labelColor),
              subtitleColor: labelColor,
              onTap: () {},
            ),
          ]),

          const SizedBox(height: 20),

          // ── Conta ─────────────────────────────────────────────────────────
          _sectionLabel('CONTA', labelColor),
          _card(isDark, cardColor, [
            _settingRow(
              icon: '👤',
              iconBg: isDark ? const Color(0xFF2A1A2E) : const Color(0xFFF3E5F5),
              title: 'Perfil',
              subtitle: null,
              textPrimary: textPrimary,
              borderColor: borderColor,
              trailing: Icon(Icons.chevron_right, color: labelColor),
              onTap: () {},
            ),
            _settingRow(
              icon: '🔒',
              iconBg: isDark ? const Color(0xFF1A2E1A) : const Color(0xFFE8F5E9),
              title: 'Privacidade & LGPD',
              subtitle: null,
              textPrimary: textPrimary,
              borderColor: borderColor,
              trailing: Icon(Icons.chevron_right, color: labelColor),
              onTap: () => _showPrivacy(context),
            ),
            _settingRow(
              icon: '🚪',
              iconBg: isDark ? const Color(0xFF3E0000) : const Color(0xFFFFEBEE),
              title: 'Sair',
              subtitle: null,
              textPrimary: textRed,
              borderColor: Colors.transparent,
              trailing: const Icon(Icons.chevron_right, color: textRed, size: 18),
              onTap: () => _signOut(context, ref),
            ),
          ]),

          const SizedBox(height: 32),
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

  Widget _card(bool isDark, Color bg, List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
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
    required Color borderColor,
    required Widget trailing,
    Color subtitleColor = const Color(0xFF888888),
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: borderColor, width: 0.8)),
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
              if (subtitle != null)
                Text(subtitle, style: TextStyle(fontSize: 11, color: subtitleColor)),
            ],
          )),
          trailing,
        ]),
      ),
    );
  }

  void _signOut(BuildContext context, WidgetRef ref) {
    showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sair'),
        content: const Text('Tem certeza que deseja sair da sua conta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed != true) return;
      ref.read(authServiceProvider).clear().then((_) {
        if (context.mounted) context.go('/login');
      });
    });
  }

  void _showPrivacy(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Privacidade & LGPD'),
        content: const SingleChildScrollView(
          child: Text(
            'O Trilho é desenvolvido em conformidade com a Lei Geral de '
            'Proteção de Dados (Lei 13.709/2018 — LGPD).\n\n'

            'IDENTIFICAÇÃO ANÔNIMA\n'
            'Você é identificado por um UUID anônimo gerado localmente, '
            'sem nome, e-mail ou qualquer informação pessoal (PII).\n\n'

            'COLETA DE LOCALIZAÇÃO (GPS)\n'
            'Se você ativar o crowdsourcing, sua localização é coletada '
            'de forma passiva enquanto você usa transporte público. '
            'Os dados são enviados como pings anônimos e automaticamente '
            'deletados do servidor após 10 minutos.\n'
            'A localização NUNCA é associada ao seu perfil pessoal.\n\n'

            'SEUS DIREITOS (LGPD, Art. 18)\n'
            '• Acesso: saiba quais dados temos sobre você\n'
            '• Exclusão: solicite a remoção de todos os seus dados\n'
            '• Portabilidade: exporte seus dados\n'
            '• Revogação: cancele o consentimento a qualquer momento\n\n'

            'Para exercer seus direitos, contate: privacidade@trilho.app\n\n'

            'O Trilho não vende, compartilha ou monetiza dados pessoais '
            'de nenhuma forma.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}
