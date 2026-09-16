import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spillcity/data/repositories/providers.dart';
import '../../profile/screens/edit_profile_screen.dart';
import 'privacy_screen.dart';
import 'notifications_settings_screen.dart';
import '../../call/screens/calling_settings_screen.dart';
import 'about_screen.dart';
import 'theme_page.dart';
import 'admin_screen.dart';

// ════════════════════════════════════════════
//  MAIN SETTINGS SCREEN — Matches page.tsx
// ════════════════════════════════════════════
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoggingOut = false;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final selfProfile =
        await ref.read(authRepositoryProvider).getCurrentUserProfile();
    if (selfProfile != null && mounted) {
      setState(() {
        _userRole = selfProfile.role;
      });
    }
  }

  Future<void> _handleLogout() async {
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    setState(() => _isLoggingOut = true);

    try {
      await ref.read(authRepositoryProvider).signOut();
      if (mounted) {
        navigator.popUntil((route) => route.isFirst);
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Logged out successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoggingOut = false);
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Log out failed: $e')),
        );
      }
    }
  }

  void _showLogoutModal() {
    final theme = Theme.of(context);
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
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.logout,
                            color: Color(0xFFEF4444), size: 24),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Logging Out?',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Are you sure you want to log out of your account?',
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
                // Actions
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _handleLogout();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Text('Log Out',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text('Cancel',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
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

  void _showFeedbackModal() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => const FeedbackPage(), fullscreenDialog: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoggingOut) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Signing out...', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 20, 0, 24),
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
                        'Settings',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),

                // Account Group
                _buildSettingsGroup(
                  title: 'Account',
                  items: [
                    SettingsItemData(
                      icon: Icons.edit_outlined,
                      label: 'Edit Profile',
                      sub: 'Change your photo and details',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const EditProfilePage()),
                      ),
                    ),
                    SettingsItemData(
                      icon: Icons.lock_outline,
                      label: 'Privacy',
                      sub: 'Manage visibility and data',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PrivacyPage()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Preferences Group
                _buildSettingsGroup(
                  title: 'Preferences',
                  items: [
                    SettingsItemData(
                      icon: Icons.notifications_none_outlined,
                      label: 'Notifications',
                      sub: 'Configure alerts and sounds',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const NotificationsPage()),
                      ),
                    ),
                    SettingsItemData(
                      icon: Icons.call_outlined,
                      label: 'Calling',
                      sub: 'Manage call quality and privacy',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CallingSettingsPage()),
                      ),
                    ),
                    SettingsItemData(
                      icon: Icons.info_outline,
                      label: 'About',
                      sub: 'Version, terms and licenses',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AboutPage()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Appearance Group
                _buildSettingsGroup(
                  title: 'Appearance',
                  items: [
                    SettingsItemData(
                      icon: Icons.dark_mode_outlined,
                      label: 'Theme',
                      sub: 'Customize your experience',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ThemePage()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Support Group
                _buildSettingsGroup(
                  title: 'Support',
                  items: [
                    SettingsItemData(
                      icon: Icons.chat_bubble_outline,
                      label: 'Feedback',
                      sub: 'Help us improve SpillCity',
                      onTap: _showFeedbackModal,
                    ),
                    SettingsItemData(
                      icon: Icons.logout,
                      label: 'Log Out',
                      sub: 'Sign out of your account',
                      onTap: _showLogoutModal,
                      isDanger: true,
                    ),
                  ],
                ),

                // Admin Group
                if (_userRole == 'admin') ...[
                  const SizedBox(height: 20),
                  _buildSettingsGroup(
                    title: 'Administration',
                    items: [
                      SettingsItemData(
                        icon: Icons.admin_panel_settings_outlined,
                        label: 'Admin Portal',
                        sub: 'Manage feedback and users',
                        onTap: () => _showAdminPortal(),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(
      {required String title, required List<SettingsItemData> items}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 12.0),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              letterSpacing: 1.0,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.12),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: items
                .asMap()
                .entries
                .map((entry) => _buildSettingsItem(
                      data: entry.value,
                      isLast: entry.key == items.length - 1,
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsItem(
      {required SettingsItemData data, bool isLast = false}) {
    final theme = Theme.of(context);
    final color = data.isDanger
        ? const Color(0xFFEF4444)
        : theme.colorScheme.onSurface;

    return InkWell(
      onTap: data.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: isLast
            ? null
            : BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.08),
                    width: 1.5,
                  ),
                ),
              ),
        child: Row(
          children: [
            // Icon box (40x40 with rounded 12px)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: data.isDanger
                    ? const Color(0xFFEF4444).withValues(alpha: 0.08)
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                data.icon,
                size: 20,
                color: data.isDanger
                    ? const Color(0xFFEF4444)
                    : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.sub,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            // Chevron
            Icon(Icons.chevron_right,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }

  void _showAdminPortal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.admin_panel_settings,
                          size: 24, color: Colors.blue),
                      const SizedBox(width: 12),
                      const Text('Admin Portal',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  tabs: const [
                    Tab(
                        icon: Icon(Icons.feedback_outlined),
                        text: 'Feedback Inbox'),
                    Tab(icon: Icon(Icons.security), text: 'Moderation'),
                  ],
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor:
                      theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  indicatorColor: theme.colorScheme.primary,
                ),
                const Expanded(
                  child: TabBarView(
                    children: [
                      AdminFeedbackInbox(),
                      AdminModerationPlaceholder(),
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
}

class SettingsItemData {
  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;
  final bool isDanger;

  SettingsItemData({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
    this.isDanger = false,
  });
}

// ════════════════════════════════════════════
//  SETTINGS SUB-PAGE SCAFFOLD (shared header)
// ════════════════════════════════════════════
class SettingsSubPage extends StatelessWidget {
  final String title;
  final Widget child;

  const SettingsSubPage({super.key, required this.title, required this.child});

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
                // Header matching TS .settings-header
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
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
                        title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════
//  EDIT PROFILE PAGE — Matches edit/page.tsx
// ════════════════════════════════════════════
