import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';

class ChatWallpaperInfo {
  final String id;
  final String nameKey;
  final String asset;

  const ChatWallpaperInfo(this.id, this.nameKey, this.asset);

  String get name => nameKey;

  static const List<ChatWallpaperInfo> all = [
    ChatWallpaperInfo('cosmos', 'cosmos', 'assets/images/chat_pattern_cosmos.png'),
    ChatWallpaperInfo('math', 'math', 'assets/images/chat_pattern_math.png'),
    ChatWallpaperInfo('starwars', 'starwars', 'assets/images/chat_pattern_starwars.png'),
    ChatWallpaperInfo('doodles', 'doodles', 'assets/images/chat_pattern_doodles.png'),
    ChatWallpaperInfo('none', 'none', ''),
  ];
}

class TelegramPatternBackground extends ConsumerWidget {
  final Widget child;

  const TelegramPatternBackground({super.key, required this.child});

  static Widget buildPattern(String wallpaperId, bool isDark) {
    if (wallpaperId == 'none') return const SizedBox.shrink();

    final wp = ChatWallpaperInfo.all.firstWhere(
      (w) => w.id == wallpaperId,
      orElse: () => ChatWallpaperInfo.all.firstWhere((w) => w.id == 'cosmos'),
    );

    if (wp.asset.isEmpty) return const SizedBox.shrink();

    Widget img = Image.asset(
      wp.asset,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );

    bool shouldInvert = !isDark;
    if (wallpaperId == 'cosmos') {
      shouldInvert = isDark;
    }

    if (shouldInvert) {
      img = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          -1, 0, 0, 0, 255,
          0, -1, 0, 0, 255,
          0, 0, -1, 0, 255,
          0, 0, 0, 0.7, 0,
        ]),
        child: img,
      );
    }

    double op = 0.5;
    if (wallpaperId == 'cosmos') {
      op = 0.15; // cosmos has a solid background, needs more transparency
    }

    return Opacity(
      opacity: op,
      child: img,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = theme.scaffoldBackgroundColor;
    final wallpaperId = ref.watch(wallpaperProvider);

    if (wallpaperId == 'none') {
      return Container(color: baseColor, child: child);
    }

    return Container(
      color: baseColor,
      child: Stack(
        children: [
          Positioned.fill(child: buildPattern(wallpaperId, isDark)),
          child,
        ],
      ),
    );
  }
}
