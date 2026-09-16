import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class CallService {
  static final CallService instance = CallService._init();
  RtcEngine? _engine;
  bool _isInitialized = false;

  // Track state
  int? remoteUid;
  bool isJoined = false;

  CallService._init();

  Future<void> initAgora({
    required String appId,
    required VoidCallback onUserJoined,
    required VoidCallback onUserOffline,
  }) async {
    if (_isInitialized) return;

    // 1. Request mic & camera permissions
    await [Permission.microphone, Permission.camera].request();

    // 2. Initialize engine
    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(
      appId: appId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    // 3. Register event handlers
    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        debugPrint("[Agora] Joined room successfully: ${connection.channelId}");
        isJoined = true;
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        debugPrint("[Agora] Remote user joined: $remoteUid");
        this.remoteUid = remoteUid;
        onUserJoined();
      },
      onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
        debugPrint("[Agora] Remote user offline: $remoteUid due to $reason");
        this.remoteUid = null;
        onUserOffline();
      },
      onLeaveChannel: (RtcConnection connection, RtcStats stats) {
        debugPrint("[Agora] Left channel: ${connection.channelId}");
        isJoined = false;
        remoteUid = null;
      },
    ));

    _isInitialized = true;
  }

  Future<void> joinCall({
    required String token,
    required String channelName,
    required int uid,
    required bool isVideo,
  }) async {
    if (_engine == null) return;

    if (isVideo) {
      await _engine!.enableVideo();
      await _engine!.startPreview();
    } else {
      await _engine!.enableAudio();
    }

    await _engine!.joinChannel(
      token: token,
      channelId: channelName,
      uid: uid,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );
  }

  Future<void> leaveCall() async {
    if (_engine == null) return;
    await _engine!.leaveChannel();
    remoteUid = null;
    isJoined = false;
  }

  Future<void> toggleMute(bool isMuted) async {
    await _engine?.muteLocalAudioStream(isMuted);
  }

  Future<void> toggleCamera(bool isCamOff) async {
    await _engine?.muteLocalVideoStream(isCamOff);
  }

  Future<void> destroy() async {
    if (_engine != null) {
      await _engine!.release();
      _engine = null;
      _isInitialized = false;
    }
  }

  // Helper Widget to display remote/local video frames
  RtcEngine get engine {
    if (_engine == null) {
      throw StateError("Agora Engine not initialized");
    }
    return _engine!;
  }
}
