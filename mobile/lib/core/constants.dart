

class AppConstants {
  // Production: VPS
  static const String _host = '31.130.150.246';
  static const bool _useHttps = false;

  // Для локальной разработки: _host = '192.168.1.114' или '10.0.2.2', _useHttps = false
  static String get apiBaseUrl =>
      '${_useHttps ? 'https' : 'http'}://$_host${_useHttps ? '' : ':3000'}/api/v1';

  static String get wsUrl =>
      '${_useHttps ? 'wss' : 'ws'}://$_host${_useHttps ? '' : ':3000'}/ws';

  static const int messagePageSize = 30;

  /// Railway webhook tester (`tg-bot-testing`). Update if public domain changes.
  static const String defaultBotWebhookUrl =
      'https://web-production-88dcc.up.railway.app/webhook';

  /// Проверяет, что URL подходит для NetworkImage/CachedNetworkImage.
  static bool isValidImageUrl(String? url) =>
      url != null &&
      url.isNotEmpty &&
      (url.startsWith('http://') || url.startsWith('https://'));
}
