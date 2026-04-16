import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:audio_session/audio_session.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:any_link_preview/any_link_preview.dart';
import '../../core/models/message_model.dart';
import '../../core/e2ee/decrypted_media_cache.dart';
import '../../core/widgets/fullscreen_media_viewer.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;
  final bool showReadStatus;
  final bool showLinkPreview;
  final bool isConnected;
  final bool isGroup;
  final bool showSenderInfo;
  final MessageModel? replyToMessage;
  final VoidCallback? onReplyTap;
  final bool isHighlighted;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.showReadStatus = true,
    this.showLinkPreview = true,
    this.isConnected = true,
    this.isGroup = false,
    this.showSenderInfo = false,
    this.replyToMessage,
    this.onReplyTap,
    this.isHighlighted = false,
  });

  static const _senderColors = [
    Color(0xFF4CAF50), Color(0xFF2196F3), Color(0xFFFF9800),
    Color(0xFF9C27B0), Color(0xFFE91E63), Color(0xFF00BCD4),
    Color(0xFF795548), Color(0xFF607D8B), Color(0xFFFF5722),
    Color(0xFF3F51B5), Color(0xFF009688), Color(0xFFFFC107),
  ];

  static Color _senderColor(String senderId) {
    final hash = senderId.hashCode.abs();
    return _senderColors[hash % _senderColors.length];
  }

  static bool _hasUrl(String text) {
    final uriRegex = RegExp(r'https?://[^\s<>\[\]{}|\\^`"]+', caseSensitive: false);
    return uriRegex.hasMatch(text);
  }

  static bool _isRawCiphertext(String text) {
    if (text.length < 30) return false;
    if (text.contains(' ') || text.contains('\n')) return false;
    return RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(text);
  }

  static String? _extractFirstUrl(String text) {
    final uriRegex = RegExp(r'https?://[^\s<>\[\]{}|\\^`"]+', caseSensitive: false);
    return uriRegex.firstMatch(text)?.group(0);
  }

  bool get _isMediaOnly =>
      (message.isImage || message.isVideo) &&
      message.fileUrl != null &&
      (message.text == null || message.text!.isEmpty);

  Widget _buildTimeStatus(Color textColor, {bool overlay = false, bool isDark = false}) {
    final isPending = message.status == 'PENDING' || (message.id.isEmpty && !isConnected);
    String timeStr = '';
    try {
      timeStr = DateFormat.Hm().format(DateTime.parse(message.createdAt));
    } catch (_) {}

    final color = overlay ? Colors.white : textColor.withValues(alpha: 0.5);
    final Color checkColor;
    if (overlay) {
      checkColor = Colors.white;
    } else if (isDark && isMine) {
      checkColor = message.status == 'READ' ? Colors.white : Colors.white70;
    } else {
      checkColor = message.status == 'READ' ? const Color(0xFF4FC3F7) : textColor.withValues(alpha: 0.5);
    }

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.isEdited)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Text('ред.',
                style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: color)),
          ),
        Text(timeStr, style: TextStyle(fontSize: 11, color: color)),
        if (isMine && showReadStatus) ...[
          const SizedBox(width: 3),
          if (isPending)
            const _PendingClockIcon()
          else
            Icon(
              message.status == 'READ' ? Icons.done_all : Icons.done,
              size: 16,
              color: checkColor,
            ),
        ],
      ],
    );

    if (overlay) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: content,
      );
    }
    return content;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (message.isDeleted) {
      return Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: (isMine ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest)
                .withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            'Сообщение удалено',
            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade500, fontSize: 13),
          ),
        ),
      );
    }

    Color bgColor;
    if (isMine) {
      bgColor = isDark
          ? theme.colorScheme.primary.withValues(alpha: 0.85)
          : HSLColor.fromColor(theme.colorScheme.primary).withLightness(0.88).withSaturation(0.45).toColor();
    } else {
      bgColor = isDark
          ? theme.colorScheme.surfaceContainerHighest
          : const Color(0xFFFFFFFF);
    }
    if (isHighlighted) {
      bgColor = isMine ? theme.colorScheme.primary : theme.colorScheme.primaryContainer;
    }

    final textColor = isMine
        ? (isDark ? Colors.white : theme.colorScheme.onSurface)
        : theme.colorScheme.onSurface;

    final hasMedia = (message.isImage || message.isVideo) &&
        message.fileUrl != null &&
        (message.fileUrl!.startsWith('http://') || message.fileUrl!.startsWith('https://'));

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: EdgeInsets.only(
          top: 1, bottom: 1,
          left: isMine ? 48 : 8,
          right: isMine ? 8 : 48,
        ),
        decoration: BoxDecoration(
          color: _isMediaOnly ? Colors.transparent : bgColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: isMine ? const Radius.circular(18) : const Radius.circular(4),
            bottomRight: isMine ? const Radius.circular(4) : const Radius.circular(18),
          ),
          boxShadow: !isDark && !_isMediaOnly
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))]
              : null,
        ),
        clipBehavior: _isMediaOnly ? Clip.antiAlias : Clip.none,
        child: _isMediaOnly
            ? _buildMediaOnlyBubble(context, theme, isDark)
            : _buildContentBubble(context, theme, textColor, hasMedia, isDark),
      ),
    );
  }

  Widget _buildMediaOnlyBubble(BuildContext context, ThemeData theme, bool isDark) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: isMine ? const Radius.circular(18) : const Radius.circular(4),
            bottomRight: isMine ? const Radius.circular(4) : const Radius.circular(18),
          ),
          child: _buildMediaWidget(context),
        ),
        Positioned(
          right: 8, bottom: 8,
          child: _buildTimeStatus(Colors.white, overlay: true),
        ),
      ],
    );
  }

  Widget _buildContentBubble(BuildContext context, ThemeData theme, Color textColor, bool hasMedia, bool isDark) {
    return Padding(
      padding: hasMedia
          ? const EdgeInsets.only(bottom: 6)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isGroup && showSenderInfo && !isMine && message.senderName != null)
            Padding(
              padding: EdgeInsets.only(bottom: 2, left: hasMedia ? 12 : 0, top: hasMedia ? 6 : 0),
              child: Text(
                message.senderName!,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _senderColor(message.senderId)),
              ),
            ),
          if (message.forwardedFromId != null)
            Padding(
              padding: EdgeInsets.only(bottom: 4, left: hasMedia ? 12 : 0, right: hasMedia ? 12 : 0, top: hasMedia ? 6 : 0),
              child: _buildForwardHeader(textColor, theme),
            ),
          if (message.replyToId != null)
            Padding(
              padding: EdgeInsets.only(bottom: 4, left: hasMedia ? 12 : 0, right: hasMedia ? 12 : 0, top: hasMedia ? 6 : 0),
              child: _buildReplyHeader(textColor, theme),
            ),
          if (message.isPinned)
            Padding(
              padding: EdgeInsets.only(bottom: 2, left: hasMedia ? 12 : 0),
              child: Icon(CupertinoIcons.pin_fill, size: 12, color: textColor.withValues(alpha: 0.4)),
            ),
          if (hasMedia)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ClipRRect(
                borderRadius: message.text != null && message.text!.isNotEmpty
                    ? const BorderRadius.vertical(top: Radius.circular(18))
                    : BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: isMine ? const Radius.circular(18) : const Radius.circular(4),
                        bottomRight: isMine ? const Radius.circular(4) : const Radius.circular(18),
                      ),
                child: _buildMediaWidget(context),
              ),
            ),
          if (message.isVoiceMessage)
            _VoiceBubble(message: message, isMine: isMine, isGroup: isGroup),
          if (message.isFile && message.fileUrl != null && !message.isImage && !message.isVideo && !message.isVoiceMessage)
            Padding(
              padding: EdgeInsets.only(left: hasMedia ? 12 : 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: textColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(CupertinoIcons.doc, color: textColor, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: Text('Вложение', style: TextStyle(color: textColor, fontSize: 14))),
                ],
              ),
            ),
          if (message.text != null && message.text!.isNotEmpty)
            _buildTextWithTime(textColor, hasMedia, theme, isDark),
          if (message.text == null || message.text!.isEmpty)
            if (!message.isVoiceMessage)
              Padding(
                padding: EdgeInsets.only(top: 2, left: hasMedia ? 12 : 0),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: _buildTimeStatus(textColor, isDark: isDark),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildTextWithTime(Color textColor, bool hasMedia, ThemeData theme, bool isDark) {
    final isUndecrypted = message.encrypted && _isRawCiphertext(message.text!);
    final displayText = isUndecrypted ? '\u{1F512} Зашифрованное сообщение' : message.text!;

    return Padding(
      padding: EdgeInsets.only(top: hasMedia ? 0 : 0, left: hasMedia ? 12 : 0, right: hasMedia ? 12 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 0),
                child: RichText(
                  text: TextSpan(
                    text: displayText,
                    style: TextStyle(
                      color: isUndecrypted ? textColor.withValues(alpha: 0.6) : textColor,
                      fontSize: isUndecrypted ? 13 : 15,
                      fontStyle: isUndecrypted ? FontStyle.italic : FontStyle.normal,
                      height: 1.35,
                    ),
                    children: [
                      WidgetSpan(
                        child: SizedBox(width: _timeStatusWidth + 8),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 0, bottom: 0,
                child: _buildTimeStatus(textColor, isDark: isDark),
              ),
            ],
          ),
          if (!isUndecrypted && showLinkPreview && _hasUrl(message.text!))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _LinkPreviewWidget(
                url: _extractFirstUrl(message.text!)!,
                textColor: textColor,
                isMine: isMine,
              ),
            ),
        ],
      ),
    );
  }

  double get _timeStatusWidth {
    double w = 40; // time text
    if (message.isEdited) w += 25;
    if (isMine && showReadStatus) w += 20;
    return w;
  }

  Widget _buildForwardHeader(Color textColor, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4, right: 8),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: isMine ? textColor.withValues(alpha: 0.4) : theme.colorScheme.primary, width: 2)),
        color: (isMine ? textColor : theme.colorScheme.primary).withValues(alpha: 0.08),
        borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.arrowshape_turn_up_left, size: 12, color: textColor.withValues(alpha: 0.5)),
              const SizedBox(width: 4),
              Text('Переслано', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: textColor.withValues(alpha: 0.5))),
            ],
          ),
          Text(
            message.forwardedFromName ?? 'Пользователь',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isMine ? textColor.withValues(alpha: 0.7) : theme.colorScheme.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyHeader(Color textColor, ThemeData theme) {
    return GestureDetector(
      onTap: onReplyTap,
      child: Container(
        padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4, right: 8),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: isMine ? textColor.withValues(alpha: 0.4) : theme.colorScheme.primary, width: 2)),
          color: (isMine ? textColor : theme.colorScheme.primary).withValues(alpha: 0.08),
          borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              replyToMessage?.senderName ?? 'Сообщение',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isMine ? textColor.withValues(alpha: 0.7) : theme.colorScheme.primary),
            ),
            const SizedBox(height: 1),
            Text(
              replyToMessage?.text ?? (replyToMessage?.isVoiceMessage == true ? 'Голосовое сообщение' : (replyToMessage?.fileUrl != null ? 'Вложение' : '...')),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaWidget(BuildContext context) {
    if (message.isImage) {
      if (message.encrypted && message.encryptedFileKey != null) {
        return _EncryptedImageBubble(message: message, isMine: isMine, isGroup: isGroup);
      }
      return GestureDetector(
        onTap: () => FullscreenMediaViewer.showImage(context, url: message.fileUrl!),
        child: CachedNetworkImage(
          imageUrl: message.fileUrl!,
          fit: BoxFit.cover,
          width: double.infinity,
          placeholder: (_, _) => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          errorWidget: (_, _, _) => const SizedBox(height: 200, child: Center(child: Icon(CupertinoIcons.photo, size: 40))),
        ),
      );
    }
    if (message.isVideo) {
      return _VideoBubble(message: message, isMine: isMine, isGroup: isGroup);
    }
    return const SizedBox.shrink();
  }
}

