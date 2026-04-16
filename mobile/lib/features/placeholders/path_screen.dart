import 'package:flutter/material.dart';

class PathScreen extends StatefulWidget {
  const PathScreen({super.key});

  @override
  State<PathScreen> createState() => _PathScreenState();
}

class _PathScreenState extends State<PathScreen> {
  bool _rebuilding = false;

  final _nodes = const [
    _PathNode(emoji: '🟢', title: 'Вы', subtitle: 'Ваше устройство', flag: ''),
    _PathNode(emoji: '🔵', title: 'Входной узел', subtitle: '45.76.xxx.xxx', flag: '🇩🇪 Германия'),
    _PathNode(emoji: '🔵', title: 'Сервисный узел', subtitle: '139.99.xxx.xxx', flag: '🇳🇱 Нидерланды'),
    _PathNode(emoji: '🟡', title: 'Назначение', subtitle: 'Swarm (распределенное хранилище)', flag: ''),
  ];

  Future<void> _rebuildPath() async {
    setState(() => _rebuilding = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _rebuilding = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Путь успешно обновлен!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Путь'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Путь сети Demos',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Demos скрывает ваш IP, направляя сообщения через несколько узлов децентрализованной сети.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 32),

            // Path nodes
            for (var i = 0; i < _nodes.length; i++) ...[
              _buildNode(_nodes[i], theme),
              if (i < _nodes.length - 1)
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Column(
                    children: List.generate(3, (_) => Container(
                      width: 2,
                      height: 8,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    )),
                  ),
                ),
            ],

            const SizedBox(height: 40),
            Center(
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _rebuilding ? null : _rebuildPath,
                  icon: _rebuilding
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(_rebuilding ? 'Обновление...' : 'Обновить путь'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () {},
                child: const Text('Подробнее о луковой маршрутизации'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNode(_PathNode node, ThemeData theme) {
    return Row(
      children: [
        Text(node.emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(node.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    node.subtitle,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontFamily: 'monospace'),
                  ),
                  if (node.flag.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(node.flag, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PathNode {
  final String emoji;
  final String title;
  final String subtitle;
  final String flag;

  const _PathNode({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.flag,
  });
}
