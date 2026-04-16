import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_settings/app_settings.dart';
import '../../core/network/api_client.dart';
import '../../l10n/app_localizations.dart';

class NotificationsSettingsScreen extends ConsumerStatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  ConsumerState<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends ConsumerState<NotificationsSettingsScreen> {
  Map<String, dynamic> _settings = {};
  bool _loading = true;

  static const _soundOptions = ['default', 'none', 'system'];
  static const _vibroOptions = ['default', 'short', 'long', 'none'];
  static const _contentOptions = ['name_and_text', 'name_only', 'hidden'];
  static const _popupOptions = ['always', 'screen_on', 'never'];

  List<String> _soundLabels(AppLocalizations l) =>
      [l.soundDefault, l.soundNone, l.soundSystem];

  List<String> _vibroLabels(AppLocalizations l) =>
      [l.vibDefault, l.vibShort, l.vibLong, l.vibOff];

  List<String> _contentLabels(AppLocalizations l) =>
      [l.contentNameAndText, l.contentNameOnly, l.contentHidden];

  List<String> _popupLabels(AppLocalizations l) =>
      [l.popupAlways, l.popupScreenOn, l.popupNever];

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
      _settings['notifications'] =
          Map<String, dynamic>.from(_settings['notifications'] ?? {});
      (_settings['notifications'] as Map<String, dynamic>)[key] = value;
    });
    try {
      await ApiClient().dio.patch('/users/me/settings', data: {
        'notifications': {key: value},
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

  bool _getBool(String key, {bool defaultValue = false}) {
    final notif = _settings['notifications'];
    if (notif is Map && notif.containsKey(key)) return notif[key] == true;
    return defaultValue;
  }

  String _getString(String key, String defaultValue) {
    final notif = _settings['notifications'];
    if (notif is Map && notif[key] != null) return notif[key].toString();
    return defaultValue;
  }

  String _labelFor(String value, List<String> options, List<String> labels) {
    final idx = options.indexOf(value);
    return idx >= 0 ? labels[idx] : labels.first;
  }

  void _showOptionPicker({
    required String title,
    required String currentValue,
    required List<String> options,
    required List<String> labels,
    required String settingKey,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            ...List.generate(options.length, (i) {
              final isSelected = currentValue == options[i];
              return ListTile(
                leading: Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: isSelected ? Theme.of(context).colorScheme.primary : null,
                ),
                title: Text(labels[i]),
                onTap: () {
                  Navigator.pop(ctx);
                  _updateSetting(settingKey, options[i]);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.notifications), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 8),

                _SectionHeader(title: l.strategy),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: Text(l.fastMode),
                        subtitle: Text(l.fastModeDescription),
                        value: _getBool('fastMode', defaultValue: true),
                        onChanged: (v) => _updateSetting('fastMode', v),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(Icons.phone_android),
                        title: Text(l.systemSettings),
                        subtitle: Text(l.systemSettingsDescription),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () {
                          AppSettings.openAppSettings(
                            type: AppSettingsType.notification,
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                _SectionHeader(title: l.styleSection),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      _OptionTile(
                        icon: Icons.music_note_outlined,
                        title: l.sound,
                        value: _labelFor(
                          _getString('sound', 'default'),
                          _soundOptions,
                          _soundLabels(l),
                        ),
                        onTap: () => _showOptionPicker(
                          title: l.notificationSound,
                          currentValue: _getString('sound', 'default'),
                          options: _soundOptions,
                          labels: _soundLabels(l),
                          settingKey: 'sound',
                        ),
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      _OptionTile(
                        icon: Icons.vibration,
                        title: l.vibration,
                        value: _labelFor(
                          _getString('vibration', 'default'),
                          _vibroOptions,
                          _vibroLabels(l),
                        ),
                        onTap: () => _showOptionPicker(
                          title: l.vibration,
                          currentValue: _getString('vibration', 'default'),
                          options: _vibroOptions,
                          labels: _vibroLabels(l),
                          settingKey: 'vibration',
                        ),
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      _OptionTile(
                        icon: Icons.notifications_active_outlined,
                        title: l.popup,
                        value: _labelFor(
                          _getString('popup', 'always'),
                          _popupOptions,
                          _popupLabels(l),
                        ),
                        onTap: () => _showOptionPicker(
                          title: l.popupNotification,
                          currentValue: _getString('popup', 'always'),
                          options: _popupOptions,
                          labels: _popupLabels(l),
                          settingKey: 'popup',
                        ),
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      SwitchListTile(
                        secondary: const Icon(Icons.volume_up_outlined),
                        title: Text(l.inAppSound),
                        subtitle: Text(l.inAppSoundDescription),
                        value: _getBool('soundWhenAppOpen'),
                        onChanged: (v) =>
                            _updateSetting('soundWhenAppOpen', v),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                _SectionHeader(title: l.contentSection),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      _OptionTile(
                        icon: Icons.visibility_outlined,
                        title: l.notificationContent,
                        value: _labelFor(
                          _getString('notificationContent', 'name_and_text'),
                          _contentOptions,
                          _contentLabels(l),
                        ),
                        onTap: () => _showOptionPicker(
                          title: l.notificationContent,
                          currentValue: _getString(
                              'notificationContent', 'name_and_text'),
                          options: _contentOptions,
                          labels: _contentLabels(l),
                          settingKey: 'notificationContent',
                        ),
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      SwitchListTile(
                        secondary: const Icon(Icons.image_outlined),
                        title: Text(l.mediaPreview),
                        subtitle: Text(l.mediaPreviewDescription),
                        value: _getBool('mediaPreview', defaultValue: true),
                        onChanged: (v) =>
                            _updateSetting('mediaPreview', v),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                _SectionHeader(title: l.exceptions),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.do_not_disturb_on_outlined),
                        title: Text(l.doNotDisturb),
                        subtitle: Text(l.doNotDisturbDescription),
                        value: _getBool('doNotDisturb'),
                        onChanged: (v) =>
                            _updateSetting('doNotDisturb', v),
                      ),
                    ],
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

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade400),
        ],
      ),
      onTap: onTap,
    );
  }
}
