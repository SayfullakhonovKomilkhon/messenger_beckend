import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final h = constraints.maxHeight;
            final logoSize = h < 640 ? 120.0 : 160.0;
            final topSpacing = h < 640 ? 16.0 : 32.0;
            final afterTitleSpacing = h < 640 ? 24.0 : 40.0;
            final betweenFeatures = h < 640 ? 20.0 : 28.0;
            final beforeButtons = h < 640 ? 24.0 : 40.0;
            final betweenButtons = h < 640 ? 12.0 : 16.0;
            final bottomSpacing = h < 640 ? 16.0 : 24.0;

            return SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: h),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: topSpacing),

                      // Logo
                      Image.asset(
                        'assets/images/apk_logo.png',
                        height: logoSize,
                        width: logoSize,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 16),

                      // Title — градиент под цвет логотипа
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF3B59FF), Color(0xFF8B9FFF)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ).createShader(bounds),
                        child: Text(
                          '2p2 мессенджер со сквозным шифрованием',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            letterSpacing: 0.2,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      SizedBox(height: afterTitleSpacing),

                      // Features
                      _FeatureItem(
                        icon: Icons.shield_outlined,
                        title: 'Номер телефона не требуется',
                        subtitle: 'Аккаунт без личных данных',
                        iconBackgroundColor: isDark
                            ? Colors.blue.withValues(alpha: 0.1)
                            : const Color(0xFFF2F3F7),
                        iconColor: const Color(0xFF3B59FF),
                      ),
                      SizedBox(height: betweenFeatures),
                      _FeatureItem(
                        icon: Icons.lock_outline,
                        title: 'Сквозное шифрование',
                        subtitle: 'Ваши сообщения конфиденциальны',
                        iconBackgroundColor: isDark
                            ? Colors.blue.withValues(alpha: 0.1)
                            : const Color(0xFFF2F3F7),
                        iconColor: const Color(0xFF3B59FF),
                      ),
                      SizedBox(height: betweenFeatures),
                      _FeatureItem(
                        icon: Icons.public,
                        title: 'Децентрализованная сеть',
                        subtitle: 'Никаких центральных серверов',
                        iconBackgroundColor: isDark
                            ? Colors.blue.withValues(alpha: 0.1)
                            : const Color(0xFFF2F3F7),
                        iconColor: const Color(0xFF3B59FF),
                      ),

                      SizedBox(height: beforeButtons),

                      // Кнопка создать аккаунт
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: () async {
                            final url = Uri.parse('https://google.com');
                            if (await canLaunchUrl(url)) {
                              await launchUrl(
                                  url, mode: LaunchMode.externalApplication);
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF8B9FFF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Создать аккаунт',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: betweenButtons),

                      // Кнопка входа
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: () => context.go('/login'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF8B9FFF),
                            side: const BorderSide(
                                color: Color(0xFF8B9FFF), width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'У меня есть аккаунт',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: bottomSpacing),
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

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconBackgroundColor;
  final Color iconColor;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconBackgroundColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconBackgroundColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color
                      ?.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
