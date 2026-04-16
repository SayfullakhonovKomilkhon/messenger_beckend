import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../l10n/app_localizations.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/models/user_model.dart';
import '../../core/models/message_model.dart';
import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import '../../core/constants.dart';
import '../../core/widgets/fullscreen_media_viewer.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  final String? conversationId;
  final String? participantName;
  final String? participantAvatar;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.conversationId,
    this.participantName,
    this.participantAvatar,
  });

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  UserModel? _user;
  bool _loading = true;
  bool _isBlocked = false;
  bool _isMuted = false;
  String? _conversationId;
  List<MessageModel> _mediaMessages = [];
  bool _mediaLoading = false;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    _load();
  }

  bool _isTrusted = false;

  Future<void> _load() async {
    try {
      final res = await ApiClient().dio.get('/users/${widget.userId}');
      final convState = ref.read(conversationsProvider);
      convState.whenData((convs) {
        final conv = convs
            .where((c) => c.participant?.id == widget.userId)
            .firstOrNull;
        if (conv != null) {
          _isTrusted = conv.isMutualTrust;
        }
      });
      setState(() {
        _user = UserModel.fromJson(res.data);
        _loading = false;
      });
      _checkBlocked();
      _findOrCreateConversation();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _checkBlocked() async {
    try {
      final res = await ApiClient().dio.get('/users/me/blocked');
      final blocked = (res.data as List).cast<Map<String, dynamic>>();
      setState(() {
        _isBlocked = blocked.any((b) => b['id'] == widget.userId);
      });
    } catch (e) {
      debugPrint('[Profile] Load error: $e');
    }
  }

  Future<void> _findOrCreateConversation() async {
    if (_conversationId != null) {
      _loadMuteState();
      _loadMedia();
      return;
    }
    final convState = ref.read(conversationsProvider);
    convState.whenData((convs) {
      final conv = convs
          .where((c) => c.participant?.id == widget.userId)
          .firstOrNull;
      if (conv != null && mounted) {
        setState(() {
          _conversationId = conv.id;
          _isMuted = conv.isMuted;
        });
        _loadMedia();
      }
    });
  }

  Future<void> _loadMuteState() async {
    if (_conversationId == null) return;
    final convState = ref.read(conversationsProvider);
    convState.whenData((convs) {
      final conv = convs
          .where((c) => c.id == _conversationId)
          .firstOrNull;
      if (conv != null && mounted) {
        setState(() => _isMuted = conv.isMuted);
      }
    });
  }

  Future<void> _loadMedia() async {
    if (_conversationId == null) return;
    setState(() => _mediaLoading = true);
    try {
      final res = await ApiClient().dio.get(
        '/conversations/$_conversationId/messages',
        queryParameters: {'limit': 100},
      );
      final list = (res.data as List)
          .map((e) => MessageModel.fromJson(e))
          .where((m) => m.isImage && m.fileUrl != null)
          .toList();
      if (mounted) {
        setState(() {
          _mediaMessages = list;
          _mediaLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _mediaLoading = false);
    }
  }

  Future<void> _toggleMute() async {
    if (_conversationId == null) return;
    try {
      await ApiClient().dio.patch(
        '/conversations/$_conversationId/mute',
        queryParameters: {'muted': !_isMuted},
      );
      ref.read(conversationsProvider.notifier).load();
      setState(() => _isMuted = !_isMuted);
    } catch (e) {
      debugPrint('[Profile] Mute toggle error: $e');
    }
  }

  String get _safeDisplayName {
    final l = AppLocalizations.of(context)!;
    final convState = ref.read(conversationsProvider);
    final conv = convState.whenOrNull(
      data: (convs) => convs
          .where((c) => c.participant?.id == widget.userId)
          .firstOrNull,
    );
    final trusted = conv?.isMutualTrust ?? _isTrusted;
    if (trusted) return _user?.name ?? l.userFallback;
    return conv?.displayName ?? widget.participantName ?? _user?.publicId ?? l.userFallback;
  }

  Future<void> _toggleBlock() async {
    final l = AppLocalizations.of(context)!;
    try {
      final wasBlocked = _isBlocked;
      if (_isBlocked) {
        await ApiClient().dio.delete('/users/${widget.userId}/block');
      } else {
        await ApiClient().dio.post('/users/${widget.userId}/block');
      }
      setState(() => _isBlocked = !_isBlocked);

      final notifier = ref.read(conversationsProvider.notifier);
      final userName = _safeDisplayName;

      if (!wasBlocked) {
        notifier.removeByParticipantId(widget.userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.userBlocked(userName))),
          );
          context.go('/');
        }
      } else {
        notifier.unblockParticipant(widget.userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.userUnblocked(userName))),
          );
        }
      }
    } catch (e) {
      debugPrint('[Profile] Block toggle error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.blockError)),
        );
      }
    }
  }

  Future<void> _startChat() async {
    try {
      final convState = ref.read(conversationsProvider);
      final existingConv = convState.whenOrNull(
        data: (convs) => convs
            .where((c) => c.participant?.id == widget.userId)
            .firstOrNull,
      );
      final trusted = existingConv?.isMutualTrust ?? false;
      final name = trusted
          ? (_user?.name ?? '')
          : (existingConv?.displayName ?? widget.participantName ?? _user?.publicId ?? '');
      final avatar = trusted ? _user?.avatarUrl : null;

      final res = await ApiClient().dio.post('/conversations', data: {
        'participantId': widget.userId,
      });
      final convId = res.data['id'] as String;
      if (mounted) {
        setState(() => _conversationId = convId);
        ref.read(conversationsProvider.notifier).load();
        final avatarParam = avatar != null && avatar.isNotEmpty
            ? '&avatar=${Uri.encodeComponent(avatar)}'
            : '';
        context.push(
          '/conversation/$convId?name=${Uri.encodeComponent(name)}'
          '&participantId=${widget.userId}'
          '$avatarParam',
        );
      }
    } catch (e) {
      debugPrint('[Profile] Start chat error: $e');
    }
  }

  void _showBlockDialog() {
    final l = AppLocalizations.of(context)!;
    final userName = _safeDisplayName;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.blockConfirmTitle(userName)),
        content: Text(l.blockConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _toggleBlock();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l.block),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(CupertinoIcons.back),
            onPressed: () => context.pop(),
          ),
          title: Text(l.info),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_user == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(CupertinoIcons.back),
            onPressed: () => context.pop(),
          ),
          title: Text(l.info),
          centerTitle: true,
        ),
        body: Center(child: Text(l.userNotFound)),
      );
    }

    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);

    final convState = ref.watch(conversationsProvider);
    final conv = convState.whenOrNull(
      data: (convs) => convs
          .where((c) => c.participant?.id == widget.userId)
          .firstOrNull,
    );
    final trusted = conv?.isMutualTrust ?? _isTrusted;
    final searchMethod = conv?.searchMethod;

    final String displayName = trusted
        ? (_user!.name ?? _user!.publicId ?? '')
        : (searchMethod == 'publicId'
            ? (_user!.publicId ?? '')
            : (searchMethod == 'aiName'
                ? (_user!.aiName ?? '')
                : (widget.participantName ?? _user!.publicId ?? '')));
    final displayAvatar = trusted ? (widget.participantAvatar ?? _user!.avatarUrl) : null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => context.pop(),
        ),
        title: Text(l.profileTitle),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.25),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: trusted
                      ? UserAvatar(
                          avatarUrl: displayAvatar,
                          name: displayName,
                          radius: 56,
                          isBot: _user?.isBot == true,
                        )
                      : CircleAvatar(
                          radius: 56,
                          backgroundColor: theme.colorScheme.primary.withAlpha(40),
                          child: Icon(CupertinoIcons.person, size: 48,
                              color: theme.colorScheme.primary),
                        ),
                ),
                const SizedBox(height: 16),
                Text(
                  displayName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: searchMethod == 'publicId' && !trusted ? 'monospace' : null,
                  ),
                ),
                if (!trusted) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withAlpha(60)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_outlined, size: 14, color: Colors.orange.shade700),
                        const SizedBox(width: 6),
                        Text(
                          l.trustNotConfirmed,
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                        ),
                      ],
                    ),
                  ),
                ],
                if (trusted && _user!.publicId != null && _user!.publicId!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _user!.publicId!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l.idCopied)),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.number, size: 12,
                              color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            _user!.publicId!,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (trusted && _user!.bio != null && _user!.bio!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _user!.bio!,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.lock, size: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                      const SizedBox(width: 4),
                      Text(
                        'E2EE',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action buttons
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: CupertinoIcons.chat_bubble,
                    label: l.writeMessage,
                    onTap: _startChat,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _ActionButton(
                    icon: CupertinoIcons.phone,
                    label: l.callAction,
                    onTap: () => context.push(
                      '/call?calleeId=${widget.userId}'
                      '&calleeName=${Uri.encodeComponent(displayName)}'
                      '&callType=AUDIO',
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _ActionButton(
                    icon: CupertinoIcons.video_camera,
                    label: l.videoCallAction,
                    onTap: () => context.push(
                      '/call?calleeId=${widget.userId}'
                      '&calleeName=${Uri.encodeComponent(displayName)}'
                      '&callType=VIDEO',
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _ActionButton(
                    icon: _isMuted ? CupertinoIcons.bell_slash : CupertinoIcons.bell,
                    label: _isMuted ? l.unmuteSound : l.muteSound,
                    onTap: _conversationId != null ? _toggleMute : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Media section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(CupertinoIcons.photo_on_rectangle, size: 20,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                    const SizedBox(width: 8),
                    Text(
                      l.mediaFiles,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (_mediaMessages.isNotEmpty)
                      GestureDetector(
                        onTap: _showAllMedia,
                        child: Text(
                          l.viewAll,
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _mediaLoading
                    ? const SizedBox(
                        height: 80,
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : _mediaMessages.isEmpty
                        ? SizedBox(
                            height: 80,
                            child: Center(
                              child: Text(
                                l.noMediaFiles,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                        : GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 4,
                              crossAxisSpacing: 4,
                              childAspectRatio: 1,
                            ),
                            itemCount: _mediaMessages.length > 9
                                ? 9
                                : _mediaMessages.length,
                            itemBuilder: (context, index) {
                              final msg = _mediaMessages[index];
                              final url = msg.fileUrl!;
                              if (!AppConstants.isValidImageUrl(url)) {
                                return _MediaPlaceholder();
                              }
                              return GestureDetector(
                                onTap: () => _showImageFullscreen(url),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: url,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: theme.colorScheme.surfaceContainerHighest,
                                      child: const Center(
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => _MediaPlaceholder(),
                                  ),
                                ),
                              );
                            },
                          ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Block button
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: Icon(
                _isBlocked ? CupertinoIcons.lock_open : CupertinoIcons.hand_raised,
                color: _isBlocked ? Colors.green : Colors.red.withValues(alpha: 0.8),
                size: 22,
              ),
              title: Text(
                _isBlocked ? l.unblockUser : l.blockUser,
                style: TextStyle(
                  color: _isBlocked ? Colors.green : Colors.red.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
              onTap: _isBlocked ? _toggleBlock : _showBlockDialog,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showImageFullscreen(String url) {
    FullscreenMediaViewer.showImage(context, url: url);
  }

  void _showAllMedia() {
    final l = AppLocalizations.of(context)!;
    if (_mediaMessages.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: AppBar(
            title: Text(l.allMedia),
            leading: IconButton(
              icon: const Icon(CupertinoIcons.back),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
          body: GridView.builder(
            padding: const EdgeInsets.all(4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            itemCount: _mediaMessages.length,
            itemBuilder: (context, index) {
              final msg = _mediaMessages[index];
              final url = msg.fileUrl!;
              if (!AppConstants.isValidImageUrl(url)) {
                return _MediaPlaceholder();
              }
              return GestureDetector(
                onTap: () => _showImageFullscreen(url),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (context, url, error) => _MediaPlaceholder(),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;
    final iconColor = enabled
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.3);
    final textColor = enabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface.withValues(alpha: 0.3);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: textColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? trailing;
  final IconData? trailingIcon;
  final VoidCallback? onTap;

  const _SettingsTile({
    this.icon,
    required this.title,
    this.trailing,
    this.trailingIcon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: icon != null ? Icon(icon, size: 22) : null,
      title: Text(title, style: const TextStyle(fontSize: 16)),
      trailing: trailingIcon != null
          ? Icon(trailingIcon, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))
          : (trailing != null
              ? Text(
                  trailing!,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                )
              : null),
      onTap: onTap,
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Icon(
        CupertinoIcons.photo,
        size: 32,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
      ),
    );
  }
}
