import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/models/conversation_model.dart';
import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';

class MessageRequestsScreen extends ConsumerStatefulWidget {
  const MessageRequestsScreen({super.key});

  @override
  ConsumerState<MessageRequestsScreen> createState() => _MessageRequestsScreenState();
}

class _MessageRequestsScreenState extends ConsumerState<MessageRequestsScreen> {
  List<ConversationModel> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient().dio.get('/conversations/requests');
      final list = (res.data as List)
          .map((e) => ConversationModel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _requests = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onAccept(ConversationModel request) async {
    final l = AppLocalizations.of(context)!;
    try {
      await ApiClient().dio.post('/conversations/${request.id}/accept-request');
      if (mounted) {
        setState(() => _requests.removeWhere((r) => r.id == request.id));
        ref.read(conversationsProvider.notifier).load();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.requestAccepted)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.acceptError)),
        );
      }
    }
  }

  Future<void> _onDecline(ConversationModel request, {bool block = false}) async {
    final l = AppLocalizations.of(context)!;
    try {
      await ApiClient().dio.post(
        '/conversations/${request.id}/decline-request',
        queryParameters: {'block': block},
      );
      if (mounted) {
        setState(() => _requests.removeWhere((r) => r.id == request.id));
        ref.read(conversationsProvider.notifier).load();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(block ? l.requestDeclinedBlocked : l.requestDeclined)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.declineError)),
        );
      }
    }
  }

  void _showDeclineOptions(ConversationModel request) {
    final l = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.close),
              title: Text(l.decline),
              onTap: () {
                Navigator.pop(ctx);
                _onDecline(request, block: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: Text(l.declineAndBlock, style: const TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _onDecline(request, block: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onClearAll() async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.clearAllRequests),
        content: Text(l.clearAllRequestsConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.declineAll),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiClient().dio.delete('/conversations/requests');
      if (mounted) {
        setState(() => _requests.clear());
        ref.read(conversationsProvider.notifier).load();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.allRequestsDeclined)),
        );
      }
    } catch (_) {
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.clearRequestsError)),
        );
      }
    }
  }

  void _openConversation(ConversationModel conv) {
    final p = conv.participant;
    if (p == null) return;
    context.push(
      '/conversation/${conv.id}?name=${Uri.encodeComponent(conv.displayName)}'
      '&participantId=${p.id}'
      '${AppConstants.isValidImageUrl(conv.displayAvatar) ? '&avatar=${Uri.encodeComponent(conv.displayAvatar!)}' : ''}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.messageRequests),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mail_outline, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        l.noRequests,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l.noRequestsHint,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _requests.length,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemBuilder: (context, index) {
                      final request = _requests[index];
                      final name = request.displayName;
                      final avatar = request.displayAvatar;
                      final isIdSearch = request.searchMethod == 'publicId';
                      final isEncrypted = request.lastMessage?.encrypted == true;
                      final lastText = isEncrypted
                          ? l.encryptedMessage
                          : (request.lastMessage?.text ?? l.noMessages);

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: () => _openConversation(request),
                                borderRadius: BorderRadius.circular(12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    request.isMutualTrust
                                        ? UserAvatar(
                                            avatarUrl: avatar,
                                            name: name,
                                            radius: 24,
                                          )
                                        : CircleAvatar(
                                            radius: 24,
                                            backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(40),
                                            child: Icon(
                                              isIdSearch ? Icons.tag : Icons.person,
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                          ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              fontFamily: isIdSearch && !request.isMutualTrust ? 'monospace' : null,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              if (isEncrypted)
                                                Padding(
                                                  padding: const EdgeInsets.only(right: 4),
                                                  child: Icon(Icons.lock, size: 14, color: Colors.grey.shade500),
                                                ),
                                              Expanded(
                                                child: Text(
                                                  lastText,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: Colors.grey.shade500,
                                                    fontSize: 14,
                                                    fontStyle: isEncrypted ? FontStyle.italic : FontStyle.normal,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: () => _onAccept(request),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.green,
                                      ),
                                      child: Text(l.accept),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _showDeclineOptions(request),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(color: Colors.red),
                                      ),
                                      child: Text(l.decline),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      bottomNavigationBar: _requests.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _onClearAll,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: Text(l.declineAll),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
