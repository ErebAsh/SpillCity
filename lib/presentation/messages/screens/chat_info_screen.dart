import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:spillcity/presentation/call/providers/global_call_manager.dart';
import 'package:spillcity/domain/entities/user.dart';
import 'package:spillcity/data/repositories/providers.dart';
import 'package:spillcity/presentation/profile/screens/profile_screen.dart';

// ─── Format Time Utility ───
class ChatInfoScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final Map<String, dynamic> threadDetails;
  final bool vanishMode;
  final bool isMuted;
  final Function(bool) onVanishToggle;
  final Function(bool) onMuteToggle;
  final VoidCallback onChatDeleted;

  const ChatInfoScreen({super.key, 
    required this.conversationId,
    required this.threadDetails,
    required this.vanishMode,
    required this.isMuted,
    required this.onVanishToggle,
    required this.onMuteToggle,
    required this.onChatDeleted,
  });

  @override
  ConsumerState<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends ConsumerState<ChatInfoScreen> {
  late bool _vanish;
  late bool _mute;

  @override
  void initState() {
    super.initState();
    _vanish = widget.vanishMode;
    _mute = widget.isMuted;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final otherUser = widget.threadDetails['otherUser'] as UserModel;
    final avatarUrl = otherUser.resolvedAvatarUrl;
    final hasAvatar = avatarUrl.isNotEmpty && !avatarUrl.contains('ui-avatars.com');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Avatar & name
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ProfileScreen(userId: otherUser.id)),
                  );
                },
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
                      child: !hasAvatar
                          ? Text(otherUser.name.isNotEmpty ? otherUser.name.substring(0, 1).toUpperCase() : '?',
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold))
                          : null,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      otherUser.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Active now',
                      style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Quick action buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildQuickAction(Icons.person_outline, 'Profile', () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ProfileScreen(userId: otherUser.id)),
                      );
                    }, theme),
                    _buildQuickAction(Icons.call_outlined, 'Audio', () async {
                      final u = widget.threadDetails['otherUser'] as UserModel?;
                      Navigator.pop(context);
                      if (u != null) {
                        final error = await ref.read(callManagerProvider.notifier).initiateCall('voice', u);
                        if (error != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error)),
                          );
                        }
                      }
                    }, theme),
                    _buildQuickAction(Icons.videocam_outlined, 'Video', () async {
                      final u = widget.threadDetails['otherUser'] as UserModel?;
                      Navigator.pop(context);
                      if (u != null) {
                        final error = await ref.read(callManagerProvider.notifier).initiateCall('video', u);
                        if (error != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error)),
                          );
                        }
                      }
                    }, theme),
                    _buildQuickAction(
                      _mute ? Icons.volume_off : Icons.notifications_outlined,
                      _mute ? 'Unmute' : 'Mute',
                      () {
                        setState(() => _mute = !_mute);
                        widget.onMuteToggle(_mute);
                      },
                      theme,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              // Settings
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 16, bottom: 8),
                      child: Text('Chat Settings', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    ),
                    SwitchListTile(
                      secondary: Icon(Icons.timer_outlined, color: _vanish ? const Color(0xFF00B4FF) : null),
                      title: const Text('Vanish Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                      value: _vanish,
                      onChanged: (val) {
                        setState(() => _vanish = val);
                        widget.onVanishToggle(val);
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.block, color: Colors.red),
                      title: const Text('Block User', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Block User?'),
                            content: const Text(
                              'They will no longer be able to find your profile or see your messages.',
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                child: const Text('Block'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true && context.mounted) {
                          final container = ProviderScope.containerOf(context);
                          await container.read(authRepositoryProvider).blockUser(otherUser.id);
                          if (context.mounted) {
                            Navigator.pop(context); // Close ChatInfoScreen
                            widget.onChatDeleted();
                          }
                        }
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.delete_outline, color: Colors.red),
                      title: const Text('Delete Chat', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Chat?'),
                            content: const Text(
                              'This will permanently remove this conversation. This action cannot be undone.',
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true && context.mounted) {
                          final supabase = Supabase.instance.client;
                          await supabase.from('conversations').delete().eq('id', widget.conversationId);
                          if (context.mounted) {
                            Navigator.pop(context); // Close ChatInfoScreen
                            widget.onChatDeleted();
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap, ThemeData theme) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
