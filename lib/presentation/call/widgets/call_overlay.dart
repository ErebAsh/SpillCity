import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'dart:async';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/global_call_manager.dart';
import 'package:spillcity/data/repositories/providers.dart';
import 'package:spillcity/domain/entities/user.dart';

class CallOverlay extends ConsumerStatefulWidget {
  final GlobalCallState callState;

  const CallOverlay({super.key, required this.callState});

  @override
  ConsumerState<CallOverlay> createState() => _CallOverlayState();
}

class _CallOverlayState extends ConsumerState<CallOverlay> {
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isSpeakerOn = false;
  bool _isFrontCamera = true;
  int _callDuration = 0;
  Timer? _timer;
  bool _areControlsVisible = true;
  Timer? _hideControlsTimer;
  double? _pipLeft;
  double? _pipTop;
  bool _isDraggingPiP = false;

  void _startHideControlsTimer() {
    final isVideoCall = widget.callState.type == 'video';
    if (!isVideoCall) return;

    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _areControlsVisible = false;
        });
      }
    });
  }

  void _resetHideControlsTimer() {
    if (!_areControlsVisible) {
      setState(() {
        _areControlsVisible = true;
      });
    }
    _startHideControlsTimer();
  }

  @override
  void initState() {
    super.initState();
    if (widget.callState.mode == 'connected') {
      _startTimer();
      _startHideControlsTimer();
    }
  }

  @override
  void didUpdateWidget(covariant CallOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.callState.mode != 'connected' && widget.callState.mode == 'connected') {
      _startTimer();
      _startHideControlsTimer();
    }
    if (oldWidget.callState.type == 'voice' && widget.callState.type == 'video') {
      setState(() {
        _isVideoOff = false;
      });
      final notifier = ref.read(callManagerProvider);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifier.toggleParticipantMute(_isMuted, false);
      });
    }
    if (oldWidget.callState.type == 'video' && widget.callState.type == 'voice') {
      setState(() {
        _isVideoOff = true;
      });
      final notifier = ref.read(callManagerProvider);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifier.toggleParticipantMute(_isMuted, true);
      });
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _callDuration++;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _hideControlsTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final mins = (seconds / 60).floor();
    final secs = seconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.callState.mode == 'connected' ? 'connected' : 'ringing';
    final isVideoCall = widget.callState.type == 'video';
    final notifier = ref.watch(callManagerProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _resetHideControlsTimer,
        child: Stack(
          children: [
            // Background Video Layer
            if (isVideoCall)
              if (status == 'connected')
                _buildVideoLayer(notifier)
              else if (status == 'ringing' && notifier.engine != null)
                Positioned.fill(
                  child: AgoraVideoView(
                    controller: VideoViewController(
                      rtcEngine: notifier.engine!,
                      canvas: const VideoCanvas(uid: 0),
                    ),
                  ),
                ),

            // Blurred Background for audio calls or when video preview is not ready during ringing
            if (!isVideoCall || (status == 'ringing' && notifier.engine == null))
              Positioned.fill(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: widget.callState.userAvatar.isNotEmpty 
                          ? widget.callState.userAvatar 
                          : 'https://via.placeholder.com/150',
                      fit: BoxFit.cover,
                    ),
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),

            // Foreground Content
            AnimatedOpacity(
              opacity: _areControlsVisible || !isVideoCall || status == 'ringing' ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: IgnorePointer(
                ignoring: !_areControlsVisible && isVideoCall && status == 'connected',
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildHeaderOrParticipants(status, notifier),
                      if (status == 'ringing' && widget.callState.mode == 'incoming')
                        _buildIncomingControls(notifier)
                      else
                        _buildActiveControls(notifier),
                    ],
                  ),
                ),
              ),
            ),

            // Voice-to-video switch overlays
            if (notifier.isSwitchRequestPending)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.85),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundImage: CachedNetworkImageProvider(
                              widget.callState.userAvatar.isNotEmpty 
                                  ? widget.callState.userAvatar 
                                  : 'https://via.placeholder.com/150'
                            ),
                          ),
                          const SizedBox(height: 32),
                          const Text(
                            'Requesting video call...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.blueAccent,
                              strokeWidth: 2.5,
                            ),
                          ),
                          const SizedBox(height: 80),
                          ElevatedButton(
                            onPressed: () => notifier.cancelSwitchRequest(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            if (notifier.showSwitchRequestDialog)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.85),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundImage: CachedNetworkImageProvider(
                              widget.callState.userAvatar.isNotEmpty 
                                  ? widget.callState.userAvatar 
                                  : 'https://via.placeholder.com/150'
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            '${notifier.switchRequestSenderName ?? widget.callState.userName} wants to switch to video call',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              'Your camera will turn on so they can see you.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 80),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildControlButton(
                                icon: Icons.close,
                                color: Colors.red,
                                label: 'Decline',
                                onTap: () => notifier.declineSwitchToVideo(),
                              ),
                              _buildControlButton(
                                icon: Icons.videocam,
                                color: Colors.green,
                                label: 'Accept',
                                onTap: () => notifier.acceptSwitchToVideo(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            if (notifier.switchRequestMessage != null)
              Positioned(
                top: 80,
                left: 24,
                right: 24,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blueAccent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            notifier.switchRequestMessage!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPipContent(GlobalCallManagerNotifier notifier) {
    return GestureDetector(
      onPanStart: (details) {
        setState(() {
          _isDraggingPiP = true;
        });
      },
      onPanUpdate: (details) {
        final size = MediaQuery.of(context).size;
        final screenWidth = size.width;
        final screenHeight = size.height;
        final pipWidth = 120.0;
        final pipHeight = 160.0;

        final defaultLeft = screenWidth - pipWidth - 16;
        final defaultTop = screenHeight - pipHeight - 180;

        double currentLeft = (_pipLeft ?? defaultLeft) + details.delta.dx;
        double currentTop = (_pipTop ?? defaultTop) + details.delta.dy;

        // Constraints: Keep completely on screen (with margins)
        currentLeft = currentLeft.clamp(16.0, screenWidth - pipWidth - 16.0);
        currentTop = currentTop.clamp(80.0, screenHeight - pipHeight - 80.0);

        setState(() {
          _pipLeft = currentLeft;
          _pipTop = currentTop;
        });

        _resetHideControlsTimer();
      },
      onPanEnd: (details) {
        final size = MediaQuery.of(context).size;
        final screenWidth = size.width;
        final screenHeight = size.height;
        final pipWidth = 120.0;
        final pipHeight = 160.0;

        final centerLeft = screenWidth / 2 - pipWidth / 2;
        final centerTop = screenHeight / 2 - pipHeight / 2;

        final currentLeft = _pipLeft ?? (screenWidth - pipWidth - 16);
        final currentTop = _pipTop ?? (screenHeight - pipHeight - 180);

        // Snap to closest corner
        final snapLeft = currentLeft < centerLeft ? 16.0 : (screenWidth - pipWidth - 16.0);
        final snapTop = currentTop < centerTop ? 80.0 : (screenHeight - pipHeight - 180.0);

        setState(() {
          _isDraggingPiP = false;
          _pipLeft = snapLeft;
          _pipTop = snapTop;
        });
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: Colors.grey[900],
          child: AgoraVideoView(
            controller: VideoViewController(
              rtcEngine: notifier.engine!,
              canvas: const VideoCanvas(uid: 0),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoLayer(GlobalCallManagerNotifier notifier) {
    if (notifier.engine == null) return const SizedBox.shrink();
    final uids = notifier.remoteUids;

    if (uids.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    // Single remote user: full screen
    if (uids.length == 1) {
      final size = MediaQuery.of(context).size;
      final screenWidth = size.width;
      final screenHeight = size.height;
      final pipWidth = 120.0;
      final pipHeight = 160.0;

      final defaultLeft = screenWidth - pipWidth - 16;
      final defaultTop = screenHeight - pipHeight - 180;

      final currentLeft = _pipLeft ?? defaultLeft;
      final currentTop = _pipTop ?? defaultTop;

      return Stack(
        children: [
          AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: notifier.engine!,
              canvas: VideoCanvas(uid: uids.first),
              connection: const RtcConnection(channelId: ''),
            ),
          ),

          // Local Video (PiP)
          if (notifier.localUserJoined && !_isVideoOff)
            _isDraggingPiP
                ? Positioned(
                    left: currentLeft,
                    top: currentTop,
                    width: pipWidth,
                    height: pipHeight,
                    child: _buildPipContent(notifier),
                  )
                : AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    left: currentLeft,
                    top: currentTop,
                    width: pipWidth,
                    height: pipHeight,
                    child: _buildPipContent(notifier),
                  ),
        ],
      );
    }

    // Multiple remote users: Grid view including local video
    final allParticipants = [
      if (notifier.localUserJoined && !_isVideoOff) 0,
      ...uids,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 80.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 3 / 4,
        ),
        itemCount: allParticipants.length,
        itemBuilder: (context, index) {
          final uid = allParticipants[index];
          
          String name = 'User';
          bool isMuted = false;
          bool isVideoOff = false;
          
          for (var entry in notifier.callParticipants.entries) {
            if (entry.value['agoraUid'] == uid) {
              name = entry.value['name'] ?? 'User';
              isMuted = entry.value['isMuted'] as bool? ?? false;
              isVideoOff = entry.value['isVideoOff'] as bool? ?? false;
              break;
            }
          }

          if (uid == 0) {
            name = 'Me';
            isMuted = _isMuted;
            isVideoOff = _isVideoOff;
          }

          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: Colors.grey[900],
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (!isVideoOff)
                    AgoraVideoView(
                      controller: uid == 0
                          ? VideoViewController(
                              rtcEngine: notifier.engine!,
                              canvas: const VideoCanvas(uid: 0),
                            )
                          : VideoViewController.remote(
                              rtcEngine: notifier.engine!,
                              canvas: VideoCanvas(uid: uid),
                              connection: const RtcConnection(channelId: ''),
                            ),
                    )
                  else
                    const Center(
                      child: Icon(Icons.videocam_off, color: Colors.white54, size: 40),
                    ),
                  // Name banner
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        name,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                  // Mute Badge
                  if (isMuted)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mic_off,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderOrParticipants(String status, GlobalCallManagerNotifier notifier) {
    final participants = notifier.callParticipants.values.toList();
    if (status == 'ringing' || participants.length <= 2) {
      // 1-on-1 ringing or connection
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: CachedNetworkImageProvider(
                widget.callState.userAvatar.isNotEmpty 
                    ? widget.callState.userAvatar 
                    : 'https://via.placeholder.com/150'
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.callState.userName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              status == 'connected'
                  ? (notifier.isLocalOnHold
                      ? 'Call on Hold'
                      : notifier.isRemoteOnHold
                          ? 'You are on Hold'
                          : _formatDuration(_callDuration))
                  : widget.callState.mode == 'incoming'
                      ? 'Incoming ${widget.callState.type == 'video' ? 'Video' : 'Voice'} Call...'
                      : '${widget.callState.type == 'video' ? 'Video' : 'Voice'} Calling...',
              style: TextStyle(
                color: (status == 'connected' && (notifier.isLocalOnHold || notifier.isRemoteOnHold))
                    ? Colors.blueAccent
                    : Colors.white70,
                fontSize: 16,
                fontWeight: (status == 'connected' && (notifier.isLocalOnHold || notifier.isRemoteOnHold))
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
      );
    }

    // Group call audio view
    return Padding(
      padding: const EdgeInsets.only(top: 40, left: 16, right: 16),
      child: Column(
        children: [
          const Text(
            'Group Call',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatDuration(_callDuration),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 30),
          Wrap(
            spacing: 24,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: participants.map((p) {
              final avatar = p['avatar'] as String? ?? '';
              final name = p['name'] as String? ?? 'User';
              final isMuted = p['isMuted'] as bool? ?? false;
              final isCalling = p['status'] == 'calling';

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: isCalling ? 0.5 : 1.0,
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.white10,
                          backgroundImage: avatar.isNotEmpty
                              ? CachedNetworkImageProvider(avatar)
                              : null,
                          child: avatar.isEmpty
                              ? Text(
                                  name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white, fontSize: 24),
                                )
                              : null,
                        ),
                      ),
                      if (isCalling)
                        const SizedBox(
                          width: 72,
                          height: 72,
                          child: CircularProgressIndicator(
                            color: Colors.white54,
                            strokeWidth: 2,
                          ),
                        ),
                      if (isMuted && !isCalling)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.mic_off,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  if (isCalling)
                    const Text(
                      'Calling...',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingControls(GlobalCallManagerNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 60),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: Icons.call_end,
            color: Colors.red,
            label: 'Decline',
            onTap: () => notifier.declineCall(),
          ),
          _buildControlButton(
            icon: Icons.call,
            color: Colors.green,
            label: 'Accept',
            onTap: () => notifier.acceptCall(),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveControls(GlobalCallManagerNotifier notifier) {
    final isVideoCall = widget.callState.type == 'video';

    return Padding(
      padding: const EdgeInsets.only(bottom: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top row buttons: Speaker, Add participant, Flip camera
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                color: _isSpeakerOn ? Colors.blueAccent : Colors.white10,
                label: 'Speaker',
                onTap: () async {
                  if (notifier.engine != null) {
                    await notifier.engine!.setEnableSpeakerphone(!_isSpeakerOn);
                    setState(() => _isSpeakerOn = !_isSpeakerOn);
                  }
                },
              ),
              _buildControlButton(
                icon: Icons.person_add,
                color: Colors.white10,
                label: 'Add',
                onTap: () => _showAddParticipantSheet(context, notifier),
              ),
              if (isVideoCall)
                _buildControlButton(
                  icon: Icons.flip_camera_ios,
                  color: Colors.white10,
                  label: 'Flip',
                  onTap: () async {
                    if (notifier.engine != null) {
                      await notifier.engine!.switchCamera();
                      setState(() => _isFrontCamera = !_isFrontCamera);
                    }
                  },
                )
              else
                _buildControlButton(
                  icon: notifier.isLocalOnHold ? Icons.play_arrow : Icons.pause,
                  color: notifier.isLocalOnHold ? Colors.blueAccent : Colors.white10,
                  label: notifier.isLocalOnHold ? 'Resume' : 'Hold',
                  onTap: () => notifier.toggleCallHold(!notifier.isLocalOnHold),
                ),
            ],
          ),
          const SizedBox(height: 20),
          // Bottom row controls: Mute, End, Switch type
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: _isMuted ? Icons.mic_off : Icons.mic,
                color: _isMuted ? Colors.blueAccent : Colors.white24,
                label: 'Mute',
                onTap: () async {
                  if (notifier.engine != null) {
                    await notifier.engine!.muteLocalAudioStream(!_isMuted);
                    setState(() => _isMuted = !_isMuted);
                    await notifier.toggleParticipantMute(_isMuted, _isVideoOff);
                  }
                },
              ),
              _buildControlButton(
                icon: Icons.call_end,
                color: Colors.red,
                label: 'End',
                onTap: () => notifier.endCall(),
              ),
              _buildControlButton(
                icon: isVideoCall ? Icons.videocam : Icons.videocam_off,
                color: isVideoCall ? Colors.blueAccent : Colors.white24,
                label: isVideoCall ? 'Switch Voice' : 'Switch Video',
                onTap: () async {
                  if (isVideoCall) {
                    // Video to Voice: Direct switch without confirmation (like WhatsApp)
                    final targetType = 'voice';
                    await notifier.switchCallType(targetType);
                    setState(() {
                      _isVideoOff = true;
                    });
                    await notifier.toggleParticipantMute(_isMuted, _isVideoOff);
                  } else {
                    // Voice to Video: Confirmation dialog (like WhatsApp)
                    if (!mounted) return;
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          backgroundColor: Colors.grey[950],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          title: const Text('Switch to video?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          content: const Text(
                            'Your camera will turn on so the other person can see you.',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Switch', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        );
                      },
                    );

                    if (confirmed == true) {
                      await notifier.requestSwitchToVideo();
                    }
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddParticipantSheet(BuildContext context, GlobalCallManagerNotifier notifier) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[950],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final authRepo = ref.watch(authRepositoryProvider);
            return FutureBuilder<List<UserModel>>(
              future: authRepo.getEligibleCallUsers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 300,
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  );
                }
                
                final allUsers = snapshot.data ?? [];
                // Filter out users who are already in the call
                final eligibleUsers = allUsers.where((u) => !notifier.callParticipants.containsKey(u.id)).toList();

                if (eligibleUsers.isEmpty) {
                  return SizedBox(
                    height: 250,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.people_outline, color: Colors.white24, size: 48),
                          SizedBox(height: 12),
                          Text(
                            'No eligible users to invite',
                            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Must be mutual follows with chat history',
                            style: TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SizedBox(
                  height: 400,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
                        child: Text(
                          'Add to Call',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: eligibleUsers.length,
                          itemBuilder: (context, index) {
                            final user = eligibleUsers[index];
                            final avatarUrl = user.resolvedAvatarUrl;
                            final hasAvatar = avatarUrl.isNotEmpty && !avatarUrl.contains('ui-avatars.com');
                            
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.white10,
                                backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
                                child: !hasAvatar
                                    ? Text(
                                        user.name.isNotEmpty ? user.name.substring(0, 1).toUpperCase() : '?',
                                        style: const TextStyle(color: Colors.white),
                                      )
                                    : null,
                              ),
                              title: Text(
                                user.name,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                '@${user.username ?? ''}',
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.add_circle, color: Colors.blueAccent),
                                onPressed: () {
                                  notifier.inviteParticipant(user);
                                  Navigator.pop(context);
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            _resetHideControlsTimer();
            onTap();
          },
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
