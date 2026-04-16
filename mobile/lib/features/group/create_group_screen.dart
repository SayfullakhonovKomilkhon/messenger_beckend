import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';
import '../../core/services/user_search_service.dart';
import '../../core/providers.dart';
import '../../core/widgets/user_avatar.dart';
import '../../l10n/app_localizations.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _searchController = TextEditingController();

  final Set<_UserEntry> _selectedMembers = {};
  List<Map<String, dynamic>> _searchResults = [];
  bool _searchLoading = false;
  bool _creating = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searchLoading = true);
    try {
      final results = await UserSearchService.search(query);
      if (mounted) setState(() => _searchResults = results);
    } catch (_) {}
    if (mounted) setState(() => _searchLoading = false);
  }

  Future<void> _createGroup() async {
    final l = AppLocalizations.of(context)!;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.enterGroupName)),
      );
      return;
    }

    setState(() => _creating = true);
    try {
      final res = await ApiClient().dio.post('/groups', data: {
        'title': title,
        'description': _descController.text.trim(),
        'memberIds': _selectedMembers.map((m) => m.id).toList(),
      });

      final convId = res.data['id'] as String;
      ref.read(conversationsProvider.notifier).load();

      if (mounted) {
        context.pop();
        context.push('/conversation/$convId?name=${Uri.encodeComponent(title)}&isGroup=true');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l.error}: $e')),
        );
      }
    }
    if (mounted) setState(() => _creating = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final myId = ref.watch(authStateProvider).user?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.newGroup),
        actions: [
          TextButton(
            onPressed: _creating ? null : _createGroup,
            child: _creating
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l.create),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: l.groupName,
                    border: const OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descController,
                  decoration: InputDecoration(
                    labelText: l.groupDescriptionOptional,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
          ),

          if (_selectedMembers.isNotEmpty)
            SizedBox(
              height: 72,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _selectedMembers.length,
                itemBuilder: (context, index) {
                  final member = _selectedMembers.elementAt(index);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            member.matchType == 'publicId'
                                ? CircleAvatar(
                                    radius: 22,
                                    backgroundColor: theme.colorScheme.primary.withAlpha(40),
                                    child: Icon(CupertinoIcons.person, size: 20,
                                        color: theme.colorScheme.primary),
                                  )
                                : UserAvatar(avatarUrl: member.avatar, name: member.displayLabel, radius: 22),
                            Positioned(
                              right: -2,
                              top: -2,
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedMembers.remove(member)),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.error,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, size: 12, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 56,
                          child: Text(
                            member.displayLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l.searchByNameOrId,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
              onChanged: _search,
            ),
          ),
          const SizedBox(height: 8),

          if (_searchLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),

          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final user = _searchResults[index];
                final userId = user['id'] as String;
                if (userId == myId) return const SizedBox.shrink();

                final matchType = user['matchType'] as String? ?? 'name';
                final isPublicIdMatch = matchType == 'publicId';

                final entry = _UserEntry(
                  id: userId,
                  publicId: user['publicId'] as String?,
                  name: user['name'] as String?,
                  avatar: user['avatarUrl'] as String?,
                  matchType: matchType,
                );
                final isSelected = _selectedMembers.contains(entry);

                return ListTile(
                  leading: isPublicIdMatch
                      ? CircleAvatar(
                          radius: 22,
                          backgroundColor: theme.colorScheme.primary.withAlpha(40),
                          child: Icon(CupertinoIcons.person, size: 22,
                              color: theme.colorScheme.primary),
                        )
                      : UserAvatar(
                          avatarUrl: user['avatarUrl'] as String?,
                          name: user['name'] as String? ?? '',
                          radius: 22,
                        ),
                  title: Text(
                    isPublicIdMatch
                        ? (user['publicId'] as String? ?? '')
                        : (user['name'] as String? ?? ''),
                    style: isPublicIdMatch
                        ? TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                  ),
                  subtitle: Text(
                    isPublicIdMatch
                        ? l.foundById
                        : l.foundByName,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                    ),
                  ),
                  trailing: Checkbox(
                    value: isSelected,
                    onChanged: (_) {
                      setState(() {
                        if (isSelected) {
                          _selectedMembers.remove(entry);
                        } else {
                          _selectedMembers.add(entry);
                        }
                      });
                    },
                  ),
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedMembers.remove(entry);
                      } else {
                        _selectedMembers.add(entry);
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UserEntry {
  final String id;
  final String? publicId;
  final String? name;
  final String? avatar;
  final String matchType;

  const _UserEntry({
    required this.id,
    this.publicId,
    this.name,
    this.avatar,
    this.matchType = 'name',
  });

  String get displayLabel {
    if (matchType == 'publicId') return publicId ?? 'ID';
    return name ?? '';
  }

  @override
  bool operator ==(Object other) => other is _UserEntry && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
