import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/gradient_button.dart';
import '../data/auth_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authRepository = AuthRepository();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _setBusy(bool busy) {
    setState(() {
      _isLoading = busy;
      if (busy) {
        _errorMessage = null;
        _infoMessage = null;
      }
    });
  }

  Future<void> _runAuthAction(Future<void> Function() action) async {
    _setBusy(true);
    try {
      await action();
    } on AuthFailure catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    _setBusy(true);
    try {
      if (_isSignUp) {
        final needsConfirmation = await _authRepository.signUpWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
          _nameController.text.trim(),
        );
        if (needsConfirmation && mounted) {
          setState(() => _infoMessage =
              'Conta criada! Confirme pelo link que enviamos para o seu email.');
        }
      } else {
        await _authRepository.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
      }
    } on AuthFailure catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      setState(() => _errorMessage = 'Digite seu email para receber o link de recuperação.');
      return;
    }
    await _runAuthAction(() async {
      await _authRepository.sendPasswordReset(email);
      if (mounted) {
        setState(() => _infoMessage =
            'Se existir uma conta com esse email, enviamos um link de recuperação.');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.75),
            radius: 1.1,
            colors: [Color(0xFF221545), AppTheme.background],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset(
                        'assets/branding/avora_logo_transparent.png',
                        height: 132,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Nosso diário de filmes',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.onSurfaceMuted,
                          fontSize: 15,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 30),
                      _ModeToggle(
                        isSignUp: _isSignUp,
                        onChanged: (value) => setState(() {
                          _isSignUp = value;
                          _errorMessage = null;
                          _infoMessage = null;
                        }),
                      ),
                      const SizedBox(height: 22),
                      if (_isSignUp) ...[
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          maxLength: 60,
                          decoration: const InputDecoration(
                            labelText: 'Nome',
                            counterText: '',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) {
                            final name = v?.trim() ?? '';
                            if (name.isEmpty) return 'Informe seu nome';
                            if (name.length < 2) return 'Nome muito curto';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        maxLength: 254,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          counterText: '',
                          prefixIcon: Icon(Icons.alternate_email),
                        ),
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        maxLength: 72,
                        autofillHints: [
                          _isSignUp ? AutofillHints.newPassword : AutofillHints.password,
                        ],
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          counterText: '',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: _validatePassword,
                      ),
                      if (!_isSignUp)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _isLoading ? null : _forgotPassword,
                            child: const Text('Esqueci minha senha'),
                          ),
                        ),
                      if (_errorMessage != null)
                        _Banner(
                          message: _errorMessage!,
                          icon: Icons.error_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      if (_infoMessage != null)
                        _Banner(
                          message: _infoMessage!,
                          icon: Icons.mark_email_unread_outlined,
                          color: AppTheme.brandTeal,
                        ),
                      const SizedBox(height: 18),
                      GradientButton(
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_isSignUp ? 'Criar conta' : 'Entrar'),
                      ),
                      const SizedBox(height: 24),
                      const _OrDivider(),
                      const SizedBox(height: 18),
                      _SocialButton(
                        label: 'Continuar com Google',
                        icon: Icons.g_mobiledata_rounded,
                        onPressed: _isLoading
                            ? null
                            : () => _runAuthAction(_authRepository.signInWithGoogle),
                      ),
                      const SizedBox(height: 10),
                      _SocialButton(
                        label: 'Continuar com Apple',
                        icon: Icons.apple,
                        onPressed: _isLoading
                            ? null
                            : () => _runAuthAction(_authRepository.signInWithApple),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Seus grupos e avaliações ficam privados, visíveis '
                        'só para quem você convidar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.onSurfaceMuted,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Informe seu email';
    if (email.length > 254) return 'Email muito longo';
    final pattern = RegExp(r'^[\w.!#$%&’*+/=?^`{|}~-]+@[\w-]+(\.[\w-]+)+$');
    if (!pattern.hasMatch(email)) return 'Email inválido';
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Informe sua senha';
    // Only enforce the full policy on sign-up: existing accounts may predate
    // it, and blocking them at login would lock them out of their own data.
    if (!_isSignUp) return null;

    if (password.length < 8) return 'Use ao menos 8 caracteres';
    if (password.length > 72) return 'Senha muito longa';
    if (!password.contains(RegExp(r'[a-z]'))) return 'Inclua uma letra minúscula';
    if (!password.contains(RegExp(r'[A-Z]'))) return 'Inclua uma letra maiúscula';
    if (!password.contains(RegExp(r'\d'))) return 'Inclua um número';
    return null;
  }
}

class _ModeToggle extends StatelessWidget {
  final bool isSignUp;
  final ValueChanged<bool> onChanged;

  const _ModeToggle({required this.isSignUp, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          _segment('Entrar', !isSignUp, () => onChanged(false)),
          _segment('Criar conta', isSignUp, () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _segment(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected ? AppTheme.primaryGradient : null,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppTheme.onSurfaceMuted,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _SocialButton({required this.label, required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.onSurface,
          side: const BorderSide(color: Color(0xFF2E2E3C)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: Color(0xFF2A2A36))),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'ou',
            style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 13),
          ),
        ),
        Expanded(child: Divider(color: Color(0xFF2A2A36))),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color color;

  const _Banner({required this.message, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
