import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../network/ws_client.dart';
import '../storage/local_storage.dart';

/// Повторная отправка сообщений, не доставленных из‑за отсутствия связи.
void retryPendingMessages() {
  if (!WsClient().isConnected) return;

  final pending = LocalStorage.getPendingMessages();
  if (pending.isEmpty) return;

  debugPrint('[PendingMessages] Retrying ${pending.length} message(s)');

  for (final msg in pending) {
    final conversationId = msg['conversationId'] as String?;
    final text = msg['text'] as String?;
    final clientMessageId = msg['clientMessageId'] as String?;
    final replyToId = msg['replyToId'] as String?;

    if (conversationId == null || text == null || clientMessageId == null) {
      LocalStorage.removePendingMessage(clientMessageId ?? '');
      continue;
    }

    final body = {
      'conversationId': conversationId,
      'text': text,
      'clientMessageId': clientMessageId,
      if (replyToId != null && replyToId.isNotEmpty) 'replyToId': replyToId,
    };

    WsClient().send('/app/chat.send', body: jsonEncode(body));
    LocalStorage.removePendingMessage(clientMessageId);
  }
}
