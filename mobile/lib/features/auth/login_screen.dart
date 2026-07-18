import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/models/service_health_model.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/service_health_provider.dart';
import '../../core/widgets/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _loadingGoogle    = false;
  bool _loadingApple     = false;
  bool _loadingAnonymous = false;
  bool _loadingEmail     = false;

  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();

  // -------------------------------------------------------------------------
  // Navigation helper
  // -------------------------------------------------------------------------

  void _navigateAfterAuth() {
    context.go('/');
  }

  // -------------------------------------------------------------------------
  // Firebase lazy-init guard
  // -------------------------------------------------------------------------

  /// Ensures Firebase is initialized before any social sign-in attempt.
  /// Returns false (and shows a SnackBar) if Firebase is not configured.
  Future<bool> _ensureFirebase() async {
    if (Firebase.apps.isNotEmpty) return true;
    try {
      await Firebase.initializeApp();
      return true;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Login social não está disponível neste momento. '
            'Use "Continuar sem conta" ou tente mais tarde.',
          ),
        ),
      );
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // Sign-in methods
  // -------------------------------------------------------------------------

  Future<void> _signInWithGoogle() async {
    setState(() => _loadingGoogle = true);
    try {
      if (!await _ensureFirebase()) return;

      final api        = ref.read(apiServiceProvider);
      final auth       = ref.read(authServiceProvider);
      final geofencing = ref.read(geofencingServiceProvider);

      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return; // user cancelled
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      final idToken  = await userCred.user!.getIdToken();
      await auth.loginWithFirebase(api, geofencing, idToken: idToken!);

      if (!mounted) return;
      _navigateAfterAuth();
    } catch (e, st) {
      debugPrint('[LoginScreen] Google sign-in error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao entrar com Google: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingGoogle = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _loadingApple = true);
    try {
      if (!await _ensureFirebase()) return;

      final api        = ref.read(apiServiceProvider);
      final auth       = ref.read(authServiceProvider);
      final geofencing = ref.read(geofencingServiceProvider);

      final rawNonce = _generateNonce();
      final nonce    = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: nonce,
      );
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken:  appleCredential.identityToken,
        rawNonce: rawNonce,
      );
      final userCred = await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      final idToken  = await userCred.user!.getIdToken();
      await auth.loginWithFirebase(api, geofencing, idToken: idToken!);

      if (!mounted) return;
      _navigateAfterAuth();
    } catch (e, st) {
      debugPrint('[LoginScreen] Apple sign-in error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao entrar com Apple: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingApple = false);
    }
  }

  Future<void> _signInAnonymous() async {
    setState(() => _loadingAnonymous = true);
    debugPrint('[LoginScreen] Anonymous sign-in started. API URL: ${ref.read(apiServiceProvider).baseUrl}');
    try {
      final api        = ref.read(apiServiceProvider);
      final auth       = ref.read(authServiceProvider);
      final geofencing = ref.read(geofencingServiceProvider);
      debugPrint('[LoginScreen] Calling ensureRegistered...');
      await auth.ensureRegistered(api, geofencing);
      debugPrint('[LoginScreen] ensureRegistered OK');

      if (!mounted) return;
      _navigateAfterAuth();
    } catch (e, st) {
      debugPrint('[LoginScreen] Anonymous sign-in error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao continuar sem conta: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingAnonymous = false);
    }
  }

  // -------------------------------------------------------------------------
  // Nonce helpers (Apple Sign-In)
  // -------------------------------------------------------------------------

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes  = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // -------------------------------------------------------------------------
  // Email / password sign-in
  // -------------------------------------------------------------------------

  Future<void> _signInWithEmail() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha e-mail e senha.')),
      );
      return;
    }
    setState(() => _loadingEmail = true);
    try {
      if (!await _ensureFirebase()) return;

      final api        = ref.read(apiServiceProvider);
      final auth       = ref.read(authServiceProvider);
      final geofencing = ref.read(geofencingServiceProvider);

      final userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final idToken = await userCred.user!.getIdToken();
      await auth.loginWithFirebase(api, geofencing, idToken: idToken!);

      if (!mounted) return;
      _navigateAfterAuth();
    } catch (e, st) {
      debugPrint('[LoginScreen] Email sign-in error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao entrar: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingEmail = false);
    }
  }

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              // ── Logo ──────────────────────────────────────────────────────
              _buildLogo(isDark),
              const SizedBox(height: 48),
              // ── Email field ───────────────────────────────────────────────
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: isDark ? AppTheme.textPrimDark : AppTheme.textPrimLight),
                decoration: const InputDecoration(labelText: 'E-mail'),
              ),
              const SizedBox(height: 14),
              // ── Password field ────────────────────────────────────────────
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                style: TextStyle(color: isDark ? AppTheme.textPrimDark : AppTheme.textPrimLight),
                decoration: const InputDecoration(labelText: 'Senha'),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/login/email'),
                  child: const Text('Esqueceu?',
                      style: TextStyle(color: AppTheme.accent, fontSize: 12)),
                ),
              ),
              const SizedBox(height: 16),
              // ── Primary CTA ───────────────────────────────────────────────
              _loadingEmail
                  ? const Center(child: CircularProgressIndicator())
                  : _GradientButton(
                      label: 'Entrar',
                      onTap: _signInWithEmail,
                    ),
              const SizedBox(height: 28),
              Row(children: [
                Expanded(child: Divider(color: isDark ? AppTheme.borderDark : AppTheme.borderLight)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('ou', style: TextStyle(
                    color: isDark ? AppTheme.textSecDark : AppTheme.textSecLight,
                    fontSize: 12,
                  )),
                ),
                Expanded(child: Divider(color: isDark ? AppTheme.borderDark : AppTheme.borderLight)),
              ]),
              const SizedBox(height: 20),
              // ── Social ────────────────────────────────────────────────────
              _SocialButton(
                label: 'Continuar com Google',
                loading: _loadingGoogle,
                icon: Icons.g_mobiledata,
                onTap: _signInWithGoogle,
              ),
              const SizedBox(height: 10),
              _SocialButton(
                label: 'Continuar com Apple',
                loading: _loadingApple,
                icon: Icons.apple,
                onTap: _signInWithApple,
              ),
              const SizedBox(height: 28),
              // ── Anonymous ─────────────────────────────────────────────────
              OutlinedButton(
                onPressed: _loadingAnonymous ? null : _signInAnonymous,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                  foregroundColor: isDark ? AppTheme.textSecDark : AppTheme.textSecLight,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _loadingAnonymous
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Continuar sem conta', style: TextStyle(fontSize: 13)),
              ),
              const SizedBox(height: 20),
              // ── Service status debug panel (retire quando não precisar mais) ─
              const _ServiceStatusPanel(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(bool isDark) {
    return Column(
      children: [
        SizedBox(
          width: 56, height: 56,
          child: CustomPaint(painter: _LogoIconPainter()),
        ),
        const SizedBox(height: 12),
        Text(
          'TRILHO',
          style: GoogleFonts.inter(
            fontSize: 28, fontWeight: FontWeight.w800,
            color: AppTheme.accent, letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Mobilidade em tempo real',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: isDark ? AppTheme.textSecDark : AppTheme.textSecLight,
          ),
        ),
      ],
    );
  }
}

