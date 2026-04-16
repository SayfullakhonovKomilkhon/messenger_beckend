import 'package:dio/dio.dart';

/// Parses backend [ErrorResponse] or common JSON shapes; falls back to a short hint.
String userFacingApiError(Object error, {String? fallback}) {
  if (error is DioException) {
    final code = error.response?.statusCode;
    final data = error.response?.data;
    if (data is Map) {
      final msg = data['message'] ?? data['error'];
      if (msg != null && msg.toString().isNotEmpty) {
        return msg.toString();
      }
    }
    if (code == 500) {
      return fallback ??
          'Ошибка сервера (500). Часто это переполненный диск на VPS или сбой БД. '
          'Проверьте на сервере: df -h и docker compose logs backend --tail=50';
    }
    if (code == 409) {
      return fallback ?? 'Конфликт данных (уже занято).';
    }
    if (code == 400) {
      return fallback ?? 'Неверные данные запроса.';
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Таймаут сети. Проверьте подключение.';
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'Нет соединения с сервером.';
    }
  }
  return fallback ?? error.toString();
}
