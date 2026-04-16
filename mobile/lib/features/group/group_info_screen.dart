import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';
import '../../core/services/user_search_service.dart';
import '../../core/providers.dart';
import '../../core/widgets/user_avatar.dart';

class GroupInfoScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GroupInfoScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  Map<String, dynamic>? _groupData;
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  String? _myRole;

  @override
  void initState() {
    super.initState();
    _loadGroup();
  }

  Future<void> _loadGroup() async {
    setState(() => _loading = true);
    try {
      final api = ApiClient().dio;
      final res = await api.get('/groups/${widget.groupId}');
      final data = res.data as Map<String, dynamic>;
      final groupInfo = data['groupInfo'] as Map<String, dynamic>?;

      setState(() {
        _groupData = data;
        _myRole = groupInfo?['myRole'] as String?;
        _members = (groupInfo?['members'] as List?)
                ?.cast<Map<String, dynamic>>() ??
            [];
      });
    } catch (e) {
      debugPrint('[GroupInfo] Load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  bool get _isAdmin => _myRole == 'ADMIN' || _myRole == 'OWNER';
  bool get _isOwner => _myRole == 'OWNER';

  Future<void> _addMember() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => const _AddMemberDialog(),
    );
    if (result == null || result.isEmpty) return;

    try {
      await ApiClient().dio.post('/groups/${widget.groupId}/members', data: {'userId': result});
      await _loadGroup();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  Future<void> _removeMember(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить участника?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiClient().dio.delete('/groups/${widget.groupId}/members/$userId');
      await _loadGroup();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  Future<void> _changeRole(String userId, String currentRole) async {
    final roles = ['MEMBER', 'ADMIN'];
    if (_isOwner) roles.add('OWNER');

    final newRole = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Выберите роль'),
        children: roles.map((role) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, role),
            child: Row(
              children: [
                Icon(
                  role == currentRole ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(_roleLabel(role)),
              ],
            ),
          );
        }).toList(),
      ),
    );
    if (newRole == null || newRole == currentRole) return;

    try {
      await ApiClient().dio.patch('/groups/${widget.groupId}/roles', data: {
        'userId': userId,
        'role': newRole,
      });
      await _loadGroup();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  Future<void> _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Покинуть группу?'),
        content: const Text('Вы больше не сможете видеть сообщения этой группы.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Покинуть', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiClient().dio.post('/groups/${widget.groupId}/leave');
      ref.read(conversationsProvider.notifier).load();
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  Future<void> _deleteGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить группу?'),
        content: const Text('Все сообщения и участники будут удалены безвозвратно.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiClient().dio.delete('/groups/${widget.groupId}');
      ref.read(conversationsProvider.notifier).load();
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'OWNER':
        return 'Владелец';
      case 'ADMIN':
        return 'Администратор';
      default:
        return 'Участник';
    }
  }

  Color _roleColor(String role, ThemeData theme) {
    switch (role) {
      case 'OWNER':
        return Colors.amber.shade700;
      case 'ADMIN':
        return theme.colorScheme.primary;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupInfo = _groupData?['groupInfo'] as Map<String, dynamic>?;
    final title = groupInfo?['title'] as String? ?? 'Группа';
    final description = groupInfo?['description'] as String?;
    final memberCount = _members.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Информация о группе'),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showEditDialog(title, description ?? ''),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 24),
                Center(
                  child: UserAvatar(
                    avatarUrl: groupInfo?['avatarUrl'] as String?,
                    name: title,
                    radius: 48,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (description != null && description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                    child: Text(
                      description,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
                  child: Builder(builder: (context) {
                    final onlineCount = _members.where((m) => m['isOnline'] == true).length;
                    final countText = '$memberCount участник${_pluralize(memberCount)}';
                    final onlineText = onlineCount > 0 ? ', $onlineCount в сети' : '';
                    return Text(
                      '$countText$onlineText',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    );
                  }),
                ),
                const Divider(height: 32),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        'Участники',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      if (_isAdmin)
                        TextButton.icon(
                          icon: const Icon(Icons.person_add, size: 18),
                          label: const Text('Добавить'),
                          onPressed: _addMember,
                        ),
                    ],
                  ),
                ),

                ...([..._members]..sort((a, b) {
                  final aOnline = a['isOnline'] == true ? 0 : 1;
                  final bOnline = b['isOnline'] == true ? 0 : 1;
                  if (aOnline != bOnline) return aOnline.compareTo(bOnline);
                  final roleOrder = {'OWNER': 0, 'ADMIN': 1, 'MODERATOR': 2, 'MEMBER': 3};
                  final aRole = roleOrder[a['role']] ?? 3;
                  final bRole = roleOrder[b['role']] ?? 3;
                  return aRole.compareTo(bRole);
                })).map((member) {
                  final userId = member['userId'] as String;
                  final name = member['name'] as String? ?? '';
                  final role = member['role'] as String? ?? 'MEMBER';
                  final isOnline = member['isOnline'] == true;
                  final myUserId = ref.watch(authStateProvider).user?.id;
                  final isMe = userId == myUserId;

                  return ListTile(
                    leading: Stack(
                      children: [
                        UserAvatar(
                          avatarUrl: member['avatarUrl'] as String?,
                          name: name,
                          radius: 22,
                        ),
                        if (isOnline)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            isMe ? '$name (вы)' : name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _roleColor(role, theme).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _roleLabel(role),
                            style: TextStyle(
                              fontSize: 11,
                              color: _roleColor(role, theme),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      isOnline ? 'в сети' : 'не в сети',
                      style: TextStyle(
                        fontSize: 12,
                        color: isOnline ? Colors.green : theme.colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                    onTap: isMe
                        ? null
                        : () => context.push('/profile/$userId'),
                    onLongPress: (!isMe && _isAdmin)
                        ? () => _showMemberActions(userId, name, role)
                        : null,
                  );
                }),

                const Divider(height: 32),

                ListTile(
                  leading: Icon(Icons.exit_to_app, color: Colors.red.shade400),
                  title: Text('Покинуть группу', style: TextStyle(color: Colors.red.shade400)),
                  onTap: _leaveGroup,
                ),
                if (_isOwner)
                  ListTile(
                    leading: Icon(Icons.delete_forever, color: Colors.red.shade700),
                    title: Text('Удалить группу', style: TextStyle(color: Colors.red.shade700)),
                    onTap: _deleteGroup,
                  ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  String _pluralize(int count) {
    if (count % 10 == 1 && count % 100 != 11) return '';
    if (count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20)) return 'а';
    return 'ов';
  }

  void _showMemberActions(String userId, String name, String role) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isOwner)
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('Изменить роль'),
                onTap: () {
                  Navigator.pop(ctx);
                  _changeRole(userId, role);
                },
              ),
            if (_isAdmin && role != 'OWNER')
              ListTile(
                leading: const Icon(Icons.person_remove, color: Colors.red),
                title: Text('Удалить $name', style: const TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _removeMember(userId);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditDialog(String currentTitle, String currentDesc) async {
    final titleCtrl = TextEditingController(text: currentTitle);
    final descCtrl = TextEditingController(text: currentDesc);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Редактировать группу'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Описание'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (result != true) return;
    try {
      await ApiClient().dio.patch('/groups/${widget.groupId}', data: {
        'title': titleCtrl.text.trim(),
        'description': descCtrl.text.trim(),
      });
      _loadGroup();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }
}

class _AddMemberDialog extends StatefulWidget {
  const _AddMemberDialog();

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;

  Future<void> _search(String query) async {
    if (query.length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final results = await UserSearchService.search(query);
      if (mounted) setState(() => _results = results);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Добавить участника'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _ctrl,
              decoration: const InputDecoration(
                hintText: 'Поиск...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _search,
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final user = _results[index];
                  final matchType = user['matchType'] as String? ?? 'name';
                  final isIdMatch = matchType == 'publicId';
                  final theme = Theme.of(context);

                  return ListTile(
                    leading: isIdMatch
                        ? CircleAvatar(
                            radius: 18,
                            backgroundColor: theme.colorScheme.primary.withAlpha(40),
                            child: Icon(Icons.person, size: 18,
                                color: theme.colorScheme.primary),
                          )
                        : UserAvatar(
                            avatarUrl: user['avatarUrl'] as String?,
                            name: user['name'] as String? ?? '',
                            radius: 18,
                          ),
                    title: Text(
                      isIdMatch
                          ? (user['publicId'] as String? ?? '')
                          : (user['name'] as String? ?? ''),
                      style: isIdMatch
                          ? TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              color: theme.colorScheme.primary,
                            )
                          : null,
                    ),
                    subtitle: Text(
                      isIdMatch ? 'Найден по ID' : 'Найден по имени',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                    onTap: () => Navigator.pop(context, user['id'] as String),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
      ],
    );
  }
}