// ── _ServiceStatusPanel ───────────────────────────────────────────────────────
class _ServiceStatusPanel extends ConsumerStatefulWidget {
  const _ServiceStatusPanel();

  @override
  ConsumerState<_ServiceStatusPanel> createState() => _ServiceStatusPanelState();
}

class _ServiceStatusPanelState extends ConsumerState<_ServiceStatusPanel> {
  Timer? _timer;

  /// Último fetch bem-sucedido — mantém os dados visíveis durante um reload.
  ServiceHealthFetch? _cached;

  /// Conjunto de sources cujo botão de reload foi pressionado e o fetch ainda
  /// não completou. Usado para mostrar spinner individual na linha.
  final Set<String> _reloading = {};

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _reload());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _reload([String? source]) {
    setState(() {
      if (source != null) _reloading.add(source);
    });
    ref.invalidate(serviceHealthProvider);
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = AppTheme.isDark(context);
    final health    = ref.watch(serviceHealthProvider);
    final secColor  = isDark ? AppTheme.textSecDark  : AppTheme.textSecLight;
    final primColor = isDark ? AppTheme.textPrimDark : AppTheme.textPrimLight;
    final bgColor   = isDark ? const Color(0xFF14142A) : const Color(0xFFF2F2F8);
    final bdColor   = isDark ? AppTheme.borderDark : AppTheme.borderLight;

    // Atualiza cache e limpa reloads individuais quando dados chegam
    final isLoading = health.isLoading;
    if (!isLoading) {
      final fetched = health.valueOrNull;
      if (fetched != null) _cached = fetched;
      if (_reloading.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _reloading.clear());
        });
      }
    }

    // Exibe dados em cache enquanto recarrega (evita "Verificando..." piscar)
    final display = health.valueOrNull ?? _cached;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bdColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabeçalho ────────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.monitor_heart_outlined, size: 13,
                  color: AppTheme.accent),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'SERVIÇOS EXTERNOS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accent,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              // Timestamp da última verificação
              if (display?.result?.checkedAt != null) ...[
                Text(
                  _fmtTime(display!.result!.checkedAt),
                  style: TextStyle(fontSize: 9, color: secColor),
                ),
                const SizedBox(width: 6),
              ],
              // Reload global
              isLoading && _reloading.isEmpty
                  ? const SizedBox(
                      width: 13, height: 13,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    )
                  : GestureDetector(
                      onTap: _reload,
                      child: Icon(Icons.refresh_rounded,
                          size: 15, color: secColor),
                    ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Linhas de serviço ─────────────────────────────────────────────
          if (display == null)
            // Ainda sem nenhum cache
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('Verificando...',
                  style: TextStyle(fontSize: 11, color: secColor)),
            )
          else if (!display.isApiOnline)
            // API completamente inacessível
            _buildApiOfflineRow(
              display.connectionError,
              primColor,
              secColor,
            )
          else ...[
            // Linha da própria API (sempre OK quando chegamos aqui)
            _buildApiRow(display.result!, primColor, secColor),
            // Uma linha por serviço externo
            ...display.result!.sources.map(
              (s) => _buildServiceRow(s, primColor, secColor),
            ),
          ],
        ],
      ),
    );
  }

  // ── Linha: API inacessível ──────────────────────────────────────────────────
  Widget _buildApiOfflineRow(
      String? error, Color primColor, Color secColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        children: [
          _dot(Colors.redAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Trilho API',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: primColor)),
                if (error != null && error.isNotEmpty)
                  Text(
                    error,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 9, color: secColor),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          _badge('Offline', Colors.redAccent),
          _reloadBtn('__api__'),
          _detailsBtn(
            title: 'Trilho API',
            source: '__api__',
            status: 'Offline',
            ageLabel: null,
            ageSeconds: null,
            errorText: error ?? 'Sem detalhes disponíveis.',
          ),
        ],
      ),
    );
  }

  // ── Linha: API online (cabeçalho) ───────────────────────────────────────────
  Widget _buildApiRow(
      ServiceHealthResult result, Color primColor, Color secColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        children: [
          _dot(Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Trilho API',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: primColor)),
          ),
          _badge('Online', Colors.green),
          // reload + detalhes globais reutilizam o refresh do provider
          _reloadBtn('__api__'),
          _detailsBtn(
            title: 'Trilho API',
            source: '__api__',
            status: 'Healthy',
            ageLabel: null,
            ageSeconds: null,
            errorText: null,
          ),
        ],
      ),
    );
  }

  // ── Linha: serviço externo individual ──────────────────────────────────────
  Widget _buildServiceRow(
      ServiceHealth s, Color primColor, Color secColor) {
    final (dotColor, badgeLabel) = _statusVisuals(s.status);
    final isThisReloading = _reloading.contains(s.source);

    final subText = s.ageSeconds > 0
        ? s.ageLabel
        : (s.lastError?.isNotEmpty == true ? s.lastError! : null);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Dot (vira spinner se reload individual em progresso)
          isThisReloading
              ? const SizedBox(
                  width: 9, height: 9,
                  child: CircularProgressIndicator(strokeWidth: 1.2),
                )
              : _dot(dotColor),
          const SizedBox(width: 8),
          // Nome + sublabel
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _displayName(s.source),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: primColor,
                      height: 1.2),
                ),
                if (subText != null)
                  Text(
                    subText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 9, color: secColor, height: 1.2),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          _badge(badgeLabel, dotColor),
          _reloadBtn(s.source),
          _detailsBtn(
            title: _displayName(s.source),
            source: s.source,
            status: s.status,
            ageLabel: s.ageLabel,
            ageSeconds: s.ageSeconds,
            errorText: s.lastError,
          ),
        ],
      ),
    );
  }

  // ── Widgets auxiliares ──────────────────────────────────────────────────────

  Widget _dot(Color color) => Container(
        width: 7, height: 7,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w700, color: color),
        ),
      );

  Widget _reloadBtn(String source) => GestureDetector(
        onTap: () => _reload(source),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(Icons.refresh_rounded,
              size: 13,
              color: AppTheme.isDark(context)
                  ? AppTheme.textSecDark
                  : AppTheme.textSecLight),
        ),
      );

  Widget _detailsBtn({
    required String title,
    required String source,
    required String status,
    required String? ageLabel,
    required double? ageSeconds,
    required String? errorText,
  }) {
    return GestureDetector(
      onTap: () => _showDetailsDialog(
        title: title,
        source: source,
        status: status,
        ageLabel: ageLabel,
        ageSeconds: ageSeconds,
        errorText: errorText,
      ),
      child: const Padding(
        padding: EdgeInsets.only(left: 2),
        child: Text(
          'Detalhes',
          style: TextStyle(
            fontSize: 9,
            color: AppTheme.accent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showDetailsDialog({
    required String title,
    required String source,
    required String status,
    required String? ageLabel,
    required double? ageSeconds,
    required String? errorText,
  }) {
    final (dotColor, _) = _statusVisuals(status);

    showDialog<void>(
      context: context,
      builder: (ctx) {
        final isDark = AppTheme.isDark(ctx);
        final bgColor =
            isDark ? const Color(0xFF1A1A2E) : Colors.white;
        final primColor =
            isDark ? AppTheme.textPrimDark : AppTheme.textPrimLight;
        final secColor =
            isDark ? AppTheme.textSecDark : AppTheme.textSecLight;

        return Dialog(
          backgroundColor: bgColor,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título
                Row(
                  children: [
                    Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: dotColor),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(title,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: primColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(source,
                    style: TextStyle(fontSize: 10, color: secColor)),
                const Divider(height: 20),

                // Status
                _dialogRow('Status', status, dotColor, primColor, secColor),

                // Idade dos dados
                if (ageLabel != null)
                  _dialogRow('Última atualização', ageLabel,
                      null, primColor, secColor),
                if (ageSeconds != null && ageSeconds >= 0)
                  _dialogRow('Idade (segundos)', ageSeconds.toStringAsFixed(1),
                      null, primColor, secColor),

                const SizedBox(height: 8),

                // Erro
                Text('Erro de conexão',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: secColor,
                        letterSpacing: 0.4)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0D0D1F)
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: isDark
                            ? AppTheme.borderDark
                            : AppTheme.borderLight),
                  ),
                  child: SelectableText(
                    errorText?.isNotEmpty == true
                        ? errorText!
                        : 'Sem erro registrado.',
                    style: TextStyle(
                        fontSize: 10,
                        color: errorText?.isNotEmpty == true
                            ? Colors.redAccent
                            : secColor,
                        fontFamily: 'monospace',
                        height: 1.4),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Fechar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _dialogRow(String label, String value, Color? valueColor,
      Color primColor, Color secColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text('$label: ',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: secColor)),
          Text(value,
              style: TextStyle(
                  fontSize: 11,
                  color: valueColor ?? primColor,
                  fontWeight: valueColor != null
                      ? FontWeight.w700
                      : FontWeight.normal)),
        ],
      ),
    );
  }

  // ── Helpers estáticos ───────────────────────────────────────────────────────

  static (Color, String) _statusVisuals(String status) => switch (status) {
        'Healthy'  => (Colors.green,     'OK'),
        'Degraded' => (Colors.amber,     'Degradado'),
        'Down'     => (Colors.redAccent, 'Fora'),
        'Stale'    => (Colors.orange,    'Stale'),
        'Offline'  => (Colors.redAccent, 'Offline'),
        _          => (Colors.grey,      'Desconhecido'),
      };

  static String _displayName(String source) => switch (source) {
        'OlhoVivo'     => 'OlhoVivo (SPTrans)',
        'LinhasMetroApiScraper' => 'Status Metro/CPTM',
        'CrowdDensity' => 'Lotação (comunidade)',
        'AbacatePay'   => 'AbacatePay (pagamentos)',
        _              => source,
      };

  /// Formata DateTime como HH:mm:ss.
  static String _fmtTime(DateTime dt) {
    final l = dt.toLocal();
    final h  = l.hour.toString().padLeft(2, '0');
    final m  = l.minute.toString().padLeft(2, '0');
    final s  = l.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

// ── _GradientButton ──────────────────────────────────────────────────────────
class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GradientButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primary, AppTheme.accent],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: GoogleFonts.inter(color: AppTheme.textPrimDark, fontSize: 14, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ── _SocialButton ────────────────────────────────────────────────────────────
class _SocialButton extends StatelessWidget {
  final String label;
  final bool loading;
  final IconData icon;
  final VoidCallback onTap;
  const _SocialButton({required this.label, required this.loading, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return OutlinedButton.icon(
      onPressed: loading ? null : onTap,
      icon: loading
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(icon, size: 20),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
        foregroundColor: isDark ? AppTheme.textPrimDark : AppTheme.textPrimLight,
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ── _LogoIconPainter ─────────────────────────────────────────────────────────
class _LogoIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cyanPaint = Paint()..color = AppTheme.accent..style = PaintingStyle.fill;
    final bluePaint = Paint()..color = AppTheme.primary..style = PaintingStyle.fill;
    final cyanLine  = Paint()..color = AppTheme.accent..strokeWidth = 2.5..style = PaintingStyle.stroke;
    final blueLine  = Paint()..color = AppTheme.primary..strokeWidth = 2..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Horizontal rail: left node — line — right node
    canvas.drawCircle(Offset(cx - 16, cy), 5, cyanPaint);
    canvas.drawCircle(Offset(cx + 16, cy), 5, cyanPaint);
    canvas.drawLine(Offset(cx - 11, cy), Offset(cx + 11, cy), cyanLine);

    // Vertical branch: top node — line — center — line — bottom node
    canvas.drawCircle(Offset(cx, cy - 14), 4, bluePaint);
    canvas.drawLine(Offset(cx, cy - 10), Offset(cx, cy - 5), blueLine);
    canvas.drawCircle(Offset(cx, cy + 14), 4, bluePaint);
    canvas.drawLine(Offset(cx, cy + 5), Offset(cx, cy + 10), blueLine);
  }

  @override
  bool shouldRepaint(_LogoIconPainter old) => false;
}
