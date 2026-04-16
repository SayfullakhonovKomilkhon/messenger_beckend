import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bot_model.dart';
import '../services/bot_service.dart';

final botServiceProvider = Provider((_) => BotService());

final myBotsProvider =
    StateNotifierProvider<MyBotsNotifier, AsyncValue<List<BotModel>>>((ref) {
  return MyBotsNotifier(ref.read(botServiceProvider));
});

class MyBotsNotifier extends StateNotifier<AsyncValue<List<BotModel>>> {
  final BotService _service;
  MyBotsNotifier(this._service) : super(const AsyncValue.loading());

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final bots = await _service.getMyBots();
      state = AsyncValue.data(bots);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<BotModel> create({
    required String name,
    required String username,
    String? description,
    String? avatarUrl,
  }) async {
    final bot = await _service.createBot(
      name: name,
      username: username,
      description: description,
      avatarUrl: avatarUrl,
    );
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([bot, ...current]);
    return bot;
  }

  Future<BotModel> toggleActive(String id) async {
    final updated = await _service.toggleActive(id);
    _replaceBot(updated);
    return updated;
  }

  Future<BotModel> regenerateToken(String id) async {
    final updated = await _service.regenerateToken(id);
    _replaceBot(updated);
    return updated;
  }

  Future<void> deleteBot(String id) async {
    await _service.deleteBot(id);
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(current.where((b) => b.id != id).toList());
  }

  Future<BotModel> update(String id, {
    String? name,
    String? username,
    String? description,
    String? avatarUrl,
    String? webhookUrl,
  }) async {
    final updated = await _service.updateBot(id,
      name: name,
      username: username,
      description: description,
      avatarUrl: avatarUrl,
      webhookUrl: webhookUrl,
    );
    _replaceBot(updated);
    return updated;
  }

  void _replaceBot(BotModel updated) {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
      current.map((b) => b.id == updated.id ? updated : b).toList(),
    );
  }
}