class _PendingClockIcon extends StatefulWidget {
  const _PendingClockIcon();
  @override
  State<_PendingClockIcon> createState() => _PendingClockIconState();
}

class _PendingClockIconState extends State<_PendingClockIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, child) => Opacity(opacity: _animation.value, child: child),
      child: Icon(CupertinoIcons.clock, size: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
    );
  }
}

class _LinkPreviewWidget extends StatelessWidget {
  final String url;
  final Color textColor;
  final bool isMine;

  const _LinkPreviewWidget({required this.url, required this.textColor, required this.isMine});

  @override
  Widget build(BuildContext context) {
    if (!AnyLinkPreview.isValidLink(url)) return const SizedBox.shrink();
    return AnyLinkPreview(
      link: url,
      displayDirection: UIDirection.uiDirectionVertical,
      showMultimedia: true,
      bodyMaxLines: 2,
      bodyTextOverflow: TextOverflow.ellipsis,
      titleStyle: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13),
      bodyStyle: TextStyle(color: textColor.withValues(alpha: 0.8), fontSize: 12),
      cache: const Duration(hours: 24),
      backgroundColor: (isMine ? Colors.white : Colors.black).withValues(alpha: 0.1),
      borderRadius: 8,
      removeElevation: true,
      errorTitle: 'Ссылка',
      errorBody: 'Нажмите, чтобы открыть',
    );
  }
}

