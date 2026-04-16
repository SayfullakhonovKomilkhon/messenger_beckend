import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/storage/local_storage.dart';
import '../../core/network/api_client.dart';
import '../../core/network/ws_client.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.settingsTitle),
        centerTitle: true,
      ),
      body: const SettingsBody(),
    );
  }
}

class SettingsBody extends ConsumerWidget {
  const SettingsBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final authState = ref.watch(authStateProvider);
    final user = authState.user;
    final theme = Theme.of(context);
    final themeState = ref.watch(themeProvider);
    final currentLocale = ref.watch(localeProvider);

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              GestureDetector(
                onTap: () => context.push('/settings/edit-profile'),
                child: Stack(
                  children: [
                    UserAvatar(
                      avatarUrl: user?.avatarUrl,
                      name: user?.name ?? '',
                      radius: 44,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.scaffoldBackgroundColor,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          CupertinoIcons.pencil,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => context.push('/settings/edit-profile'),
                child: Text(
                  user?.name ?? '',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              if (user?.publicId != null && user!.publicId!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'ID: ${user.publicId}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              if (user?.aiName != null && user!.aiName!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l.avatarNameLabel(user.aiName!),
                    style: TextStyle(
                      color: theme.colorScheme.primary.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (user?.bio != null && user!.bio!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 32, right: 32),
                  child: Text(
                    user.bio!,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      final pid = user?.publicId ?? user?.id ?? '';
                      Clipboard.setData(ClipboardData(text: pid));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l.idCopied)),
                      );
                    },
                    icon: const Icon(CupertinoIcons.doc_on_doc, size: 16),
                    label: Text(l.copyId),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      final pid = user?.publicId ?? user?.id ?? '';
                      SharePlus.instance.share(
                        ShareParams(text: l.myIdInDemos(pid)),
                      );
                    },
                    icon: const Icon(CupertinoIcons.share, size: 16),
                    label: Text(l.shareId),
                  ),
                ],
              ),
            ],
          ),
        ),

        SettingsGroup(children: [
          SettingsTile(
            icon: CupertinoIcons.person,
            title: l.editProfile,
            onTap: () => context.push('/settings/edit-profile'),
          ),
          SettingsTile(
            icon: CupertinoIcons.shield,
            title: l.privacy,
            onTap: () => context.push('/settings/privacy'),
          ),
          SettingsTile(
            icon: CupertinoIcons.bell,
            title: l.notifications,
            onTap: () => context.push('/settings/notifications'),
          ),
          SettingsTile(
            icon: CupertinoIcons.chat_bubble_2,
            title: l.conversations,
            onTap: () => context.push('/settings/conversations'),
          ),
          SettingsTile(
            icon: CupertinoIcons.mail,
            title: l.messageRequests,
            onTap: () => context.push('/settings/message-requests'),
          ),
          SettingsTile(
            icon: CupertinoIcons.bolt,
            title: l.myBots,
            onTap: () => context.push('/settings/bots'),
          ),
        ]),

        const SizedBox(height: 8),

        SettingsGroup(children: [
          SettingsTile(
            icon: CupertinoIcons.paintbrush,
            title: l.appearance,
            trailing: Text(
              _themeName(themeState.type, l),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
            onTap: () => context.push('/settings/appearance'),
          ),
          SettingsTile(
            icon: CupertinoIcons.globe,
            title: l.language,
            trailing: Text(
              currentLocale.languageCode == 'ru' ? l.languageRussian : l.languageEnglish,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
            onTap: () => _showLanguagePicker(context, ref),
          ),
          SettingsTile(
            icon: CupertinoIcons.lock,
            title: l.appLock,
            trailing: Switch(
              value: LocalStorage.getBlockApp(),
              onChanged: (_) => context.push('/settings/privacy'),
            ),
            onTap: () => context.push('/settings/privacy'),
          ),
        ]),

        const SizedBox(height: 8),

        SettingsGroup(children: [
          SettingsTile(
            icon: CupertinoIcons.question_circle,
            title: l.help,
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l.helpInDevelopment)),
            ),
          ),
          SettingsTile(
            icon: CupertinoIcons.person_badge_plus,
            title: l.inviteFriend,
            onTap: () {
              final login = user?.phone ?? user?.id ?? '';
              SharePlus.instance.share(ShareParams(
                text: l.inviteText(login),
              ));
            },
          ),
        ]),

        const SizedBox(height: 8),

        SettingsGroup(children: [
          SettingsTile(
            icon: CupertinoIcons.lock_rotation,
            title: l.regenerateKeys,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l.keysUpdated)),
              );
            },
          ),
          SettingsTile(
            icon: CupertinoIcons.square_arrow_right,
            title: l.logout,
            color: Colors.orange,
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l.logoutTitle),
                  content: Text(l.logoutConfirm),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(l.cancel),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(l.logout),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                WsClient().disconnect();
                await ref.read(authStateProvider.notifier).logout();
              }
            },
          ),
          SettingsTile(
            icon: CupertinoIcons.trash,
            title: l.clearAllData,
            color: Colors.red,
            onTap: () => _confirmDeleteAccount(context, ref, l),
          ),
        ]),

        const SizedBox(height: 24),
        Center(
          child: Text(
            l.appVersion,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  static String _themeName(AppThemeType type, AppLocalizations l) {
    switch (type) {
      case AppThemeType.light:
        return l.themeLight;
      case AppThemeType.dark:
        return l.themeDark;
    }
  }

  static void _showLanguagePicker(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final currentLocale = ref.read(localeProvider);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l.language,
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            ListTile(
              leading: const Text('🇷🇺', style: TextStyle(fontSize: 24)),
              title: const Text('Русский'),
              trailing: currentLocale.languageCode == 'ru'
                  ? Icon(CupertinoIcons.checkmark_alt, color: Theme.of(ctx).colorScheme.primary)
                  : null,
              onTap: () {
                ref.read(localeProvider.notifier).setLocale('ru');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Text('🇬🇧', style: TextStyle(fontSize: 24)),
              title: const Text('English'),
              trailing: currentLocale.languageCode == 'en'
                  ? Icon(CupertinoIcons.checkmark_alt, color: Theme.of(ctx).colorScheme.primary)
                  : null,
              onTap: () {
                ref.read(localeProvider.notifier).setLocale('en');
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static void _confirmDeleteAccount(BuildContext context, WidgetRef ref, AppLocalizations l) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.clearAllData),
        content: Text(l.clearAllDataConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiClient().dio.delete('/users/me');
              } catch (_) {}
              WsClient().disconnect();
              ref.read(authStateProvider.notifier).logout();
            },
            child: Text(l.delete),
          ),
        ],
      ),
    );
  }
}

class SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const SettingsGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Color? color;
  final Widget? trailing;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
    this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultIconColor = isDark ? Colors.white70 : const Color(0xFF333333);
    final defaultTextColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final trailColor = isDark ? Colors.white38 : const Color(0xFF999999);

    return ListTile(
      leading: Icon(icon, color: color ?? defaultIconColor),
      title: Text(title, style: TextStyle(color: color ?? defaultTextColor)),
      trailing: trailing ?? Icon(CupertinoIcons.chevron_right, size: 16, color: trailColor),
      onTap: onTap,
    );
  }
}
