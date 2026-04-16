import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/network/ws_client.dart';
import 'core/storage/local_storage.dart';
import 'core/providers.dart';
import 'core/services/firebase_service.dart';
import 'core/services/pending_messages_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorage.init();

  WsClient.onConnectCallbacks.add(retryPendingMessages);

  bool firebaseReady = false;
  final firebaseService = FirebaseService();
  try {
    await firebaseService.init().timeout(const Duration(seconds: 3));
    firebaseReady = true;
  } catch (e) {
    debugPrint('[Main] Firebase недоступен: $e');
  }

  final container = ProviderContainer();
  try {
    await container.read(authStateProvider.notifier).checkAuth();
  } catch (_) {
    debugPrint('[Main] checkAuth failed, proceeding to login');
  }

  if (firebaseReady && container.read(authStateProvider).isAuthenticated) {
    firebaseService.registerToken();
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MessengerApp(),
    ),
  );
}
