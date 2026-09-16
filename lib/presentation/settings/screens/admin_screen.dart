import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ════════════════════════════════════════════
//  MAIN SETTINGS SCREEN — Matches page.tsx
// ════════════════════════════════════════════
class FeedbackPage extends ConsumerStatefulWidget {
  const FeedbackPage({super.key});

  @override
  ConsumerState<FeedbackPage> createState() => FeedbackPageState();
}

class FeedbackPageState extends ConsumerState<FeedbackPage> {
  String _selectedType = 'Suggestion';
  final _messageController = TextEditingController();
  bool _isSubmitting = false;
  bool _showSuccess = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final supabase = Supabase.instance.client;
      final currentUserId = supabase.auth.currentUser?.id;

      await supabase.from('feedback').insert({
        'userId': currentUserId,
        'type': _selectedType,
        'message': message,
      });

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _showSuccess = true;
        });

        _messageController.clear();
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send feedback: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: _showSuccess
                ? _buildSuccessState(theme)
                : _buildFeedbackForm(theme),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.check, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 20),
          Text('Thank You!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              )),
          const SizedBox(height: 8),
          Text(
            'Your feedback helps us make SpillCity better for everyone.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackForm(ThemeData theme) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(Icons.close,
                      size: 24, color: theme.colorScheme.onSurface),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              const SizedBox(height: 12),
              // Icon
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.chat_bubble_outline,
                      color: theme.colorScheme.primary, size: 24),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text('Share Feedback',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    )),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Have a suggestion or found a bug? Let us know!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.5),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Type selector — 3-column grid matching TS
              Row(
                children: ['Suggestion', 'Bug', 'Other'].map((type) {
                  final isActive = _selectedType == type;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          left: type == 'Suggestion' ? 0 : 4,
                          right: type == 'Other' ? 0 : 4),
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _selectedType = type),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding:
                              const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isActive
                                ? theme.colorScheme.primary
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isActive
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline
                                      .withValues(alpha: 0.15),
                              width: 1.5,
                            ),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.2),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              type,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isActive
                                    ? Colors.white
                                    : theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Textarea
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: theme.colorScheme.outline
                          .withValues(alpha: 0.12),
                      width: 1.5),
                ),
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  expands: true,
                  enabled: !_isSubmitting,
                  style: TextStyle(
                    fontSize: 15,
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: "Tell us what's on your mind...",
                    hintStyle: TextStyle(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.3)),
                    contentPadding: const EdgeInsets.all(14),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text('Cancel',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          )),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ||
                              _messageController.text.trim().isEmpty
                          ? null
                          : _submitFeedback,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: theme.colorScheme.primary
                            .withValues(alpha: 0.4),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text(
                        _isSubmitting ? 'Sending...' : 'Send Feedback',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════
//  ADMIN WIDGETS
// ════════════════════════════════════════════
class AdminFeedbackInbox extends StatefulWidget {
  const AdminFeedbackInbox({super.key});

  @override
  State<AdminFeedbackInbox> createState() => AdminFeedbackInboxState();
}

class AdminFeedbackInboxState extends State<AdminFeedbackInbox> {
  late Future<List<Map<String, dynamic>>> _feedbacksFuture;

  @override
  void initState() {
    super.initState();
    _loadFeedbacks();
  }

  void _loadFeedbacks() {
    final supabase = Supabase.instance.client;
    setState(() {
      _feedbacksFuture = supabase
          .from('feedback')
          .select(
              'id, type, message, created_at, userId, user:users(name, email)')
          .order('created_at', ascending: false)
          .then((res) => List<Map<String, dynamic>>.from(res as List));
    });
  }

  Future<void> _resolveFeedback(String feedbackId) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('feedback').delete().eq('id', feedbackId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feedback resolved.')),
        );
      }
      _loadFeedbacks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _feedbacksFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final feedbacks = snapshot.data!;
        if (feedbacks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                const Text('All caught up!',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text('No user feedback currently awaiting review.',
                    style: TextStyle(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5))),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: feedbacks.length,
          itemBuilder: (context, index) {
            final fb = feedbacks[index];
            final id = fb['id'] as String;
            final type = fb['type'] as String? ?? 'Feedback';
            final message = fb['message'] as String? ?? '';
            final userMap = fb['user'] as Map<String, dynamic>?;
            final userName = userMap?['name'] as String? ?? 'Anonymous';
            final dateStr = fb['created_at'] as String? ?? '';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: type == 'Bug'
                                ? Colors.redAccent.withValues(alpha: 0.2)
                                : Colors.blueAccent
                                    .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(type.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: type == 'Bug'
                                    ? Colors.red
                                    : Colors.blue,
                              )),
                        ),
                        const Spacer(),
                        Text(
                          dateStr.length > 10
                              ? dateStr.substring(0, 10)
                              : dateStr,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(message,
                        style: const TextStyle(
                            fontSize: 13, height: 1.3)),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(userName,
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold)),
                        ),
                        TextButton(
                          onPressed: () => _resolveFeedback(id),
                          child: const Text('Resolve',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class AdminModerationPlaceholder extends StatelessWidget {
  const AdminModerationPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.security, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          const Text('Moderation Queue',
              style: TextStyle(fontWeight: FontWeight.bold)),
          Text('No reports pending.',
              style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }
}

// ─── CALLING SETTINGS SCREEN ───
// Stateful widget to configure calling privacy and Agora resolution settings
