import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/telegram_pattern_background.dart';
import '../../l10n/app_localizations.dart';

class AppearanceSettingsScreen extends ConsumerStatefulWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  ConsumerState<AppearanceSettingsScreen> createState() =>
      _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState
    extends ConsumerState<AppearanceSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final themeState = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.appearance)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.theme, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.1,
            children: AppThemeType.values.map((type) {
              final isSelected = themeState.type == type;
              return _ThemePreviewCard(
                themeType: type,
                label: type == AppThemeType.light ? l.themeLight : l.themeDark,
                isSelected: isSelected,
                onTap: () => themeNotifier.setTheme(type),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          Text(l.accentColor, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              AppColors.accentColors.length,
              (i) => GestureDetector(
                onTap: () => themeNotifier.setAccent(i),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accentColors[i],
                    shape: BoxShape.circle,
                    border: themeState.accentIndex == i
                        ? Border.all(color: Colors.white, width: 2)
                        : null,
                  ),
                  child: themeState.accentIndex == i
                      ? const Icon(Icons.check, color: Colors.white, size: 22)
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          Text(l.chatWallpaper, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          _WallpaperGrid(),
          const SizedBox(height: 24),

          Text(l.systemTheme, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(CupertinoIcons.device_phone_portrait),
            title: Text(l.followSystem),
            trailing: Switch(
              value: themeState.followSystemTheme,
              onChanged: (v) => themeNotifier.setFollowSystemTheme(v),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemePreviewData {
  final Color bg;
  final Color sentBubble;
  final Color sentText;
  final Color receivedBubble;
  final Color receivedText;

  const _ThemePreviewData({
    required this.bg,
    required this.sentBubble,
    required this.sentText,
    required this.receivedBubble,
    required this.receivedText,
  });
}

class _ThemePreviewCard extends StatelessWidget {
  final AppThemeType themeType;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemePreviewCard({
    required this.themeType,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  static const _previewData = {
    AppThemeType.light: _ThemePreviewData(
      bg: Color(0xFFf6f7fb),
      sentBubble: Color(0xFF7c8cff),
      sentText: Colors.white,
      receivedBubble: Color(0xFFFFFFFF),
      receivedText: Color(0xFF1f2242),
    ),
    AppThemeType.dark: _ThemePreviewData(
      bg: Color(0xFF1A1A2E),
      sentBubble: Color(0xFF31F196),
      sentText: Colors.black,
      receivedBubble: Color(0xFF2E3142),
      receivedText: Colors.white,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final data = _previewData[themeType]!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: data.bg,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
              : Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _MessageBubble(
                        text: 'Привет!',
                        bg: data.receivedBubble,
                        textColor: data.receivedText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _MessageBubble(
                        text: 'Как дела?',
                        bg: data.receivedBubble,
                        textColor: data.receivedText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _MessageBubble(
                        text: 'Все отлично!',
                        bg: data.sentBubble,
                        textColor: data.sentText,
                        isSent: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: data.receivedText,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final Color bg;
  final Color textColor;
  final bool isSent;

  const _MessageBubble({
    required this.text,
    required this.bg,
    required this.textColor,
    this.isSent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isSent ? 16 : 4),
          bottomRight: Radius.circular(isSent ? 4 : 16),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: textColor),
      ),
    );
  }
}

class _WallpaperGrid extends ConsumerWidget {
  static String _wallpaperName(String key, AppLocalizations l) {
    switch (key) {
      case 'starwars': return l.wallpaperStarwars;
      case 'doodles': return l.wallpaperDoodles;
      case 'math': return l.wallpaperMath;
      case 'cosmos': return l.wallpaperCosmos;
      case 'none': return l.wallpaperNone;
      default: return key;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final current = ref.watch(wallpaperProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.75,
      ),
      itemCount: ChatWallpaperInfo.all.length,
      itemBuilder: (context, index) {
        final wp = ChatWallpaperInfo.all[index];
        final isSelected = current == wp.id;

        return GestureDetector(
          onTap: () => ref.read(wallpaperProvider.notifier).set(wp.id),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned.fill(
                  child: _WallpaperPreviewTile(wallpaperId: wp.id),
                ),
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
                      ),
                    ),
                    child: Text(
                      _wallpaperName(wp.nameKey, l),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                if (isSelected)
                  Positioned(
                    top: 6, right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 12),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WallpaperPreviewTile extends StatelessWidget {
  final String wallpaperId;
  const _WallpaperPreviewTile({required this.wallpaperId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF0F0F0);

    if (wallpaperId == 'none') {
      return Container(color: bgColor);
    }

    return Container(
      color: bgColor,
      child: TelegramPatternBackground.buildPattern(wallpaperId, isDark),
    );
  }
}
