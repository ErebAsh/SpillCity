import 'package:spillcity/core/utils/helpers.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';
import 'package:spillcity/services/cloudinary_service.dart';

// ─── Format Time Utility ───
class StoryCreationSheet extends StatefulWidget {
  const StoryCreationSheet({super.key});

  @override
  StoryCreationSheetState createState() => StoryCreationSheetState();
}

class StoryCreationSheetState extends State<StoryCreationSheet> with WidgetsBindingObserver {
  String _createStoryTab = 'text'; // 'text' | 'camera' | 'photo' | 'video'
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();
  
  int _selectedGradientIdx = 0;
  bool _isCreating = false;
  final _picker = ImagePicker();

  // Camera specific
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIdx = 0;
  bool _isRecordingVideo = false;
  String _cameraMode = 'photo'; // 'photo' | 'video'
  
  // Timer for video recording
  Timer? _recordTimer;
  int _recordDuration = 0;

  // Captured camera paths
  String? _capturedPath;
  String? _capturedType; // 'image' | 'video'

  // Selected or Confirmed Media File
  File? _mediaFile;
  String _mediaType = 'image'; // 'image' or 'video'
  VideoPlayerController? _reviewVideoController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCameras();
  }

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        // Look for front/user camera first as default if available, or just first one
        int defaultIdx = 0;
        for (int i = 0; i < _cameras.length; i++) {
          if (_cameras[i].lensDirection == CameraLensDirection.front) {
            defaultIdx = i;
            break;
          }
        }
        _selectedCameraIdx = defaultIdx;
        _setCamera(_cameras[_selectedCameraIdx]);
      }
    } catch (e) {
      debugPrint("Camera init error: $e");
    }
  }

  Future<void> _setCamera(CameraDescription desc) async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }
    _cameraController = CameraController(desc, ResolutionPreset.high, enableAudio: true);
    try {
      await _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Camera configure error: $e");
    }
  }

  void _flipCamera() {
    if (_cameras.length > 1) {
      _selectedCameraIdx = (_selectedCameraIdx + 1) % _cameras.length;
      _setCamera(_cameras[_selectedCameraIdx]);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _setCamera(cameraController.description);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    _captionController.dispose();
    _cameraController?.dispose();
    _reviewVideoController?.dispose();
    _recordTimer?.cancel();
    super.dispose();
  }

  // Gallery Picker
  Future<void> _pickGalleryMedia() async {
    final XFile? picked = await _picker.pickMedia(imageQuality: 70);
    if (picked != null) {
      final ext = picked.path.split('.').last.toLowerCase();
      final isVideo = ext == 'mp4' || ext == 'mov' || ext == 'webm' || ext == '3gp' || ext == 'avi' || ext == 'mkv';
      
      setState(() {
        _mediaFile = File(picked.path);
        _mediaType = isVideo ? 'video' : 'image';
        _createStoryTab = isVideo ? 'video' : 'photo';
        _capturedPath = null;
        _capturedType = null;
      });
      
      if (isVideo) {
        _initReviewVideo(_mediaFile!);
      }
    }
  }

  // Camera Actions
  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      final XFile photo = await _cameraController!.takePicture();
      setState(() {
        _capturedPath = photo.path;
        _capturedType = 'image';
      });
    } catch (e) {
      debugPrint("Photo capture error: $e");
    }
  }

  Future<void> _startVideoRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_cameraController!.value.isRecordingVideo) return;
    try {
      await _cameraController!.startVideoRecording();
      setState(() {
        _isRecordingVideo = true;
      });
      _startRecordTimer();
    } catch (e) {
      debugPrint("Start video record error: $e");
    }
  }

  Future<void> _stopVideoRecording() async {
    if (_cameraController == null || !_cameraController!.value.isRecordingVideo) return;
    try {
      final XFile video = await _cameraController!.stopVideoRecording();
      _stopRecordTimer();
      setState(() {
        _isRecordingVideo = false;
        _capturedPath = video.path;
        _capturedType = 'video';
      });
      _initReviewVideo(File(video.path));
    } catch (e) {
      debugPrint("Stop video record error: $e");
    }
  }

  void _discardCameraCapture() {
    _reviewVideoController?.dispose();
    _reviewVideoController = null;
    setState(() {
      _capturedPath = null;
      _capturedType = null;
    });
  }

  void _useCameraCapture() {
    if (_capturedPath != null) {
      setState(() {
        _mediaFile = File(_capturedPath!);
        _mediaType = _capturedType!;
        _createStoryTab = _capturedType == 'video' ? 'video' : 'photo';
        _capturedPath = null;
        _capturedType = null;
      });
      if (_mediaType == 'video') {
        _initReviewVideo(_mediaFile!);
      }
    }
  }

  void _initReviewVideo(File file) {
    _reviewVideoController?.dispose();
    _reviewVideoController = VideoPlayerController.file(file)
      ..initialize().then((_) {
        _reviewVideoController!.setLooping(true);
        _reviewVideoController!.setVolume(0.0); // Muted by default per user request
        _reviewVideoController!.play();
        if (mounted) setState(() {});
      });
  }

  void _startRecordTimer() {
    _recordTimer?.cancel();
    setState(() {
      _recordDuration = 0;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _recordDuration++;
        });
      }
    });
  }

  void _stopRecordTimer() {
    _recordTimer?.cancel();
    _recordTimer = null;
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  // Publish
  Future<void> _publishStory() async {
    final text = _textController.text.trim();
    final caption = _captionController.text.trim();

    if (_createStoryTab == 'text' && text.isEmpty) return;
    if ((_createStoryTab == 'photo' || _createStoryTab == 'video') && _mediaFile == null) return;

    setState(() => _isCreating = true);

    try {
      final supabase = Supabase.instance.client;
      final myId = supabase.auth.currentUser?.id;
      if (myId == null) return;

      String type = 'text';
      String? mediaUrl;

      if ((_createStoryTab == 'photo' || _createStoryTab == 'video') && _mediaFile != null) {
        type = _mediaType;
        mediaUrl = await CloudinaryService.uploadMedia(
          file: _mediaFile!,
          category: 'stories',
        );
      }

      try {
        await supabase.from('stories').insert({
          'user_id': myId,
          'seen': false,
        });
      } catch (_) {}

      // Reset seen status for all viewers when a new slide is published
      try {
        await supabase.from('story_views').delete().eq('story_id', myId);
      } catch (e) {
        debugPrint("Failed to reset story views: $e");
      }

      await supabase.from('story_slides').insert({
        'id': 's${DateTime.now().millisecondsSinceEpoch}',
        'story_id': myId,
        'type': type == 'image' ? 'image' : (type == 'video' ? 'video' : 'text'),
        'text': _createStoryTab == 'text' ? text : null,
        'caption': (_createStoryTab == 'photo' || _createStoryTab == 'video') && caption.isNotEmpty ? caption : null,
        'gradient': storyGradients[_selectedGradientIdx],
        'media_url': mediaUrl,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Failed to create story: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to publish story: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  // UI Building helpers
  Widget _buildCircleIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: 44,
          height: 44,
          color: Colors.white.withValues(alpha: 0.12),
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 22),
            onPressed: onPressed,
            tooltip: tooltip,
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }

  Widget _buildModeSwitcher() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSwitcherButton(
                label: 'Text',
                icon: Icons.text_fields,
                isActive: _createStoryTab == 'text',
                onTap: () {
                  setState(() {
                    _createStoryTab = 'text';
                  });
                },
              ),
              _buildSwitcherButton(
                label: 'Camera',
                icon: Icons.camera_alt_outlined,
                isActive: _createStoryTab == 'camera',
                onTap: () {
                  setState(() {
                    _createStoryTab = 'camera';
                  });
                  if (_cameraController == null && _cameras.isNotEmpty) {
                    _setCamera(_cameras[_selectedCameraIdx]);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitcherButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.6),
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendFab({
    required VoidCallback? onPressed,
    required bool enabled,
    bool isSmall = false,
  }) {
    final size = isSmall ? 48.0 : 56.0;
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.35,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF25D366), Color(0xFF128C7E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: const Color(0xFF25D366).withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    )
                  ]
                : null,
          ),
          child: const Center(
            child: Icon(
              Icons.send,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  // Tab View Builders
  Widget _buildTextMode(BuildContext context) {
    final gradient = parseHtmlGradient(storyGradients[_selectedGradientIdx]);
    final canPost = _textController.text.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(gradient: gradient),
      child: Stack(
        children: [
          // Centered Text Input
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: TextField(
                controller: _textController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textAlign: TextAlign.center,
                maxLength: 200,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                decoration: InputDecoration(
                  hintText: 'Type a status...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),

          // Top Controls
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCircleIconButton(
                  icon: Icons.close,
                  onPressed: () => Navigator.pop(context),
                ),
                _buildCircleIconButton(
                  icon: Icons.color_lens_outlined,
                  onPressed: () {
                    setState(() {
                      _selectedGradientIdx = (_selectedGradientIdx + 1) % storyGradients.length;
                    });
                  },
                ),
              ],
            ),
          ),

          // Bottom Bar and gradient list
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Gradient Dots Strip
                SizedBox(
                  height: 48,
                  child: Center(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      shrinkWrap: true,
                      itemCount: storyGradients.length,
                      itemBuilder: (context, idx) {
                        final grad = parseHtmlGradient(storyGradients[idx]);
                        final isActive = _selectedGradientIdx == idx;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedGradientIdx = idx),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: grad,
                              border: Border.all(
                                color: isActive ? Colors.white : Colors.white24,
                                width: isActive ? 3 : 2,
                              ),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      )
                                    ]
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildModeSwitcher(),
                    _buildSendFab(
                      onPressed: canPost ? _publishStory : null,
                      enabled: canPost && !_isCreating,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraMode(BuildContext context) {
    final hasCaptured = _capturedPath != null;

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // 1. Camera Viewport / Live feed OR Captured image/video preview
          Positioned.fill(
            child: !hasCaptured
                ? (_cameraController != null && _cameraController!.value.isInitialized
                    ? ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                        child: Center(
                          child: CameraPreview(_cameraController!),
                        ),
                      )
                    : Container(
                        color: Colors.black,
                        child: const Center(
                          child: CircularProgressIndicator(color: Color(0xFF25D366)),
                        ),
                      ))
                : ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                    child: Container(
                      color: Colors.black,
                      child: _capturedType == 'image'
                          ? Image.file(
                              File(_capturedPath!),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            )
                          : (_reviewVideoController != null && _reviewVideoController!.value.isInitialized
                              ? Center(
                                  child: AspectRatio(
                                    aspectRatio: _reviewVideoController!.value.aspectRatio,
                                    child: VideoPlayer(_reviewVideoController!),
                                  ),
                                )
                              : const Center(
                                  child: CircularProgressIndicator(color: Color(0xFF25D366)),
                                )),
                    ),
                  ),
          ),

          // 2. Top bar (different actions depending on captured state)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCircleIconButton(
                  icon: Icons.close,
                  onPressed: () {
                    if (hasCaptured) {
                      _discardCameraCapture();
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
                if (!hasCaptured)
                  _buildCircleIconButton(
                    icon: Icons.flip_camera_ios_outlined,
                    onPressed: _flipCamera,
                  ),
              ],
            ),
          ),

          // 3. Recording Indicator Banner
          if (_isRecordingVideo)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _formatDuration(_recordDuration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 4. Bottom Controls Area (grid matching web layout)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!hasCaptured) ...[
                  // Shutter controls row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Gallery button
                      _buildCircleIconButton(
                        icon: Icons.photo_library_outlined,
                        onPressed: _pickGalleryMedia,
                        tooltip: 'Gallery',
                      ),
                      // Shutter Center
                      GestureDetector(
                        onTap: () {
                          if (_cameraMode == 'photo') {
                            _capturePhoto();
                          } else {
                            if (_isRecordingVideo) {
                              _stopVideoRecording();
                            } else {
                              _startVideoRecording();
                            }
                          }
                        },
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _isRecordingVideo ? Colors.red : Colors.white,
                              width: 4,
                            ),
                          ),
                          padding: const EdgeInsets.all(5),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: _isRecordingVideo ? BoxShape.rectangle : BoxShape.circle,
                              borderRadius: _isRecordingVideo ? BorderRadius.circular(6) : null,
                              color: _isRecordingVideo ? Colors.red : Colors.white,
                            ),
                          ),
                        ),
                      ),
                      // Camera Mode Toggle (Photo vs Video)
                      _buildCircleIconButton(
                        icon: _cameraMode == 'photo'
                            ? Icons.videocam_outlined
                            : Icons.photo_camera_outlined,
                        onPressed: () {
                          setState(() {
                            _cameraMode = _cameraMode == 'photo' ? 'video' : 'photo';
                          });
                        },
                        tooltip: _cameraMode == 'photo' ? 'Switch to Video' : 'Switch to Photo',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _cameraMode == 'photo' ? 'Tap for photo' : 'Tap to record',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildModeSwitcher(),
                ] else ...[
                  // Review buttons (Discard / Retake and Use Capture)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _discardCameraCapture,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                            backgroundColor: Colors.white.withValues(alpha: 0.1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.close, size: 20),
                              SizedBox(width: 8),
                              Text('Retake', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF25D366).withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _useCameraCapture,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check, size: 20),
                                const SizedBox(width: 8),
                                Text('Use ${_capturedType == 'video' ? 'Video' : 'Photo'}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaMode(BuildContext context) {
    final isVideo = _createStoryTab == 'video';

    return Container(
      color: const Color(0xFF0A0A0A),
      child: Stack(
        children: [
          // 1. Fullscreen Viewport
          Positioned.fill(
            child: _mediaFile == null
                ? Container(
                    color: Colors.black,
                    child: const Center(
                      child: Text("No media selected", style: TextStyle(color: Colors.white)),
                    ),
                  )
                : (!isVideo
                    ? Image.file(
                        _mediaFile!,
                        fit: BoxFit.contain,
                      )
                    : (_reviewVideoController != null && _reviewVideoController!.value.isInitialized
                        ? Center(
                            child: AspectRatio(
                              aspectRatio: _reviewVideoController!.value.aspectRatio,
                              child: VideoPlayer(_reviewVideoController!),
                            ),
                          )
                        : const Center(
                            child: CircularProgressIndicator(color: Color(0xFF25D366)),
                          ))),
          ),

          // 2. Top bar with Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Row(
              children: [
                _buildCircleIconButton(
                  icon: Icons.arrow_back,
                  onPressed: () {
                    // Dispose media and return to camera/text selector
                    _reviewVideoController?.dispose();
                    _reviewVideoController = null;
                    setState(() {
                      _mediaFile = null;
                      _createStoryTab = 'camera';
                    });
                  },
                ),
              ],
            ),
          ),

          // 3. Caption text entry bar + Small Send FAB
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: TextField(
                          controller: _captionController,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          decoration: InputDecoration(
                            hintText: 'Add a caption...',
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: InputBorder.none,
                          ),
                          maxLength: 100,
                          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _buildSendFab(
                  onPressed: _publishStory,
                  enabled: !_isCreating,
                  isSmall: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Render the correct tab/layout based on state
    Widget content;
    switch (_createStoryTab) {
      case 'text':
        content = _buildTextMode(context);
        break;
      case 'camera':
        content = _buildCameraMode(context);
        break;
      case 'photo':
      case 'video':
        content = _buildMediaMode(context);
        break;
      default:
        content = _buildTextMode(context);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: content,
    );
  }
}

// ════════════════════════════════════════════
//  NEW CHAT MODAL
// ════════════════════════════════════════════

