import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spillcity/data/repositories/providers.dart';
import 'settings_screen.dart';

// ════════════════════════════════════════════
//  MAIN SETTINGS SCREEN — Matches page.tsx
// ════════════════════════════════════════════
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() =>
      NotificationsPageState();
}

class NotificationsPageState extends ConsumerState<NotificationsPage> {
  bool _notifyLikes = true;
  bool _notifyComments = true;
  bool _notifyMentions = true;
  bool _notifyNewPosts = false;
  bool _notifyMessages = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user =
        await ref.read(authRepositoryProvider).getCurrentUserProfile();
    if (user != null && mounted) {
      setState(() {
        _notifyLikes = user.notifyLikes;
        _notifyComments = user.notifyComments;
        _notifyMentions = user.notifyMentions;
        _notifyNewPosts = user.notifyNewPosts;
      });
    }
  }

  void _showToggleConfirmation(
      String label, bool currentValue, Function(bool) onConfirm) {
    final theme = Theme.of(context);
    final newValue = !currentValue;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
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
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: currentValue
                              ? const Color(0xFFFEE2E2)
                              : const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          currentValue ? Icons.close : Icons.check,
                          color: currentValue
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF3B82F6),
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        currentValue
                            ? 'Turn off $label?'
                            : 'Turn on $label?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Are you sure you want to change your ${label.toLowerCase()} notification status?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            onConfirm(newValue);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: currentValue
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF3B82F6),
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: Text(
                            currentValue ? 'Turn Off' : 'Turn On',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancel',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5))),
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

  Future<void> _updateSetting(String key, bool value) async {
    setState(() {
      switch (key) {
        case 'likes':
          _notifyLikes = value;
          break;
        case 'comments':
          _notifyComments = value;
          break;
        case 'mentions':
          _notifyMentions = value;
          break;
        case 'newPosts':
          _notifyNewPosts = value;
          break;
        case 'messages':
          _notifyMessages = value;
          break;
      }
    });

    try {
      await ref.read(authRepositoryProvider).updateNotificationSettings(
        notifyLikes: _notifyLikes,
        notifyComments: _notifyComments,
        notifyMentions: _notifyMentions,
        notifyNewPosts: _notifyNewPosts,
      );
    } catch (e) {
      // Revert on failure
      setState(() {
        switch (key) {
          case 'likes':
            _notifyLikes = !value;
            break;
          case 'comments':
            _notifyComments = !value;
            break;
          case 'mentions':
            _notifyMentions = !value;
            break;
          case 'newPosts':
            _notifyNewPosts = !value;
            break;
          case 'messages':
            _notifyMessages = !value;
            break;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SettingsSubPage(
      title: 'Notifications',
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 10),
            child: Text(
              'PUSH NOTIFICATIONS',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color:
                      theme.colorScheme.outline.withValues(alpha: 0.12),
                  width: 1.5),
            ),
            child: Column(
              children: [
                _buildToggleItem(
                  label: 'Likes',
                  sub: 'When someone likes your post',
                  active: _notifyLikes,
                  onToggle: () => _showToggleConfirmation(
                      'Likes', _notifyLikes, (v) => _updateSetting('likes', v)),
                  theme: theme,
                ),
                _buildToggleItem(
                  label: 'Comments',
                  sub: 'When someone comments on your post',
                  active: _notifyComments,
                  onToggle: () => _showToggleConfirmation('Comments',
                      _notifyComments, (v) => _updateSetting('comments', v)),
                  theme: theme,
                ),
                _buildToggleItem(
                  label: 'Mentions',
                  sub: 'When someone mentions you in a comment',
                  active: _notifyMentions,
                  onToggle: () => _showToggleConfirmation('Mentions',
                      _notifyMentions, (v) => _updateSetting('mentions', v)),
                  theme: theme,
                ),
                _buildToggleItem(
                  label: 'New Posts',
                  sub: 'From accounts you follow',
                  active: _notifyNewPosts,
                  onToggle: () => _showToggleConfirmation('New Posts',
                      _notifyNewPosts, (v) => _updateSetting('newPosts', v)),
                  theme: theme,
                ),
                _buildToggleItem(
                  label: 'Messages',
                  sub: 'When someone sends you a message',
                  active: _notifyMessages,
                  onToggle: () => _showToggleConfirmation('Messages',
                      _notifyMessages, (v) => _updateSetting('messages', v)),
                  theme: theme,
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem({
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: isLast
            ? null
            : BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.08),
                  ),
                ),
              ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                      )),
                ],
              ),
            ),
            // Custom toggle switch — matches TS notification-toggle
            GestureDetector(
              onTap: onToggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: 44,
                height: 24,
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFF3B82F6)
                      : const Color(0xFF374151),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  alignment:
                      active ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 18,
                    height: 18,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════
//  PRIVACY PAGE — Matches privacy/page.tsx
// ════════════════════════════════════════════
