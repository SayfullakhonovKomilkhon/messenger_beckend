import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import '../../core/storage/local_storage.dart';
import '../../l10n/app_localizations.dart';

class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
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
      final raw = res.data;
      final data = raw is Map
          ? Map<String, dynamic>.from(raw.map((k, v) => MapEntry(k.toString(), v)))
          : <String, dynamic>{};
      _settings = data;
      final privacy = data['privacy'];
      if (privacy is Map && privacy.containsKey('blockApp')) {
        await LocalStorage.setBlockApp(privacy['blockApp'] == true);
      }
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (_settings['privacy'] == null) {
        _settings['privacy'] = <String, dynamic>{'blockApp': LocalStorage.getBlockApp()};
      }
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    setState(() {
      _settings['privacy'] =
          Map<String, dynamic>.from(_settings['privacy'] ?? {});
      (_settings['privacy'] as Map<String, dynamic>)[key] = value;
    });
    if (key == 'blockApp') {
      await LocalStorage.setBlockApp(value == true);
    }
    try {
      await ApiClient().dio.patch('/users/me/settings', data: {
        'privacy': {key: value},
      });
      ref.invalidate(userSettingsProvider);
    } catch (_) {
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.settingSaveError)),
        );
      }
    }
  }

  bool _getBool(String key, {bool defaultValue = false}) {
    final privacy = _settings['privacy'];
    if (privacy is Map && privacy.containsKey(key)) {
      return privacy[key] == true;
    }
    if (key == 'blockApp') return LocalStorage.getBlockApp();
    return defaultValue;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.privacy),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _PrivacySection(
                  header: l.voiceVideoBeta,
                  children: [
                    SwitchListTile(
                      title: Text(l.voiceVideoCalls),
                      subtitle: Text(l.allowCalls),
                      value: _getBool('voiceVideoCalls', defaultValue: true),
                      onChanged: (v) => _updateSetting('voiceVideoCalls', v),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _PrivacySection(
                  header: l.screenSecurity,
                  children: [
                    SwitchListTile(
                      title: Text(l.lockApp),
                      subtitle: Text(l.lockAppDescription),
                      value: _getBool('blockApp'),
                      onChanged: (v) => _updateSetting('blockApp', v),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _PrivacySection(
                  children: [
                    ListTile(
                      title: Text(l.messageRequests),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => context.push('/settings/message-requests'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _PrivacySection(
                  children: [
                    SwitchListTile(
                      title: Text(l.readReceipts),
                      subtitle: Text(l.readReceiptsDescription),
                      value: _getBool('readReceipts', defaultValue: true),
                      onChanged: (v) => _updateSetting('readReceipts', v),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _PrivacySection(
                  children: [
                    SwitchListTile(
                      title: Text(l.typingIndicators),
                      subtitle: Text(l.typingIndicatorsDescription),
                      value: _getBool('typingIndicators', defaultValue: true),
                      onChanged: (v) => _updateSetting('typingIndicators', v),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _PrivacySection(
                  children: [
                    SwitchListTile(
                      title: Text(l.linkPreviews),
                      subtitle: Text(l.linkPreviewsDescription),
                      value: _getBool('linkPreview', defaultValue: true),
                      onChanged: (v) => _updateSetting('linkPreview', v),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  final String? header;
  final List<Widget> children;

  const _PrivacySection({
    this.header,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                header!,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ...children,
        ],
      ),
    );
  }
}
