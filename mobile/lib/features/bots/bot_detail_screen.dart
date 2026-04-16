import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants.dart';
import '../../core/network/api_client.dart';
import '../../core/providers/bot_provider.dart';
import '../../core/models/bot_model.dart';
import '../../core/widgets/user_avatar.dart';
import '../../l10n/app_localizations.dart';
import 'bot_username_util.dart';
import 'bot_webhook_util.dart';

class BotDetailScreen extends ConsumerStatefulWidget {
  final String botId;
  const BotDetailScreen({super.key, required this.botId});

  @override
  ConsumerState<BotDetailScreen> createState() => _BotDetailScreenState();
}

class _BotDetailScreenState extends ConsumerState<BotDetailScreen> {
  BotModel? _bot;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBot();
  }

  Future<void> _loadBot() async {
    try {
      final bot = await ref.read(botServiceProvider).getBot(widget.botId);
      if (mounted) setState(() { _bot = bot; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l.botEditTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_bot == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l.error)),
      );
    }

    final bot = _bot!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.botEditTitle),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.pencil),
            onPressed: () => _showEditSheet(context, bot),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    UserAvatar(avatarUrl: bot.avatarUrl, name: bot.name, radius: 44),
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                        ),
                        child: Text(
                          l.botBadge,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(bot.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                if (bot.username != null && bot.username!.isNotEmpty)
                  Text('@${bot.username}', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: bot.isActive ? Colors.green.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    bot.isActive ? l.botActive : l.botInactive,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: bot.isActive ? Colors.green : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (bot.description != null && bot.description!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(bot.description!),
              ),
            ),
          ],
          const SizedBox(height: 16),

          _SectionCard(
            title: l.botToken,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SelectableText(
                  bot.token ?? '***',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: bot.token ?? ''));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l.botTokenCopied)),
                      );
                    },
                    icon: const Icon(CupertinoIcons.doc_on_doc, size: 16),
                    label: Text(l.copied),
                  ),
                  TextButton.icon(
                    onPressed: () => _regenerateToken(bot),
                    icon: const Icon(CupertinoIcons.refresh, size: 16),
                    label: Text(l.botRegenerateToken),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          _SectionCard(
            title: l.botWebhookUrl,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  bot.webhookUrl ?? '—',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: bot.webhookUrl != null ? null : Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _showSetWebhookDialog(bot),
                    icon: const Icon(CupertinoIcons.link, size: 16),
                    label: Text(l.botSetWebhook),
                  ),
                  if (bot.webhookUrl != null && bot.webhookUrl!.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => _deleteWebhook(bot),
                      icon: Icon(CupertinoIcons.trash, size: 16, color: Colors.red.shade400),
                      label: Text(l.botDeleteWebhook, style: TextStyle(color: Colors.red.shade400)),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          _SectionCard(
            title: l.botToggleActive,
            children: [
              SwitchListTile(
                title: Text(bot.isActive ? l.botActive : l.botInactive),
                value: bot.isActive,
                onChanged: (_) => _toggleActive(bot),
              ),
            ],
          ),
          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: () => _confirmDelete(bot),
            icon: const Icon(CupertinoIcons.trash),
            label: Text(l.botDelete),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _toggleActive(BotModel bot) async {
    try {
      final updated = await ref.read(myBotsProvider.notifier).toggleActive(bot.id);
      if (mounted) setState(() => _bot = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _regenerateToken(BotModel bot) async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.botRegenerateToken),
        content: Text(l.botRegenerateTokenConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.ok)),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final updated = await ref.read(myBotsProvider.notifier).regenerateToken(bot.id);
      if (mounted) setState(() => _bot = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _showSetWebhookDialog(BotModel bot) {
    final l = AppLocalizations.of(context)!;
    final existing = bot.webhookUrl?.trim();
    final ctrl = TextEditingController(
      text: (existing != null && existing.isNotEmpty)
          ? existing
          : AppConstants.defaultBotWebhookUrl,
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.botSetWebhook),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  hintText: l.botWebhookHint,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    ctrl.text = AppConstants.defaultBotWebhookUrl;
                  },
                  child: Text(l.botWebhookUseRailwayDefault),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final normalized =
                    BotWebhookUtil.normalizeWebhookUrl(ctrl.text);
                final updated = await ref.read(myBotsProvider.notifier).update(
                  bot.id,
                  webhookUrl: normalized,
                );
                if (mounted) {
                  setState(() => _bot = updated);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l.botWebhookUpdated)),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }
            },
            child: Text(l.save),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteWebhook(BotModel bot) async {
    final l = AppLocalizations.of(context)!;
    try {
      final updated = await ref.read(myBotsProvider.notifier).update(bot.id, webhookUrl: '');
      if (mounted) {
        setState(() => _bot = updated.copyWith(webhookUrl: null));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.botWebhookDeleted)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _confirmDelete(BotModel bot) async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.botDelete),
        content: Text(l.botDeleteConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(myBotsProvider.notifier).deleteBot(bot.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.botDeleted)),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _showEditSheet(BuildContext context, BotModel bot) {
    final l = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController(text: bot.name);
    final usernameCtrl = TextEditingController(text: bot.username ?? '');
    final descCtrl = TextEditingController(text: bot.description ?? '');
    String? avatarUrl = bot.avatarUrl;
    File? newAvatarFile;
    bool uploadingAvatar = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        final theme = Theme.of(sheetCtx);
        return StatefulBuilder(
          builder: (ctx, setModal) {
            Future<void> pickAvatar(ImageSource source) async {
              final picker = ImagePicker();
              final picked = await picker.pickImage(source: source, maxWidth: 512);
              if (picked == null) return;
              if (!ctx.mounted) return;
              setModal(() {
                newAvatarFile = File(picked.path);
                uploadingAvatar = true;
              });
              try {
                final formData = FormData.fromMap({
                  'file': await MultipartFile.fromFile(picked.path, filename: 'avatar.jpg'),
                });
                final res = await ApiClient().dio.post('/files/upload', data: formData);
                var raw = res.data;
                if (raw is Map && raw.containsKey('data') && raw.length == 1) {
                  raw = raw['data'];
                }
                String? url;
                if (raw is Map) {
                  url = (raw['fileUrl'] ?? raw['url'])?.toString();
                }
                if (url != null && url.isNotEmpty) {
                  if (!ctx.mounted) return;
                  setModal(() {
                    avatarUrl = url;
                    newAvatarFile = null;
                    uploadingAvatar = false;
                  });
                } else {
                  if (!ctx.mounted) return;
                  setModal(() {
                    newAvatarFile = null;
                    uploadingAvatar = false;
                  });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l.photoUrlFailed)),
                    );
                  }
                }
              } catch (e) {
                if (!ctx.mounted) return;
                setModal(() {
                  newAvatarFile = null;
                  uploadingAvatar = false;
                });
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${l.photoUploadFailed}: $e')),
                  );
                }
              }
            }

            void showAvatarPicker() {
              showModalBottomSheet<void>(
                context: ctx,
                builder: (pickerCtx) {
                  final isDark = Theme.of(pickerCtx).brightness == Brightness.dark;
                  final ic = isDark ? Colors.white70 : const Color(0xFF333333);
                  return SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: Icon(CupertinoIcons.photo, color: ic),
                          title: Text(l.pickFromGallery),
                          onTap: () {
                            Navigator.pop(pickerCtx);
                            pickAvatar(ImageSource.gallery);
                          },
                        ),
                        ListTile(
                          leading: Icon(CupertinoIcons.camera, color: ic),
                          title: Text(l.takePhoto),
                          onTap: () {
                            Navigator.pop(pickerCtx);
                            pickAvatar(ImageSource.camera);
                          },
                        ),
                        if (AppConstants.isValidImageUrl(avatarUrl) || newAvatarFile != null)
                          ListTile(
                            leading: const Icon(CupertinoIcons.trash, color: Colors.red),
                            title: Text(l.deletePhoto, style: const TextStyle(color: Colors.red)),
                            onTap: () {
                              Navigator.pop(pickerCtx);
                              setModal(() {
                                avatarUrl = null;
                                newAvatarFile = null;
                              });
                            },
                          ),
                      ],
                    ),
                  );
                },
              );
            }

            final displayName = nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : bot.name;

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.botEditTitle,
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: GestureDetector(
                      onTap: uploadingAvatar ? null : showAvatarPicker,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (newAvatarFile != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.file(
                                newAvatarFile!,
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            UserAvatar(
                              avatarUrl: avatarUrl,
                              name: displayName,
                              radius: 36,
                              isBot: true,
                            ),
                          if (uploadingAvatar)
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: Colors.black38,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                              ),
                              child: const Icon(CupertinoIcons.camera, size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      l.botAvatar,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: l.botName,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setModal(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: usernameCtrl,
                    decoration: InputDecoration(
                      labelText: l.botUsername,
                      prefixText: '@',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    decoration: InputDecoration(
                      labelText: l.botDescription,
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: uploadingAvatar
                        ? null
                        : () async {
                            final name = nameCtrl.text.trim();
                            final username = normalizeBotUsername(usernameCtrl.text);
                            final description = descCtrl.text.trim();
                            final avatar =
                                avatarUrl?.trim().isNotEmpty == true ? avatarUrl! : '';

                            try {
                              final updated = await ref.read(myBotsProvider.notifier).update(
                                    bot.id,
                                    name: name,
                                    username: username,
                                    description: description,
                                    avatarUrl: avatar,
                                  );
                              if (!sheetCtx.mounted) return;
                              Navigator.of(sheetCtx).pop();
                              if (!mounted) return;
                              setState(() => _bot = updated);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l.botUpdated)),
                              );
                            } catch (e) {
                              if (sheetCtx.mounted) {
                                ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            }
                          },
                    child: Text(l.save),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      nameCtrl.dispose();
      usernameCtrl.dispose();
      descCtrl.dispose();
    });
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}
