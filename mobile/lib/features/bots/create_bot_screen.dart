import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/dio_error_message.dart';
import '../../core/providers/bot_provider.dart';
import '../../core/widgets/user_avatar.dart';
import '../../l10n/app_localizations.dart';
import 'bot_username_util.dart';

class CreateBotScreen extends ConsumerStatefulWidget {
  const CreateBotScreen({super.key});

  @override
  ConsumerState<CreateBotScreen> createState() => _CreateBotScreenState();
}

class _CreateBotScreenState extends ConsumerState<CreateBotScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _avatarUrl;
  File? _newAvatarFile;
  bool _loading = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  String get _avatarDisplayName {
    final n = _nameCtrl.text.trim();
    return n.isNotEmpty ? n : 'Bot';
  }

  Future<void> _pickAvatar(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 512);
    if (picked == null) return;

    setState(() {
      _newAvatarFile = File(picked.path);
      _uploadingAvatar = true;
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
      if (url != null && url.isNotEmpty && mounted) {
        setState(() => _avatarUrl = url);
      } else if (mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.photoUrlFailed)),
        );
        setState(() => _newAvatarFile = null);
      }
    } catch (e) {
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l.photoUploadFailed}: $e')),
        );
        setState(() => _newAvatarFile = null);
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  void _showAvatarPicker() {
    final l = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final ic = isDark ? Colors.white70 : const Color(0xFF333333);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(CupertinoIcons.photo, color: ic),
                title: Text(l.pickFromGallery),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAvatar(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(CupertinoIcons.camera, color: ic),
                title: Text(l.takePhoto),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAvatar(ImageSource.camera);
                },
              ),
              if (AppConstants.isValidImageUrl(_avatarUrl) || _newAvatarFile != null)
                ListTile(
                  leading: const Icon(CupertinoIcons.trash, color: Colors.red),
                  title: Text(l.deletePhoto, style: const TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _avatarUrl = null;
                      _newAvatarFile = null;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final bot = await ref.read(myBotsProvider.notifier).create(
            name: _nameCtrl.text.trim(),
            username: normalizeBotUsername(_usernameCtrl.text),
            description: _descCtrl.text.trim(),
            avatarUrl: _avatarUrl?.trim().isNotEmpty == true ? _avatarUrl : null,
          );
      if (!mounted) return;
      final l = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.botCreated)),
      );
      context.pop();
      context.push('/settings/bots/${bot.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFacingApiError(e)),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.createBot),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _uploadingAvatar ? null : _showAvatarPicker,
                  child: Stack(
                    children: [
                      if (_newAvatarFile != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.file(
                            _newAvatarFile!,
                            width: 108,
                            height: 108,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        UserAvatar(
                          avatarUrl: _avatarUrl,
                          name: _avatarDisplayName,
                          radius: 54,
                        ),
                      if (_uploadingAvatar)
                        Positioned.fill(
                          child: Container(
                            width: 108,
                            height: 108,
                            decoration: BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.scaffoldBackgroundColor,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            CupertinoIcons.camera,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  l.botAvatar,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: l.botName,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? l.botNameRequired : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameCtrl,
                decoration: InputDecoration(
                  labelText: l.botUsername,
                  border: const OutlineInputBorder(),
                  prefixText: '@',
                ),
                validator: (v) => normalizeBotUsername(v).isEmpty
                    ? l.botUsernameRequired
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descCtrl,
                decoration: InputDecoration(
                  labelText: l.botDescription,
                  hintText: l.botDescriptionHint,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 3,
                maxLength: 256,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _loading || _uploadingAvatar ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(l.create, style: const TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
