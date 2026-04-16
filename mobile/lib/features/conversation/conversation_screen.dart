import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:audio_session/audio_session.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/providers.dart';
import '../../core/storage/local_storage.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/telegram_pattern_background.dart';
import '../../core/models/message_model.dart';
import '../../core/network/api_client.dart';
import '../../core/network/ws_client.dart';
import '../../core/e2ee/key_manager.dart';
import '../../core/e2ee/crypto_service.dart';
import '../../core/e2ee/group_key_manager.dart';
import '../../core/e2ee/encryption_info_sheet.dart';
import '../../core/e2ee/decrypted_media_cache.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart' show CiphertextMessage;
import '../../l10n/app_localizations.dart';
import 'message_bubble.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String participantName;
  final String? participantAvatar;
  final String participantId;
  final bool isGroup;

  const ConversationScreen({
    super.key,
    required this.conversationId,
    required this.participantName,
    this.participantAvatar,
    this.participantId = '',
    this.isGroup = false,
  });

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _uuid = const Uuid();

  String _getSenderName(String senderId) {
    final conv = ref.read(conversationsProvider).whenOrNull(
          data: (convs) => convs
              .where((c) => c.id == widget.conversationId)
              .firstOrNull,
        );
    if (conv?.groupInfo != null) {
      final member = conv!.groupInfo!.members
          .where((m) => m.userId == senderId)
          .firstOrNull;
      if (member != null) return member.name;
    }
    return widget.participantName;
  }
  MessageModel? _replyTo;
  String? _highlightedMessageId;

  String get _liveName {
    final conv = ref.read(conversationsProvider).whenOrNull(
          data: (convs) => convs
              .where((c) => c.id == widget.conversationId)
              .firstOrNull,
        );
    if (conv != null) return conv.displayName;
    return widget.participantName;
  }

  String? get _liveAvatar {
    final conv = ref.read(conversationsProvider).whenOrNull(
          data: (convs) => convs
              .where((c) => c.id == widget.conversationId)
              .firstOrNull,
        );
    if (conv != null) return conv.displayAvatar;
    return widget.participantAvatar;
  }

  void _scrollToMessage(String messageId, List<MessageModel> messages) {
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    setState(() => _highlightedMessageId = messageId);

    final itemHeight = 60.0;
    final offset = index * itemHeight;
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _highlightedMessageId = null);
    });
  }

  bool _isSearching = false;
  final _searchMsgController = TextEditingController();
  String _searchMsgQuery = '';
  bool _hasText = false;
  bool _participantTyping = false;
  String? _typingUserId;
  Timer? _typingTimer;
  bool _notificationsMuted = false;
  Timer? _draftSaveTimer;

  // Voice recording
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  String? _recordPath;

  static List<String> _localizedMonths(AppLocalizations l) => [
    l.monthJanuary, l.monthFebruary, l.monthMarch, l.monthApril,
    l.monthMay, l.monthJune, l.monthJuly, l.monthAugust,
    l.monthSeptember, l.monthOctober, l.monthNovember, l.monthDecember,
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _textController.addListener(_onTextChanged);
    _initRecorder();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(messagesProvider(widget.conversationId).notifier).load();
      if (!mounted) return;

      // Ждём E2EE инициализации до 5 секунд (избегаем race condition)
      if (!E2eeKeyManager().isInitialized) {
        for (int i = 0; i < 25 && !E2eeKeyManager().isInitialized; i++) {
          await Future.delayed(const Duration(milliseconds: 200));
          if (!mounted) return;
        }
      }

      if (widget.isGroup && E2eeKeyManager().isInitialized) {
        await _initGroupE2ee();
      }
      await _decryptLoadedMessages();
      _subscribeToMessages();
      _loadMuteState();
      await _markAsRead();
      _loadDraft();
    });
  }

  Future<void> _initRecorder() async {
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker |
          AVAudioSessionCategoryOptions.allowBluetooth,
      avAudioSessionMode: AVAudioSessionMode.spokenAudio,
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        usage: AndroidAudioUsage.voiceCommunication,
      ),
    ));
    await _recorder.openRecorder();
  }

  Future<void> _initGroupE2ee() async {
    final userId = ref.read(authStateProvider).user?.id ?? '';
    if (userId.isEmpty) return;
    final gkm = GroupKeyManager();
    await gkm.processPendingKeys(groupId: widget.conversationId);
    final memberIds = _getGroupMemberIds();
    if (memberIds.isNotEmpty) {
      final hasKey = await gkm.hasSenderKey(widget.conversationId, userId);
      if (!hasKey) {
        await gkm.distributeKeys(widget.conversationId, userId, memberIds);
      }
    }
  }

  List<String> _getGroupMemberIds() {
    final conv = ref.read(conversationsProvider).whenOrNull(
          data: (convs) =>
              convs.where((c) => c.id == widget.conversationId).firstOrNull,
        );
    if (conv?.groupInfo != null) {
      return conv!.groupInfo!.members.map((m) => m.userId).toList();
    }
    return [];
  }

  Future<void> _markAsRead() async {
    try {
      await ApiClient().dio.post('/conversations/${widget.conversationId}/read');
      ref.read(conversationsProvider.notifier).markRead(widget.conversationId);

      // Отправляем chat.read только если включены отчёты о прочтении
      final settings = await ref.read(userSettingsProvider.future);
      final privacy = settings['privacy'];
      final readReceipts = privacy is Map ? (privacy['readReceipts'] ?? true) : true;
      if (readReceipts == true) {
        final messages = ref.read(messagesProvider(widget.conversationId)).valueOrNull;
        if (messages != null && messages.isNotEmpty) {
          WsClient().send('/app/chat.read', body: jsonEncode({
            'conversationId': widget.conversationId,
            'messageId': messages.first.id,
          }));
        }
      }
    } catch (_) {}
  }

  void _loadMuteState() {
    final convState = ref.read(conversationsProvider);
    convState.whenData((conversations) {
      final conv = conversations
          .where((c) => c.id == widget.conversationId)
          .firstOrNull;
      if (conv != null && mounted) {
        setState(() => _notificationsMuted = conv.isMuted);
      }
    });
  }

  void _onTextChanged() {
    final hasText = _textController.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
    if (hasText) _notifyTypingIfEnabled();
    _scheduleDraftSave();
  }

  void _loadDraft() {
    final draft = LocalStorage.getDraft(widget.conversationId);
    if (draft != null && draft.isNotEmpty && _textController.text.isEmpty) {
      _textController.text = draft;
      setState(() => _hasText = true);
    }
  }

  void _scheduleDraftSave() {
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(milliseconds: 500), () {
      final text = _textController.text.trim();
      if (text.isNotEmpty && WsClient().isConnected) {
        LocalStorage.setDraft(widget.conversationId, text);
      } else if (text.isEmpty) {
        LocalStorage.setDraft(widget.conversationId, null);
      }
    });
  }

  void _clearDraft() {
    _draftSaveTimer?.cancel();
    LocalStorage.setDraft(widget.conversationId, null);
  }

  Future<void> _subscribeToMessages() async {
    final userId = ref.read(authStateProvider).user?.id;
    if (userId == null) return;

    final ws = WsClient();
    await ws.connect(); // Гарантируем подключение — иначе подписки не получают события
    if (!mounted) return;

    ws.subscribe('/user/$userId/queue/typing', (frame) {
      if (!mounted) return;
      if (frame.body == null) return;
      final data = jsonDecode(frame.body!);
      if (data is Map<String, dynamic>) {
        _handleTypingEvent(data);
      }
    });

    ws.subscribe('/user/$userId/queue/messages', (frame) {
      if (!mounted) return;
      if (frame.body == null) return;
      final data = jsonDecode(frame.body!);
      if (data is Map<String, dynamic>) {
        final type = data['type'] as String?;
        if (type == 'message_edited') {
          _handleMessageEdited(data);
        } else if (type == 'message_deleted') {
          _handleMessageDeleted(data);
        } else if (type == 'message_pinned' || type == 'message_unpinned') {
          if (mounted) ref.read(messagesProvider(widget.conversationId).notifier).load();
        } else if (type == 'trust_updated') {
          ref.read(conversationsProvider.notifier).load();
        } else if (type == 'sender_key_rotation_needed' &&
            data['conversationId'] == widget.conversationId) {
          _handleSenderKeyRotation(data);
        } else if (type == 'group_member_added' &&
            data['conversationId'] == widget.conversationId) {
          _handleGroupMemberAdded(data);
        } else if (data.containsKey('clientMessageId') &&
            data['conversationId'] == widget.conversationId) {
          var msg = MessageModel.fromJson(data);
          final myUserId = ref.read(authStateProvider).user?.id ?? '';
          if (msg.encrypted && msg.senderId == myUserId) {
            // Own encrypted message echoed back — preserve the original plaintext
            final cachedText = LocalStorage.getCachedPlaintext(msg.clientMessageId);
            if (cachedText != null) {
              if (msg.id.isNotEmpty) {
                LocalStorage.cacheDecryptedMessage(msg.id, cachedText);
              }
              LocalStorage.cacheConversationPreview(widget.conversationId, cachedText);
              msg = MessageModel(
                id: msg.id,
                conversationId: msg.conversationId,
                senderId: msg.senderId,
                senderName: msg.senderName,
                senderAvatar: msg.senderAvatar,
                text: cachedText,
                fileUrl: msg.fileUrl,
                mimeType: msg.mimeType,
                clientMessageId: msg.clientMessageId,
                status: msg.status,
                createdAt: msg.createdAt,
                isVoiceMessage: msg.isVoiceMessage,
                voiceDuration: msg.voiceDuration,
                voiceWaveform: msg.voiceWaveform,
                replyToId: msg.replyToId,
                forwardedFromId: msg.forwardedFromId,
                forwardedFromName: msg.forwardedFromName,
                isPinned: msg.isPinned,
                isEdited: msg.isEdited,
                isDeleted: msg.isDeleted,
                editedAt: msg.editedAt,
                encrypted: msg.encrypted,
                encryptedFileKey: msg.encryptedFileKey,
                fileIv: msg.fileIv,
              );
            }
            if (mounted) {
              ref.read(messagesProvider(widget.conversationId).notifier).addMessage(msg);
            }
          } else if (msg.encrypted && msg.senderId != myUserId) {
            _decryptAndAddMessage(msg);
          } else if (mounted) {
            ref.read(messagesProvider(widget.conversationId).notifier).addMessage(msg);
            _markAsRead();
          }
        }
      }
    });

    // Subscribe to status updates (DELIVERED, READ)
    ws.subscribe('/user/$userId/queue/status', (frame) {
      if (!mounted) return;
      if (frame.body == null) return;
      final data = jsonDecode(frame.body!);
      if (data is Map<String, dynamic>) {
        final messageId = data['messageId'] as String?;
        final type = data['type'] as String?;
        final status = data['status'] as String? ?? type; // backend шлёт type: "READ", не status
        final convId = data['conversationId'] as String?;
        if (messageId != null && status != null && convId == widget.conversationId && mounted) {
          final messages = ref.read(messagesProvider(widget.conversationId)).valueOrNull ?? [];
          final msgIdx = messages.indexWhere((m) => m.id == messageId);
          if (msgIdx >= 0) {
            final msg = messages[msgIdx];
            final updated = MessageModel(
              id: msg.id,
              conversationId: msg.conversationId,
              senderId: msg.senderId,
              text: msg.text,
              fileUrl: msg.fileUrl,
              mimeType: msg.mimeType,
              clientMessageId: msg.clientMessageId,
              status: status,
              createdAt: msg.createdAt,
              isVoiceMessage: msg.isVoiceMessage,
              voiceDuration: msg.voiceDuration,
              voiceWaveform: msg.voiceWaveform,
              replyToId: msg.replyToId,
              forwardedFromId: msg.forwardedFromId,
              isPinned: msg.isPinned,
              isEdited: msg.isEdited,
              isDeleted: msg.isDeleted,
              editedAt: msg.editedAt,
              encrypted: msg.encrypted,
              encryptedFileKey: msg.encryptedFileKey,
              fileIv: msg.fileIv,
            );
            ref
                .read(messagesProvider(widget.conversationId).notifier)
                .updateMessage(messageId, updated);
          }
        }
      }
    });
  }

  Future<void> _decryptLoadedMessages({int retryCount = 0}) async {
    // Если E2EE ещё не готов — отложить и повторить (макс 3 попытки)
    if (!E2eeKeyManager().isInitialized) {
      if (retryCount < 3 && mounted) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _decryptLoadedMessages(retryCount: retryCount + 1);
        });
      }
      return;
    }

    final messages = ref.read(messagesProvider(widget.conversationId)).valueOrNull;
    if (messages == null) return;

    final userId = ref.read(authStateProvider).user?.id ?? '';
    bool changed = false;
    final updated = <MessageModel>[];

    // Сортируем по дате (oldest first) — Signal Protocol stateful,
    // PreKey-сообщение должно расшифроваться раньше Whisper-сообщений
    final sortedMessages = [...messages]..sort((a, b) {
        try {
          return DateTime.parse(a.createdAt).compareTo(DateTime.parse(b.createdAt));
        } catch (_) {
          return 0;
        }
      });

    for (final msg in sortedMessages) {
      if (!msg.encrypted || msg.text == null || msg.text!.isEmpty) {
        updated.add(msg);
        continue;
      }

      // 1) Check local cache first (works for both sent and received messages)
      String? resolvedText;
      if (msg.id.isNotEmpty) {
        resolvedText = LocalStorage.getDecryptedMessage(msg.id);
      }
      resolvedText ??= LocalStorage.getCachedPlaintext(msg.clientMessageId);

      if (resolvedText == null && msg.senderId != userId) {
        final crypto = E2eeCryptoService();
        if (widget.isGroup) {
          try {
            final cipherBytes = base64Decode(msg.text!);
            resolvedText = await crypto.decryptGroupMessage(
              widget.conversationId, msg.senderId, Uint8List.fromList(cipherBytes),
            );
          } catch (_) {}
        } else {
          resolvedText = await crypto.decryptMessage(msg.senderId, msg.text!, CiphertextMessage.prekeyType);
          resolvedText ??= await crypto.decryptMessage(msg.senderId, msg.text!, CiphertextMessage.whisperType);
        }
        if (resolvedText != null && msg.id.isNotEmpty) {
          LocalStorage.cacheDecryptedMessage(msg.id, resolvedText);
          LocalStorage.cacheConversationPreview(widget.conversationId, resolvedText);
        }
      }

      if (resolvedText != null) {
        updated.add(MessageModel(
          id: msg.id,
          conversationId: msg.conversationId,
          senderId: msg.senderId,
          senderName: msg.senderName,
          senderAvatar: msg.senderAvatar,
          text: resolvedText,
          fileUrl: msg.fileUrl,
          mimeType: msg.mimeType,
          clientMessageId: msg.clientMessageId,
          status: msg.status,
          createdAt: msg.createdAt,
          isVoiceMessage: msg.isVoiceMessage,
          voiceDuration: msg.voiceDuration,
          voiceWaveform: msg.voiceWaveform,
          replyToId: msg.replyToId,
          forwardedFromId: msg.forwardedFromId,
          forwardedFromName: msg.forwardedFromName,
          isPinned: msg.isPinned,
          isEdited: msg.isEdited,
          isDeleted: msg.isDeleted,
          editedAt: msg.editedAt,
          encrypted: msg.encrypted,
          encryptedFileKey: msg.encryptedFileKey,
          fileIv: msg.fileIv,
        ));
        changed = true;
      } else {
        updated.add(msg);
      }
    }

    if (changed && mounted) {
      for (final msg in updated) {
        if (msg.id.isNotEmpty) {
          final original = messages.where((m) => m.id == msg.id).firstOrNull;
          if (original != null && original.text != msg.text) {
            ref.read(messagesProvider(widget.conversationId).notifier).updateMessage(msg.id, msg);
          }
        }
      }
    }
  }

  Future<void> _decryptAndAddMessage(MessageModel msg) async {
    if (!msg.encrypted || msg.text == null || msg.text!.isEmpty) {
      if (mounted) {
        ref.read(messagesProvider(widget.conversationId).notifier).addMessage(msg);
        _markAsRead();
      }
      return;
    }

    String? decryptedText;

    // 1) Check cache first
    if (msg.id.isNotEmpty) {
      decryptedText = LocalStorage.getDecryptedMessage(msg.id);
    }
    decryptedText ??= LocalStorage.getCachedPlaintext(msg.clientMessageId);

    if (decryptedText == null && E2eeKeyManager().isInitialized) {
      final crypto = E2eeCryptoService();
      if (widget.isGroup) {
        try {
          final cipherBytes = base64Decode(msg.text!);
          decryptedText = await crypto.decryptGroupMessage(
            widget.conversationId, msg.senderId, Uint8List.fromList(cipherBytes),
          );
        } catch (_) {}
      } else {
        decryptedText = await crypto.decryptMessage(
          msg.senderId,
          msg.text!,
          CiphertextMessage.prekeyType,
        );
        decryptedText ??= await crypto.decryptMessage(
          msg.senderId,
          msg.text!,
          CiphertextMessage.whisperType,
        );
      }
      if (decryptedText != null && msg.id.isNotEmpty) {
        LocalStorage.cacheDecryptedMessage(msg.id, decryptedText);
        LocalStorage.cacheConversationPreview(widget.conversationId, decryptedText);
      }
    }

    final decryptedMsg = MessageModel(
      id: msg.id,
      conversationId: msg.conversationId,
      senderId: msg.senderId,
      senderName: msg.senderName,
      senderAvatar: msg.senderAvatar,
      text: decryptedText ?? msg.text!,
      fileUrl: msg.fileUrl,
      mimeType: msg.mimeType,
      clientMessageId: msg.clientMessageId,
      status: msg.status,
      createdAt: msg.createdAt,
      isVoiceMessage: msg.isVoiceMessage,
      voiceDuration: msg.voiceDuration,
      voiceWaveform: msg.voiceWaveform,
      replyToId: msg.replyToId,
      forwardedFromId: msg.forwardedFromId,
      forwardedFromName: msg.forwardedFromName,
      isPinned: msg.isPinned,
      isEdited: msg.isEdited,
      isDeleted: msg.isDeleted,
      editedAt: msg.editedAt,
      encrypted: msg.encrypted,
      encryptedFileKey: msg.encryptedFileKey,
      fileIv: msg.fileIv,
    );

    if (mounted) {
      ref.read(messagesProvider(widget.conversationId).notifier).addMessage(decryptedMsg);
      _markAsRead();
    }
  }

  void _handleTypingEvent(Map<String, dynamic> data) {
    if (!mounted) return;
    if (data['conversationId'] != widget.conversationId) return;
    final typingUser = data['userId'] as String?;
    if (typingUser == ref.read(authStateProvider).user?.id) return;
    setState(() {
      _participantTyping = true;
      _typingUserId = typingUser;
    });
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() {
        _participantTyping = false;
        _typingUserId = null;
      });
    });
  }

  void _notifyTypingIfEnabled() {
    ref.read(userSettingsProvider.future).then((settings) {
      final privacy = settings['privacy'];
      final typingIndicators = privacy is Map ? (privacy['typingIndicators'] ?? true) : true;
      if (typingIndicators == true) _notifyTyping(true);
    });
  }

  void _handleMessageEdited(Map<String, dynamic> data) {
    if (!mounted) return;
    if (data['conversationId'] != widget.conversationId) return;
    ref.read(messagesProvider(widget.conversationId).notifier).load();
  }

  void _handleMessageDeleted(Map<String, dynamic> data) {
    if (!mounted) return;
    if (data['conversationId'] != widget.conversationId) return;
    final msgId = data['messageId'] as String;
    ref
        .read(messagesProvider(widget.conversationId).notifier)
        .removeMessage(msgId);
  }

  Future<void> _handleSenderKeyRotation(Map<String, dynamic> data) async {
    if (!widget.isGroup || !E2eeKeyManager().isInitialized) return;
    final userId = ref.read(authStateProvider).user?.id ?? '';
    final memberIds = _getGroupMemberIds();
    await GroupKeyManager().rotateKeys(widget.conversationId, userId, memberIds);
  }

  Future<void> _handleGroupMemberAdded(Map<String, dynamic> data) async {
    if (!widget.isGroup || !E2eeKeyManager().isInitialized) return;
    final userId = ref.read(authStateProvider).user?.id ?? '';
    final memberIds = _getGroupMemberIds();
    final newMemberId = data['newMemberId'] as String?;
    if (newMemberId != null && !memberIds.contains(newMemberId)) {
      memberIds.add(newMemberId);
    }
    await GroupKeyManager().distributeKeys(widget.conversationId, userId, memberIds);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(messagesProvider(widget.conversationId).notifier).loadMore();
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _clearDraft();

    final clientMsgId = _uuid.v4();
    final replyToId = _replyTo?.id;
    _textController.clear();
    setState(() => _replyTo = null);

    final userId = ref.read(authStateProvider).user?.id ?? '';

    String wireText = text;
    bool isEncrypted = false;
    if (widget.isGroup && E2eeKeyManager().isInitialized) {
      final crypto = E2eeCryptoService();
      final encrypted = await crypto.encryptGroupMessage(
          widget.conversationId, userId, text);
      if (encrypted != null) {
        wireText = base64Encode(encrypted);
        isEncrypted = true;
        LocalStorage.cacheEncryptedPlaintext(clientMsgId, text);
        LocalStorage.cacheConversationPreview(widget.conversationId, text);
      }
    } else if (!widget.isGroup && widget.participantId.isNotEmpty && E2eeKeyManager().isInitialized) {
      final result = await E2eeCryptoService().encryptMessage(widget.participantId, text);
      if (result != null) {
        wireText = result.ciphertextBase64;
        isEncrypted = true;
        LocalStorage.cacheEncryptedPlaintext(clientMsgId, text);
        LocalStorage.cacheConversationPreview(widget.conversationId, text);
      }
    }

    final body = <String, dynamic>{
      'conversationId': widget.conversationId,
      'text': wireText,
      'clientMessageId': clientMsgId,
      if (replyToId != null) 'replyToId': replyToId,
      if (isEncrypted) 'encrypted': true,
    };

    final optimisticMsg = MessageModel(
      id: '',
      conversationId: widget.conversationId,
      senderId: userId,
      text: text,
      fileUrl: null,
      mimeType: null,
      clientMessageId: clientMsgId,
      status: 'PENDING',
      createdAt: DateTime.now().toIso8601String(),
      isVoiceMessage: false,
      voiceDuration: null,
      voiceWaveform: null,
      replyToId: replyToId,
      forwardedFromId: null,
      isPinned: false,
      isEdited: false,
      isDeleted: false,
      editedAt: null,
      encrypted: isEncrypted,
    );
    ref.read(messagesProvider(widget.conversationId).notifier).addMessage(optimisticMsg);
    ref.read(conversationsProvider.notifier).addOrUpdateFromMessage(optimisticMsg);

    await WsClient().send('/app/chat.send', body: jsonEncode(body));

    if (!mounted) return;
    if (!WsClient().isConnected) {
      await LocalStorage.addPendingMessage({
        'conversationId': widget.conversationId,
        'text': wireText,
        'clientMessageId': clientMsgId,
        if (replyToId != null && replyToId.isNotEmpty) 'replyToId': replyToId,
        if (isEncrypted) 'encrypted': true,
      });
    }
    _notifyTyping(false);
  }

  void _notifyTyping([bool typing = true]) {
    if (!typing) return;
    WsClient().send(
      '/app/chat.typing',
      body: jsonEncode({'conversationId': widget.conversationId}),
    );
  }

  void _showAttachMenu() {
    final l = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final ic = isDark ? Colors.white70 : const Color(0xFF333333);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(CupertinoIcons.photo, color: ic),
                title: Text(l.photo),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndSendMedia(isVideo: false);
                },
              ),
              ListTile(
                leading: Icon(CupertinoIcons.videocam, color: ic),
                title: Text(l.video),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndSendMedia(isVideo: true);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndSendMedia({required bool isVideo}) async {
    final picker = ImagePicker();
    final xFile = isVideo
        ? await picker.pickVideo(source: ImageSource.gallery)
        : await picker.pickImage(source: ImageSource.gallery);
    if (xFile == null) return;

    final clientMsgId = _uuid.v4();
    final defaultName = isVideo ? 'video.mp4' : 'image.jpg';
    try {
      final api = ApiClient().dio;

      final fileBytes = await xFile.readAsBytes();
      final filename = xFile.name.isNotEmpty ? xFile.name : defaultName;

      Uint8List uploadBytes = Uint8List.fromList(fileBytes);
      bool isEncrypted = false;
      String? encryptedFileKeyBase64;
      String? fileIvBase64;

      final shouldEncrypt = E2eeKeyManager().isInitialized &&
          (widget.isGroup || widget.participantId.isNotEmpty);

      if (shouldEncrypt) {
        final crypto = E2eeCryptoService();
        final encResult = await crypto.encryptFile(uploadBytes);
        uploadBytes = encResult.encryptedBytes;
        fileIvBase64 = base64Encode(encResult.iv);

        if (widget.isGroup) {
          final userId = ref.read(authStateProvider).user?.id ?? '';
          encryptedFileKeyBase64 = await crypto.encryptGroupFileKey(
            widget.conversationId, userId, encResult.aesKey,
          );
        } else {
          encryptedFileKeyBase64 = await crypto.encryptFileKey(
            widget.participantId, encResult.aesKey,
          );
        }
        if (encryptedFileKeyBase64 != null) {
          isEncrypted = true;
          LocalStorage.cacheDecryptedMessage(
            'filekey_$clientMsgId', base64Encode(encResult.aesKey),
          );
        }
      }

      final multipartFile = MultipartFile.fromBytes(
        uploadBytes,
        filename: filename,
      );

      final formData = FormData.fromMap({'file': multipartFile});
      final uploadRes = await api.post('/files/upload', data: formData);
      final data = uploadRes.data is Map ? uploadRes.data as Map : null;
      final fileUrl = (data?['url'] ?? data?['fileUrl'] ?? '').toString();
      final mimeType = data?['mimeType'] as String?;

      if (fileUrl.isEmpty) {
        if (mounted) {
          final l = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.fileUploadError)),
          );
        }
        return;
      }

      final originalMime = isVideo ? 'video/mp4' : 'image/jpeg';
      final mime = isEncrypted ? originalMime : (mimeType ?? originalMime);

      final userId = ref.read(authStateProvider).user?.id ?? '';
      final optimisticMsg = MessageModel(
        id: '',
        conversationId: widget.conversationId,
        senderId: userId,
        text: null,
        fileUrl: fileUrl,
        mimeType: mime,
        clientMessageId: clientMsgId,
        status: 'PENDING',
        createdAt: DateTime.now().toIso8601String(),
        isVoiceMessage: false,
        voiceDuration: null,
        voiceWaveform: null,
        replyToId: null,
        forwardedFromId: null,
        isPinned: false,
        isEdited: false,
        isDeleted: false,
        editedAt: null,
        encrypted: isEncrypted,
        encryptedFileKey: encryptedFileKeyBase64,
        fileIv: fileIvBase64,
      );

      if (isEncrypted) {
        DecryptedMediaCache.cacheBytes(clientMsgId, fileBytes);
      }

      ref.read(messagesProvider(widget.conversationId).notifier).addMessage(optimisticMsg);
      ref.read(conversationsProvider.notifier).addOrUpdateFromMessage(optimisticMsg);

      final wsBody = <String, dynamic>{
        'conversationId': widget.conversationId,
        'fileUrl': fileUrl,
        'mimeType': mime,
        'clientMessageId': clientMsgId,
      };
      if (isEncrypted) {
        wsBody['encrypted'] = true;
        wsBody['encryptedFileKey'] = encryptedFileKeyBase64;
        wsBody['fileIv'] = fileIvBase64;
      }
      await WsClient().send('/app/chat.send', body: jsonEncode(wsBody));
    } catch (e, stack) {
      debugPrint('[MEDIA] upload error: $e\n$stack');
      if (mounted) {
        ref.read(messagesProvider(widget.conversationId).notifier).removeByClientId(clientMsgId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: ${e.toString().split('\n').first}')),
        );
      }
    }
  }

  // ── Date divider helpers ──────────────────────────────────────────────

  String _formatDateLabel(DateTime date) {
    final l = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(date.year, date.month, date.day);

    if (messageDay == today) return l.today;
    if (messageDay == today.subtract(const Duration(days: 1))) return l.yesterday;
    return '${date.day} ${_localizedMonths(l)[date.month - 1]} ${date.year}';
  }

  bool _shouldShowDateDivider(List<MessageModel> messages, int index) {
    if (index == messages.length - 1) return true;
    try {
      final current = DateTime.parse(messages[index].createdAt);
      final next = DateTime.parse(messages[index + 1].createdAt);
      return current.year != next.year ||
          current.month != next.month ||
          current.day != next.day;
    } catch (_) {
      return false;
    }
  }

  // ── Context menu ──────────────────────────────────────────────────────

  void _showMessageContextMenu(MessageModel msg) {
    final userId = ref.read(authStateProvider).user?.id;
    final isMine = msg.senderId == userId;
    final l = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      builder: (sheetCtx) {
        final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
        final ic = isDark ? Colors.white70 : const Color(0xFF333333);
        return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(CupertinoIcons.arrowshape_turn_up_left, color: ic),
              title: Text(l.reply),
              onTap: () {
                Navigator.pop(sheetCtx);
                setState(() => _replyTo = msg);
              },
            ),
            if (msg.text != null)
              ListTile(
                leading: Icon(CupertinoIcons.doc_on_doc, color: ic),
                title: Text(l.copyText),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  Clipboard.setData(ClipboardData(text: msg.text!));
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(l.copied),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ListTile(
              leading: Icon(CupertinoIcons.arrowshape_turn_up_right, color: ic),
              title: Text(l.forward),
              onTap: () {
                Navigator.pop(sheetCtx);
                _forwardMessage(msg);
              },
            ),
            ListTile(
              leading: Icon(
                msg.isPinned ? CupertinoIcons.pin_slash : CupertinoIcons.pin,
                color: ic,
              ),
              title: Text(msg.isPinned ? l.unpin : l.pin),
              onTap: () {
                Navigator.pop(sheetCtx);
                final dest =
                    msg.isPinned ? '/app/chat.unpin' : '/app/chat.pin';
                WsClient()
                    .send(dest, body: jsonEncode({'messageId': msg.id}));
              },
            ),
            if (isMine) ...[
              ListTile(
                leading: Icon(CupertinoIcons.pencil, color: ic),
                title: Text(l.edit),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _editMessage(msg);
                },
              ),
              ListTile(
                leading: const Icon(CupertinoIcons.trash, color: Colors.red),
                title: Text(l.deleteMsg,
                    style: const TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  WsClient().send('/app/chat.delete',
                      body: jsonEncode({'messageId': msg.id}));
                },
              ),
            ],
          ],
        ),
      );
      },
    );
  }

  // ── Edit ───────────────────────────────────────────────────────────────

  void _editMessage(MessageModel msg) {
    final l = AppLocalizations.of(context)!;
    final editController = TextEditingController(text: msg.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.editMessage),
        content: TextField(
          controller: editController,
          autofocus: true,
          maxLines: null,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () {
              final newText = editController.text.trim();
              if (newText.isNotEmpty && newText != msg.text) {
                WsClient().send('/app/chat.edit',
                    body: jsonEncode({'messageId': msg.id, 'text': newText}));
              }
              Navigator.pop(ctx);
            },
            child: Text(l.save),
          ),
        ],
      ),
    );
  }

  // ── Forward (bottom sheet with multi-select) ──────────────────────────

  void _forwardMessage(MessageModel msg) {
    final l = AppLocalizations.of(context)!;
    final convState = ref.read(conversationsProvider);
    convState.whenData((conversations) {
      final selected = <String>{};

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (ctx, scrollCtrl) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.forwardMessage,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(CupertinoIcons.xmark, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollCtrl,
                      itemCount: conversations.length,
                      itemBuilder: (_, i) {
                        final c = conversations[i];
                        final isSelected = selected.contains(c.id);
                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (val) {
                            setSheetState(() {
                              if (val == true) {
                                selected.add(c.id);
                              } else {
                                selected.remove(c.id);
                              }
                            });
                          },
                          secondary: UserAvatar(
                            avatarUrl: c.displayAvatar,
                            name: c.displayName,
                            radius: 24,
                          ),
                          title: Text(c.displayName),
                        );
                      },
                    ),
                  ),
                  if (selected.isNotEmpty) ...[
                    const Divider(height: 1),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Text(
                              l.selectedCount(selected.length),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const Spacer(),
                            FilledButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                WsClient().send(
                                  '/app/chat.forward',
                                  body: jsonEncode({
                                    'messageId': msg.id,
                                    'toConversationIds': selected.toList(),
                                  }),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l.messageForwarded),
                                  ),
                                );
                              },
                              child: Text(l.forward),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      );
    });
  }

  // ── Chat menu actions ─────────────────────────────────────────────────

  Future<void> _updateTrust(String status) async {
    try {
      await ApiClient().dio.patch(
        '/conversations/${widget.conversationId}/trust',
        queryParameters: {'status': status},
      );
      ref.read(conversationsProvider.notifier).load();
    } catch (_) {}
  }

  void _toggleNotifications() {
    setState(() => _notificationsMuted = !_notificationsMuted);
    final dest = _notificationsMuted
        ? '/app/conversation.mute'
        : '/app/conversation.unmute';
    WsClient().send(
      dest,
      body: jsonEncode({'conversationId': widget.conversationId}),
    );
  }

  void _showEncryptionInfo() {
    final userId = ref.read(authStateProvider).user?.id ?? '';
    if (widget.isGroup) {
      _showGroupEncryptionInfo();
    } else {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => EncryptionInfoSheet(
          localUserId: userId,
          remoteUserId: widget.participantId,
          remoteName: _liveName,
        ),
      );
    }
  }

  void _showGroupEncryptionInfo() {
    final l = AppLocalizations.of(context)!;
    final memberCount = _getGroupMemberIds().length;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Icon(CupertinoIcons.lock_shield_fill, size: 48, color: Colors.greenAccent.shade400),
              const SizedBox(height: 16),
              Text(
                l.groupE2eeTitle,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                l.groupE2eeDescription,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.person_2, color: Colors.greenAccent.shade400),
                    const SizedBox(width: 12),
                    Text(
                      l.membersWithE2ee(memberCount),
                      style: TextStyle(color: Colors.greenAccent.shade400),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmClearHistory() {
    final l = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.clearHistoryTitle),
        content: Text(l.clearHistoryConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ApiClient()
                  .dio
                  .delete(
                      '/conversations/${widget.conversationId}/messages')
                  .then((_) {
                ref
                    .read(messagesProvider(widget.conversationId).notifier)
                    .load();
              }).catchError((_) {});
            },
            child: Text(l.clear),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteChat() {
    final l = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteChatTitle),
        content: Text(l.deleteChatConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              ApiClient()
                  .dio
                  .delete('/conversations/${widget.conversationId}')
                  .then((_) {
                ref.read(conversationsProvider.notifier).load();
                if (mounted) context.go('/');
              }).catchError((_) {});
            },
            child: Text(l.delete),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _draftSaveTimer?.cancel();
    final text = _textController.text.trim();
    if (text.isNotEmpty && WsClient().isConnected) {
      LocalStorage.setDraft(widget.conversationId, text);
    } else if (text.isEmpty) {
      LocalStorage.setDraft(widget.conversationId, null);
    }
    _textController.dispose();
    _scrollController.dispose();
    _searchMsgController.dispose();
    _typingTimer?.cancel();
    _recordTimer?.cancel();
    _recorder.closeRecorder();
    super.dispose();
  }

  // ── Voice recording ──────────────────────────────────────────────────

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.micPermissionError)),
        );
      }
      return;
    }
    final dir = await getTemporaryDirectory();
    _recordPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac';
    await _recorder.startRecorder(
      toFile: _recordPath,
      codec: Codec.aacADTS,
      sampleRate: 44100,
      numChannels: 1,
      bitRate: 128000,
    );
    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordSeconds++);
    });
  }

  Future<void> _stopAndSendVoice() async {
    _recordTimer?.cancel();
    await _recorder.stopRecorder();
    if (!mounted) return;
    final recordSeconds = _recordSeconds;
    setState(() => _isRecording = false);

    final path = _recordPath;
    if (path == null) return;

    final file = File(path);
    if (!file.existsSync()) return;

    final clientMsgId = _uuid.v4();
    try {
      final voiceBytes = await file.readAsBytes();

      Uint8List uploadBytes = Uint8List.fromList(voiceBytes);
      bool isEncrypted = false;
      String? encryptedFileKeyBase64;
      String? fileIvBase64;

      final shouldEncrypt = E2eeKeyManager().isInitialized &&
          (widget.isGroup || widget.participantId.isNotEmpty);

      if (shouldEncrypt) {
        final crypto = E2eeCryptoService();
        final encResult = await crypto.encryptFile(uploadBytes);
        uploadBytes = encResult.encryptedBytes;
        fileIvBase64 = base64Encode(encResult.iv);

        if (widget.isGroup) {
          final usrId = ref.read(authStateProvider).user?.id ?? '';
          encryptedFileKeyBase64 = await crypto.encryptGroupFileKey(
            widget.conversationId, usrId, encResult.aesKey,
          );
        } else {
          encryptedFileKeyBase64 = await crypto.encryptFileKey(
            widget.participantId, encResult.aesKey,
          );
        }
        if (encryptedFileKeyBase64 != null) {
          isEncrypted = true;
          LocalStorage.cacheDecryptedMessage(
            'filekey_$clientMsgId', base64Encode(encResult.aesKey),
          );
        }
      }

      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(uploadBytes, filename: 'voice.aac'),
      });
      final uploadRes = await ApiClient().dio.post('/files/upload', data: formData);
      final data = uploadRes.data is Map ? uploadRes.data as Map : null;
      final fileUrl = (data?['url'] ?? data?['fileUrl'] ?? '').toString();
      if (fileUrl.isEmpty) {
        if (mounted) {
          final l = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.voiceUploadError)),
          );
        }
        return;
      }

      final userId = ref.read(authStateProvider).user?.id ?? '';
      final optimisticMsg = MessageModel(
        id: '',
        conversationId: widget.conversationId,
        senderId: userId,
        text: null,
        fileUrl: fileUrl,
        mimeType: 'audio/aac',
        clientMessageId: clientMsgId,
        status: 'PENDING',
        createdAt: DateTime.now().toIso8601String(),
        isVoiceMessage: true,
        voiceDuration: recordSeconds,
        voiceWaveform: null,
        replyToId: null,
        forwardedFromId: null,
        isPinned: false,
        isEdited: false,
        isDeleted: false,
        editedAt: null,
        encrypted: isEncrypted,
        encryptedFileKey: encryptedFileKeyBase64,
        fileIv: fileIvBase64,
      );

      if (isEncrypted) {
        DecryptedMediaCache.cacheBytes(clientMsgId, voiceBytes);
      }

      ref.read(messagesProvider(widget.conversationId).notifier).addMessage(optimisticMsg);
      ref.read(conversationsProvider.notifier).addOrUpdateFromMessage(optimisticMsg);

      final body = <String, dynamic>{
        'conversationId': widget.conversationId,
        'clientMessageId': clientMsgId,
        'fileUrl': fileUrl,
        'mimeType': 'audio/aac',
        'isVoiceMessage': true,
        'voiceDuration': recordSeconds,
      };
      if (isEncrypted) {
        body['encrypted'] = true;
        body['encryptedFileKey'] = encryptedFileKeyBase64;
        body['fileIv'] = fileIvBase64;
      }
      await WsClient().send('/app/chat.send', body: jsonEncode(body));
    } catch (e, stack) {
      debugPrint('[VOICE] upload/send error: $e\n$stack');
      if (mounted) {
        ref.read(messagesProvider(widget.conversationId).notifier).removeByClientId(clientMsgId);
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.voiceSendError)),
        );
      }
    } finally {
      try { file.deleteSync(); } catch (_) {}
    }
  }

  void _cancelRecording() {
    _recordTimer?.cancel();
    _recorder.stopRecorder();
    setState(() => _isRecording = false);
    if (_recordPath != null) {
      try { File(_recordPath!).deleteSync(); } catch (_) {}
    }
  }

  String _formatRecordTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // ── Build ─────────────────────────────────────────────────────────────

  bool _getPrivacyBool(String key, {bool defaultValue = true}) {
    final settings = ref.read(userSettingsProvider).valueOrNull;
    final privacy = settings?['privacy'];
    if (privacy is Map && privacy.containsKey(key)) {
      return privacy[key] == true;
    }
    return defaultValue;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final messagesState = ref.watch(messagesProvider(widget.conversationId));
    final userId = ref.watch(authStateProvider).user?.id;
    final theme = Theme.of(context);
    ref.watch(userSettingsProvider); // Перестраиваем при изменении настроек

    final readReceipts = _getPrivacyBool('readReceipts');
    final linkPreview = _getPrivacyBool('linkPreview');
    // incognito keyboard removed — suggestions always enabled

    final isDark = theme.brightness == Brightness.dark;
    final appBarFg = isDark ? Colors.white : const Color(0xFF333333);

    final isOnline = widget.isGroup
        ? null
        : ref.watch(conversationsProvider).whenOrNull(
              data: (convs) => convs
                  .where((c) => c.id == widget.conversationId)
                  .firstOrNull
                  ?.participant
                  ?.isOnline,
            );

    final showTyping = _participantTyping;
    final String statusText;
    if (widget.isGroup) {
      final conv = ref.watch(conversationsProvider).whenOrNull(
            data: (convs) => convs
                .where((c) => c.id == widget.conversationId)
                .firstOrNull,
          );
      final memberCount = conv?.groupInfo?.memberCount ?? 0;
      if (showTyping && _typingUserId != null) {
        final typingName = _getSenderName(_typingUserId!);
        statusText = l.typingStatus(typingName);
      } else {
        statusText = l.membersCount(memberCount);
      }
    } else {
      statusText = showTyping
          ? l.typing
          : (isOnline == true ? l.online : l.offline);
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, size: 22),
          onPressed: () => context.pop(),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchMsgController,
                autofocus: true,
                style: TextStyle(color: appBarFg),
                decoration: InputDecoration(
                  hintText: l.searchInChat,
                  hintStyle: TextStyle(color: appBarFg.withValues(alpha: 0.5)),
                  border: InputBorder.none,
                  filled: false,
                ),
                onChanged: (v) =>
                    setState(() => _searchMsgQuery = v.toLowerCase()),
              )
            : Builder(builder: (context) {
                final liveConv = ref.watch(conversationsProvider).whenOrNull(
                      data: (convs) => convs
                          .where((c) => c.id == widget.conversationId)
                          .firstOrNull,
                    );
                final currentName = liveConv?.displayName ?? widget.participantName;
                final currentAvatar = liveConv?.displayAvatar ?? widget.participantAvatar;

                return InkWell(
                onTap: () {
                  if (widget.isGroup) {
                    context.push('/groups/${widget.conversationId}/info');
                  } else if (widget.participantId.isNotEmpty) {
                    context.push(
                      '/profile/${widget.participantId}'
                      '?conversationId=${widget.conversationId}'
                      '&name=${Uri.encodeComponent(currentName)}'
                      '&avatar=${Uri.encodeComponent(currentAvatar ?? '')}',
                    );
                  }
                },
                child: Row(
                  children: [
                    UserAvatar(
                      avatarUrl: currentAvatar,
                      name: currentName,
                      radius: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              if (E2eeKeyManager().isInitialized)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Icon(CupertinoIcons.lock, size: 14, color: Colors.greenAccent.shade400),
                                ),
                              Expanded(
                                child: Text(
                                  currentName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.normal,
                              color: showTyping
                                  ? theme.colorScheme.primary
                                  : (isOnline == true
                                      ? Colors.green
                                      : appBarFg.withValues(alpha: 0.5)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
              }),
        actions: _isSearching
            ? [
                IconButton(
                  icon: const Icon(CupertinoIcons.xmark, size: 20),
                  onPressed: () {
                    setState(() {
                      _isSearching = false;
                      _searchMsgController.clear();
                      _searchMsgQuery = '';
                    });
                  },
                ),
              ]
            : [
                if (!widget.isGroup) ...[
                  IconButton(
                    icon: const Icon(CupertinoIcons.video_camera, size: 26),
                    tooltip: l.videoCall,
                    onPressed: () => context.push(
                      '/call?calleeId=${widget.participantId}'
                      '&calleeName=${Uri.encodeComponent(_liveName)}'
                      '&callType=VIDEO',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.phone, size: 22),
                    tooltip: l.audioCall,
                    onPressed: () => context.push(
                      '/call?calleeId=${widget.participantId}'
                      '&calleeName=${Uri.encodeComponent(_liveName)}'
                      '&callType=AUDIO',
                    ),
                  ),
                ],
                if (widget.isGroup)
                  IconButton(
                    icon: const Icon(CupertinoIcons.info, size: 22),
                    tooltip: l.groupInfo,
                    onPressed: () => context.push('/groups/${widget.conversationId}/info'),
                  ),
                PopupMenuButton<String>(
                  icon: const Icon(CupertinoIcons.ellipsis_vertical, size: 20),
                  onSelected: (value) {
                    switch (value) {
                      case 'mute':
                        _toggleNotifications();
                      case 'search':
                        setState(() => _isSearching = true);
                      case 'encryption':
                        _showEncryptionInfo();
                      case 'clear':
                        _confirmClearHistory();
                      case 'delete':
                        _confirmDeleteChat();
                    }
                  },
                  itemBuilder: (ctx) {
                    final isDark = Theme.of(ctx).brightness == Brightness.dark;
                    final ic = isDark ? Colors.white70 : const Color(0xFF333333);
                    final tc = isDark ? Colors.white : const Color(0xFF1A1A1A);
                    return [
                    PopupMenuItem(
                      value: 'mute',
                      child: Row(
                        children: [
                          Icon(
                            _notificationsMuted
                                ? Icons.notifications_off_rounded
                                : Icons.notifications_active_rounded,
                            size: 22,
                            color: _notificationsMuted
                                ? (isDark ? Colors.grey : Colors.grey.shade600)
                                : const Color(0xFF2196F3),
                          ),
                          const SizedBox(width: 12),
                          Text(_notificationsMuted
                              ? l.enableNotifications
                              : l.disableNotifications,
                              style: TextStyle(color: tc)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'search',
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, size: 22,
                              color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
                          const SizedBox(width: 12),
                          Text(l.searchInChat, style: TextStyle(color: tc)),
                        ],
                      ),
                    ),
                    if (E2eeKeyManager().isInitialized)
                      PopupMenuItem(
                        value: 'encryption',
                        child: Row(
                          children: [
                            Icon(CupertinoIcons.lock_shield, size: 20, color: Colors.green.shade700),
                            const SizedBox(width: 12),
                            Text(l.encryption, style: TextStyle(color: tc)),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'clear',
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.paintbrush, size: 20, color: ic),
                          const SizedBox(width: 12),
                          Text(l.clearHistoryAll, style: TextStyle(color: tc)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.trash, size: 20, color: Colors.red),
                          const SizedBox(width: 12),
                          Text(l.deleteChat,
                              style: const TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ];},
                ),
              ],
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: WsClient().connectionNotifier,
        builder: (context, isConnected, child) => TelegramPatternBackground(
        child: Column(
          children: [
            // Trust banner
            if (!widget.isGroup)
              Builder(builder: (ctx) {
                final conv = ref.watch(conversationsProvider).whenOrNull(
                      data: (convs) => convs
                          .where((c) => c.id == widget.conversationId)
                          .firstOrNull,
                    );
                if (conv == null || conv.myTrustStatus != 'PENDING') {
                  return const SizedBox.shrink();
                }
                return _TrustBanner(
                  onTrust: () => _updateTrust('TRUSTED'),
                  onDecline: () => _updateTrust('DECLINED'),
                );
              }),
            // Pinned message bar
            messagesState.whenOrNull(
              data: (messages) {
                final pinned = messages.where((m) => m.isPinned).toList();
                if (pinned.isEmpty) return null;
                final pinnedMsg = pinned.first;
                return _PinnedMessageBar(
                  message: pinnedMsg,
                  onTap: () => _scrollToMessage(pinnedMsg.id, messages),
                  onUnpin: () {
                    WsClient().send('/app/chat.unpin', body: jsonEncode({'messageId': pinnedMsg.id}));
                  },
                );
              },
            ) ?? const SizedBox.shrink(),
            Expanded(
            child: messagesState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text(l.errorLoadingMessages)),
              data: (messages) {
                var filtered = messages;
                if (_searchMsgQuery.isNotEmpty) {
                  filtered = messages
                      .where((m) =>
                          m.text?.toLowerCase().contains(_searchMsgQuery) ==
                          true)
                      .toList();
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      l.noMessagesYet,
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final msg = filtered[index];
                    final isMine = msg.senderId == userId;
                    final showDivider =
                        _shouldShowDateDivider(filtered, index);

                    bool showSenderInfo = false;
                    if (widget.isGroup && !isMine) {
                      if (index == filtered.length - 1) {
                        showSenderInfo = true;
                      } else {
                        final prevMsg = filtered[index + 1];
                        showSenderInfo = prevMsg.senderId != msg.senderId;
                      }
                    }

                    MessageModel? replyMsg;
                    if (msg.replyToId != null) {
                      replyMsg = filtered
                          .where((m) => m.id == msg.replyToId)
                          .firstOrNull;
                    }

                    final isSystemMsg = msg.clientMessageId.startsWith('sys-');

                    Widget bubble;
                    if (isSystemMsg) {
                      bubble = Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 48),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurface.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            msg.text ?? '',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      );
                    } else {
                      bubble = GestureDetector(
                        onLongPress: () => _showMessageContextMenu(msg),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          color: _highlightedMessageId == msg.id
                              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                              : Colors.transparent,
                          child: MessageBubble(
                            message: msg,
                            isMine: isMine,
                            showReadStatus: readReceipts,
                            showLinkPreview: linkPreview,
                            isConnected: isConnected,
                            isGroup: widget.isGroup,
                            showSenderInfo: showSenderInfo,
                            replyToMessage: replyMsg,
                            isHighlighted: _highlightedMessageId == msg.id,
                            onReplyTap: msg.replyToId != null
                                ? () => _scrollToMessage(msg.replyToId!, filtered)
                                : null,
                          ),
                        ),
                      );
                    }

                    if (showDivider) {
                      DateTime? date;
                      try {
                        date = DateTime.parse(msg.createdAt);
                      } catch (_) {}

                      return Column(
                        children: [
                          if (date != null) _buildDateDivider(date),
                          bubble,
                        ],
                      );
                    }

                    return bubble;
                  },
                );
              },
            ),
          ),

          // ── Reply bar ───────────────────────────────────────────────
          if (_replyTo != null)
            Container(
              color: theme.colorScheme.surfaceContainerHighest,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(CupertinoIcons.arrowshape_turn_up_left,
                      size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Container(
                    width: 3,
                    height: 30,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _replyTo!.senderId == userId
                              ? l.you
                              : (widget.isGroup ? _getSenderName(_replyTo!.senderId) : _liveName),
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _replyTo!.text ?? l.attachment,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark, size: 16),
                    onPressed: () => setState(() => _replyTo = null),
                  ),
                ],
              ),
            ),

          // ── Input bar ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: theme.appBarTheme.backgroundColor,
            ),
            child: SafeArea(
              top: false,
              child: _isRecording
                  ? Row(
                      children: [
                        IconButton(
                          icon: const Icon(CupertinoIcons.trash, color: Colors.redAccent),
                          onPressed: _cancelRecording,
                        ),
                        const SizedBox(width: 4),
                        const Icon(CupertinoIcons.circle_fill, color: Colors.red, size: 10),
                        const SizedBox(width: 6),
                        Text(
                          _formatRecordTime(_recordSeconds),
                          style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 16),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(CupertinoIcons.arrow_up_circle_fill,
                              color: isDark
                                  ? Colors.white
                                  : theme.colorScheme.primary,
                              size: 28),
                          onPressed: _stopAndSendVoice,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        IconButton(
                          icon: Icon(CupertinoIcons.paperclip,
                              color: isDark ? Colors.white70 : Colors.black54,
                              size: 22),
                          onPressed: _showAttachMenu,
                        ),
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            maxLines: null,
                            textCapitalization: TextCapitalization.sentences,
                            autocorrect: true,
                            enableSuggestions: true,
                            style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(
                              hintText: l.messageHint,
                              hintStyle: TextStyle(
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.black38),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.06),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(
                            _hasText
                                ? CupertinoIcons.arrow_up_circle_fill
                                : CupertinoIcons.mic,
                            color: isDark
                                ? Colors.white
                                : theme.colorScheme.primary,
                            size: _hasText ? 28 : 24,
                          ),
                          onPressed: _hasText ? _sendMessage : _startRecording,
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    ),
    ),
    );
  }

  Widget _buildDateDivider(DateTime date) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatDateLabel(date),
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }
}

class _PinnedMessageBar extends StatelessWidget {
  final MessageModel message;
  final VoidCallback onTap;
  final VoidCallback onUnpin;

  const _PinnedMessageBar({
    required this.message,
    required this.onTap,
    required this.onUnpin,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    String preview;
    if (message.text != null && message.text!.isNotEmpty) {
      preview = message.text!;
    } else if (message.isVoiceMessage) {
      preview = l.voiceMessage;
    } else if (message.isImage) {
      preview = l.photo;
    } else if (message.isVideo) {
      preview = l.video;
    } else {
      preview = l.attachment;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
          border: Border(
            bottom: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.2),
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Icon(CupertinoIcons.pin_fill, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.senderName ?? l.pinnedMessage,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(CupertinoIcons.xmark, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              onPressed: onUnpin,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustBanner extends StatelessWidget {
  final VoidCallback onTrust;
  final VoidCallback onDecline;

  const _TrustBanner({required this.onTrust, required this.onDecline});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2744) : const Color(0xFFE8F0FE),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.shade300,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 20,
                  color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.trustBannerTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l.trustBannerDescription,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDecline,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey,
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                  child: Text(l.trustNo),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onTrust,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(l.trustYes),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
