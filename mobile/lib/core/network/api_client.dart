import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants.dart';
import '../storage/local_storage.dart';
import '../storage/secure_storage.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await SecureStorage.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        
        // Add device ID header
        final deviceId = LocalStorage.getDeviceId();
        if (deviceId != null) {
          options.headers['X-Device-Id'] = deviceId;
        }
        
        options.headers['Accept-Language'] = LocalStorage.getLocale();
        // Для FormData Dio сам устанавливает Content-Type с boundary
        if (options.data is FormData) {
          options.headers.remove('Content-Type');
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        final d = response.data;
        if (d is Map<String, dynamic> && d.containsKey('data') && d.length == 1) {
          response.data = d['data'];
        }
        handler.next(response);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          final refreshed = await _refreshToken();
          if (refreshed) {
            final token = await SecureStorage.getAccessToken();
            error.requestOptions.headers['Authorization'] = 'Bearer $token';
            final response = await dio.fetch(error.requestOptions);
            return handler.resolve(response);
          }
        }
        handler.next(error);
      },
    ));

    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
      ));
    }
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await SecureStorage.getRefreshToken();
      if (refreshToken == null) return false;

      final response = await Dio(BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
      )).post('/auth/refresh', data: {'refreshToken': refreshToken});

      final body = response.data is Map && response.data.containsKey('data')
          ? response.data['data']
          : response.data;
      final newAccess = body['accessToken'] as String;
      final newRefresh = body['refreshToken'] as String;
      await SecureStorage.saveTokens(newAccess, newRefresh);
      return true;
    } catch (_) {
      await SecureStorage.clearTokens();
      return false;
    }
  }
}
