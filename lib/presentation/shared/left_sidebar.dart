import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spillcity/data/repositories/providers.dart';

class LeftSidebar extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const LeftSidebar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserAsync = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final unreadMessagesCount = ref.watch(unreadMessageCountProvider).valueOrNull ?? 0;
    final unreadNotificationsCount = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;

    final navItems = [
      {'label': 'Home', 'icon': Icons.home_outlined, 'activeIcon': Icons.home},
      {'label': 'Explore', 'icon': Icons.search_outlined, 'activeIcon': Icons.search},
      {'label': 'Create Post', 'icon': Icons.add_box_outlined, 'activeIcon': Icons.add_box},
      {'label': 'Notifications', 'icon': Icons.notifications_outlined, 'activeIcon': Icons.notifications},
      {'label': 'Messages', 'icon': Icons.mail_outlined, 'activeIcon': Icons.mail},
      {'label': 'Profile', 'icon': Icons.person_outline, 'activeIcon': Icons.person},
    ];

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 📰 Logo Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.blue, Colors.purple],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Text('📰', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      text: 'Proxy',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: -0.3,
                      ),
                      children: const [
                        TextSpan(
                          text: 'Press',
                          style: TextStyle(color: Colors.blue),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    'College News',
                    style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'MENU',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          // Navigation List
          Expanded(
            child: ListView.builder(
              itemCount: navItems.length,
              itemBuilder: (context, index) {
                final item = navItems[index];
                final isSelected = currentIndex == index;
                final isCreate = index == 2; // Create Post button is styled differently

                if (isCreate) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.blue, Colors.purple],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        onTap: () => onTabSelected(index),
                        dense: true,
                        leading: Icon(item['activeIcon'] as IconData, color: Colors.white),
                        title: Text(
                          item['label'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: ListTile(
                    onTap: () => onTabSelected(index),
                    dense: true,
                    selected: isSelected,
                    selectedTileColor: Colors.blue.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: Icon(
                      isSelected ? (item['activeIcon'] as IconData) : (item['icon'] as IconData),
                      color: isSelected ? Colors.blue : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    title: Text(
                      item['label'] as String,
                      style: TextStyle(
                        color: isSelected ? Colors.blue : theme.colorScheme.onSurface,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    trailing: () {
                      if (index == 3 && unreadNotificationsCount > 0) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unreadNotificationsCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }
                      if (index == 4 && unreadMessagesCount > 0) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unreadMessagesCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }
                      return null;
                    }(),
                  ),
                );
              },
            ),
          ),
          // Bottom Section Divider
          const Divider(),
          // Dark Mode Toggle Row
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
            child: Row(
              children: [
                Icon(
                  isDark ? Icons.dark_mode : Icons.light_mode,
                  size: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 8),
                Text(
                  'Dark Mode',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
                const Spacer(),
                Switch(
                  value: isDark,
                  onChanged: (val) {
                    // Update theme mode state dynamically if using a provider
                  },
                ),
              ],
            ),
          ),
          // Profile Widget at the bottom
          currentUserAsync.when(
            data: (user) {
              if (user == null) return const SizedBox.shrink();
              return InkWell(
                onTap: () => onTabSelected(5),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundImage: () {
                          final avatarUrl = user.resolvedAvatarUrl;
                          if (avatarUrl.startsWith('http') && !avatarUrl.contains('ui-avatars.com')) {
                            return NetworkImage(avatarUrl);
                          }
                          return null;
                        }(),
                        child: () {
                          final avatarUrl = user.resolvedAvatarUrl;
                          if (avatarUrl.isEmpty || !avatarUrl.startsWith('http') || avatarUrl.contains('ui-avatars.com')) {
                            return Text(
                              avatarUrl.isNotEmpty && !avatarUrl.startsWith('http') ? avatarUrl : user.name[0].toUpperCase(),
                            );
                          }
                          return null;
                        }(),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '@${user.username ?? user.id.substring(0, 6)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (err, stack) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
