import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../core/storage/local_storage.dart';
import '../../core/theme/app_colors.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _rememberMe = LocalStorage.getRememberMe();
    if (_rememberMe) {
      final savedId = LocalStorage.getSavedUserId();
      if (savedId != null) _loginController.text = savedId;
    }
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final login = _loginController.text.trim();
    final password = _passwordController.text.trim();
    if (login.isEmpty || password.isEmpty) return;

    if (_rememberMe) {
      LocalStorage.setRememberMe(true);
      LocalStorage.setSavedUserId(login);
    } else {
      LocalStorage.setRememberMe(false);
      LocalStorage.setSavedUserId(null);
    }

    await ref.read(authStateProvider.notifier).login(login, password);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
                      const _HeroLetter(),
                      const SizedBox(height: 16),
                      const _BrandedTitle(),
                      const SizedBox(height: 24),
                      if (authState.error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              authState.error!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      TextField(
                        controller: _loginController,
                        keyboardType: TextInputType.text,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.username],
                        decoration: InputDecoration(
                          labelText: 'Логин',
                          hintText: 'Введите логин',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Пароль',
                          hintText: 'Ваш пароль',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onSubmitted: (_) => _login(),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: (v) => setState(() => _rememberMe = v ?? false),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _rememberMe = !_rememberMe),
                            child: const Text('Запомнить меня'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: authState.isLoading ? null : _login,
                          child: authState.isLoading
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    ),
                                    SizedBox(width: 12),
                                    Text('Вход...', style: TextStyle(fontSize: 16)),
                                  ],
                                )
                              : const Text(
                                  'Войти',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Нет аккаунта?'),
                          TextButton(
                            onPressed: () {
                              context.go('/onboarding');
                            },
                            child: const Text('Создать аккаунт'),
                          ),
                        ],
                      ),
                      const Spacer(flex: 1),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeroLetter extends StatelessWidget {
  const _HeroLetter();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: const [
            Color(0xFFFF6B6B),
            Color(0xFFE4AD3C),
            Color(0xFF28A745),
            Color(0xFF3B59FF),
            Color(0xFFFF6B6B),
          ],
          transform: const GradientRotation(-math.pi / 2),
        ),
      ),
      child: Center(
        child: Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).scaffoldBackgroundColor,
          ),
          child: Center(
            child: Text(
              'D',
              style: TextStyle(
                fontFamily: 'Magneto',
                fontSize: 60,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandedTitle extends StatelessWidget {
  const _BrandedTitle();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const style = TextStyle(
      fontFamily: 'Magneto',
      fontSize: 36,
      fontWeight: FontWeight.w700,
      letterSpacing: 1,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('D',
            style: style.copyWith(
                color: isDark ? Colors.white : Colors.black)),
        Text('e', style: style.copyWith(color: AppColors.brandE)),
        Text('m', style: style.copyWith(color: AppColors.brandM)),
        Text('o', style: style.copyWith(color: AppColors.brandO)),
        Text('s', style: style.copyWith(color: AppColors.brandS)),
      ],
    );
  }
}
