import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../core/constants.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/providers.dart';
import '../../core/network/api_client.dart';
import '../../core/models/user_model.dart';
import '../../l10n/app_localizations.dart';

class _RussianLettersFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final filtered = newValue.text.replaceAll(RegExp(r'[^а-яА-ЯёЁ\s\-]'), '');
    if (filtered == newValue.text) return newValue;
    return TextEditingValue(
      text: filtered,
      selection: TextSelection.collapsed(offset: filtered.length),
    );
  }
}

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late TextEditingController _nicknameCtrl;
  late TextEditingController _aiNameCtrl;
  late TextEditingController _bioCtrl;
  String? _avatarUrl;
  File? _newAvatarFile;
  bool _saving = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authStateProvider).user;
    _nicknameCtrl = TextEditingController(text: user?.name ?? '');
    _aiNameCtrl = TextEditingController(text: user?.aiName ?? '');
    _bioCtrl = TextEditingController(text: user?.bio ?? '');
    _avatarUrl = user?.avatarUrl;
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _aiNameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
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
            if (AppConstants.isValidImageUrl(_avatarUrl))
              ListTile(
                leading: const Icon(CupertinoIcons.trash, color: Colors.red),
                title: Text(l.deletePhoto,
                    style: const TextStyle(color: Colors.red)),
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
      );},
    );
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    final nickname = _nicknameCtrl.text.trim();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.nickCannotBeEmpty)),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final res = await ApiClient().dio.patch('/users/me', data: {
        'name': nickname,
        'aiName': _aiNameCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'avatarUrl': _avatarUrl ?? '',
      });
      final updated = UserModel.fromJson(res.data);
      ref.read(authStateProvider.notifier).updateUser(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.profileUpdated)),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        String msg = l.errorSaving;
        if (e is DioException && e.response?.data is Map) {
          msg = (e.response!.data as Map)['message']?.toString() ?? msg;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final user = ref.watch(authStateProvider).user;
    final publicId = user?.publicId ?? '—';

    return Scaffold(
      appBar: AppBar(
        title: Text(l.editProfileTitle),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    l.save,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.all(16),
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
                          width: 108, height: 108, fit: BoxFit.cover,
                        ),
                      )
                    else
                      UserAvatar(
                        avatarUrl: _avatarUrl,
                        name: _nicknameCtrl.text,
                        radius: 54,
                      ),
                    if (_uploadingAvatar)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.scaffoldBackgroundColor, width: 2,
                          ),
                        ),
                        child: const Icon(
                          CupertinoIcons.camera, size: 18, color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              l.yourId,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(CupertinoIcons.number, size: 18,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      publicId,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: publicId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l.idCopied)),
                      );
                    },
                    child: Icon(CupertinoIcons.doc_on_doc, size: 18,
                        color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                l.idDescription,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              l.nickname,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nicknameCtrl,
              decoration: InputDecoration(
                hintText: l.nicknameHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(CupertinoIcons.person),
              ),
              inputFormatters: [
                _RussianLettersFormatter(),
                LengthLimitingTextInputFormatter(30),
              ],
              textInputAction: TextInputAction.next,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
                return Text(
                  '$currentLength / 30',
                  style: TextStyle(
                    fontSize: 12,
                    color: currentLength >= 30 ? Colors.red : Colors.grey.shade500,
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                l.nicknameDescription,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              l.aiAgentName,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _aiNameCtrl,
              decoration: InputDecoration(
                hintText: l.aiNameHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(CupertinoIcons.sparkles),
              ),
              inputFormatters: [
                _RussianLettersFormatter(),
                LengthLimitingTextInputFormatter(40),
              ],
              textInputAction: TextInputAction.next,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
                return Text(
                  '$currentLength / 40',
                  style: TextStyle(
                    fontSize: 12,
                    color: currentLength >= 40 ? Colors.red : Colors.grey.shade500,
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                l.aiNameDescription,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              l.aboutYou,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bioCtrl,
              decoration: InputDecoration(
                hintText: l.aboutHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(CupertinoIcons.info),
                counterText: '',
              ),
              maxLines: 3,
              inputFormatters: [
                LengthLimitingTextInputFormatter(70),
              ],
              textInputAction: TextInputAction.done,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
                return Text(
                  '$currentLength / 70',
                  style: TextStyle(
                    fontSize: 12,
                    color: currentLength >= 70 ? Colors.red : Colors.grey.shade500,
                  ),
                );
              },
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white,
                        ),
                      )
                    : Text(
                        l.saveChanges,
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
