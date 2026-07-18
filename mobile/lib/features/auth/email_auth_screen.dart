import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/app_providers.dart';
import '../../core/widgets/app_theme.dart';

class EmailAuthScreen extends ConsumerStatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  ConsumerState<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends ConsumerState<EmailAuthScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isSignUp         = false;
  bool _loading          = false;
  bool _obscurePassword  = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      // Lazy Firebase init — only happens on first submit, not on screen open.
      if (Firebase.apps.isEmpty) {
        try {
          await Firebase.initializeApp();
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Login por e-mail não está disponível neste momento. '
                'Tente novamente mais tarde.',
              ),
            ),
          );
          return;
        }
      }

      final api        = ref.read(apiServiceProvider);
      final auth       = ref.read(authServiceProvider);
      final geofencing = ref.read(geofencingServiceProvider);

      UserCredential userCred;
      if (_isSignUp) {
        userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
      } else {
        userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
      }
      final idToken = await userCred.user!.getIdToken();
      await auth.loginWithFirebase(api, geofencing, idToken: idToken!);

      if (!mounted) return;
      context.go('/');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_mapFirebaseError(e.code))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mapFirebaseError(String code) => switch (code) {
    'user-not-found'       => 'Usuário não encontrado.',
    'wrong-password'       => 'Senha incorreta.',
    'email-already-in-use' => 'Este e-mail já possui uma conta.',
    'weak-password'        => 'A senha deve ter pelo menos 6 caracteres.',
    'invalid-email'        => 'E-mail inválido.',
    _                      => 'Erro de autenticação. Tente novamente.',
  };

  @override
  Widget build(BuildContext context) {
    final theme       = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: AppTheme.isDark(context) ? AppTheme.bgDark : AppTheme.bgLight,
      appBar: AppBar(
        title: Text(_isSignUp ? 'Criar conta' : 'Entrar com e-mail'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Text(
                  _isSignUp ? 'Crie sua conta' : 'Bem-vindo de volta',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isSignUp
                      ? 'Informe seu e-mail e crie uma senha'
                      : 'Informe seu e-mail e senha para continuar',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 32),

                // Email field
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Informe o e-mail';
                    if (!v.contains('@')) return 'E-mail inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password field
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Informe a senha';
                    if (_isSignUp && v.length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Submit button
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.textPrimDark,
                          ),
                        )
                      : Text(
                          _isSignUp ? 'Criar conta' : 'Entrar',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
                const SizedBox(height: 16),

                // Toggle sign-in / sign-up
                TextButton(
                  onPressed: () => setState(() => _isSignUp = !_isSignUp),
                  child: Text(
                    _isSignUp
                        ? 'Já tem uma conta? Entrar'
                        : 'Não tem conta? Criar conta',
                    style: TextStyle(color: colorScheme.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
