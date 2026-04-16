import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../network/api_client.dart';
import '../storage/secure_storage.dart';

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM] Background message: ${message.messageId}');
}

class NotificationPayload {
  final String type;
  final String? senderId;
  final String? conversationId;
  final String? callId;
  final String? callType;
  final String? callerId;

  NotificationPayload({
    required this.type,
    this.senderId,
    this.conversationId,
    this.callId,
    this.callType,
    this.callerId,
  });

  factory NotificationPayload.fromMap(Map<String, dynamic> data) {
    return NotificationPayload(
      type: data['type']?.toString() ?? '',
      senderId: data['senderId']?.toString(),
      conversationId: data['conversationId']?.toString(),
      callId: data['callId']?.toString(),
      callType: data['callType']?.toString(),
      callerId: data['callerId']?.toString(),
    );
  }
}

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  static final _notificationOpenedController =
      StreamController<NotificationPayload>.broadcast();

  static Stream<NotificationPayload> get onNotificationOpened =>
      _notificationOpenedController.stream;

  NotificationPayload? _initialPayload;
  NotificationPayload? get initialPayload => _initialPayload;

  FirebaseMessaging? _messaging;
  bool _initialized = false;

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const _messagesChannel = AndroidNotificationChannel(
    'messages',
    'Сообщения',
    description: 'Уведомления о новых сообщениях',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  static const _callsChannel = AndroidNotificationChannel(
    'calls',
    'Звонки',
    description: 'Уведомления о входящих звонках',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  Future<void> init() async {
    if (_initialized) return;

    await Firebase.initializeApp();
    _messaging = FirebaseMessaging.instance;

    final settings = await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    await _initLocalNotifications();

    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.data.isNotEmpty) {
        _emitNotificationOpened(message.data);
      }
    });

    final initialMessage = await _messaging!.getInitialMessage();
    if (initialMessage != null && initialMessage.data.isNotEmpty) {
      _initialPayload = NotificationPayload.fromMap(initialMessage.data);
      debugPrint('[FCM] Opened from notification: ${initialMessage.data}');
    }

    if (Platform.isIOS) {
      await _messaging!.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    _initialized = true;
    debugPrint('[FCM] Firebase service initialized');
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(_messagesChannel);
      await androidPlugin.createNotificationChannel(_callsChannel);
    }
  }

  static void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      _notificationOpenedController.add(NotificationPayload.fromMap(data));
    } catch (_) {}
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM] Foreground: ${message.data}');

    if (Platform.isIOS) return;

    final notification = message.notification;
    final android = message.notification?.android;

    if (notification == null) return;

    final isCall = message.data['type'] == 'INCOMING_CALL';
    final channel = isCall ? _callsChannel : _messagesChannel;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: isCall ? Priority.max : Priority.high,
          icon: android?.smallIcon ?? '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _emitNotificationOpened(Map<String, dynamic> data) {
    _notificationOpenedController.add(NotificationPayload.fromMap(data));
  }

  Future<void> registerToken() async {
    if (_messaging == null) return;
    try {
      String? token;
      if (Platform.isIOS) {
        token = await _messaging!.getAPNSToken();
        debugPrint('[FCM] APNS token: $token');
        token = await _messaging!.getToken();
      } else {
        token = await _messaging!.getToken();
      }

      if (token == null) return;
      debugPrint('[FCM] Token: $token');

      final hasAuth = await SecureStorage.hasTokens();
      if (!hasAuth) return;

      await ApiClient().dio.patch('/users/me/fcm-token', data: {
        'fcmToken': token,
      });
      debugPrint('[FCM] Token registered on backend');
    } catch (e) {
      debugPrint('[FCM] Token registration error: $e');
    }

    _messaging!.onTokenRefresh.listen((newToken) async {
      debugPrint('[FCM] Token refreshed: $newToken');
      try {
        final hasAuth = await SecureStorage.hasTokens();
        if (!hasAuth) return;
        await ApiClient().dio.patch('/users/me/fcm-token', data: {
          'fcmToken': newToken,
        });
      } catch (e) {
        debugPrint('[FCM] Token update error: $e');
      }
    });
  }
}
