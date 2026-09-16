import 'chat_info_screen.dart';
import 'package:spillcity/core/utils/helpers.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:spillcity/presentation/call/providers/global_call_manager.dart';
import 'package:spillcity/domain/entities/user.dart';
import 'package:spillcity/presentation/profile/screens/profile_screen.dart';
import '../widgets/media_lightbox.dart';

// ─── Format Time Utility ───
class ChatConversationPanel extends ConsumerStatefulWidget {
  final String conversationId;
  final Map<String, dynamic> threadDetails;
  final VoidCallback onBack;

  const ChatConversationPanel({super.key, 
    required this.conversationId,
    required this.threadDetails,
    required this.onBack,
  });

  @override
  ConsumerState<ChatConversationPanel> createState() => _ChatConversationPanelState();
}

class _ChatConversationPanelState extends ConsumerState<ChatConversationPanel> {
  final _msgInputController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  bool _isSending = false;
  bool _vanishMode = false;
  bool _isMuted = false;

  late String _currentConvId;
  Stream<List<Map<String, dynamic>>>? _messageStream;

  // Message being replied to
  Map<String, dynamic>? _replyingToMessage;

  // Selected message (long-press selection mode)
  Map<String, dynamic>? _selectedMessage;

  // UI toggles
  bool _showEmojiPicker = false;
  bool _showShareMenu = false;

  // Editing
  String? _editingMessageId;
  final _editController = TextEditingController();

  // Voice recording state (stubbed)
  bool _isVoiceRecording = false;
  int _voiceRecordingDuration = 0;
  Timer? _voiceRecordTimer;

  /// Fire-and-forget: calls the message-notification Edge Function
  Future<void> _sendMessageNotification(
    String targetUserId, String senderName, String senderAvatar,
    String messageText, String conversationId,
  ) async {
    try {
      await Supabase.instance.client.functions.invoke(
        'message-notification',
        body: {
          'targetUserId': targetUserId,
          'senderName': senderName,
          'senderAvatar': senderAvatar,
          'messageText': messageText,
          'conversationId': conversationId,
        },
      );
    } catch (e) {
      debugPrint('[MsgPush] Failed to send message notification: $e');
    }
  }

  void _initMessageStream() {
    if (_currentConvId.startsWith('new_')) {
      _messageStream = Stream.value([]);
    } else {
      _messageStream = Supabase.instance.client
          .from('messages')
          .stream(primaryKey: ['id'])
          .eq('conversation_id', _currentConvId)
          .order('timestamp', ascending: false)
          .map((list) {
            final myId = Supabase.instance.client.auth.currentUser?.id;
            final hasUnseen = list.any((msg) =>
                msg['sender_id'] != myId && (msg['seen'] as bool? ?? false) == false);
            if (hasUnseen) {
              _markMessagesAsSeen();
            }
            return list;
          });
    }
  }

  @override
  void initState() {
    super.initState();
    _currentConvId = widget.conversationId;
    _vanishMode = widget.threadDetails['vanishMode'] as bool? ?? false;
    _isMuted = widget.threadDetails['muted'] as bool? ?? false;
    _initMessageStream();
    _loadChatSettings();
    _markMessagesAsSeen();
  }

  @override
  void dispose() {
    _msgInputController.dispose();
    _scrollController.dispose();
    _editController.dispose();
    _voiceRecordTimer?.cancel();
    super.dispose();
  }

  Future<void> _markMessagesAsSeen() async {
    if (_currentConvId.startsWith('new_')) return;
    try {
      final supabase = Supabase.instance.client;
      final myId = supabase.auth.currentUser?.id;
      if (myId == null) return;
      await supabase
          .from('messages')
          .update({'seen': true})
          .eq('conversation_id', _currentConvId)
          .neq('sender_id', myId)
          .eq('seen', false);
    } catch (_) {}
  }

