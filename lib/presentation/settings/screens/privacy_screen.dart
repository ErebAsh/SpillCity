import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spillcity/data/repositories/providers.dart';
import 'settings_screen.dart';

// ════════════════════════════════════════════
//  MAIN SETTINGS SCREEN — Matches page.tsx
// ════════════════════════════════════════════
class PrivacyPage extends ConsumerStatefulWidget {
  const PrivacyPage({super.key});

  @override
  ConsumerState<PrivacyPage> createState() => PrivacyPageState();
}

class PrivacyPageState extends ConsumerState<PrivacyPage> {
  bool _isPrivateAccount = false;
  bool _showActivityStatus = true;
  String _commentPrivacy = 'Everyone';
  int _blockedCount = 0;
  int _requestCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPrivacyData();
  }

  Future<void> _loadPrivacyData() async {
    try {
      final user =
          await ref.read(authRepositoryProvider).getCurrentUserProfile();
      if (user != null && mounted) {
        setState(() {
          _isPrivateAccount = user.isPrivate;
          _showActivityStatus = user.showActivityStatus;
          _commentPrivacy = user.commentPrivacy;
        });
      }

      final blocked = await ref.read(authRepositoryProvider).getBlockedUsers();
      if (mounted) setState(() => _blockedCount = blocked.length);

      if (_isPrivateAccount) {
        final requests =
            await ref.read(authRepositoryProvider).getFollowRequests();
        if (mounted) setState(() => _requestCount = requests.length);
      }
    } catch (e) {
      // Silently handle
    }
  }

  void _showConfirmDialog({
    required String title,
    required String description,
    required String confirmLabel,
    required VoidCallback onConfirm,
  }) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return Center(
          child: Container(
            width: 320,
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(Icons.shield_outlined,
                            color: theme.colorScheme.primary, size: 24),
                      ),
                      const SizedBox(height: 16),
                      Text(title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                          )),
                      const SizedBox(height: 8),
                      Text(description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                            height: 1.5,
                          )),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            onConfirm();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: Text(confirmLabel,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Not Now',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                              )),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SettingsSubPage(
      title: 'Privacy',
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // Account Privacy
          _buildGroupTitle('Account Privacy', theme),
          _buildGroupCard([
            _buildPrivacyToggle(
              label: 'Private Account',
              sub: 'Only people you approve can see your posts',
              active: _isPrivateAccount,
              onToggle: () => _showConfirmDialog(
                title: _isPrivateAccount
                    ? 'Make Account Public?'
                    : 'Make Account Private?',
                description: _isPrivateAccount
                    ? 'Anyone will be able to see your posts and follow you without approval.'
                    : 'Only people you approve will be able to see your posts and followers.',
                confirmLabel: _isPrivateAccount
                    ? 'Make Public'
                    : 'Switch to Private',
                onConfirm: () async {
                  final newVal = !_isPrivateAccount;
                  setState(() => _isPrivateAccount = newVal);
                  try {
                    await ref
                        .read(authRepositoryProvider)
                        .updateAccountPrivacy(newVal);
                  } catch (e) {
                    setState(() => _isPrivateAccount = !newVal);
                  }
                },
              ),
              theme: theme,
            ),
            _buildPrivacyToggle(
              label: 'Show Activity Status',
              sub: "Allow accounts you follow to see when you're active",
              active: _showActivityStatus,
              onToggle: () => _showConfirmDialog(
                title: _showActivityStatus
                    ? 'Hide Activity Status?'
                    : 'Show Activity Status?',
                description: _showActivityStatus
                    ? "Others won't be able to see when you're active."
                    : 'Allow accounts you follow to see when you were last active.',
                confirmLabel:
                    _showActivityStatus ? 'Hide Status' : 'Show Status',
                onConfirm: () async {
                  final newVal = !_showActivityStatus;
                  setState(() => _showActivityStatus = newVal);
                  try {
                    await ref
                        .read(authRepositoryProvider)
                        .updateActivityStatus(newVal);
                  } catch (e) {
                    setState(() => _showActivityStatus = !newVal);
                  }
                },
              ),
              theme: theme,
              isLast: true,
            ),
          ], theme),
          const SizedBox(height: 20),

          // Interactions
          _buildGroupTitle('Interactions', theme),
          _buildGroupCard([
            _buildLinkItem(
              label: 'Comments & Mentions',
              value: _commentPrivacy,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const _InteractionsPage()),
                );
                _loadPrivacyData();
              },
              theme: theme,
            ),
            _buildLinkItem(
              label: 'Blocked Accounts',
              value: '$_blockedCount Users',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const _BlockedAccountsPage()),
                );
                _loadPrivacyData();
              },
              theme: theme,
            ),
            if (_isPrivateAccount)
              _buildLinkItem(
                label: 'Follow Requests',
                value: '$_requestCount pending',
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const _FollowRequestsPage()),
                  );
                  _loadPrivacyData();
                },
                theme: theme,
                isLast: true,
              ),
          ], theme),
          const SizedBox(height: 20),

          // Personal Data
          _buildGroupTitle('Personal Data', theme),
          _buildGroupCard([
            _buildPrivacyToggle(
              label: 'Personalized Ads',
              sub: 'Show ads based on your interests',
              active: true,
              onToggle: () => _showComingSoonDialog(),
              theme: theme,
            ),
            InkWell(
              onTap: () => _showComingSoonDialog(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Download My Data',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary,
                              )),
                          const SizedBox(height: 2),
                          Text('Request a copy of your information',
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.4),
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ], theme),
        ],
      ),
    );
  }

  Widget _buildGroupTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildGroupCard(List<Widget> children, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.12),
            width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _buildPrivacyToggle({
    required String label,
    required String sub,
    required bool active,
    required VoidCallback onToggle,
    required ThemeData theme,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: isLast
            ? null
            : BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: theme.colorScheme.outline
                            .withValues(alpha: 0.08)))),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.4),
                      )),
                ],
              ),
            ),
            _buildCustomToggle(active),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomToggle(bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 46,
      height: 26,
      decoration: BoxDecoration(
        color: active
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 300),
        alignment: active ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkItem({
    required String label,
    required String value,
    required VoidCallback onTap,
    required ThemeData theme,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: isLast
            ? null
            : BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: theme.colorScheme.outline
                            .withValues(alpha: 0.08)))),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            Text(value,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                )),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }

  void _showComingSoonDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return Center(
          child: Container(
            width: 320,
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.info_outline,
                            color: Color(0xFFF59E0B), size: 24),
                      ),
                      const SizedBox(height: 16),
                      Text('Coming Soon!',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                          )),
                      const SizedBox(height: 8),
                      Text(
                        "We're working hard on this feature. It will be available in a future update.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text('Got it',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Sheets replaced by standalone full sub-pages
}

