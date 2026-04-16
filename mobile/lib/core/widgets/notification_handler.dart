import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../network/api_client.dart';
import '../services/firebase_service.dart';

/// Обрабатывает нажатие на push-уведомление — открывает чат
class NotificationHandler extends StatefulWidget {
  final Widget child;
  final bool isAuthenticated;

  const NotificationHandler({
    super.key,
    required this.child,
    required this.isAuthenticated,
  });

  @override
  State<NotificationHandler> createState() => _NotificationHandlerState();
}

class _NotificationHandlerState extends State<NotificationHandler> {
  StreamSubscription<NotificationPayload>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = FirebaseService.onNotificationOpened.listen(_handleNotification);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkInitialMessage());
  }

  void _checkInitialMessage() {
    final payload = FirebaseService().initialPayload;
    if (payload != null && widget.isAuthenticated && mounted) {
      _navigateToPayload(payload);
    }
  }

  void _handleNotification(NotificationPayload payload) {
    if (!widget.isAuthenticated || !mounted) return;
    _navigateToPayload(payload);
  }

  void _navigateToPayload(NotificationPayload payload) {
    if (payload.type == 'MESSAGE_REQUEST') {
      context.push('/settings/message-requests');
      return;
    }
    if (payload.type == 'NEW_MESSAGE' &&
        payload.conversationId != null &&
        payload.senderId != null) {
      _openConversation(payload.conversationId!, payload.senderId!);
    } else if (payload.type == 'INCOMING_CALL' && payload.callId != null && payload.callId!.isNotEmpty) {
      final callType = payload.callType ?? 'AUDIO';
      final calleeId = payload.callerId ?? '';
      context.go(
        '/call?callId=${Uri.encodeComponent(payload.callId!)}'
        '&calleeId=${Uri.encodeComponent(calleeId)}'
        '&calleeName=${Uri.encodeComponent('Звонок')}'
        '&callType=$callType&incoming=true',
      );
    }
  }

  Future<void> _openConversation(String conversationId, String participantId) async {
    try {
      final res = await ApiClient().dio.get('/users/$participantId');
      final user = res.data;
      final name = user['name'] as String? ?? 'Чат';
      final avatar = user['avatarUrl'] as String?;
      final avatarParam = avatar != null && avatar.toString().isNotEmpty
          ? '&avatar=${Uri.encodeComponent(avatar.toString())}'
          : '';
      if (mounted) {
        context.push(
          '/conversation/$conversationId?name=${Uri.encodeComponent(name)}'
          '&participantId=$participantId$avatarParam',
        );
      }
    } catch (_) {
      if (mounted) {
        context.push(
          '/conversation/$conversationId?name=Чат&participantId=$participantId',
        );
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
