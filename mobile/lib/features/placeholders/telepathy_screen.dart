import 'package:flutter/material.dart';
import '../../core/widgets/telepathy_icon.dart';

class TelepathyScreen extends StatefulWidget {
  const TelepathyScreen({super.key});

  @override
  State<TelepathyScreen> createState() => _TelepathyScreenState();
}

class _TelepathyScreenState extends State<TelepathyScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Телепатия'), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, child) => Transform.scale(
                scale: 1.0 + _pulseCtrl.value * 0.15,
                child: Opacity(
                  opacity: 0.5 + _pulseCtrl.value * 0.5,
                  child: child,
                ),
              ),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                ),
                child: Center(
                  child: TelepathyIcon(
                    size: 60,
                    color: theme.colorScheme.primary.withValues(alpha: 0.6),
                    filled: true,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Телепатия',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
