import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/bot_provider.dart';
import '../../core/models/bot_model.dart';
import '../../core/widgets/user_avatar.dart';
import '../../l10n/app_localizations.dart';

class BotsListScreen extends ConsumerStatefulWidget {
  const BotsListScreen({super.key});

  @override
  ConsumerState<BotsListScreen> createState() => _BotsListScreenState();
}

class _BotsListScreenState extends ConsumerState<BotsListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(myBotsProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final botsState = ref.watch(myBotsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.myBots),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/settings/bots/create'),
        child: const Icon(Icons.add),
      ),
      body: botsState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.error, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => ref.read(myBotsProvider.notifier).load(),
                child: Text(l.retry),
              ),
            ],
          ),
        ),
        data: (bots) => bots.isEmpty
            ? _buildEmpty(context, l)
            : RefreshIndicator(
                onRefresh: () => ref.read(myBotsProvider.notifier).load(),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: bots.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                  itemBuilder: (context, index) => _BotTile(bot: bots[index]),
                ),
              ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, AppLocalizations l) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.bolt, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(l.noBots, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(l.noBotsHint, style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class _BotTile extends StatelessWidget {
  final BotModel bot;
  const _BotTile({required this.bot});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;

    return ListTile(
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          UserAvatar(avatarUrl: bot.avatarUrl, name: bot.name, radius: 24),
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: theme.scaffoldBackgroundColor, width: 1.5),
              ),
              child: Text(
                l.botBadge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      title: Text(bot.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        bot.username != null ? '@${bot.username}' : (bot.description ?? ''),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bot.isActive
              ? Colors.green.withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          bot.isActive ? l.botActive : l.botInactive,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: bot.isActive ? Colors.green : Colors.grey,
          ),
        ),
      ),
      onTap: () => context.push('/settings/bots/${bot.id}'),
    );
  }
}
