import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spillcity/data/repositories/providers.dart';
import '../../settings/screens/settings_screen.dart';

// ════════════════════════════════════════════
//  MAIN SETTINGS SCREEN — Matches page.tsx
// ════════════════════════════════════════════
class CallingSettingsPage extends ConsumerStatefulWidget {
  const CallingSettingsPage({super.key});

  @override
  ConsumerState<CallingSettingsPage> createState() => CallingSettingsPageState();
}

class CallingSettingsPageState extends ConsumerState<CallingSettingsPage> {
  String _callPrivacy = 'everyone';
  String _callQuality = 'hd';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
  }

  Future<void> _loadUserSettings() async {
    setState(() => _isLoading = true);
    try {
      final user = await ref.read(authRepositoryProvider).getCurrentUserProfile();
      if (user != null && mounted) {
        setState(() {
          _callPrivacy = user.callPrivacy;
          _callQuality = user.callQuality;
        });
      }
    } catch (e) {
      debugPrint("Failed to load user settings for calling: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changePrivacy(String newVal) async {
    if (newVal == _callPrivacy) return;

    final privacyLabels = {
      'everyone': 'Everyone',
      'following': 'People I Follow',
      'none': 'Nobody',
    };

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[950],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Change call privacy?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          content: Text(
            'Are you sure you want to restrict incoming calls to "${privacyLabels[newVal]}"?',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Change', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _callPrivacy = newVal);
    try {
      await ref.read(authRepositoryProvider).updateCallPrivacy(newVal);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update call privacy: $e')),
      );
    }
  }

  Future<void> _changeQuality(String newVal) async {
    if (newVal == _callQuality) return;

    final qualityLabels = {
      'hd': 'Video HD (720p)',
      'fhd': 'Video FHD (1080p)',
      '2k': 'Video UHD 2K',
      '4k': 'Video UHD 4K',
    };

    String description = 'Are you sure you want to change video call quality to "${qualityLabels[newVal]}"?';
    if (newVal == '2k' || newVal == '4k') {
      description += '\n\nWarning: UHD resolutions require extremely fast network speeds (3.5+ Mbps upload/download) and high-end devices. Calls may disconnect or lag under poor network conditions.';
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[950],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Change video quality?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          content: Text(
            description,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Change', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _callQuality = newVal);
    try {
      await ref.read(authRepositoryProvider).updateCallQuality(newVal);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update call quality: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SettingsSubPage(
      title: 'Calling Settings',
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                // Call Quality Resolution
                _buildSectionHeader('Video Call Quality', theme),
                _buildSectionCard([
                  _buildQualityItem(
                    label: 'Video HD (720p)',
                    sub: 'Standard HD. Clear quality and balanced data usage.',
                    value: 'hd',
                    isSelected: _callQuality == 'hd',
                    theme: theme,
                  ),
                  _buildQualityItem(
                    label: 'Video FHD (1080p)',
                    sub: 'Full High Definition. Sharp details and colors.',
                    value: 'fhd',
                    isSelected: _callQuality == 'fhd',
                    theme: theme,
                  ),
                  _buildQualityItem(
                    label: 'Video UHD 2K',
                    sub: '2K resolution. Premium crystal-clear streams.',
                    value: '2k',
                    isSelected: _callQuality == '2k',
                    theme: theme,
                    badgeText: 'PREMIUM',
                  ),
                  _buildQualityItem(
                    label: 'Video UHD 4K',
                    sub: 'Cinematic quality. Ultra High Definition & High data.',
                    value: '4k',
                    isSelected: _callQuality == '4k',
                    theme: theme,
                    badgeText: '4K ULTRA',
                    isLast: true,
                  ),
                ], theme),
                const SizedBox(height: 24),

                // Call Privacy Settings
                _buildSectionHeader('Who can call me', theme),
                _buildSectionCard([
                  _buildRadioItem(
                    label: 'Everyone',
                    sub: 'Allow any user on the platform to call you',
                    value: 'everyone',
                    isSelected: _callPrivacy == 'everyone',
                    onTap: () => _changePrivacy('everyone'),
                    theme: theme,
                  ),
                  _buildRadioItem(
                    label: 'People I Follow',
                    sub: 'Only accounts you follow can call you',
                    value: 'following',
                    isSelected: _callPrivacy == 'following',
                    onTap: () => _changePrivacy('following'),
                    theme: theme,
                  ),
                  _buildRadioItem(
                    label: 'Nobody',
                    sub: 'Disable all incoming voice and video calls',
                    value: 'none',
                    isSelected: _callPrivacy == 'none',
                    onTap: () => _changePrivacy('none'),
                    theme: theme,
                    isLast: true,
                  ),
                ], theme),
                const SizedBox(height: 24),

                // Important Info help section card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: theme.colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Important Information',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildHelpBullet(
                        'Call Privacy:',
                        'If set to "People I Follow" or "Nobody", incoming calls from restricted users will be automatically blocked, and they will receive a notification that you are not accepting calls.',
                        theme,
                      ),
                      const SizedBox(height: 10),
                      _buildHelpBullet(
                        'Video Quality (2K/4K):',
                        'Higher resolution video streams require high network bandwidth (3.5+ Mbps upload/download speed) and premium devices. If network conditions are poor, calls may disconnect, drop frames, or fail to connect.',
                        theme,
                      ),
                      const SizedBox(height: 10),
                      _buildHelpBullet(
                        'Signaling Connectivity:',
                        'SpillCity utilizes secure private signaling networks. If either user has poor internet connectivity, the call handshake may fail, resulting in a ringing state without initiating the conversation.',
                        theme,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHelpBullet(String title, String desc, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          desc,
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 12,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
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

  Widget _buildSectionCard(List<Widget> children, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.12),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _buildRadioItem({
    required String label,
    required String sub,
    required String value,
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
                  Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(sub, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityItem({
    required String label,
    required String sub,
    required String value,
    required bool isSelected,
    required ThemeData theme,
    String? badgeText,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: () => _changeQuality(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
                  Row(
                    children: [
                      Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      if (badgeText != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF512F), Color(0xFFDD2476)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(sub, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}
