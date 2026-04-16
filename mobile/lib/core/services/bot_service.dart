import '../models/bot_model.dart';
import '../network/api_client.dart';

class BotService {
  final _dio = ApiClient().dio;

  Future<List<BotModel>> getMyBots() async {
    final response = await _dio.get('/bots');
    final list = response.data as List;
    return list.map((e) => BotModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<BotModel> getBot(String id) async {
    final response = await _dio.get('/bots/$id');
    return BotModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BotModel> createBot({
    required String name,
    required String username,
    String? description,
    String? avatarUrl,
  }) async {
    final response = await _dio.post('/bots', data: {
      'name': name,
      if (username.isNotEmpty) 'username': username,
      if (description != null && description.isNotEmpty) 'description': description,
      if (avatarUrl != null && avatarUrl.isNotEmpty) 'avatarUrl': avatarUrl,
    });
    return BotModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BotModel> updateBot(String id, {
    String? name,
    String? username,
    String? description,
    String? avatarUrl,
    String? webhookUrl,
  }) async {
    final response = await _dio.patch('/bots/$id', data: {
      if (name != null) 'name': name,
      if (username != null) 'username': username,
      if (description != null) 'description': description,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (webhookUrl != null) 'webhookUrl': webhookUrl,
    });
    return BotModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BotModel> regenerateToken(String id) async {
    final response = await _dio.post('/bots/$id/regenerate-token');
    return BotModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BotModel> toggleActive(String id) async {
    final response = await _dio.post('/bots/$id/toggle-active');
    return BotModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteBot(String id) async {
    await _dio.delete('/bots/$id');
  }
}
