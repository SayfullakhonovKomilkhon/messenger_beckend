import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../constants.dart';
import '../storage/secure_storage.dart';

typedef StompCallback = void Function(StompFrame frame);

class WsClient {
  static final WsClient _instance = WsClient._internal();
  factory WsClient() => _instance;

  StompClient? _client;
  /// Все активные подписки: destination -> list of {id, callback, unsubscribeFn}
  final _subscriptions = <String, List<_SubEntry>>{};
  bool _connected = false;
  Completer<void>? _connectCompleter;
  int _subIdCounter = 0;

  final ValueNotifier<bool> connectionNotifier = ValueNotifier<bool>(false);

  /// Вызываются при успешном подключении — для повторной отправки отложенных сообщений.
  static final List<VoidCallback> onConnectCallbacks = [];

  WsClient._internal();

  Future<void> connect() async {
    if (_connected && _client != null) return;
    if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
      return _connectCompleter!.future;
    }

    _connectCompleter = Completer<void>();

    final token = await SecureStorage.getAccessToken();
    if (token == null) {
      _connectCompleter?.completeError('No token');
      _connectCompleter = null;
      return;
    }

    debugPrint('[WS] Connecting to ${AppConstants.wsUrl}');

    _client = StompClient(
      config: StompConfig(
        url: AppConstants.wsUrl,
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        onConnect: _onConnect,
        onDisconnect: _onDisconnect,
        onWebSocketError: (error) {
          debugPrint('[WS] WebSocket error: $error');
          if (!(_connectCompleter?.isCompleted ?? true)) {
            _connectCompleter?.completeError(error);
            _connectCompleter = null;
          }
        },
        onStompError: (frame) {
          debugPrint('[WS] STOMP error: ${frame.body}');
        },
        reconnectDelay: const Duration(seconds: 5),
      ),
    );

    _client!.activate();
    return _connectCompleter!.future;
  }

  void _onConnect(StompFrame frame) {
    debugPrint('[WS] Connected');
    _connected = true;
    connectionNotifier.value = true;
    for (final cb in onConnectCallbacks) {
      try {
        cb();
      } catch (e) {
        debugPrint('[WS] onConnect callback error: $e');
      }
    }
    // Перерегистрируем все существующие подписки после реконнекта
    for (final entry in _subscriptions.entries) {
      for (final sub in entry.value) {
        sub.unsubscribeFn = _doSubscribe(entry.key, sub.callback);
      }
    }
    if (!(_connectCompleter?.isCompleted ?? true)) {
      _connectCompleter?.complete();
    }
    _connectCompleter = null;
  }

  void _onDisconnect(StompFrame frame) {
    debugPrint('[WS] Disconnected');
    _connected = false;
    connectionNotifier.value = false;
  }

  /// Подписывается на destination и возвращает id подписки.
  /// Можно подписать несколько слушателей на один destination.
  /// Вызовите [unsubscribeById] с возвращённым id, чтобы отписаться.
  int subscribe(String destination, StompCallback callback) {
    final id = _subIdCounter++;
    final entry = _SubEntry(id: id, callback: callback);

    if (_connected && _client != null) {
      entry.unsubscribeFn = _doSubscribe(destination, callback);
    }

    _subscriptions.putIfAbsent(destination, () => []);
    _subscriptions[destination]!.add(entry);

    return id;
  }

  Function({Map<String, String>? unsubscribeHeaders})? _doSubscribe(
      String destination, StompCallback callback) {
    try {
      final result = _client!.subscribe(
        destination: destination,
        callback: callback,
      );
      return result;
    } catch (e) {
      debugPrint('[WS] Subscribe error: $e');
      return null;
    }
  }

  /// Отписывается по id подписки (возвращённому из [subscribe]).
  void unsubscribeById(int subId) {
    for (final entry in _subscriptions.entries) {
      final list = entry.value;
      final idx = list.indexWhere((s) => s.id == subId);
      if (idx != -1) {
        final sub = list[idx];
        sub.unsubscribeFn?.call();
        list.removeAt(idx);
        if (list.isEmpty) {
          _subscriptions.remove(entry.key);
        }
        return;
      }
    }
  }

  /// Убирает все подписки на destination (старый API, для совместимости).
  void unsubscribe(String destination) {
    final list = _subscriptions.remove(destination);
    if (list != null) {
      for (final sub in list) {
        sub.unsubscribeFn?.call();
      }
    }
  }

  Future<void> send(String destination, {String? body}) async {
    if (!_connected || _client == null) {
      debugPrint('[WS] Not connected, attempting to connect before send...');
      try {
        await connect();
      } catch (e) {
        debugPrint('[WS] Failed to connect: $e');
        return;
      }
    }
    if (_connected && _client != null) {
      _client!.send(destination: destination, body: body);
    }
  }

  void disconnect() {
    _client?.deactivate();
    _connected = false;
    connectionNotifier.value = false;
    _subscriptions.clear();
    _connectCompleter = null;
  }

  bool get isConnected => _connected;
}

class _SubEntry {
  final int id;
  final StompCallback callback;
  Function({Map<String, String>? unsubscribeHeaders})? unsubscribeFn;

  _SubEntry({required this.id, required this.callback});
}