class _VoiceBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMine;
  final bool isGroup;
  const _VoiceBubble({required this.message, required this.isMine, this.isGroup = false});
  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble> {
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool _isPlaying = false;
  double _progress = 0;
  StreamSubscription? _progressSub;

  @override
  void initState() { super.initState(); _player.openPlayer(); }

  @override
  void dispose() { _progressSub?.cancel(); _player.closePlayer(); super.dispose(); }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.stopPlayer();
      _progressSub?.cancel();
      if (mounted) setState(() { _isPlaying = false; _progress = 0; });
      return;
    }

    final url = widget.message.fileUrl;
    if (url == null || url.isEmpty || (!url.startsWith('http://') && !url.startsWith('https://'))) return;

    setState(() { _isPlaying = true; _progress = 0; });

    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker | AVAudioSessionCategoryOptions.allowBluetooth,
      avAudioSessionMode: AVAudioSessionMode.spokenAudio,
      androidAudioAttributes: const AndroidAudioAttributes(contentType: AndroidAudioContentType.speech, usage: AndroidAudioUsage.voiceCommunication),
    ));
    await session.setActive(true);

    final totalMs = (widget.message.voiceDuration ?? 1) * 1000;
    _progressSub?.cancel();
    _progressSub = _player.onProgress?.listen((event) {
      if (mounted && totalMs > 0) setState(() => _progress = event.position.inMilliseconds / totalMs);
    });
    _player.setSubscriptionDuration(const Duration(milliseconds: 100));

    try {
      Uint8List bytes;
      final msg = widget.message;
      if (msg.encrypted && msg.encryptedFileKey != null) {
        final decrypted = await DecryptedMediaCache.getOrDecrypt(
          messageId: msg.id, clientMessageId: msg.clientMessageId, fileUrl: url,
          senderId: msg.senderId, encryptedFileKey: msg.encryptedFileKey, fileIv: msg.fileIv,
          isMine: widget.isMine, groupId: widget.isGroup ? msg.conversationId : null,
        );
        if (decrypted == null) throw Exception('Decryption failed');
        bytes = decrypted;
      } else {
        final dir = await getTemporaryDirectory();
        final ext = url.contains('.aac') ? '.aac' : '.m4a';
        final localPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}$ext';
        await Dio().download(url, localPath);
        final file = File(localPath);
        if (!file.existsSync()) throw Exception('File not found');
        bytes = await file.readAsBytes();
        try { file.deleteSync(); } catch (_) {}
      }

      await _player.startPlayer(
        fromDataBuffer: bytes, codec: Codec.aacADTS,
        whenFinished: () { if (mounted) setState(() { _isPlaying = false; _progress = 0; }); },
      );
    } catch (e) {
      if (mounted) {
        setState(() { _isPlaying = false; _progress = 0; });
        String msg = 'Не удалось воспроизвести голосовое';
        if (e is DioException && e.response?.statusCode == 404) msg = 'Файл не найден';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = widget.isMine
        ? (isDark ? Colors.white : theme.colorScheme.onSurface)
        : theme.colorScheme.onSurface;
    final accentColor = widget.isMine
        ? (isDark ? Colors.white : theme.colorScheme.primary)
        : theme.colorScheme.primary;
    final duration = widget.message.voiceDuration ?? 0;
    final mins = duration ~/ 60;
    final secs = duration % 60;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor,
            ),
            child: Icon(
              _isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
              color: widget.isMine && isDark ? theme.colorScheme.primary : Colors.white,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 28,
                child: CustomPaint(
                  size: const Size(160, 28),
                  painter: _WaveformPainter(
                    color: textColor.withValues(alpha: 0.25),
                    progress: _progress,
                    activeColor: accentColor,
                  ),
                ),
              ),
              Text(
                '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
                style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VideoBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMine;
  final bool isGroup;
  const _VideoBubble({required this.message, required this.isMine, this.isGroup = false});
  @override
  State<_VideoBubble> createState() => _VideoBubbleState();
}

class _VideoBubbleState extends State<_VideoBubble> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() { super.initState(); _initPlayer(); }

  Future<void> _initPlayer() async {
    final msg = widget.message;
    final url = msg.fileUrl;
    if (url == null || url.isEmpty || (!url.startsWith('http://') && !url.startsWith('https://'))) return;

    if (msg.encrypted && msg.encryptedFileKey != null) {
      final path = await DecryptedMediaCache.getOrDecryptToFile(
        messageId: msg.id, clientMessageId: msg.clientMessageId, fileUrl: url,
        senderId: msg.senderId, encryptedFileKey: msg.encryptedFileKey, fileIv: msg.fileIv,
        isMine: widget.isMine, extension: 'mp4', groupId: widget.isGroup ? msg.conversationId : null,
      );
      if (path == null) { if (mounted) setState(() => _hasError = true); return; }
      _controller = VideoPlayerController.file(File(path))..addListener(() { if (mounted) setState(() {}); });
    } else {
      _controller = VideoPlayerController.networkUrl(Uri.parse(url))..addListener(() { if (mounted) setState(() {}); });
    }

    try {
      await _controller!.initialize();
      if (mounted) setState(() => _initialized = true);
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() { _controller?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        height: 200,
        color: Colors.black12,
        child: const Center(child: Icon(CupertinoIcons.video_camera_solid, size: 48, color: Colors.grey)),
      );
    }
    if (!_initialized || _controller == null) {
      return Container(height: 200, color: Colors.black12, child: const Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }
    return GestureDetector(
      onTap: () => FullscreenMediaViewer.showVideo(context, _controller!),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(aspectRatio: _controller!.value.aspectRatio, child: VideoPlayer(_controller!)),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
            child: const Icon(CupertinoIcons.play_fill, color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final Color color;
  final double progress;
  final Color activeColor;

  _WaveformPainter({required this.color, this.progress = 0, Color? activeColor})
      : activeColor = activeColor ?? color;

  @override
  void paint(Canvas canvas, Size size) {
    final inactivePaint = Paint()..color = color..strokeWidth = 2.5..strokeCap = StrokeCap.round;
    final activePaint = Paint()..color = activeColor..strokeWidth = 2.5..strokeCap = StrokeCap.round;

    const barCount = 32;
    final barWidth = size.width / (barCount * 2);
    final progressX = size.width * progress;

    for (int i = 0; i < barCount; i++) {
      final x = i * barWidth * 2 + barWidth;
      final h = (size.height * 0.25) + (size.height * 0.75 * ((i * 7 + 3) % 11) / 11);
      final y1 = (size.height - h) / 2;
      canvas.drawLine(Offset(x, y1), Offset(x, y1 + h), x <= progressX ? activePaint : inactivePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) => old.progress != progress || old.color != color;
}

class _EncryptedImageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMine;
  final bool isGroup;
  const _EncryptedImageBubble({required this.message, required this.isMine, this.isGroup = false});
  @override
  State<_EncryptedImageBubble> createState() => _EncryptedImageBubbleState();
}

class _EncryptedImageBubbleState extends State<_EncryptedImageBubble> {
  Uint8List? _decryptedBytes;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() { super.initState(); _decrypt(); }

  Future<void> _decrypt() async {
    final msg = widget.message;
    final bytes = await DecryptedMediaCache.getOrDecrypt(
      messageId: msg.id, clientMessageId: msg.clientMessageId, fileUrl: msg.fileUrl!,
      senderId: msg.senderId, encryptedFileKey: msg.encryptedFileKey, fileIv: msg.fileIv,
      isMine: widget.isMine, groupId: widget.isGroup ? msg.conversationId : null,
    );
    if (mounted) setState(() { _decryptedBytes = bytes; _loading = false; _hasError = bytes == null; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    if (_hasError || _decryptedBytes == null) return const SizedBox(height: 200, child: Center(child: Icon(CupertinoIcons.photo, size: 40)));
    return GestureDetector(
      onTap: () => FullscreenMediaViewer.showImage(context, bytes: _decryptedBytes!),
      child: Image.memory(_decryptedBytes!, fit: BoxFit.cover, width: double.infinity),
    );
  }
}
