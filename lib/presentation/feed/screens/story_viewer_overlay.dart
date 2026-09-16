import 'package:spillcity/core/utils/helpers.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:spillcity/domain/entities/story.dart';

// ─── Format Time Utility ───
class StoryViewerOverlay extends StatefulWidget {
  final int initialUserIndex;
  final List<StoryModel> stories;
  final VoidCallback onFinish;

  const StoryViewerOverlay({super.key, 
    required this.initialUserIndex,
    required this.stories,
    required this.onFinish,
  });

  @override
  StoryViewerOverlayState createState() => StoryViewerOverlayState();
}

class StoryViewerOverlayState extends State<StoryViewerOverlay> with SingleTickerProviderStateMixin {
  late int _currentUserIdx;
  int _currentSlideIdx = 0;
  late AnimationController _progressController;
  final TextEditingController _replyController = TextEditingController();
  bool _isPaused = false;
  VideoPlayerController? _videoPlayerController;
  
  List<Map<String, dynamic>> _storyViewers = [];
  bool _isLoadingViewers = false;
  bool _canPop = false;

  @override
  void initState() {
    super.initState();
    _currentUserIdx = widget.initialUserIndex;
    _progressController = AnimationController(vsync: this);
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_isPaused) {
        _nextSlide();
      }
    });
    _playCurrentSlide();
  }

  void _playCurrentSlide() {
    _videoPlayerController?.dispose();
    _videoPlayerController = null;
    
    final currentUser = widget.stories[_currentUserIdx];
    final currentSlide = currentUser.slides[_currentSlideIdx];

    _markCurrentStoryAsSeen();

    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUser.userId == myId) {
      _loadStoryViewers(currentUser.userId);
    }

    if (currentSlide.type == 'video' && currentSlide.mediaUrl != null) {
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(currentSlide.mediaUrl!))
        ..initialize().then((_) {
          _videoPlayerController!.setVolume(0.0); // Muted by default per user request
          _videoPlayerController!.play();
          _progressController.duration = _videoPlayerController!.value.duration;
          _progressController.forward(from: 0.0);
          setState(() {});
        }).catchError((e) {
          debugPrint("Video play error: $e");
          _progressController.duration = const Duration(seconds: 5);
          _progressController.forward(from: 0.0);
        });
    } else {
      _progressController.duration = const Duration(seconds: 5);
      _progressController.forward(from: 0.0);
    }
  }

  Future<void> _loadStoryViewers(String storyOwnerId) async {
    setState(() {
      _isLoadingViewers = true;
      _storyViewers = [];
    });

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('story_views')
          .select('created_at, reaction, viewer:users(id, name, username, avatar, profile_picture)')
          .eq('story_id', storyOwnerId)
          .order('created_at', ascending: false);

      if (mounted) {
        final List<Map<String, dynamic>> rawViews = List<Map<String, dynamic>>.from(response);
        final Map<String, Map<String, dynamic>> uniqueViewers = {};
        for (final view in rawViews) {
          final viewer = view['viewer'] as Map<String, dynamic>?;
          if (viewer != null) {
            final viewerId = viewer['id']?.toString();
            if (viewerId != null && !uniqueViewers.containsKey(viewerId)) {
              uniqueViewers[viewerId] = view;
            }
          }
        }
        setState(() {
          _storyViewers = uniqueViewers.values.toList();
          _isLoadingViewers = false;
        });
      }
    } catch (e) {
      debugPrint("Failed to load story viewers: $e");
      if (mounted) {
        setState(() => _isLoadingViewers = false);
      }
    }
  }

  void _pauseStory() {
    setState(() => _isPaused = true);
    _progressController.stop();
    _videoPlayerController?.pause();
  }

  void _resumeStory() {
    setState(() => _isPaused = false);
    _progressController.forward();
    _videoPlayerController?.play();
  }

  Future<void> _deleteStorySlide(StorySlideModel slide) async {
    _pauseStory();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Story'),
        content: const Text('Are you sure you want to delete this story?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      _resumeStory();
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      await supabase.from('story_slides').delete().eq('id', slide.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Story deleted successfully')),
        );
        
        final currentUser = widget.stories[_currentUserIdx];
        setState(() {
          currentUser.slides.removeAt(_currentSlideIdx);
        });

        if (currentUser.slides.isEmpty) {
          if (_currentUserIdx < widget.stories.length - 1) {
            setState(() {
              _currentSlideIdx = 0;
            });
            _playCurrentSlide();
          } else if (_currentUserIdx > 0) {
            setState(() {
              _currentUserIdx--;
              _currentSlideIdx = 0;
            });
            _playCurrentSlide();
          } else {
            _close();
          }
        } else {
          if (_currentSlideIdx >= currentUser.slides.length) {
            _currentSlideIdx = currentUser.slides.length - 1;
          }
          _playCurrentSlide();
        }
      }
    } catch (e) {
      debugPrint("Failed to delete story: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete story: $e')),
        );
        _resumeStory();
      }
    }
  }

  Future<void> _editStorySlide(StorySlideModel slide) async {
    _pauseStory();
    final isText = slide.type == 'text';
    final controller = TextEditingController(text: isText ? slide.text : slide.caption);

    final newContent = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isText ? 'Edit Story Text' : 'Edit Caption'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: isText ? 'Enter story text...' : 'Enter caption...',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newContent == null) {
      _resumeStory();
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      if (isText) {
        await supabase.from('story_slides').update({'text': newContent}).eq('id', slide.id);
      } else {
        await supabase.from('story_slides').update({'caption': newContent}).eq('id', slide.id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Story updated successfully')),
        );
        
        final currentUser = widget.stories[_currentUserIdx];
        final updatedSlide = StorySlideModel(
          id: slide.id,
          storyId: slide.storyId,
          type: slide.type,
          text: isText ? newContent : slide.text,
          emoji: slide.emoji,
          caption: isText ? slide.caption : newContent,
          gradient: slide.gradient,
          mediaUrl: slide.mediaUrl,
          timestamp: slide.timestamp,
          createdAt: slide.createdAt,
        );

        setState(() {
          currentUser.slides[_currentSlideIdx] = updatedSlide;
        });
        
        _resumeStory();
      }
    } catch (e) {
      debugPrint("Failed to edit story: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to edit story: $e')),
        );
        _resumeStory();
      }
    }
  }

  void _showStoryManagementMenu(BuildContext context, StorySlideModel slide) {
    _pauseStory();
    showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit Story'),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete Story', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    ).then((action) {
      if (action == 'edit') {
        _editStorySlide(slide);
      } else if (action == 'delete') {
        _deleteStorySlide(slide);
      } else {
        _resumeStory();
      }
    });
  }

  void _nextSlide() {
    final currentUser = widget.stories[_currentUserIdx];
    if (_currentSlideIdx < currentUser.slides.length - 1) {
      setState(() => _currentSlideIdx++);
      _playCurrentSlide();
    } else if (_currentUserIdx < widget.stories.length - 1) {
      setState(() {
        _currentUserIdx++;
        _currentSlideIdx = 0;
      });
      _playCurrentSlide();
    } else {
      _close();
    }
  }

  void _prevSlide() {
    if (_currentSlideIdx > 0) {
      setState(() => _currentSlideIdx--);
      _playCurrentSlide();
    } else if (_currentUserIdx > 0) {
      setState(() {
        _currentUserIdx--;
        _currentSlideIdx = widget.stories[_currentUserIdx].slides.length - 1;
      });
      _playCurrentSlide();
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _replyController.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  void _close() {
    setState(() {
      _canPop = true;
    });
    Future.microtask(() {
      widget.onFinish();
    });
  }

  Future<void> _sendStoryReaction(String emoji) async {
    if (emoji.isEmpty) return;

    final supabase = Supabase.instance.client;
    final myId = supabase.auth.currentUser?.id;
    final currentUser = widget.stories[_currentUserIdx];
    if (myId == null || myId == currentUser.userId) return;

    try {
      await supabase.from('story_views').upsert({
        'story_id': currentUser.userId,
        'viewer_id': myId,
        'reaction': emoji,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reaction $emoji sent!'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint("Failed to send story reaction: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send reaction: $e')),
        );
      }
    }
  }

  Future<void> _sendReply(String emoji) async {
    final text = emoji.isNotEmpty ? emoji : _replyController.text.trim();
    if (text.isEmpty) return;

    final supabase = Supabase.instance.client;
    final myId = supabase.auth.currentUser?.id;
    final currentUser = widget.stories[_currentUserIdx];
    if (myId == null || myId == currentUser.userId) return;

    try {
      final targetUserId = currentUser.userId;

      // 1. Check blocks
      final blockCheck = await supabase
          .from('user_blocks')
          .select()
          .or('and(user_id.eq.$myId,blocked_id.eq.$targetUserId),and(user_id.eq.$targetUserId,blocked_id.eq.$myId)')
          .maybeSingle();
      if (blockCheck != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot reply to a blocked user')),
          );
        }
        return;
      }

      // 2. Resolve or create conversation
      String convId;
      final myParticipants = await supabase
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', myId);
      
      final List<String> myConvIds = [];
      for (final item in myParticipants) {
        if (item['conversation_id'] != null) {
          myConvIds.add(item['conversation_id'].toString());
        }
      }
    
      if (myConvIds.isNotEmpty) {
        final otherParticipants = await supabase
            .from('conversation_participants')
            .select('conversation_id')
            .eq('user_id', targetUserId)
            .inFilter('conversation_id', myConvIds)
            .limit(1)
            .maybeSingle();
        if (otherParticipants != null && otherParticipants['conversation_id'] != null) {
          convId = otherParticipants['conversation_id'].toString();
        } else {
          convId = await _createNewStoryReplyConv(supabase, myId, targetUserId);
        }
      } else {
        convId = await _createNewStoryReplyConv(supabase, myId, targetUserId);
      }

      // 3. Send message
      final msgText = text;
      final currentSlide = currentUser.slides[_currentSlideIdx];
      final storyReplyMeta = {
        'story_reply': true,
        'slide_id': currentSlide.id,
        'type': currentSlide.type,
        'media_url': currentSlide.mediaUrl,
        'text': currentSlide.text,
        'caption': currentSlide.caption,
        'gradient': currentSlide.gradient,
        'author_name': currentUser.authorName,
      };
      final attachmentJson = jsonEncode(storyReplyMeta);

      await supabase.from('messages').insert({
        'id': 'm${DateTime.now().millisecondsSinceEpoch}',
        'conversation_id': convId,
        'sender_id': myId,
        'text': msgText,
        'type': 'text',
        'attachment': attachmentJson,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });

      await supabase.from('conversations').update({
        'last_message': msgText,
        'last_message_time': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', convId);

      _replyController.clear();
      setState(() => _isPaused = false);
      _progressController.forward();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reply sent')));
      }
    } catch (e) {
      debugPrint("Failed to send story reply: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send reply: $e')));
      }
    }
  }

  Future<String> _createNewStoryReplyConv(SupabaseClient supabase, String myId, String targetUserId) async {
    final newConvId = 'c${DateTime.now().millisecondsSinceEpoch}';
    final nowIso = DateTime.now().toUtc().toIso8601String();

    await supabase.from('conversations').insert({
      'id': newConvId,
      'last_message': '',
      'last_message_time': nowIso,
    });

    await supabase.from('conversation_participants').insert([
      {'conversation_id': newConvId, 'user_id': myId},
      {'conversation_id': newConvId, 'user_id': targetUserId},
    ]);

    return newConvId;
  }

  Future<void> _markCurrentStoryAsSeen() async {
    final supabase = Supabase.instance.client;
    final myId = supabase.auth.currentUser?.id;
    final currentUser = widget.stories[_currentUserIdx];
    if (myId == null || currentUser.userId == myId) return;

    try {
      await supabase.from('story_views').upsert({
        'story_id': currentUser.userId,
        'viewer_id': myId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint("Failed to mark story as seen: $e");
    }
  }

  Widget _buildViewerAvatar(String avatarUrl, String name, {double radius = 18}) {
    final hasAvatar = avatarUrl.isNotEmpty && 
        !avatarUrl.contains('ui-avatars.com') && 
        avatarUrl.startsWith('http');
    return CircleAvatar(
      radius: radius,
      backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
      backgroundColor: Colors.grey[800],
      child: !hasAvatar
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(fontSize: radius * 0.9, color: Colors.white),
            )
          : null,
    );
  }

  void _showStoryViewersSheet(BuildContext context) {
    _pauseStory();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          constraints: const BoxConstraints(maxHeight: 400),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Views (${_storyViewers.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              Expanded(
                child: _storyViewers.isEmpty
                    ? const Center(
                        child: Text(
                          'No views yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _storyViewers.length,
                        itemBuilder: (context, index) {
                          final viewerData = _storyViewers[index];
                          final viewer = viewerData['viewer'] as Map<String, dynamic>?;
                          if (viewer == null) return const SizedBox.shrink();

                          final name = viewer['name'] as String? ?? 'User';
                          final username = viewer['username'] as String? ?? 'user';
                          final avatarUrl = viewer['avatar'] as String? ?? viewer['profile_picture'] as String? ?? '';
                          final viewTimeStr = viewerData['created_at'] as String? ?? '';
                          
                          String timeAgo = 'some time ago';
                          if (viewTimeStr.isNotEmpty) {
                            try {
                              timeAgo = formatMessageTime(viewTimeStr);
                            } catch (_) {}
                          }

                           final reaction = viewerData['reaction'] as String? ?? '';

                          return ListTile(
                            leading: _buildViewerAvatar(avatarUrl, name, radius: 18),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (reaction.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: Text(reaction, style: const TextStyle(fontSize: 20)),
                                  ),
                              ],
                            ),
                            subtitle: Text('@$username • $timeAgo'),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      _resumeStory();
    });
  }

  Widget _buildSelfStoryBottomView(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 20.0),
      child: Center(
        child: GestureDetector(
          onTap: () {
            _showStoryViewersSheet(context);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.remove_red_eye_outlined, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                if (_isLoadingViewers)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  Text(
                    _storyViewers.isEmpty
                        ? 'No views yet'
                        : 'Viewed by ${_storyViewers.length} ${_storyViewers.length == 1 ? 'person' : 'people'}',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = widget.stories[_currentUserIdx];
    final slide = currentUser.slides[_currentSlideIdx];

    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _close();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTapDown: (details) {
            final screenWidth = MediaQuery.of(context).size.width;
            if (details.globalPosition.dx < screenWidth / 3) {
              _prevSlide();
            } else {
              _nextSlide();
            }
          },
          onLongPressStart: (_) {
            setState(() => _isPaused = true);
            _progressController.stop();
            _videoPlayerController?.pause();
          },
          onLongPressEnd: (_) {
            setState(() => _isPaused = false);
            _progressController.forward();
            _videoPlayerController?.play();
          },
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null && details.primaryVelocity! > 200) {
              _close();
            }
          },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Slide Background
            if (slide.type == 'text')
              Container(
                decoration: BoxDecoration(gradient: parseHtmlGradient(slide.gradient)),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      slide.text ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              )
            else if (slide.type == 'video' && _videoPlayerController != null && _videoPlayerController!.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: _videoPlayerController!.value.aspectRatio,
                  child: VideoPlayer(_videoPlayerController!),
                ),
              )
            else if (slide.mediaUrl != null)
              Image.network(slide.mediaUrl!, fit: BoxFit.cover)
            else
              Container(color: Colors.grey[900]),

            // Safe Area Overlays
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress Bars
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: List.generate(currentUser.slides.length, (idx) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                double width = 0;
                                if (idx < _currentSlideIdx) {
                                  width = constraints.maxWidth;
                                } else if (idx == _currentSlideIdx) {
                                  width = constraints.maxWidth * _progressController.value;
                                }
                                return Container(
                                  height: 2,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: AnimatedBuilder(
                                      animation: _progressController,
                                      builder: (context, _) => Container(
                                        width: width,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  // User Info Header
                  GestureDetector(
                    onTap: () {}, // Prevent taps here from skipping slide
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundImage: currentUser.authorAvatar.isNotEmpty ? NetworkImage(currentUser.authorAvatar) : null,
                            backgroundColor: Colors.grey[800],
                            child: currentUser.authorAvatar.isEmpty
                                ? Text(currentUser.authorName.isNotEmpty ? currentUser.authorName[0].toUpperCase() : '?',
                                    style: const TextStyle(fontSize: 14, color: Colors.white))
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            currentUser.authorName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatMessageTime(slide.timestamp),
                            style: const TextStyle(color: Colors.white70, fontSize: 12, shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
                          ),
                          const Spacer(),
                          if (slide.type == 'video' && _videoPlayerController != null)
                            IconButton(
                              icon: Icon(
                                _videoPlayerController!.value.volume > 0 ? Icons.volume_up : Icons.volume_off,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                setState(() {
                                  final isMuted = _videoPlayerController!.value.volume == 0;
                                  _videoPlayerController!.setVolume(isMuted ? 1.0 : 0.0);
                                });
                              },
                            ),
                          if (currentUser.userId == Supabase.instance.client.auth.currentUser?.id)
                            IconButton(
                              icon: const Icon(Icons.more_vert, color: Colors.white),
                              onPressed: () => _showStoryManagementMenu(context, slide),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Bottom Caption / Reply Section
                  GestureDetector(
                    onTap: () {}, // Prevent taps here from skipping slide
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (slide.caption != null)
                          Align(
                            alignment: Alignment.center,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                slide.caption!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 16, shadows: [Shadow(color: Colors.black, blurRadius: 8)]),
                              ),
                            ),
                          ),
                        if (currentUser.userId == Supabase.instance.client.auth.currentUser?.id)
                          _buildSelfStoryBottomView(context)
                        else
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _replyController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      hintText: 'Reply...',
                                      hintStyle: const TextStyle(color: Colors.white70),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                      filled: true,
                                      fillColor: Colors.black.withValues(alpha: 0.3),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(30),
                                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(30),
                                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                                      ),
                                    ),
                                    onTap: () {
                                      setState(() => _isPaused = true);
                                      _progressController.stop();
                                      _videoPlayerController?.pause();
                                    },
                                    onSubmitted: (v) => _sendReply(''),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.send, color: Colors.white),
                                  onPressed: () => _sendReply(''),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _sendStoryReaction('❤️'),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4),
                                    child: Text('❤️', style: TextStyle(fontSize: 28)),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _sendStoryReaction('🔥'),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4),
                                    child: Text('🔥', style: TextStyle(fontSize: 28)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
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
}



// ════════════════════════════════════════════
//  CHAT INFO BOTTOM SHEET
// ════════════════════════════════════════════
