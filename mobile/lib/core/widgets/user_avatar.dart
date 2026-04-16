import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants.dart';

/// Аватар пользователя — квадрат с закруглёнными углами.
/// При ошибке загрузки показывает инициалы.
class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final double radius;
  final bool isBot;

  const UserAvatar({
    super.key,
    this.avatarUrl,
    required this.name,
    this.radius = 24,
    this.isBot = false,
  });

  String get _initial => name.isNotEmpty ? name[0].toUpperCase() : '?';

  /// Радиус скругления углов (пропорционально размеру)
  double get _cornerRadius => radius * 0.4;

  @override
  Widget build(BuildContext context) {
    Widget avatar;
    if (avatarUrl == null ||
        avatarUrl!.isEmpty ||
        !AppConstants.isValidImageUrl(avatarUrl)) {
      avatar = _buildPlaceholder(context);
    } else {
      avatar = ClipRRect(
        borderRadius: BorderRadius.circular(_cornerRadius),
        child: CachedNetworkImage(
          imageUrl: avatarUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorWidget: (context, url, error) => _buildPlaceholder(context),
          placeholder: (context, url) => SizedBox(
            width: radius * 2,
            height: radius * 2,
            child: Center(
              child: SizedBox(
                width: radius,
                height: radius,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ),
      );
    }

    if (!isBot) return avatar;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          top: -2,
          right: -2,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: radius * 0.12, vertical: 1),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(radius * 0.15),
              border: Border.all(
                color: Theme.of(context).scaffoldBackgroundColor,
                width: 1.5,
              ),
            ),
            child: Icon(Icons.smart_toy, size: radius * 0.45, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 1.0),
        borderRadius: BorderRadius.circular(_cornerRadius),
      ),
      child: Center(
        child: Text(
          _initial,
          style: TextStyle(
            fontSize: radius * 0.6,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
