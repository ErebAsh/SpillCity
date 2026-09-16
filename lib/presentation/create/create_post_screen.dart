import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:spillcity/data/repositories/providers.dart';
import 'package:spillcity/data/database/local_db.dart';
import 'package:spillcity/services/cloudinary_service.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  final String? editPostId;

  const CreatePostScreen({super.key, this.editPostId});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  String _selectedCategory = '';
  File? _selectedMediaFile;
  String? _remoteMediaUrl;
  String? _existingVideoUrl;
  String? _mediaType; // 'image' or 'video'
  bool _isPublishing = false;
  bool _isSavingDraft = false;
  bool _isLoadingPost = false;
  List<PendingPost> _localDrafts = [];

  final List<String> _categories = [
    'Events', 'Notices', 'Sports', 'Academic', 'Clubs', 'Exams', 'News', 'College Daily Update', 'Others'
  ];

  final Map<String, String> _categoryEmojis = {
    'Events': '🎉', 'Notices': '📢', 'Sports': '⚽', 'Academic': '📚',
    'Clubs': '🎭', 'Exams': '📝', 'News': '📰', 'College Daily Update': '🗓️', 'Others': '✨'
  };

  final Map<String, Color> _categoryColors = {
    'Events': const Color(0xFF8B5CF6),
    'Notices': const Color(0xFFF59E0B),
    'Sports': const Color(0xFF10B981),
    'Academic': const Color(0xFF2563EB),
    'Clubs': const Color(0xFFEC4899),
    'Exams': const Color(0xFFEF4444),
    'News': const Color(0xFF6366F1),
    'College Daily Update': const Color(0xFF14B8A6),
    'Others': const Color(0xFF94A3B8),
  };

  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadDrafts();
    _titleController.addListener(_onTextChanged);
    _descController.addListener(_onTextChanged);
    
    // Load post details if we are in editing mode
    if (widget.editPostId != null) {
      _loadPostDataForEditing();
    }
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTextChanged);
    _descController.removeListener(_onTextChanged);
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadPostDataForEditing() async {
    setState(() {
      _isLoadingPost = true;
    });

    try {
      final post = await ref.read(postRepositoryProvider).getPostById(widget.editPostId!);
      if (post != null) {
        _titleController.text = post.title;
        _descController.text = post.description;
        setState(() {
          _selectedCategory = post.category ?? '';
          _remoteMediaUrl = post.imageUrl;
          _existingVideoUrl = post.videoUrl;
          if (post.videoUrl != null && post.videoUrl!.isNotEmpty) {
            _mediaType = 'video';
          } else if (post.imageUrl.isNotEmpty && !post.imageUrl.startsWith('https://images.unsplash.com')) {
            _mediaType = 'image';
          }
        });
      }
    } catch (e) {
      debugPrint("Failed to load post for editing: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load post: $e')),
      );
      }
    } finally {
      setState(() {
        _isLoadingPost = false;
      });
    }
  }

  Future<void> _loadDrafts() async {
    try {
      final drafts = await ref.read(postRepositoryProvider).getDrafts();
      setState(() {
        _localDrafts = drafts;
      });
    } catch (e) {
      debugPrint("Failed to load local drafts: $e");
    }
  }

  Future<void> _pickMedia(ImageSource source, {bool isVideo = false}) async {
    try {
      final XFile? file = isVideo
          ? await _imagePicker.pickVideo(source: source)
          : await _imagePicker.pickImage(source: source, imageQuality: 80);

      if (file != null) {
        setState(() {
          _selectedMediaFile = File(file.path);
          _remoteMediaUrl = null; // Override previous remote media
          _existingVideoUrl = null;
          _mediaType = isVideo ? 'video' : 'image';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error choosing media: $e')),
      );
      }
    }
  }

  void _showCameraPickerOptions() {
    showModalBottomSheet(
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
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('📷 Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia(ImageSource.camera, isVideo: false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: const Text('📹 Record Video'),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia(ImageSource.camera, isVideo: true);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveDraft() async {
    final title = _titleController.text.trim();
    final description = _descController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title to save a draft.')),
      );
      return;
    }

    setState(() {
      _isSavingDraft = true;
    });

    try {
      final repo = ref.read(postRepositoryProvider);
      final draftId = 'draft_${DateTime.now().millisecondsSinceEpoch}';
      
      await repo.saveDraft(
        id: draftId,
        title: title,
        description: description,
        category: _selectedCategory,
        localImageUrl: _selectedMediaFile?.path ?? _remoteMediaUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft saved successfully.')),
      );
      }
      
      _titleController.clear();
      _descController.clear();
      setState(() {
        _selectedCategory = '';
        _selectedMediaFile = null;
        _remoteMediaUrl = null;
        _existingVideoUrl = null;
        _mediaType = null;
      });

      _loadDrafts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save draft: $e')),
      );
      }
    } finally {
      setState(() {
        _isSavingDraft = false;
      });
    }
  }

  Future<void> _publishPost() async {
    final title = _titleController.text.trim();
    final description = _descController.text.trim();

    if (title.isEmpty || description.isEmpty || _selectedCategory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out all fields and choose a category.')),
      );
      return;
    }

    setState(() {
      _isPublishing = true;
    });

    try {
      final supabaseClient = Supabase.instance.client;
      final currentUserId = supabaseClient.auth.currentUser?.id;

      if (currentUserId == null) {
        throw Exception("You must be logged in to publish a post.");
      }

      // Fetch user profile for optimistic local SQLite cache
      final userModel = await ref.read(authRepositoryProvider).getCurrentUserProfile();

      String finalImageUrl = _remoteMediaUrl ?? '';
      String? finalVideoUrl = _existingVideoUrl;

      // 1. Upload media if a new file is chosen
      if (_selectedMediaFile != null) {
        final category = _mediaType == 'video' ? 'videos' : 'images';
        final publicUrl = await CloudinaryService.uploadMedia(
          file: _selectedMediaFile!,
          category: category,
        );
        
        if (_mediaType == 'video') {
          finalVideoUrl = publicUrl;
          finalImageUrl = 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=800&q=80'; // Default placeholder cover
        } else {
          finalImageUrl = publicUrl;
          finalVideoUrl = null;
        }
      } else if (finalImageUrl.isEmpty) {
        finalImageUrl = 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=800&q=80';
      }

      final cleanTitle = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
      final postId = 'p${DateTime.now().millisecondsSinceEpoch}';
      final slug = '${cleanTitle.isEmpty ? 'post' : cleanTitle}-$postId';
      
      if (widget.editPostId != null) {
        // Edit flow
        await ref.read(postRepositoryProvider).updatePost(
          widget.editPostId!,
          title: title,
          description: description,
          category: _selectedCategory,
          imageUrl: finalImageUrl,
          videoUrl: finalVideoUrl,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post updated successfully!')),
        );
        }
      } else {
        // Create flow
        await supabaseClient.from('posts').insert({
          'id': postId,
          'title': title,
          'description': description,
          'content': description,
          'category': _selectedCategory,
          'image_url': finalImageUrl,
          'video_url': finalVideoUrl,
          'author_id': currentUserId,
          'slug': slug,
          'image_color': 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
          'published_at': DateTime.now().toUtc().toIso8601String(),
        });

        // Save post details locally to SQLite
        final db = ref.read(localDatabaseProvider);
        await db.saveGlobalPost(
          GlobalFeedData(
            id: postId,
            slug: slug,
            title: title,
            description: description,
            imageUrl: finalImageUrl,
            publishedAt: DateTime.now().toUtc().toIso8601String(),
            category: _selectedCategory,
            likes: 0,
            comments: 0,
            authorName: userModel?.name ?? 'User',
            authorAvatar: userModel?.avatar,
          ),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Story published successfully!')),
        );
        }
      }

      _titleController.clear();
      _descController.clear();
      setState(() {
        _selectedCategory = '';
        _selectedMediaFile = null;
        _remoteMediaUrl = null;
        _existingVideoUrl = null;
        _mediaType = null;
      });

      // Refresh feeds provider
      ref.invalidate(homeFeedPostsProvider);

      if (mounted) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save post: $e')),
      );
      }
    } finally {
      setState(() {
        _isPublishing = false;
      });
    }
  }

  void _resumeDraft(PendingPost draft) {
    setState(() {
      _titleController.text = draft.title ?? '';
      _descController.text = draft.description ?? '';
      _selectedCategory = draft.category ?? '';
      
      final mediaPath = draft.localImageUrl;
      if (mediaPath != null && mediaPath.isNotEmpty) {
        if (mediaPath.startsWith('http')) {
          _remoteMediaUrl = mediaPath;
          _selectedMediaFile = null;
        } else {
          _selectedMediaFile = File(mediaPath);
          _remoteMediaUrl = null;
        }
        _mediaType = mediaPath.contains('.mp4') || mediaPath.contains('.mov') ? 'video' : 'image';
      } else {
        _selectedMediaFile = null;
        _remoteMediaUrl = null;
        _mediaType = null;
      }
    });

    ref.read(postRepositoryProvider).deleteDraft(draft.id).then((_) => _loadDrafts());
  }

  Future<void> _deleteDraft(String draftId) async {
    try {
      await ref.read(postRepositoryProvider).deleteDraft(draftId);
      _loadDrafts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft deleted.')),
      );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete draft: $e')),
      );
      }
    }
  }

  Widget _buildPageHeader(ThemeData theme) {
    final isEditing = widget.editPostId != null;
    return Column(
      children: [
        const SizedBox(height: 10),
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              theme.colorScheme.onSurface,
              theme.colorScheme.primary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: Text(
            isEditing ? 'Edit Post' : 'Create Post',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.8,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isEditing ? 'Update your campus news' : 'Share your latest campus updates',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          height: 1,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                theme.colorScheme.outline.withValues(alpha: 0.2),
                Colors.transparent,
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  List<Widget> _buildFormChildren(ThemeData theme) {
    final isEditing = widget.editPostId != null;
    final hasMedia = _selectedMediaFile != null || _remoteMediaUrl != null;

    return [
      Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('📝', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  'Post Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Media zone label
            Text(
              'Cover Media (Image/Video)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),

            // Media upload zone card
            hasMedia
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _selectedMediaFile != null
                              ? (_mediaType == 'video'
                                  ? Container(
                                      color: Colors.black,
                                      child: const Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.video_file_outlined, size: 48, color: Colors.white70),
                                            SizedBox(height: 8),
                                            Text('Video selected', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                    )
                                  : Image.file(_selectedMediaFile!, fit: BoxFit.cover))
                              : (_mediaType == 'video'
                                  ? Container(
                                      color: Colors.black,
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.video_file_outlined, size: 48, color: Colors.white70),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Video loaded: ${_existingVideoUrl?.split('/').last ?? 'video'}',
                                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: _remoteMediaUrl!,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                                        child: const Center(child: CircularProgressIndicator()),
                                      ),
                                      errorWidget: (context, url, error) => const Icon(Icons.error),
                                    )),
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.black45, Colors.transparent],
                                begin: Alignment.bottomCenter,
                                end: Alignment.center,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 16,
                            right: 16,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedMediaFile = null;
                                  _remoteMediaUrl = null;
                                  _existingVideoUrl = null;
                                  _mediaType = null;
                                });
                              },
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: const Icon(Icons.close, color: Colors.black, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : CustomPaint(
                    painter: DashedBorderPainter(
                      color: theme.colorScheme.outline.withValues(alpha: 0.35),
                      strokeWidth: 2,
                      dashWidth: 6,
                      dashSpace: 4,
                      borderRadius: 20,
                    ),
                    child: Container(
                      height: 220,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(Icons.add_photo_alternate_outlined, color: theme.colorScheme.primary, size: 30),
                          ),
                          const SizedBox(height: 14),
                          const Text('Upload Cover Media', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                          const SizedBox(height: 4),
                          Text(
                            'Select image or video',
                            style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _showCameraPickerOptions,
                                icon: const Icon(Icons.camera_alt_outlined, size: 16),
                                label: const Text('Camera'),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.surface,
                                  foregroundColor: theme.colorScheme.onSurface,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.4)),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: () => _pickMedia(ImageSource.gallery, isVideo: false),
                                icon: const Icon(Icons.folder_open_outlined, size: 16),
                                label: const Text('Files'),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.surface,
                                  foregroundColor: theme.colorScheme.onSurface,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.4)),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
            const SizedBox(height: 24),

            // Title Input
            Text.rich(
              TextSpan(
                text: 'Title ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                children: const [
                  TextSpan(text: '*', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              maxLength: 120,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Enter a compelling headline...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                counterText: '',
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${_titleController.text.length}/120',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Description Input
            Text.rich(
              TextSpan(
                text: 'Description ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                children: const [
                  TextSpan(text: '*', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 5,
              maxLength: 400,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Write a short summary of your post...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
                ),
                contentPadding: const EdgeInsets.all(16),
                counterText: '',
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${_descController.text.length}/400',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Category Dropdown
            Text.rich(
              TextSpan(
                text: 'Category ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                children: const [
                  TextSpan(text: '*', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory.isEmpty ? null : _selectedCategory,
              hint: const Text('Select a category...'),
              style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              items: _categories.map((cat) {
                final emoji = _categoryEmojis[cat] ?? '📁';
                return DropdownMenuItem<String>(
                  value: cat,
                  child: Row(
                    children: [
                      Text(emoji),
                      const SizedBox(width: 8),
                      Text(cat),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCategory = value;
                  });
                }
              },
            ),
            const SizedBox(height: 32),

            // Submit and Draft Action Buttons
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isPublishing ? null : _publishPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isPublishing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text(
                        isEditing ? '💾 Update Post' : '🚀 Publish Post',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
              ),
            ),
            if (!isEditing) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: _isSavingDraft ? null : _saveDraft,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                  ),
                  child: _isSavingDraft
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('📁 Save Draft', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ],
        ),
      ),

      // Local Drafts Section List
      if (_localDrafts.isNotEmpty && !isEditing) ...[
        const SizedBox(height: 40),
        const Divider(),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.drafts_outlined, size: 20),
            const SizedBox(width: 8),
            Text(
              'Saved Local Drafts',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _localDrafts.length,
          itemBuilder: (context, index) {
            final draft = _localDrafts[index];
            final time = draft.createdAt ?? '';

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.12)),
              ),
              child: ListTile(
                title: Text(draft.title ?? 'No title', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  '${draft.category ?? 'No Category'} • Created ${time.length > 10 ? time.substring(0, 10) : time}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_note, color: Colors.blue),
                      onPressed: () => _resumeDraft(draft),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteDraft(draft.id),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    ];
  }

  Widget _buildLivePreview(ThemeData theme) {
    final categoryColor = _categoryColors[_selectedCategory] ?? theme.colorScheme.primary;
    final categoryEmoji = _categoryEmojis[_selectedCategory] ?? '📁';
    final hasMedia = _selectedMediaFile != null || _remoteMediaUrl != null;

    final currentUser = ref.watch(currentUserProvider).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.remove_red_eye_outlined, size: 18),
            const SizedBox(width: 8),
            const Text(
              'Live Preview',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'REAL-TIME',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Live Post Mock Card matching ArticleDetailScreen layout
        Card(
          elevation: 4,
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _selectedCategory.isNotEmpty
                        ? '$categoryEmoji ${_selectedCategory.toUpperCase()}'
                        : '📰 NEWS',
                    style: TextStyle(
                      color: categoryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Title
                Text(
                  _titleController.text.isNotEmpty
                      ? _titleController.text
                      : 'Headline',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),

                // Author metadata row
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: () {
                        final avatarUrl = currentUser?.profilePicture ?? currentUser?.avatar ?? '';
                        if (avatarUrl.startsWith('http') && !avatarUrl.contains('ui-avatars.com')) {
                          return NetworkImage(avatarUrl);
                        }
                        return null;
                      }(),
                      child: () {
                        final avatarUrl = currentUser?.profilePicture ?? currentUser?.avatar ?? '';
                        if (avatarUrl.isEmpty || !avatarUrl.startsWith('http') || avatarUrl.contains('ui-avatars.com')) {
                          return Text(
                            avatarUrl.isNotEmpty && !avatarUrl.startsWith('http')
                                ? avatarUrl
                                : (currentUser?.name ?? 'U')[0].toUpperCase(),
                          );
                        }
                        return null;
                      }(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentUser?.name ?? 'Alex Johnson',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            '${currentUser?.college ?? 'MIT Campus'} · Just now',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Hero Cover Media
                if (hasMedia)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: _selectedMediaFile != null
                          ? (_mediaType == 'video'
                              ? Container(
                                  color: Colors.black,
                                  child: const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.play_circle_outline, size: 48, color: Colors.white70),
                                        SizedBox(height: 8),
                                        Text('Video selected', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                )
                              : Image.file(_selectedMediaFile!, fit: BoxFit.cover))
                          : (_mediaType == 'video'
                              ? Container(
                                  color: Colors.black,
                                  child: const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.play_circle_outline, size: 48, color: Colors.white70),
                                        SizedBox(height: 8),
                                        Text('Video selected', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                )
                              : CachedNetworkImage(
                                  imageUrl: _remoteMediaUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: Colors.black12,
                                    child: const Center(child: CircularProgressIndicator()),
                                  ),
                                  errorWidget: (context, url, error) => const Icon(Icons.error),
                                )),
                    ),
                  )
                else
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_outlined, size: 32, color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
                          const SizedBox(height: 6),
                          Text(
                            'No Cover Media Uploaded',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),

                // Description (italic / bold lead)
                if (_descController.text.isNotEmpty) ...[
                  Text(
                    _descController.text,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Content Body paragraphs
                  Text(
                    _descController.text,
                    style: const TextStyle(fontSize: 16, height: 1.6),
                  ),
                ] else ...[
                  Text(
                    'Your description will appear here...',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Engagement Row
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.thumb_up_alt_outlined, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    const Text(
                      '0 likes',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.comment_outlined, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    const Text(
                      '0 comments',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: Navigator.canPop(context)
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
                onPressed: () => Navigator.pop(context),
              ),
            )
          : null,
      body: SafeArea(
        child: _isLoadingPost
            ? const Center(child: CircularProgressIndicator())
            : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 800;

                    if (isWide) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: _buildPageHeader(theme),
                          ),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Form column
                                Expanded(
                                  flex: 3,
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.only(left: 24, right: 12, bottom: 40),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: _buildFormChildren(theme),
                                    ),
                                  ),
                                ),
                                // Live preview column
                                SizedBox(
                                  width: 380,
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.only(left: 12, right: 24, bottom: 40),
                                    child: _buildLivePreview(theme),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    } else {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildPageHeader(theme),
                            ..._buildFormChildren(theme),
                            const SizedBox(height: 40),
                            const Divider(),
                            const SizedBox(height: 24),
                            _buildLivePreview(theme),
                            const SizedBox(height: 40),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// CUSTOM PAINTER FOR DASHED BORDERS
// ──────────────────────────────────────────────────────────
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double borderRadius;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 2,
    this.dashWidth = 6,
    this.dashSpace = 4,
    this.borderRadius = 20,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius),
      ));

    final dashPath = Path();
    var distance = 0.0;
    for (final pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth ||
      dashWidth != oldDelegate.dashWidth ||
      dashSpace != oldDelegate.dashSpace ||
      borderRadius != oldDelegate.borderRadius;
}
