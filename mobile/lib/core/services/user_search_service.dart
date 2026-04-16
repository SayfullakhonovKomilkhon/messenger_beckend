import '../network/api_client.dart';

class UserSearchService {
  static Future<List<Map<String, dynamic>>> search(String query) async {
    final res = await ApiClient().dio.get(
      '/users/search',
      queryParameters: {'query': query},
    );
    return (res.data as List).cast<Map<String, dynamic>>();
  }
}