// ════════════════════════════════════════════
//  INTERACTIONS PAGE — Matches settings/privacy/interactions
// ════════════════════════════════════════════
class _InteractionsPage extends ConsumerStatefulWidget {
  const _InteractionsPage();

  @override
  ConsumerState<_InteractionsPage> createState() => _InteractionsPageState();
}

class _InteractionsPageState extends ConsumerState<_InteractionsPage> {
  String _commentPrivacy = 'Everyone';
  String _mentionPrivacy = 'Everyone';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInteractions();
  }

  Future<void> _loadInteractions() async {
    try {
      final user = await ref.read(authRepositoryProvider).getCurrentUserProfile();
      if (user != null && mounted) {
        setState(() {
          _commentPrivacy = user.commentPrivacy;
          _mentionPrivacy = user.mentionPrivacy;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleUpdate(String type, String value) async {
    setState(() {
      if (type == 'comments') {
        _commentPrivacy = value;
      } else {
        _mentionPrivacy = value;
      }
    });

    try {
      await ref.read(authRepositoryProvider).updateInteractionPrivacy(
        commentPrivacy: type == 'comments' ? value : null,
        mentionPrivacy: type == 'mentions' ? value : null,
      );
    } catch (err) {
      debugPrint('Failed to update interaction privacy: $err');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = ['Everyone', 'People You Follow', 'No One'];

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(Icons.chevron_left,
                              size: 28, color: theme.colorScheme.onSurface),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Interactions',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          children: [
                            _buildGroupTitle('Comments', theme),
                            _buildGroupCard(
                              options.map((option) {
                                final isSelected = _commentPrivacy == option;
                                return _buildOptionItem(
                                  label: option,
                                  isSelected: isSelected,
                                  onTap: () => _handleUpdate('comments', option),
                                  theme: theme,
                                  isLast: option == options.last,
                                );
                              }).toList(),
                              theme,
                            ),
                            _buildInfoText('Choose who can comment on your posts.', theme),
                            const SizedBox(height: 24),
                            _buildGroupTitle('Mentions', theme),
                            _buildGroupCard(
                              options.map((option) {
                                final isSelected = _mentionPrivacy == option;
                                return _buildOptionItem(
                                  label: option,
                                  isSelected: isSelected,
                                  onTap: () => _handleUpdate('mentions', option),
                                  theme: theme,
                                  isLast: option == options.last,
                                );
                              }).toList(),
                              theme,
                            ),
                            _buildInfoText('Choose who can mention you in their comments or posts.', theme),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildGroupCard(List<Widget> children, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.12),
            width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _buildOptionItem({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeData theme,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: isLast
            ? null
            : BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: theme.colorScheme.outline
                            .withValues(alpha: 0.08)))),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            if (isSelected)
              Icon(Icons.check, color: theme.colorScheme.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoText(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          height: 1.4,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════
//  BLOCKED ACCOUNTS PAGE — Matches settings/privacy/blocked
// ════════════════════════════════════════════
class _BlockedAccountsPage extends ConsumerStatefulWidget {
  const _BlockedAccountsPage();

  @override
  ConsumerState<_BlockedAccountsPage> createState() => _BlockedAccountsPageState();
}

class _BlockedAccountsPageState extends ConsumerState<_BlockedAccountsPage> {
  List<Map<String, dynamic>> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    try {
      final users = await ref.read(authRepositoryProvider).getBlockedUsers();
      if (mounted) {
        setState(() {
          _blockedUsers = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleUnblock(String blockedUserId) async {
    try {
      await ref.read(authRepositoryProvider).unblockUser(blockedUserId);
      setState(() {
        _blockedUsers.removeWhere((item) {
          final userJson = item['blocked_user'] as Map<String, dynamic>? ?? {};
          return userJson['id'] == blockedUserId;
        });
      });
    } catch (err) {
      debugPrint('Failed to unblock user: $err');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(Icons.chevron_left,
                              size: 28, color: theme.colorScheme.onSurface),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Blocked Accounts',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _blockedUsers.isEmpty
                          ? _buildEmptyState(theme)
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _blockedUsers.length,
                              separatorBuilder: (context, index) => Divider(
                                height: 1,
                                color: theme.colorScheme.outline.withValues(alpha: 0.08),
                                indent: 72,
                              ),
                              itemBuilder: (context, index) {
                                final item = _blockedUsers[index];
                                final userJson = item['blocked_user'] as Map<String, dynamic>? ?? {};
                                final name = userJson['name'] as String? ?? 'User';
                                final username = userJson['username'] as String? ?? '';
                                final avatar = userJson['profile_picture'] as String? ?? userJson['profilePicture'] as String? ?? userJson['avatar'] as String? ?? '';
                                final hasAvatar = avatar.isNotEmpty && !avatar.contains('ui-avatars.com');
                                final blockedUserId = userJson['id'] as String? ?? '';

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  leading: CircleAvatar(
                                    radius: 20,
                                    backgroundImage: hasAvatar ? NetworkImage(avatar) : null,
                                    child: !hasAvatar ? Text(name.substring(0, 1).toUpperCase()) : null,
                                  ),
                                  title: Text(
                                    name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  subtitle: Text('@$username', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
                                  trailing: ElevatedButton(
                                    onPressed: () => _handleUnblock(blockedUserId),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                                      foregroundColor: theme.colorScheme.primary,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    ),
                                    child: const Text('Unblock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.block,
                size: 32,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Blocked Accounts',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Accounts you block will appear here. You haven't blocked anyone yet.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════
//  FOLLOW REQUESTS PAGE — Matches settings/privacy/requests
// ════════════════════════════════════════════
class _FollowRequestsPage extends ConsumerStatefulWidget {
  const _FollowRequestsPage();

  @override
  ConsumerState<_FollowRequestsPage> createState() => _FollowRequestsPageState();
}

class _FollowRequestsPageState extends ConsumerState<_FollowRequestsPage> {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    try {
      final data = await ref.read(authRepositoryProvider).getFollowRequests();
      if (mounted) {
        setState(() {
          _requests = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleAction(String requestId, String followerId, bool accept) async {
    try {
      await ref.read(authRepositoryProvider).respondToFollowRequest(requestId, followerId, accept);
      setState(() {
        _requests.removeWhere((item) => item['id'] == requestId);
      });
    } catch (err) {
      debugPrint('Failed to handle follow request: $err');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context, true),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(Icons.chevron_left,
                              size: 28, color: theme.colorScheme.onSurface),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Follow Requests',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _requests.isEmpty
                          ? _buildEmptyState(theme)
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _requests.length,
                              separatorBuilder: (context, index) => Divider(
                                height: 1,
                                color: theme.colorScheme.outline.withValues(alpha: 0.08),
                                indent: 72,
                              ),
                              itemBuilder: (context, index) {
                                final item = _requests[index];
                                final requestId = item['id'] as String;
                                final followerJson = item['follower'] as Map<String, dynamic>? ?? {};
                                final followerId = followerJson['id'] as String? ?? '';
                                final name = followerJson['name'] as String? ?? 'User';
                                final username = followerJson['username'] as String? ?? '';
                                final avatar = followerJson['profile_picture'] as String? ?? followerJson['profilePicture'] as String? ?? followerJson['avatar'] as String? ?? '';
                                 final hasAvatar = avatar.isNotEmpty && !avatar.contains('ui-avatars.com');

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  leading: CircleAvatar(
                                    radius: 20,
                                    backgroundImage: hasAvatar ? NetworkImage(avatar) : null,
                                    child: !hasAvatar ? Text(name.substring(0, 1).toUpperCase()) : null,
                                  ),
                                  title: Text(
                                    name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  subtitle: Text('@$username', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ElevatedButton(
                                        onPressed: () => _handleAction(requestId, followerId, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: theme.colorScheme.primary,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        ),
                                        child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton(
                                        onPressed: () => _handleAction(requestId, followerId, false),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: theme.colorScheme.onSurface,
                                          side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        ),
                                        child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.people_outline,
                size: 32,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Follow Requests',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "When people ask to follow you, their requests will appear here.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════
//  THEME PAGE — Matches theme/page.tsx
// ════════════════════════════════════════════
