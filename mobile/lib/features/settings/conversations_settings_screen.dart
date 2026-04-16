import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';
import '../../l10n/app_localizations.dart';

class ConversationsSettingsScreen extends ConsumerStatefulWidget {
  const ConversationsSettingsScreen({super.key});

  @override
  ConsumerState<ConversationsSettingsScreen> createState() =>
      _ConversationsSettingsScreenState();
}

class _ConversationsSettingsScreenState
    extends ConsumerState<ConversationsSettingsScreen> {
  Map<String, dynamic> _settings = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final res = await ApiClient().dio.get('/users/me/settings');
      setState(() {
        _settings = res.data is Map<String, dynamic>
            ? Map<String, dynamic>.from(res.data)
            : {};
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    setState(() {
      _settings['conversations'] =
          Map<String, dynamic>.from(_settings['conversations'] ?? {});
      (_settings['conversations'] as Map<String, dynamic>)[key] = value;
    });
    try {
      await ApiClient().dio.patch('/users/me/settings', data: {
        'conversations': {key: value},
      });
    } catch (_) {
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.settingSaveError)),
        );
      }
    }
  }

  bool _getBool(String key) {
    final conv = _settings['conversations'];
    if (conv is Map && conv.containsKey(key)) return conv[key] == true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.conversations), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 8),

                _SectionHeader(title: l.messageCleanup),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: SwitchListTile(
                    title: Text(l.communityCleanup),
                    subtitle: Text(l.communityCleanupDescription),
                    value: _getBool('communityCleanup'),
                    onChanged: (v) => _updateSetting('communityCleanup', v),
                  ),
                ),

                const SizedBox(height: 16),
                _SectionHeader(title: l.enterKey),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: SwitchListTile(
                    title: Text(l.enterSends),
                    subtitle: Text(l.enterSendsDescription),
                    value: _getBool('enterSends'),
                    onChanged: (v) => _updateSetting('enterSends', v),
                  ),
                ),

                const SizedBox(height: 16),
                _SectionHeader(title: l.voiceMessages),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: SwitchListTile(
                    title: Text(l.autoPlay),
                    subtitle: Text(l.autoPlayDescription),
                    value: _getBool('autoPlayVoice'),
                    onChanged: (v) => _updateSetting('autoPlayVoice', v),
                  ),
                ),

                const SizedBox(height: 16),
                _SectionHeader(title: l.blockedContacts),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const Icon(Icons.block),
                    title: Text(l.blockedContacts),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => context.push('/settings/blocked'),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}
