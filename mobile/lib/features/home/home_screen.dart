import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/providers.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/telepathy_icon.dart';
import '../../core/widgets/telegram_pattern_background.dart';
import '../../core/models/conversation_model.dart';
import '../../core/models/message_model.dart';
import '../../core/network/api_client.dart';
import '../../core/services/user_search_service.dart';
import '../settings/settings_screen.dart';
import '../../core/network/ws_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/storage/local_storage.dart';
import '../../core/e2ee/key_manager.dart';
import '../../core/e2ee/crypto_service.dart';
import '../../l10n/app_localizations.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  String _searchQuery = '';
  bool _isSearching = false;
  final _searchController = TextEditingController();

  final Set<String> _selectedIds = {};
  bool get _isSelecting => _selectedIds.isNotEmpty;

  bool _isConnected = false;

  Timer? _refreshTimer;

  // Server search
  List<Map<String, dynamic>> _serverResults = [];
  bool _serverSearchLoading = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(conversationsProvider.notifier).load();
      _connectWebSocket();
    });
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      ref.read(conversationsProvider.notifier).loadSilently();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final ws = WsClient();
      if (!ws.isConnected) {
        _connectWebSocket();
      }
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          ref.read(conversationsProvider.notifier).loadSilently();
        }
      });
    }
  }

  Future<void> _connectWebSocket() async {
    final ws = WsClient();
    try {
      await ws.connect();
      if (!mounted) return;
      setState(() => _isConnected = true);
      final userId = ref.read(authStateProvider).user?.id;
      ws.subscribe('/user/$userId/queue/messages', (frame) async {
        if (frame.body == null) return;
        if (!mounted) return;
        final data = jsonDecode(frame.body!);
        if (data is Map<String, dynamic>) {
          final type = data['type'] as String?;
          if (type == 'group_member_added' || type == 'group_member_removed' || type == 'group_updated' || type == 'trust_updated') {
            ref.read(conversationsProvider.notifier).load();
            return;
          }
          if (data.containsKey('clientMessageId')) {
            final msg = MessageModel.fromJson(data);
            if (!mounted) return;
            final isFromOther = msg.senderId != userId;
            if (msg.encrypted && msg.text != null && msg.text!.isNotEmpty) {
              await _decryptForPreview(msg);
            }
            ref.read(conversationsProvider.notifier).addOrUpdateFromMessage(msg, incrementUnread: isFromOther);
          }
        }
      });

      ws.subscribe('/user/$userId/queue/status', (frame) {
        if (frame.body == null) return;
        if (!mounted) return;
        final data = jsonDecode(frame.body!);
        if (data is Map<String, dynamic>) {
          final type = data['type'] as String?;
          final convId = data['conversationId'] as String?;
          if (type == 'READ' && convId != null && mounted) {
            ref.read(conversationsProvider.notifier).updateLastMessageStatus(convId, 'READ');
          }
        }
      });

      ws.subscribe('/user/$userId/queue/presence', (frame) {
        if (frame.body == null) return;
        if (!mounted) return;
        final data = jsonDecode(frame.body!);
        if (data is Map<String, dynamic>) {
          final type = data['type'] as String?;
          final uid = data['userId'] as String?;
          if (type != null && uid != null && mounted) {
            final online = type == 'USER_ONLINE';
            ref.read(conversationsProvider.notifier).updateParticipantOnline(uid, online);
          }
        }
      });

      ws.subscribe('/user/$userId/queue/call', (frame) {
        if (frame.body == null) return;
        final data = jsonDecode(frame.body!);
        if (data is Map<String, dynamic>) {
          final type = data['type'] as String?;
          if (type == 'CALL_INCOMING') {
            final callId = data['callId'] as String? ?? '';
            final callerId = data['callerId'] as String? ?? '';
            final callType = data['callType'] as String? ?? 'AUDIO';
            final eventData = data['data'] as Map<String, dynamic>?;
            String callerName = eventData?['callerName'] as String? ??
                data['callerName'] as String? ?? '';
            if (callerName.isEmpty) {
              callerName = AppLocalizations.of(context)!.unknown;
            }
            if (mounted && callId.isNotEmpty && callerId != userId) {
              context.push(
                '/call?callId=$callId'
                '&calleeId=$callerId'
                '&calleeName=${Uri.encodeComponent(callerName)}'
                '&callType=$callType'
                '&incoming=true',
              );
            }
          }
        }
      });
    } catch (_) {
      if (mounted) setState(() => _isConnected = false);
    }
  }

  Future<void> _decryptForPreview(MessageModel msg) async {
    if (msg.text == null || msg.text!.isEmpty) return;

    final convId = msg.conversationId;

    // Already cached by message ID — just update conversation preview
    if (msg.id.isNotEmpty) {
      final cached = LocalStorage.getDecryptedMessage(msg.id);
      if (cached != null) {
        await LocalStorage.cacheConversationPreview(convId, cached);
        return;
      }
    }

    final userId = ref.read(authStateProvider).user?.id ?? '';

    // Own message — check clientMessageId cache
    if (msg.senderId == userId) {
      final cached = LocalStorage.getCachedPlaintext(msg.clientMessageId);
      if (cached != null) {
        if (msg.id.isNotEmpty) LocalStorage.cacheDecryptedMessage(msg.id, cached);
        await LocalStorage.cacheConversationPreview(convId, cached);
      }
      return;
    }

    // Other party's message — decrypt with Signal Protocol
    if (!E2eeKeyManager().isInitialized) return;
    final crypto = E2eeCryptoService();
    var plaintext = await crypto.decryptMessage(
      msg.senderId, msg.text!, CiphertextMessage.prekeyType,
    );
    plaintext ??= await crypto.decryptMessage(
      msg.senderId, msg.text!, CiphertextMessage.whisperType,
    );
    if (plaintext != null) {
      if (msg.id.isNotEmpty) await LocalStorage.cacheDecryptedMessage(msg.id, plaintext);
      await LocalStorage.cacheConversationPreview(convId, plaintext);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _refreshTimer?.cancel();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value.toLowerCase());
    _searchDebounce?.cancel();
    if (value.length >= 2) {
      _searchDebounce = Timer(const Duration(milliseconds: 400), () {
        _searchServer(value);
      });
    } else {
      setState(() {
        _serverResults = [];
        _serverSearchLoading = false;
      });
    }
  }

  Future<void> _searchServer(String query) async {
    if (!mounted) return;
    setState(() => _serverSearchLoading = true);
    try {
      final results = await UserSearchService.search(query);
      if (!mounted) return;
      setState(() => _serverResults = results);
    } catch (_) {}
    if (mounted) setState(() => _serverSearchLoading = false);
  }

  Future<void> _openOrCreateChat(String participantId, String name, String? avatar, {String? searchMethod}) async {
    final convState = ref.read(conversationsProvider);
    final conversations = convState.valueOrNull ?? [];
    final existing = conversations.where((c) => c.participant?.id == participantId).toList();

    if (existing.isNotEmpty) {
      _openConversation(existing.first);
      return;
    }

    try {
      final res = await ApiClient().dio.post('/conversations', data: {
        'participantId': participantId,
        if (searchMethod != null) 'searchMethod': searchMethod,
      });
      final convId = res.data['id'] as String;
      ref.read(conversationsProvider.notifier).load();
      if (mounted) {
        _exitSearch();
        context.push(
          '/conversation/$convId?name=${Uri.encodeComponent(name)}'
          '&participantId=$participantId'
          '${avatar != null ? '&avatar=${Uri.encodeComponent(avatar)}' : ''}',
        );
      }
    } catch (_) {}
  }

  void _exitSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
      _searchQuery = '';
      _serverResults = [];
      _serverSearchLoading = false;
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _clearSelection() => setState(() => _selectedIds.clear());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authStateProvider).user;
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: _currentIndex == 3
          ? AppBar(title: Text(l.settingsTitle), centerTitle: true)
          : (_isSelecting
              ? _buildSelectionAppBar(theme)
              : _buildNormalAppBar(theme, user)),
      body: TelegramPatternBackground(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _buildChatList(),
            _buildCallHistoryTab(),
            _buildTelepathyTab(),
            const SettingsBody(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          _clearSelection();
          if (_isSearching) _exitSearch();
          setState(() => _currentIndex = i);
          if (i == 1) {
            ref.read(callHistoryProvider.notifier).load();
          }
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(CupertinoIcons.chat_bubble),
            selectedIcon: const Icon(CupertinoIcons.chat_bubble_fill),
            label: l.tabMessages,
          ),
          NavigationDestination(
            icon: const Icon(CupertinoIcons.phone),
            selectedIcon: const Icon(CupertinoIcons.phone_fill),
            label: l.tabCalls,
          ),
          NavigationDestination(
            icon: const TelepathyIcon(size: 28, filled: false),
            selectedIcon: const TelepathyIcon(size: 28, filled: true),
            label: l.tabTelepathy,
          ),
          NavigationDestination(
            icon: const Icon(CupertinoIcons.gear),
            selectedIcon: const Icon(CupertinoIcons.gear_solid),
            label: l.tabSettings,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildNormalAppBar(ThemeData theme, dynamic user) {
    final l = AppLocalizations.of(context)!;
    if (_isSearching) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, size: 22),
          onPressed: _exitSearch,
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l.searchHint,
            border: InputBorder.none,
          ),
          onChanged: _onSearchChanged,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(CupertinoIcons.xmark, size: 20),
              onPressed: () {
                _searchController.clear();
                _onSearchChanged('');
              },
            ),
        ],
      );
    }

    return AppBar(
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: GestureDetector(
          onTap: () => setState(() => _currentIndex = 2),
          child: Center(
            child: _buildUserAvatar(user, 18),
          ),
        ),
      ),
      title: const _BrandedD(),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(CupertinoIcons.search, size: 22),
          onPressed: () => setState(() => _isSearching = true),
        ),
        PopupMenuButton<String>(
          icon: const Icon(CupertinoIcons.ellipsis_vertical, size: 20),
          onSelected: (value) {
            switch (value) {
              case 'new_group':
                context.push('/groups/create');
              case 'dark_theme':
                ref.read(themeProvider.notifier).toggle();
              case 'wallet':
                // TODO: navigate to wallet
                break;
            }
          },
          itemBuilder: (ctx) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            final tc = isDark ? Colors.white : const Color(0xFF1A1A1A);
            return [
            PopupMenuItem(
              value: 'new_group',
              child: Row(
                children: [
                  Icon(Icons.group_add_rounded, size: 22,
                      color: const Color(0xFF2196F3)),
                  const SizedBox(width: 12),
                  Text(l.newGroup, style: TextStyle(color: tc)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'dark_theme',
              child: Row(
                children: [
                  Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    size: 22,
                    color: isDark ? const Color(0xFFFFC107) : const Color(0xFF5C6BC0),
                  ),
                  const SizedBox(width: 12),
                  Text(isDark ? l.lightThemeMenu : l.darkThemeMenu,
                      style: TextStyle(color: tc)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'wallet',
              child: Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded, size: 22,
                      color: const Color(0xFF4CAF50)),
                  const SizedBox(width: 12),
                  Text(l.wallet, style: TextStyle(color: tc)),
                ],
              ),
            ),
          ];},
        ),
        if (!_isConnected)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
      ],
    );
  }

  PreferredSizeWidget _buildSelectionAppBar(ThemeData theme) {
    final l = AppLocalizations.of(context)!;
    return AppBar(
      leading: IconButton(
        icon: const Icon(CupertinoIcons.xmark, size: 20),
        onPressed: _clearSelection,
      ),
      title: Text('${_selectedIds.length}'),
      actions: [
        IconButton(
          icon: const Icon(CupertinoIcons.pin, size: 20),
          tooltip: l.pinTooltip,
          onPressed: () => _bulkAction('pin'),
        ),
        IconButton(
          icon: const Icon(CupertinoIcons.bell_slash, size: 20),
          tooltip: l.muteTooltip,
          onPressed: () => _bulkAction('mute'),
        ),
        IconButton(
          icon: const Icon(CupertinoIcons.trash, size: 20),
          tooltip: l.deleteTooltip,
          onPressed: () => _bulkAction('delete'),
        ),
        PopupMenuButton<String>(
          onSelected: (v) => _bulkAction(v),
          itemBuilder: (ctx) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            final ic = isDark ? Colors.white70 : const Color(0xFF333333);
            final tc = isDark ? Colors.white : const Color(0xFF1A1A1A);
            return [
            PopupMenuItem(value: 'read', child: Row(children: [Icon(CupertinoIcons.eye, size: 20, color: ic), const SizedBox(width: 12), Text(l.markAsRead, style: TextStyle(color: tc))])),
            PopupMenuItem(value: 'clear', child: Row(children: [Icon(CupertinoIcons.paintbrush, size: 20, color: Colors.red), const SizedBox(width: 12), Text(l.clearHistory, style: TextStyle(color: Colors.red))])),
          ];},
        ),
      ],
    );
  }

  Future<void> _bulkAction(String action) async {
    final api = ApiClient().dio;
    final ids = Set<String>.from(_selectedIds);
    final conversations = ref.read(conversationsProvider).valueOrNull ?? [];
    _clearSelection();

    for (final id in ids) {
      try {
        final conv = conversations.where((c) => c.id == id).firstOrNull;
        final isGroup = conv?.isGroup ?? false;

        switch (action) {
          case 'pin':
            await api.patch('/conversations/$id/pin?pinned=true');
            break;
          case 'mute':
            await api.patch('/conversations/$id/mute?muted=true');
            break;
          case 'delete':
            if (isGroup) {
              await api.post('/groups/$id/leave');
            } else {
              await api.delete('/conversations/$id');
            }
            break;
          case 'clear':
            await api.delete('/conversations/$id/messages');
            break;
          case 'read':
            await api.post('/conversations/$id/read');
            break;
        }
      } catch (_) {}
    }
    ref.read(conversationsProvider.notifier).load();
  }

  Widget _buildUserAvatar(dynamic user, double radius) {
    final name = user?.name ?? '';
    return UserAvatar(
      avatarUrl: user?.avatarUrl as String?,
      name: name,
      radius: radius,
    );
  }

  Widget _buildChatList() {
    final convState = ref.watch(conversationsProvider);
    final l = AppLocalizations.of(context)!;

    if (_isSearching && _searchQuery.isNotEmpty) {
      return _buildSearchResults(convState);
    }

    return convState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.failedToLoadChats),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => ref.read(conversationsProvider.notifier).load(),
              child: Text(l.retry),
            ),
          ],
        ),
      ),
      data: (conversations) => _buildConversationList(conversations),
    );
  }

  Widget _buildConversationList(List<ConversationModel> conversations) {
    final l = AppLocalizations.of(context)!;
    final pinned = conversations.where((c) => c.isPinned).toList();
    final unpinned = conversations.where((c) => !c.isPinned).toList();
    final sorted = [...pinned, ...unpinned];

    if (sorted.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.chat_bubble, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(l.noChatsYet,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(l.findContactViaSearch,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(conversationsProvider.notifier).load(),
      child: ListView.builder(
        itemCount: sorted.length,
        itemBuilder: (context, index) {
          final conv = sorted[index];
          final isSelected = _selectedIds.contains(conv.id);
          return _ConversationTile(
            conversation: conv,
            isSelected: isSelected,
            isSelecting: _isSelecting,
            onTap: () {
              if (_isSelecting) {
                _toggleSelect(conv.id);
              } else {
                _openConversation(conv);
              }
            },
            onLongPress: () {
              HapticFeedback.mediumImpact();
              _toggleSelect(conv.id);
            },
          );
        },
      ),
    );
  }

  Widget _buildSearchResults(AsyncValue<List<ConversationModel>> convState) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final conversations = convState.valueOrNull ?? [];

    final q = _searchQuery.toLowerCase();
    final matchingChats = conversations
        .where((c) {
          final name = c.displayName.toLowerCase();
          final pubId = c.participant?.publicId?.toLowerCase() ?? '';
          return name.contains(q) || pubId.contains(q);
        })
        .toList();

    final matchingChatUserIds = matchingChats
        .where((c) => c.participant != null)
        .map((c) => c.participant!.id)
        .toSet();
    final newUsers = _serverResults
        .where((u) => !matchingChatUserIds.contains(u['id'] as String))
        .toList();

    final hasChats = matchingChats.isNotEmpty;
    final hasUsers = newUsers.isNotEmpty;
    final hasNothing = !hasChats && !hasUsers && !_serverSearchLoading;

    return ListView(
      children: [
        if (hasChats) ...[
          _SectionHeader(title: l.chatsSection, theme: theme),
          ...matchingChats.map((conv) => _ConversationTile(
            conversation: conv,
            isSelected: false,
            isSelecting: false,
            onTap: () {
              _exitSearch();
              _openConversation(conv);
            },
            onLongPress: () {},
          )),
        ],
        if (_serverSearchLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        if (hasUsers) ...[
          _SectionHeader(title: l.usersSection, theme: theme),
          ...newUsers.map((user) {
            final matchType = user['matchType'] as String? ?? 'name';
            final isIdMatch = matchType == 'publicId';
            final isAiNameMatch = matchType == 'aiName';
            final String displayText;
            if (isIdMatch) {
              displayText = user['publicId'] as String? ?? '';
            } else if (isAiNameMatch) {
              displayText = user['aiName'] as String? ?? '';
            } else {
              displayText = user['name'] as String? ?? user['aiName'] as String? ?? '';
            }

            final String subtitle;
            if (isIdMatch) {
              subtitle = l.foundById;
            } else if (isAiNameMatch) {
              subtitle = l.foundByAvatarName;
            } else {
              subtitle = l.foundByNickname;
            }

            return _UserSearchResultTile(
              titleText: displayText,
              subtitleText: subtitle,
              isIdMatch: isIdMatch,
              isOnline: user['isOnline'] == true,
              isBot: user['isBot'] == true,
              onTap: () => _openOrCreateChat(
                user['id'] as String,
                displayText,
                null,
                searchMethod: matchType,
              ),
            );
          }),
        ],
        if (hasNothing)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                l.nothingFound,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCallHistoryTab() {
    final callsState = ref.watch(callHistoryProvider);
    final l = AppLocalizations.of(context)!;

    return callsState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.failedToLoadCalls),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => ref.read(callHistoryProvider.notifier).load(),
              child: Text(l.retry),
            ),
          ],
        ),
      ),
      data: (calls) {
        if (calls.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.phone, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(l.noCallsYet,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(l.callHistoryHere,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    textAlign: TextAlign.center),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.read(callHistoryProvider.notifier).load(),
          child: ListView.builder(
            itemCount: calls.length,
            itemBuilder: (context, index) {
              final call = calls[index];
              final isVideo = call.callType == 'VIDEO';
              final isMissed = call.status == 'MISSED' || call.status == 'REJECTED';

              String timeStr = '';
              if (call.startedAt != null) {
                try {
                  final dt = DateTime.parse(call.startedAt!);
                  final now = DateTime.now();
                  if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
                    timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                  } else {
                    timeStr = '${dt.day}.${dt.month.toString().padLeft(2, '0')}';
                  }
                } catch (_) {}
              }

              String durationStr = '';
              if (call.duration != null && call.duration! > 0) {
                final m = call.duration! ~/ 60;
                final s = call.duration! % 60;
                durationStr = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
              }

              final isDark = Theme.of(context).brightness == Brightness.dark;
              final titleColor = isDark ? Colors.white : Colors.black87;
              final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
              final cardColor = isDark
                  ? Colors.black.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.7);

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  leading: UserAvatar(
                    avatarUrl: call.participant.avatarUrl,
                    name: call.participant.name,
                    radius: 24,
                  ),
                  title: Text(
                    call.participant.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isMissed ? Colors.red : titleColor,
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      Icon(
                        isMissed ? CupertinoIcons.phone_down : CupertinoIcons.phone_arrow_up_right,
                        size: 14,
                        color: isMissed ? Colors.red : Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isVideo ? l.videoCall : l.audioCall,
                        style: TextStyle(fontSize: 13, color: subtitleColor),
                      ),
                      if (durationStr.isNotEmpty) ...[
                        Text(' • ', style: TextStyle(color: subtitleColor)),
                        Text(durationStr, style: TextStyle(fontSize: 13, color: subtitleColor)),
                      ],
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (timeStr.isNotEmpty)
                        Text(timeStr, style: TextStyle(fontSize: 12, color: subtitleColor)),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          isVideo ? CupertinoIcons.video_camera : CupertinoIcons.phone,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        onPressed: () => context.push(
                          '/call?calleeId=${call.participant.id}'
                          '&calleeName=${Uri.encodeComponent(call.participant.name)}'
                          '&callType=${call.callType}',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTelepathyTab() {
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulsingIcon(
            child: TelepathyIcon(
              size: 100,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
              filled: false,
            ),
          ),
          const SizedBox(height: 20),
          Text(l.telepathy, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _openConversation(ConversationModel conv) {
    if (conv.isGroup) {
      final name = conv.groupInfo?.title ?? AppLocalizations.of(context)!.group;
      final avatar = conv.groupInfo?.avatarUrl;
      context.push(
        '/conversation/${conv.id}?name=${Uri.encodeComponent(name)}'
        '&isGroup=true'
        '${avatar != null && AppConstants.isValidImageUrl(avatar) ? '&avatar=${Uri.encodeComponent(avatar)}' : ''}',
      );
    } else {
      final p = conv.participant;
      if (p == null) return;
      context.push(
        '/conversation/${conv.id}?name=${Uri.encodeComponent(conv.displayName)}'
        '&participantId=${p.id}'
        '${AppConstants.isValidImageUrl(conv.displayAvatar) ? '&avatar=${Uri.encodeComponent(conv.displayAvatar!)}' : ''}',
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final ThemeData theme;

  const _SectionHeader({required this.title, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _BrandedD extends StatelessWidget {
  const _BrandedD();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/apk_logo.png',
      height: 70,
      width: 70,
      fit: BoxFit.contain,
    );
  }
}

class _PulsingIcon extends StatefulWidget {
  final Widget child;

  const _PulsingIcon({required this.child});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Transform.scale(
        scale: 1.0 + _ctrl.value * 0.1,
        child: Opacity(
          opacity: 0.6 + _ctrl.value * 0.4,
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Same card + [UserAvatar] styling as [_ConversationTile] (solid avatar, not transparent row).
class _UserSearchResultTile extends StatelessWidget {
  final String titleText;
  final String subtitleText;
  final bool isIdMatch;
  final bool isOnline;
  final bool isBot;
  final VoidCallback onTap;

  const _UserSearchResultTile({
    required this.titleText,
    required this.subtitleText,
    required this.isIdMatch,
    required this.isOnline,
    required this.isBot,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final cardColor = isDark
        ? Colors.black.withValues(alpha: 0.35)
        : Colors.white.withValues(alpha: 0.7);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            UserAvatar(
              avatarUrl: null,
              name: titleText.isNotEmpty ? titleText : '?',
              radius: 24,
              isBot: isBot,
            ),
            if (isOnline)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.onlineGreen,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          titleText,
          overflow: TextOverflow.ellipsis,
          style: isIdMatch
              ? TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                )
              : TextStyle(
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                  fontSize: 16,
                ),
        ),
        subtitle: Text(
          subtitleText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: subtitleColor, fontSize: 12),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ConversationModel conversation;
  final bool isSelected;
  final bool isSelecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ConversationTile({
    required this.conversation,
    required this.isSelected,
    required this.isSelecting,
    required this.onTap,
    required this.onLongPress,
  });

  String _messagePreview(LastMessageInfo? lm, AppLocalizations l) {
    if (lm == null) return l.noMessagesPreview;
    if (lm.encrypted == true) {
      if (lm.isVoiceMessage == true) return '\u{1F512} ${l.voiceMessage}';
      final mime = lm.mimeType?.toLowerCase() ?? '';
      if (mime.startsWith('image/')) return '\u{1F512} ${l.photo}';
      if (mime.startsWith('video/')) return '\u{1F512} ${l.video}';
      if ((lm.fileUrl ?? '').isNotEmpty) return '\u{1F512} ${l.attachment}';

      if (lm.id != null && lm.id!.isNotEmpty) {
        final cached = LocalStorage.getDecryptedMessage(lm.id!);
        if (cached != null && cached.isNotEmpty) return cached;
      }
      final convPreview = LocalStorage.getConversationPreview(conversation.id);
      if (convPreview != null && convPreview.isNotEmpty) return convPreview;
      return '\u{1F512} ${l.encryptedMessage}';
    }
    final text = lm.text;
    if (text != null && text.isNotEmpty) return text;
    if (lm.isVoiceMessage == true) return l.voiceMessage;
    final mime = lm.mimeType?.toLowerCase() ?? '';
    if (mime.startsWith('image/')) return l.photo;
    if (mime.startsWith('video/')) return l.video;
    if ((lm.fileUrl ?? '').isNotEmpty) return l.attachment;
    return l.noMessagesPreview;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final lm = conversation.lastMessage;
    final name = conversation.displayName;
    final avatar = conversation.displayAvatar;
    final isGroup = conversation.isGroup;
    final isOnline = !isGroup && conversation.participant?.isOnline == true;

    String timeStr = '';
    if (lm?.createdAt != null) {
      try {
        final dt = DateTime.parse(lm!.createdAt!);
        final now = DateTime.now();
        if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
          timeStr = DateFormat.Hm().format(dt);
        } else {
          timeStr = DateFormat.MMMd().format(dt);
        }
      } catch (_) {}
    }

    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final timeColor = isDark ? Colors.grey.shade500 : Colors.grey.shade600;
    final cardColor = isDark
        ? Colors.black.withValues(alpha: 0.35)
        : Colors.white.withValues(alpha: 0.7);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.2) : cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Stack(
          children: [
            if (isSelecting)
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected ? theme.colorScheme.primary : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: isSelected
                      ? const Icon(CupertinoIcons.checkmark_alt, color: Colors.white, size: 20)
                      : Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 20),
                        ),
                ),
              )
            else ...[
              UserAvatar(
                avatarUrl: avatar,
                name: name,
                radius: 24,
                isBot: conversation.participant?.isBot == true,
              ),
              if (isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.onlineGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                    ),
                  ),
                ),
            ],
          ],
        ),
        title: Row(
          children: [
            if (conversation.isPinned)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(CupertinoIcons.pin_fill, size: 14, color: theme.colorScheme.primary),
              ),
            if (isGroup)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(CupertinoIcons.person_2_fill, size: 16, color: subtitleColor),
              ),
            Expanded(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                  fontSize: 16,
                ),
              ),
            ),
            if (conversation.isMuted)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(CupertinoIcons.bell_slash_fill, size: 14, color: subtitleColor),
              ),
            if (timeStr.isNotEmpty)
              Text(timeStr, style: TextStyle(fontSize: 12, color: timeColor)),
          ],
        ),
        subtitle: Row(
          children: [
            if (isGroup && conversation.groupInfo != null)
              Text(
                '${conversation.groupInfo!.memberCount} ${l.members} · ',
                style: TextStyle(color: subtitleColor, fontSize: 12),
              ),
            Expanded(
              child: Text(
                _messagePreview(lm, l),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: subtitleColor),
              ),
            ),
            if (conversation.unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: conversation.isMuted ? Colors.grey : theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  conversation.unreadCount > 99 ? '99+' : '${conversation.unreadCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}