  Future<void> _loadChatSettings() async {
    if (_currentConvId.startsWith('new_')) return;
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('conversations')
          .select('vanish_mode, muted')
          .eq('id', _currentConvId)
          .maybeSingle();
      if (response != null && mounted) {
        setState(() {
          _vanishMode = response['vanish_mode'] as bool? ?? response['vanishMode'] as bool? ?? false;
          _isMuted = response['muted'] as bool? ?? false;
        });
      }
    } catch (e) {
      debugPrint("Failed to load chat settings: $e");
    }
  }

  Future<void> _toggleVanishMode(bool val) async {
    if (_currentConvId.startsWith('new_')) return;
    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('conversations')
          .update({'vanish_mode': val})
          .eq('id', _currentConvId);
      setState(() => _vanishMode = val);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vanish Mode ${val ? 'On · 1h' : 'Off'}')),
        );
      }
    } catch (e) {
      debugPrint("Failed to toggle vanish mode: $e");
    }
  }

  Future<void> _toggleMuteThread(bool val) async {
    if (_currentConvId.startsWith('new_')) return;
    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('conversations')
          .update({'muted': val})
          .eq('id', _currentConvId);
      setState(() => _isMuted = val);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chat ${val ? 'Muted' : 'Notifications On'}')),
        );
      }
    } catch (e) {
      debugPrint("Failed to toggle mute thread: $e");
    }
  }

  Future<String> _resolveConversationId() async {
    if (!_currentConvId.startsWith('new_')) return _currentConvId;

    final supabaseClient = Supabase.instance.client;
    final currentUserId = supabaseClient.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('Not authenticated');

    final targetUserId = _currentConvId.replaceFirst('new_', '');

    // Check blocks
    final blockCheck = await supabaseClient
        .from('user_blocks')
        .select()
        .or('and(user_id.eq.$currentUserId,blocked_id.eq.$targetUserId),and(user_id.eq.$targetUserId,blocked_id.eq.$currentUserId)')
        .maybeSingle();
    if (blockCheck != null) {
      throw Exception('Cannot send message to a blocked user');
    }

    // Check existing conversation
    final myParticipants = await supabaseClient
        .from('conversation_participants')
        .select('conversation_id')
        .eq('user_id', currentUserId);
    final List<String> myConvIds = (myParticipants as List<dynamic>).map((c) => c['conversation_id'] as String).toList();

    if (myConvIds.isNotEmpty) {
      final otherParticipants = await supabaseClient
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', targetUserId)
          .inFilter('conversation_id', myConvIds)
          .limit(1)
          .maybeSingle();
      if (otherParticipants != null) {
        _currentConvId = otherParticipants['conversation_id'] as String;
        setState(() {
          _initMessageStream();
        });
        return _currentConvId;
      }
    }

    // Create new conversation
    final newConvId = 'c${DateTime.now().millisecondsSinceEpoch}';
    final nowIso = DateTime.now().toUtc().toIso8601String();

    await supabaseClient.from('conversations').insert({
      'id': newConvId,
      'last_message': '',
      'last_message_time': nowIso,
    });

    await supabaseClient.from('conversation_participants').insert([
      {'conversation_id': newConvId, 'user_id': currentUserId},
      {'conversation_id': newConvId, 'user_id': targetUserId},
    ]);

    _currentConvId = newConvId;
    setState(() {
      _initMessageStream();
    });
    return _currentConvId;
  }

  Future<void> _sendMessage({String? attachmentUrl, String type = 'text', String? overrideText}) async {
    final text = overrideText ?? _msgInputController.text.trim();
    if (text.isEmpty && attachmentUrl == null) return;

    setState(() => _isSending = true);

    try {
      final supabaseClient = Supabase.instance.client;
      final currentUserId = supabaseClient.auth.currentUser?.id;
      if (currentUserId == null) return;

      final convId = await _resolveConversationId();

      String messageText = text;
      if (type == 'image' && text.isEmpty) messageText = '📷 Sent an image';
      // Heart is sent via _sendHeart() which adds ❤️ via overrideText
      if (type == 'video' && text.isEmpty) messageText = '🎥 Sent a video';
      if (type == 'file' && text.isEmpty) messageText = '📄 Sent a file';
      if (type == 'voice') messageText = '🎤 Voice message';
      if (type == 'heart') messageText = '❤️';

      final replyId = _replyingToMessage?['id']?.toString();
      await supabaseClient.from('messages').insert({
        'id': 'm${DateTime.now().millisecondsSinceEpoch}',
        'conversation_id': convId,
        'sender_id': currentUserId,
        'text': messageText,
        'type': type,
        'attachment': attachmentUrl,
        'reply_to': replyId,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });

      await supabaseClient.from('conversations').update({
        'last_message': messageText,
        'last_message_time': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', convId);

      // Fire-and-forget: send push notification to recipient
      final otherUser = widget.threadDetails['otherUser'] as UserModel?;
      if (otherUser != null) {
        final myMeta = supabaseClient.auth.currentUser?.userMetadata;
        final myName = myMeta?['name'] as String? ?? myMeta?['full_name'] as String? ?? 'Someone';
        final myAvatar = myMeta?['profile_picture'] as String? ?? myMeta?['avatar_url'] as String? ?? '';
        _sendMessageNotification(otherUser.id, myName, myAvatar, messageText, convId);
      }

      _msgInputController.clear();
      setState(() {
        _replyingToMessage = null;
        _showEmojiPicker = false;
        _showShareMenu = false;
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint("Failed to send message: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendHeart() async {
    await _sendMessage(type: 'heart', overrideText: '❤️');
  }

  Future<void> _pickAndSendMedia(String type) async {
    try {
      XFile? file;
      if (type == 'image') {
        file = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      } else if (type == 'video') {
        file = await _imagePicker.pickVideo(source: ImageSource.gallery);
      }
      if (file == null) return;
      if (!mounted) return;

      setState(() => _showShareMenu = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uploading $type...')),
      );

      final supabaseClient = Supabase.instance.client;
      final fileExtension = file.path.split('.').last;
      final fileName = 'msg_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

      await supabaseClient.storage
          .from('messages')
          .upload(fileName, File(file.path));

      final publicUrl = supabaseClient.storage.from('messages').getPublicUrl(fileName);
      await _sendMessage(attachmentUrl: publicUrl, type: type);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to attach: $e')),
      );
    }
  }

  Future<void> _pickAndSendDocument() async {
    // Stub: Document picker would need file_picker package
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document sharing coming soon!')),
      );
    }
    setState(() => _showShareMenu = false);
  }

  void _startVoiceRecording() {
    // Stub: Would need record/flutter_sound package
    setState(() {
      _isVoiceRecording = true;
      _voiceRecordingDuration = 0;
    });
    _voiceRecordTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) {
        setState(() => _voiceRecordingDuration++);
      }
    });
  }

  void _stopVoiceRecording(bool shouldSend) {
    _voiceRecordTimer?.cancel();
    setState(() => _isVoiceRecording = false);
    if (shouldSend) {
      // Stub: would send the recorded audio
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice messages coming soon!')),
      );
    }
  }

  String _formatRecordDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _editMessage(String msgId, String newText) async {
    if (newText.trim().isEmpty) return;
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('messages').update({
        'text': newText.trim(),
        'is_edited': true,
      }).eq('id', msgId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to edit: $e')),
        );
      }
    }
    setState(() {
      _editingMessageId = null;
      _editController.clear();
    });
  }

  Future<void> _deleteMessage(String msgId) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('messages').update({
        'is_deleted': true,
        'text': 'This message was deleted',
        'attachment': null,
      }).eq('id', msgId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
    setState(() => _selectedMessage = null);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _openChatInfoScreen(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ChatInfoScreen(
          conversationId: _currentConvId,
          threadDetails: widget.threadDetails,
          vanishMode: _vanishMode,
          isMuted: _isMuted,
          onVanishToggle: _toggleVanishMode,
          onMuteToggle: _toggleMuteThread,
          onChatDeleted: widget.onBack,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  void _openLightbox(String url, String sender, String time, String type) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, _, _) => MediaLightbox(
          url: url,
          sender: sender,
          time: time,
          mediaType: type,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final otherUser = widget.threadDetails['otherUser'] as UserModel?;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final avatarUrl = otherUser?.resolvedAvatarUrl;
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty && !avatarUrl.contains('ui-avatars.com');

    final messageStream = _messageStream ?? Stream.value(<Map<String, dynamic>>[]);

    final bool isSelectionMode = _selectedMessage != null;

    return Scaffold(
      appBar: AppBar(
        leading: isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedMessage = null),
              )
            : IconButton(
                icon: const Icon(Icons.chevron_left, size: 28),
                onPressed: widget.onBack,
              ),
        title: isSelectionMode
            ? const Text('1 Selected', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))
            : GestureDetector(
                onTap: () => _openChatInfoScreen(context),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
                      child: !hasAvatar
                          ? Text(otherUser?.name.isNotEmpty == true ? otherUser!.name.substring(0, 1).toUpperCase() : '?',
                              style: const TextStyle(fontWeight: FontWeight.bold))
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(otherUser?.name ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text('Active now', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        actions: isSelectionMode
            ? _buildSelectionActions(currentUserId)
            : [
                IconButton(
                  icon: const Icon(Icons.call_outlined, size: 22),
                  onPressed: () async {
                    if (otherUser != null) {
                      final error = await ref.read(callManagerProvider.notifier).initiateCall('voice', otherUser);
                      if (error != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error)),
                        );
                      }
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.videocam_outlined, size: 22),
                  onPressed: () async {
                    if (otherUser != null) {
                      final error = await ref.read(callManagerProvider.notifier).initiateCall('video', otherUser);
                      if (error != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error)),
                        );
                      }
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 22),
                  onPressed: () => _openChatInfoScreen(context),
                ),
              ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              // Vanish mode banner
              if (_vanishMode)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.timer_outlined, size: 14, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Vanish mode is on — seen messages will disappear',
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),

              // Messages area
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: messageStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final rawList = snapshot.data!;

                    // De-duplicate messages by id (Supabase stream can emit duplicates)
                    final seenIds = <String>{};
                    final list = rawList.where((msg) {
                      final id = msg['id']?.toString() ?? '';
                      if (id.isEmpty || seenIds.contains(id)) return false;
                      seenIds.add(id);
                      return true;
                    }).toList();

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      reverse: true,
                      itemCount: list.length + 1, // +1 for intro
                      itemBuilder: (context, index) {
                        // Chat intro at the end (appears at top because of reverse)
                        if (index == list.length) {
                          if (otherUser == null) return const SizedBox.shrink();
                          return _buildChatIntro(otherUser, theme);
                        }

                        final rawMsg = list[index];
                        if (otherUser == null) return const SizedBox.shrink();
                        return _buildMessageBubble(rawMsg, list, currentUserId, otherUser, theme);
                      },
                    );
                  },
                ),
              ),

              // Reply bar
              if (_replyingToMessage != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    border: Border(
                      left: BorderSide(color: const Color(0xFF00B4FF), width: 3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Replying to',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF00B4FF)),
                            ),
                            Text(
                              _replyingToMessage!['text']?.toString() ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => setState(() => _replyingToMessage = null),
                      ),
                    ],
                  ),
                ),

              // Emoji picker
              if (_showEmojiPicker)
                Container(
                  height: 180,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  ),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                    ),
                    itemCount: emojiList.length,
                    itemBuilder: (context, i) {
                      return GestureDetector(
                        onTap: () {
                          _msgInputController.text += emojiList[i];
                          _msgInputController.selection = TextSelection.fromPosition(
                            TextPosition(offset: _msgInputController.text.length),
                          );
                        },
                        child: Center(
                          child: Text(emojiList[i], style: const TextStyle(fontSize: 24)),
                        ),
                      );
                    },
                  ),
                ),

              // Share menu popup
              if (_showShareMenu)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildShareItem(Icons.image_outlined, 'Image', const Color(0xFF3B82F6), () => _pickAndSendMedia('image')),
                      _buildShareItem(Icons.videocam_outlined, 'Video', const Color(0xFF8B5CF6), () => _pickAndSendMedia('video')),
                      _buildShareItem(Icons.description_outlined, 'Document', const Color(0xFF10B981), _pickAndSendDocument),
                    ],
                  ),
                ),

              // Chat Input Row
              Container(
                padding: EdgeInsets.fromLTRB(8, 8, 8, MediaQuery.of(context).padding.bottom + 8),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  border: Border(
                    top: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.06)),
                  ),
                ),
                child: _isVoiceRecording
                    ? _buildRecordingBar(theme)
                    : Row(
                        children: [
                          // Plus / share button
                          GestureDetector(
                            onTap: () => setState(() {
                              _showShareMenu = !_showShareMenu;
                              _showEmojiPicker = false;
                            }),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _showShareMenu
                                    ? const Color(0xFF00B4FF).withValues(alpha: 0.15)
                                    : Colors.transparent,
                              ),
                              child: Icon(
                                Icons.add,
                                color: _showShareMenu ? const Color(0xFF00B4FF) : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                size: 26,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Text input
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _msgInputController,
                                      style: const TextStyle(fontSize: 14.5),
                                      decoration: InputDecoration(
                                        hintText: 'Message...',
                                        hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.35)),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      ),
                                      textInputAction: TextInputAction.send,
                                      onSubmitted: (_) => _sendMessage(),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                  // Emoji toggle
                                  GestureDetector(
                                    onTap: () => setState(() {
                                      _showEmojiPicker = !_showEmojiPicker;
                                      _showShareMenu = false;
                                    }),
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: Icon(
                                        Icons.emoji_emotions_outlined,
                                        size: 22,
                                        color: _showEmojiPicker
                                            ? const Color(0xFF00B4FF)
                                            : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Heart quick-send button (visible when text is empty)
                          if (_msgInputController.text.trim().isEmpty) ...[
                            const SizedBox(width: 2),
                            GestureDetector(
                              onTap: _sendHeart,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Text('❤️', style: TextStyle(fontSize: 24)),
                              ),
                            ),
                          ],
                          const SizedBox(width: 6),
                          // Adaptive send/mic button
                          GestureDetector(
                            onTap: _isSending
                                ? null
                                : () {
                                    if (_msgInputController.text.trim().isNotEmpty) {
                                      _sendMessage();
                                    } else {
                                      _startVoiceRecording();
                                    }
                                  },
                             child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: _msgInputController.text.trim().isNotEmpty
                                    ? const LinearGradient(
                                        colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : const LinearGradient(
                                        colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_msgInputController.text.trim().isNotEmpty
                                            ? const Color(0xFF3B82F6)
                                            : const Color(0xFF8B5CF6))
                                        .withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: _isSending
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Icon(
                                      _msgInputController.text.trim().isNotEmpty ? Icons.send : Icons.mic,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                            ),
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

  Widget _buildRecordingBar(ThemeData theme) {
    return Row(
      children: [
        // Recording indicator
        Expanded(
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _formatRecordDuration(_voiceRecordingDuration),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(width: 16),
              TextButton(
                onPressed: () => _stopVoiceRecording(false),
                child: const Text('Cancel', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
        // Send recording
        GestureDetector(
          onTap: () => _stopVoiceRecording(true),
          child: Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFF00B4FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.send, size: 20, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildShareItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  List<Widget> _buildSelectionActions(String? currentUserId) {
    final msg = _selectedMessage;
    if (msg == null) return [];

    final senderId = msg['sender_id'] as String? ?? msg['senderId'] as String? ?? '';
    final isMe = senderId == currentUserId;
    final type = msg['type'] as String? ?? 'text';
    final isDeleted = msg['is_deleted'] as bool? ?? msg['isDeleted'] as bool? ?? false;

    return [
      // Reply
      IconButton(
        icon: const Icon(Icons.reply),
        tooltip: 'Reply',
        onPressed: () {
          setState(() {
            _replyingToMessage = msg;
            _selectedMessage = null;
          });
        },
      ),
      // Edit (own text messages only)
      if (isMe && type == 'text' && !isDeleted)
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Edit',
          onPressed: () {
            setState(() {
              _editingMessageId = msg['id']?.toString();
              _editController.text = msg['text'] as String? ?? '';
              _selectedMessage = null;
            });
          },
        ),
      // Delete (own messages only)
      if (isMe && !isDeleted)
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          tooltip: 'Delete',
          onPressed: () {
            final msgId = msg['id']?.toString() ?? '';
            _deleteMessage(msgId);
          },
        ),
    ];
  }

  Widget _buildChatIntro(UserModel otherUser, ThemeData theme) {
    final avatarUrl = otherUser.resolvedAvatarUrl;
    final hasAvatar = avatarUrl.isNotEmpty && !avatarUrl.contains('ui-avatars.com');

    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 32),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ProfileScreen(userId: otherUser.id)),
          );
        },
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.1), width: 2),
              ),
              child: CircleAvatar(
                radius: 40,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
                child: !hasAvatar
                    ? Text(otherUser.name.isNotEmpty ? otherUser.name.substring(0, 1).toUpperCase() : '?',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold))
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            Text(otherUser.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 4),
            Text(
              'ProxyPress · You both follow each other',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    Map<String, dynamic> rawMsg,
    List<Map<String, dynamic>> allMessages,
    String? currentUserId,
    UserModel otherUser,
    ThemeData theme,
  ) {
    final senderId = rawMsg['sender_id'] as String? ?? rawMsg['senderId'] as String? ?? '';
    final isMe = senderId == currentUserId;
    final text = rawMsg['text'] as String? ?? '';
    final type = rawMsg['type'] as String? ?? 'text';
    final attachment = rawMsg['attachment'] as String?;
    final timeStr = rawMsg['timestamp'] as String? ?? '';
    final replyTo = rawMsg['reply_to']?.toString() ?? rawMsg['replyTo']?.toString();
    final isEdited = rawMsg['is_edited'] as bool? ?? rawMsg['isEdited'] as bool? ?? false;
    final isDeleted = rawMsg['is_deleted'] as bool? ?? rawMsg['isDeleted'] as bool? ?? false;
    final msgId = rawMsg['id']?.toString() ?? '';
    final isSelected = _selectedMessage?['id']?.toString() == msgId;
    
    // Check if it's a story reply
    Map<String, dynamic>? storyReply;
    if (attachment != null && attachment.startsWith('{"story_reply"')) {
      try {
        storyReply = jsonDecode(attachment) as Map<String, dynamic>;
      } catch (_) {}
    }

    // Find replied message
    Map<String, dynamic>? repliedMsg;
    if (replyTo != null) {
      try {
        repliedMsg = allMessages.firstWhere((m) => m['id']?.toString() == replyTo);
      } catch (_) {}
    }

    // Editing mode
    if (_editingMessageId == msgId) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(8),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
          decoration: BoxDecoration(
            color: const Color(0xFF00B4FF),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _editController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 14.5),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                onSubmitted: (_) => _editMessage(msgId, _editController.text),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => setState(() {
                      _editingMessageId = null;
                      _editController.clear();
                    }),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ),
                  TextButton(
                    onPressed: () => _editMessage(msgId, _editController.text),
                    child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onLongPress: isDeleted ? null : () => setState(() => _selectedMessage = rawMsg),
      child: Container(
        color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.08) : Colors.transparent,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Message bubble
            Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: _buildBubbleContent(
                rawMsg,
                type,
                text,
                attachment,
                isMe,
                isDeleted,
                isEdited,
                timeStr,
                otherUser,
                theme,
                repliedMsg,
                storyReply,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getQuotedText(Map<String, dynamic> msg) {
    final isDeleted = msg['isDeleted'] as bool? ?? msg['is_deleted'] as bool? ?? false;
    if (isDeleted) return 'Deleted message';
    final type = msg['type'] as String? ?? 'text';
    if (type == 'image') return '📷 Photo';
    if (type == 'video') return '🎥 Video';
    if (type == 'voice') return '🎤 Voice message';
    if (type == 'file') return '📄 File';
    if (type == 'heart') return '❤️ Love';
    return msg['text'] as String? ?? '';
  }

  String _getStoryPreviewText(Map<String, dynamic> storyReply) {
    final type = storyReply['type'] as String? ?? 'text';
    if (type == 'text') {
      return storyReply['text'] as String? ?? '';
    } else {
      final caption = storyReply['caption'] as String? ?? '';
      if (caption.isNotEmpty) return caption;
      return type == 'video' ? '🎥 Video' : '📷 Photo';
    }
  }

  Widget _buildStoryPreviewThumbnail(Map<String, dynamic> storyReply) {
    final type = storyReply['type'] as String? ?? 'text';
    final mediaUrl = storyReply['media_url'] as String?;
    
    if (type == 'text') {
      final gradientStr = storyReply['gradient'] as String? ?? 'linear-gradient(135deg, #FF512F, #DD2476)';
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          gradient: parseHtmlGradient(gradientStr),
        ),
        alignment: Alignment.center,
        child: const Text(
          'Aa',
          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      );
    } else if (mediaUrl != null && mediaUrl.isNotEmpty) {
      if (type == 'video') {
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.play_arrow, color: Colors.white, size: 14),
        );
      } else {
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.network(
            mediaUrl,
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 36,
              height: 36,
              color: Colors.grey[800],
              child: const Icon(Icons.broken_image, color: Colors.white70, size: 14),
            ),
          ),
        );
      }
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildBubbleContent(
    Map<String, dynamic> rawMsg,
    String type,
    String text,
    String? attachment,
    bool isMe,
    bool isDeleted,
    bool isEdited,
    String timeStr,
    UserModel otherUser,
    ThemeData theme,
    Map<String, dynamic>? repliedMsg,
    Map<String, dynamic>? storyReply,
  ) {
    // Heart message — no bubble
    if (type == 'heart' && !isDeleted) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            const Text('❤️', style: TextStyle(fontSize: 42)),
            Text(
              formatMessageTime(timeStr),
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.3), fontSize: 9),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
      decoration: BoxDecoration(
        gradient: isMe && !isDeleted
            ? const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isMe
            ? null
            : isDeleted
                ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
                : theme.colorScheme.surface,
        border: !isMe && !isDeleted
            ? Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.12), width: 1)
            : null,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(22),
          topRight: const Radius.circular(22),
          bottomLeft: isMe ? const Radius.circular(22) : const Radius.circular(6),
          bottomRight: isMe ? const Radius.circular(6) : const Radius.circular(22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDeleted)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                'This message was deleted',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else ...[
            // Quoted reply inside the bubble
            if (repliedMsg != null)
              Container(
                margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.15)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border(
                    left: BorderSide(
                      color: isMe ? Colors.white70 : const Color(0xFF3B82F6),
                      width: 3,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (repliedMsg['sender_id'] == Supabase.instance.client.auth.currentUser?.id ||
                              repliedMsg['senderId'] == Supabase.instance.client.auth.currentUser?.id)
                          ? 'You'
                          : otherUser.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isMe ? Colors.white : const Color(0xFF3B82F6),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getQuotedText(repliedMsg),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isMe ? Colors.white70 : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),

            // Quoted story reply inside the bubble
            if (storyReply != null)
              Container(
                margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.15)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border(
                    left: BorderSide(
                      color: isMe ? Colors.white70 : const Color(0xFF3B82F6),
                      width: 3,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Story Reply • ${storyReply['author_name'] ?? 'User'}",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isMe ? Colors.white : const Color(0xFF3B82F6),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getStoryPreviewText(storyReply),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isMe ? Colors.white70 : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStoryPreviewThumbnail(storyReply),
                  ],
                ),
              ),
            // Image attachment
            if (type == 'image' && attachment != null)
              GestureDetector(
                onTap: () => _openLightbox(attachment, isMe ? 'You' : otherUser.name, formatMessageTime(timeStr), 'image'),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: Image.network(
                    attachment,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 200,
                    errorBuilder: (_, _, _) => Container(
                      height: 100,
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                ),
              ),

            // Video attachment
            if (type == 'video' && attachment != null)
              GestureDetector(
                onTap: () => _openLightbox(attachment, isMe ? 'You' : otherUser.name, formatMessageTime(timeStr), 'video'),
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  child: const Center(
                    child: Icon(Icons.play_circle_fill, color: Colors.white, size: 48),
                  ),
                ),
              ),

            // Voice attachment
            if (type == 'voice')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_circle_fill, color: isMe ? Colors.white : const Color(0xFF00B4FF), size: 28),
                    const SizedBox(width: 8),
                    ...List.generate(7, (i) {
                      final heights = [0.4, 0.7, 1.0, 0.6, 0.8, 0.5, 0.3];
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        width: 3,
                        height: 24 * heights[i],
                        decoration: BoxDecoration(
                          color: isMe ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF00B4FF).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      );
                    }),
                  ],
                ),
              ),

            // File attachment
            if (type == 'file')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.description_outlined, color: isMe ? Colors.white : theme.colorScheme.onSurface, size: 22),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        text.replaceFirst('Sent a file: ', ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: isMe ? Colors.white : theme.colorScheme.onSurface, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // Text (only show if there's text and it's not a pure media message label)
            if (type == 'text' || (type != 'heart' && type != 'voice' && type != 'file' && text.isNotEmpty && !text.startsWith('📷') && !text.startsWith('🎥') && !text.startsWith('🎤')))
              if (type == 'text')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text(
                    text,
                    style: TextStyle(
                      color: isMe ? Colors.white : theme.colorScheme.onSurface,
                      fontSize: 14.5,
                    ),
                  ),
                ),
          ],

          // Bottom status row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isEdited && !isDeleted)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      'Edited',
                      style: TextStyle(
                        color: isMe ? Colors.white54 : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                        fontSize: 9,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                Text(
                  formatMessageTime(timeStr),
                  style: TextStyle(
                    color: isMe ? Colors.white60 : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    fontSize: 9,
                  ),
                ),
                if (isMe && !isDeleted) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all,
                    size: 13,
                    color: (rawMsg['seen'] as bool? ?? false) ? const Color(0xFF00B4FF) : Colors.white54,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════
//  MEDIA LIGHTBOX VIEWER
// ════════════════════════════════════════════
