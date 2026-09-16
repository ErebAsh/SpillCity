import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';

import 'package:spillcity/domain/entities/user.dart';
import 'package:spillcity/core/constants/app_config.dart';
import 'package:http/http.dart' as http;
import '../widgets/call_overlay.dart';

int getIntUid(String uuid) {
  final bytes = utf8.encode(uuid);
  final digest = sha256.convert(bytes);
  final value = ByteData.sublistView(Uint8List.fromList(digest.bytes)).getUint32(0);
  return (value & 0x7FFFFFFF) == 0 ? 1 : (value & 0x7FFFFFFF);
}

final callManagerProvider = ChangeNotifierProvider((ref) => GlobalCallManagerNotifier());

class GlobalCallState {
  final String type; // 'voice' or 'video'
  final String mode; // 'incoming', 'outgoing', 'connected'
  final String userId;
  final String userName;
  final String userAvatar;
  final String channelName;

  GlobalCallState({
    required this.type,
    required this.mode,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.channelName,
  });

  GlobalCallState copyWith({String? mode}) {
    return GlobalCallState(
      type: type,
      mode: mode ?? this.mode,
      userId: userId,
      userName: userName,
      userAvatar: userAvatar,
      channelName: channelName,
    );
  }
}

class GlobalCallManagerNotifier extends ChangeNotifier {
  GlobalCallState? _activeCall;
  GlobalCallState? get activeCall => _activeCall;

  RtcEngine? _engine;
  PusherChannelsFlutter? _pusher;
  final List<int> _remoteUids = [];
  bool _localUserJoined = false;

  final Map<String, Map<String, dynamic>> _callParticipants = {};

  bool _isSwitchRequestPending = false;
  bool get isSwitchRequestPending => _isSwitchRequestPending;

  bool _showSwitchRequestDialog = false;
  bool get showSwitchRequestDialog => _showSwitchRequestDialog;

  String? _switchRequestSenderName;
  String? get switchRequestSenderName => _switchRequestSenderName;

  String? _switchRequestMessage;
  String? get switchRequestMessage => _switchRequestMessage;

  Timer? _switchRequestTimer;

  bool _isLocalOnHold = false;
  bool get isLocalOnHold => _isLocalOnHold;

  bool _isRemoteOnHold = false;
  bool get isRemoteOnHold => _isRemoteOnHold;

  List<int> get remoteUids => _remoteUids;
  bool get localUserJoined => _localUserJoined;
  RtcEngine? get engine => _engine;
  Map<String, Map<String, dynamic>> get callParticipants => _callParticipants;

  GlobalCallManagerNotifier() {
    _initPusher();
    _listenToCallKitEvents();
    checkActiveCalls();
  }

  void _listenToCallKitEvents() {
    try {
      FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
        if (event == null) return;
        debugPrint('[CallKit Event] Received event: ${event.event}');
        
        switch (event.event) {
          case Event.actionCallAccept:
            final extra = event.body['extra'] ?? {};
            final callerId = extra['callerId'] ?? event.body['id'];
            final callerName = event.body['nameCaller'] ?? 'Caller';
            final avatarUrl = event.body['avatar'] ?? '';
            final channelName = extra['channelName'] ?? '';
            final callType = extra['callType'] ?? 'voice';

            if (_activeCall?.mode == 'connected') return;

            _activeCall = GlobalCallState(
              type: callType,
              mode: 'connected',
              userId: callerId,
              userName: callerName,
              userAvatar: avatarUrl,
              channelName: channelName,
            );
            notifyListeners();
            _sendPusherEvent(callerId, 'call-accepted', {});
            _initAgora();
            break;

          case Event.actionCallDecline:
            final extra = event.body['extra'] ?? {};
            final callerId = extra['callerId'] ?? event.body['id'];
            if (_activeCall != null && _activeCall!.userId == callerId) {
              _sendPusherEvent(callerId, 'call-rejected', {});
              _activeCall = null;
              notifyListeners();
            }
            break;

          case Event.actionCallEnded:
            final extra = event.body['extra'] ?? {};
            final callerId = extra['callerId'] ?? event.body['id'];
            if (_activeCall != null && _activeCall!.userId == callerId) {
              _sendPusherEvent(callerId, 'call-ended', {});
              _activeCall = null;
              _cleanupAgora();
              notifyListeners();
            }
            break;

          default:
            break;
        }
      });
    } catch (e) {
      debugPrint('[CallKit] Error listening to events: $e');
    }
  }

  Future<void> checkActiveCalls() async {
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      if (calls != null && calls is List && calls.isNotEmpty) {
        final activeCallData = calls.first;
        final extra = activeCallData['extra'] ?? {};
        final callerId = extra['callerId'] ?? activeCallData['id'];
        final callerName = activeCallData['nameCaller'] ?? 'Caller';
        final avatarUrl = activeCallData['avatar'] ?? '';
        final channelName = extra['channelName'] ?? '';
        final callType = extra['callType'] ?? 'voice';
        final isAccepted = activeCallData['isAccepted'] as bool? ?? true;

        if (_activeCall?.mode == 'connected') return;

        _activeCall = GlobalCallState(
          type: callType,
          mode: 'connected',
          userId: callerId,
          userName: callerName,
          userAvatar: avatarUrl,
          channelName: channelName,
        );

        // Clear and populate call participants so they render correctly in the UI
        _callParticipants.clear();
        _remoteUids.clear();

        // Add the caller
        _callParticipants[callerId] = {
          'name': callerName,
          'avatar': avatarUrl,
          'status': 'connected',
          'isMuted': false,
          'isVideoOff': callType == 'voice',
          'agoraUid': getIntUid(callerId),
        };

        // Add current user (recipient)
        final currentUser = Supabase.instance.client.auth.currentUser;
        if (currentUser != null) {
          final response = await Supabase.instance.client
              .from('users')
              .select('name, profile_picture')
              .eq('id', currentUser.id)
              .maybeSingle();

          _callParticipants[currentUser.id] = {
            'name': response?['name'] ?? 'User',
            'avatar': response?['profile_picture'] ?? '',
            'status': 'connected',
            'isMuted': false,
            'isVideoOff': callType == 'voice',
            'agoraUid': getIntUid(currentUser.id),
          };
        }

        notifyListeners();

        // If the CallKit event is accepted, send the signaling packet back to the caller
        if (isAccepted) {
          await _sendPusherEvent(callerId, 'call-accepted', {});
        }

        await _initAgora();
      }
    } catch (e) {
      debugPrint('[CallKit] Error checking active calls: $e');
    }
  }

  Future<void> _initPusher() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      _pusher = PusherChannelsFlutter.getInstance();
      await _pusher!.init(
        apiKey: AppConfig.pusherKey,
        cluster: AppConfig.pusherCluster,
        onEvent: _onPusherEvent,
        onAuthorizer: (String channelName, String socketId, dynamic options) async {
          // Generate Pusher Auth Signature via Supabase Edge Function
          final session = Supabase.instance.client.auth.currentSession;
          if (session == null) throw Exception('No session found');

          final response = await http.post(
            Uri.parse('${AppConfig.supabaseUrl}/functions/v1/pusher-auth'),
            headers: {
              'Authorization': 'Bearer ${session.accessToken}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'socket_id': socketId,
              'channel_name': channelName,
            }),
          );

          if (response.statusCode == 200) {
            return jsonDecode(response.body);
          } else {
            throw Exception('Failed to authorize Pusher channel: ${response.body}');
          }
        },
      );
      await _pusher!.subscribe(channelName: 'private-user-${user.id}');
      await _pusher!.connect();
    } catch (e) {
      debugPrint('Pusher init error: $e');
    }
  }

  Future<void> _onPusherEvent(dynamic event) async {
    if (event is PusherEvent) {
      final data = event.data != null && event.data.toString().isNotEmpty 
          ? jsonDecode(event.data.toString()) 
          : {};
      
      switch (event.eventName) {
        case 'incoming-call':
          if (_activeCall != null) {
            // Reject if busy
            _sendPusherEvent(data['caller']['id'], 'call-rejected', {});
            return;
          }
          _activeCall = GlobalCallState(
            type: data['type'] ?? 'voice',
            mode: 'incoming',
            userId: data['caller']['id'],
            userName: data['caller']['name'] ?? 'Incoming Caller',
            userAvatar: data['caller']['avatar'] ?? '',
            channelName: data['channelName'],
          );

          // Reset participants
          _callParticipants.clear();
          _remoteUids.clear();

          // Add caller
          final callerId = data['caller']['id'] as String;
          _callParticipants[callerId] = {
            'name': data['caller']['name'] ?? 'Incoming Caller',
            'avatar': data['caller']['avatar'] ?? '',
            'status': 'connected',
            'isMuted': false,
            'isVideoOff': (data['type'] ?? 'voice') == 'voice',
            'agoraUid': getIntUid(callerId),
          };

          // Add other participants in incoming-call invitation list
          final participantsList = data['participants'] as List<dynamic>? ?? [];
          for (var pId in participantsList) {
            final participantId = pId.toString();
            if (participantId == callerId) continue;
            final currentUser = Supabase.instance.client.auth.currentUser;
            if (currentUser != null && participantId == currentUser.id) continue;

            _callParticipants[participantId] = {
              'name': 'Participant',
              'avatar': '',
              'status': 'calling',
              'isMuted': false,
              'isVideoOff': (data['type'] ?? 'voice') == 'voice',
              'agoraUid': getIntUid(participantId),
            };
          }

          _initAgora(join: false);
          notifyListeners();
          break;

        case 'call-accepted':
          if (_activeCall?.mode == 'outgoing') {
            _activeCall = _activeCall!.copyWith(mode: 'connected');
            if (_callParticipants.containsKey(_activeCall!.userId)) {
              _callParticipants[_activeCall!.userId]!['status'] = 'connected';
            }
            try {
              FlutterCallkitIncoming.setCallConnected(_activeCall!.userId);
            } catch (e) {
              debugPrint('[CallKit] Error setting call connected: $e');
            }
            if (_engine == null) {
              _initAgora(join: true);
            } else {
              _joinChannel();
            }
            notifyListeners();
          }
          break;

        case 'call-rejected':
        case 'call-ended':
          if (_activeCall != null) {
            try {
              FlutterCallkitIncoming.endCall(_activeCall!.userId);
            } catch (e) {
              debugPrint('[CallKit] Error ending call: $e');
            }
          }
          _activeCall = null;
          _cleanupAgora();
          notifyListeners();
          break;

        case 'call-switch-request':
          if (_activeCall != null && _activeCall!.type == 'voice') {
            _showSwitchRequestDialog = true;
            _switchRequestSenderName = data['senderName'] ?? 'Someone';
            notifyListeners();

            _switchRequestTimer?.cancel();
            _switchRequestTimer = Timer(const Duration(seconds: 15), () {
              if (_showSwitchRequestDialog) {
                declineSwitchToVideo(sendSignal: true, isTimeout: true);
              }
            });
          }
          break;

        case 'call-switch-cancel':
          if (_showSwitchRequestDialog) {
            _showSwitchRequestDialog = false;
            _switchRequestTimer?.cancel();
            notifyListeners();
          }
          break;

        case 'call-switch-response':
          if (_isSwitchRequestPending && _activeCall != null) {
            _isSwitchRequestPending = false;
            _switchRequestTimer?.cancel();

            final accepted = data['accepted'] as bool? ?? false;
            if (accepted) {
              _activeCall = GlobalCallState(
                type: 'video',
                mode: _activeCall!.mode,
                userId: _activeCall!.userId,
                userName: _activeCall!.userName,
                userAvatar: _activeCall!.userAvatar,
                channelName: _activeCall!.channelName,
              );
              if (_engine != null) {
                await _engine!.enableVideo();
                await _engine!.startPreview();
              }
              notifyListeners();
            } else {
              final reason = data['reason'] as String? ?? 'declined';
              if (reason == 'timeout') {
                _switchRequestMessage = '${_activeCall!.userName} did not respond';
              } else {
                _switchRequestMessage = '${_activeCall!.userName} declined the request';
              }
              notifyListeners();
              
              Timer(const Duration(seconds: 3), () {
                _switchRequestMessage = null;
                notifyListeners();
              });
            }
          }
          break;

        case 'call-hold-changed':
          final onHold = data['onHold'] as bool? ?? false;
          _isRemoteOnHold = onHold;
          notifyListeners();
          break;

        case 'call-type-changed':
          final newType = data['type'] as String;
          if (_activeCall != null) {
            _activeCall = GlobalCallState(
              type: newType,
              mode: _activeCall!.mode,
              userId: _activeCall!.userId,
              userName: _activeCall!.userName,
              userAvatar: _activeCall!.userAvatar,
              channelName: _activeCall!.channelName,
            );
            if (newType == 'video') {
              _engine?.enableVideo();
              _engine?.startPreview();
            } else {
              _engine?.disableVideo();
              _engine?.stopPreview();
            }
            notifyListeners();
          }
          break;

        case 'participant-added':
          final addedUser = data['user'] as Map<String, dynamic>;
          final addedUserId = addedUser['id'] as String;
          _callParticipants[addedUserId] = {
            'name': addedUser['name'] ?? '',
            'avatar': addedUser['avatar'] ?? '',
            'status': 'calling',
            'isMuted': false,
            'isVideoOff': addedUser['type'] == 'voice',
            'agoraUid': getIntUid(addedUserId),
          };
          notifyListeners();
          break;

        case 'participant-mute-changed':
          final pUserId = data['userId'] as String;
          if (_callParticipants.containsKey(pUserId)) {
            _callParticipants[pUserId]!['isMuted'] = data['isMuted'] as bool? ?? false;
            _callParticipants[pUserId]!['isVideoOff'] = data['isVideoOff'] as bool? ?? false;
            notifyListeners();
          }
          break;
      }
    }
  }

  Future<void> _sendPusherEvent(String targetUserId, String eventName, Map<String, dynamic> data) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'call-signaling',
        body: {
          'targetUserId': targetUserId,
          'event': eventName,
          'data': data,
        },
      );

      if (response.status == 200 || response.status == 201) {
        debugPrint('[Signaling] Successfully sent event "$eventName" via Edge Function');
      } else {
        debugPrint('[Signaling] Failed to send event via Edge Function: ${response.status} - ${response.data}');
      }
    } catch (e) {
      debugPrint('Error sending signaling event via Edge Function: $e');
    }
  }

  Future<String?> initiateCall(String type, UserModel targetUser) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return 'Not authenticated';

    // Call privacy checks
    try {
      final supabase = Supabase.instance.client;
      final targetProfile = await supabase
          .from('users')
          .select('call_privacy')
          .eq('id', targetUser.id)
          .maybeSingle();

      final privacy = targetProfile?['call_privacy'] as String? ?? 'everyone';

      if (privacy == 'none') {
        return '${targetUser.name} does not accept incoming calls';
      }

      if (privacy == 'following') {
        final followCheck = await supabase
            .from('follows')
            .select()
            .eq('follower_id', targetUser.id)
            .eq('following_id', currentUser.id)
            .maybeSingle();

        if (followCheck == null) {
          return '${targetUser.name} only accepts calls from people they follow';
        }
      }
    } catch (e) {
      debugPrint("Privacy check failed: $e");
    }

    final channelName = 'call_${DateTime.now().millisecondsSinceEpoch}';

    _activeCall = GlobalCallState(
      type: type,
      mode: 'outgoing',
      userId: targetUser.id,
      userName: targetUser.name,
      userAvatar: targetUser.profilePicture ?? '',
      channelName: channelName,
    );

    // Populate local participants map
    _callParticipants.clear();
    _remoteUids.clear();

    _callParticipants[targetUser.id] = {
      'name': targetUser.name,
      'avatar': targetUser.profilePicture ?? '',
      'status': 'calling',
      'isMuted': false,
      'isVideoOff': type == 'voice',
      'agoraUid': getIntUid(targetUser.id),
    };

    notifyListeners();

    try {
      final params = CallKitParams(
        id: targetUser.id,
        nameCaller: targetUser.name,
        appName: 'SpillCity',
        avatar: targetUser.profilePicture ?? 'https://via.placeholder.com/150',
        handle: type == 'video' ? 'Video Call' : 'Voice Call',
        type: type == 'video' ? 1 : 0,
        duration: 30000,
        extra: <String, dynamic>{
          'channelName': channelName,
          'callerId': targetUser.id,
          'callerName': targetUser.name,
          'avatarUrl': targetUser.profilePicture ?? '',
          'callType': type,
        },
      );
      await FlutterCallkitIncoming.startCall(params);
    } catch (e) {
      debugPrint('[CallKit] Error starting outgoing call: $e');
    }

    // Fetch my own profile for caller info
    final response = await Supabase.instance.client
        .from('users')
        .select('name, profile_picture')
        .eq('id', currentUser.id)
        .maybeSingle();

    final myName = response?['name'] ?? 'User';
    final myAvatar = response?['profile_picture'] ?? '';
    _callParticipants[currentUser.id] = {
      'name': myName,
      'avatar': myAvatar,
      'status': 'connected',
      'isMuted': false,
      'isVideoOff': type == 'voice',
      'agoraUid': getIntUid(currentUser.id),
    };

    await _sendPusherEvent(targetUser.id, 'incoming-call', {
      'type': type,
      'channelName': channelName,
      'participants': _callParticipants.keys.toList(),
      'caller': {
        'id': currentUser.id,
        'name': myName,
        'avatar': myAvatar,
      }
    });
    _initAgora(join: false);
    return null;
  }

  Future<void> acceptCall() async {
    if (_activeCall == null) return;
    
    // Add current user to participants map
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      final response = await Supabase.instance.client
          .from('users')
          .select('name, profile_picture')
          .eq('id', currentUser.id)
          .maybeSingle();

      _callParticipants[currentUser.id] = {
        'name': response?['name'] ?? 'User',
        'avatar': response?['profile_picture'] ?? '',
        'status': 'connected',
        'isMuted': false,
        'isVideoOff': _activeCall!.type == 'voice',
        'agoraUid': getIntUid(currentUser.id),
      };
    }

    await _sendPusherEvent(_activeCall!.userId, 'call-accepted', {});
    _activeCall = _activeCall!.copyWith(mode: 'connected');
    notifyListeners();

    try {
      await FlutterCallkitIncoming.setCallConnected(_activeCall!.userId);
    } catch (e) {
      debugPrint('[CallKit] Error setting call connected: $e');
    }

    if (_engine == null) {
      await _initAgora(join: true);
    } else {
      await _joinChannel();
    }
  }

  Future<void> declineCall() async {
    if (_activeCall == null) return;
    await _sendPusherEvent(_activeCall!.userId, 'call-rejected', {});
    try {
      await FlutterCallkitIncoming.endCall(_activeCall!.userId);
    } catch (e) {
      debugPrint('[CallKit] Error ending call: $e');
    }
    _activeCall = null;
    await _cleanupAgora();
    notifyListeners();
  }

  Future<void> endCall() async {
    if (_activeCall == null) return;
    for (var participantId in _callParticipants.keys) {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null && participantId == currentUser.id) continue;
      await _sendPusherEvent(participantId, 'call-ended', {});
    }
    try {
      await FlutterCallkitIncoming.endCall(_activeCall!.userId);
    } catch (e) {
      debugPrint('[CallKit] Error ending call: $e');
    }
    _activeCall = null;
    await _cleanupAgora();
    notifyListeners();
  }

  Future<void> switchCallType(String newType) async {
    if (_activeCall == null || _engine == null) return;

    _activeCall = GlobalCallState(
      type: newType,
      mode: _activeCall!.mode,
      userId: _activeCall!.userId,
      userName: _activeCall!.userName,
      userAvatar: _activeCall!.userAvatar,
      channelName: _activeCall!.channelName,
    );

    if (newType == 'video') {
      await _engine!.enableVideo();
      await _engine!.startPreview();
    } else {
      await _engine!.disableVideo();
      await _engine!.stopPreview();
    }
    notifyListeners();

    // Broadcast change to other active participants
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    for (var participantId in _callParticipants.keys) {
      if (participantId == currentUser.id) continue;
      await _sendPusherEvent(participantId, 'call-type-changed', {
        'type': newType,
      });
    }
  }

  Future<void> inviteParticipant(UserModel targetUser) async {
    if (_activeCall == null) return;
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    if (_callParticipants.length >= 8) {
      return;
    }

    _callParticipants[targetUser.id] = {
      'name': targetUser.name,
      'avatar': targetUser.profilePicture ?? '',
      'status': 'calling',
      'isMuted': false,
      'isVideoOff': _activeCall!.type == 'voice',
      'agoraUid': getIntUid(targetUser.id),
    };
    notifyListeners();

    // Send participant-added to existing participants
    for (var participantId in _callParticipants.keys) {
      if (participantId == currentUser.id || participantId == targetUser.id) continue;
      await _sendPusherEvent(participantId, 'participant-added', {
        'user': {
          'id': targetUser.id,
          'name': targetUser.name,
          'avatar': targetUser.profilePicture ?? '',
          'type': _activeCall!.type,
        }
      });
    }

    // Send incoming-call to invited user
    final myDetails = _callParticipants[currentUser.id] ?? {};
    await _sendPusherEvent(targetUser.id, 'incoming-call', {
      'type': _activeCall!.type,
      'channelName': _activeCall!.channelName,
      'participants': _callParticipants.keys.toList(),
      'caller': {
        'id': currentUser.id,
        'name': myDetails['name'] ?? 'User',
        'avatar': myDetails['avatar'] ?? '',
      }
    });
  }

  Future<void> toggleParticipantMute(bool isMuted, bool isVideoOff) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    if (_callParticipants.containsKey(currentUser.id)) {
      _callParticipants[currentUser.id]!['isMuted'] = isMuted;
      _callParticipants[currentUser.id]!['isVideoOff'] = isVideoOff;
      notifyListeners();
    }

    // Broadcast to other participants
    for (var participantId in _callParticipants.keys) {
      if (participantId == currentUser.id) continue;
      await _sendPusherEvent(participantId, 'participant-mute-changed', {
        'userId': currentUser.id,
        'isMuted': isMuted,
        'isVideoOff': isVideoOff,
      });
    }
  }

  Future<void> _initAgora({bool join = true}) async {
    if (_activeCall == null) return;
    
    await [Permission.microphone, Permission.camera].request();

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(
      appId: AppConfig.agoraAppId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("local user ${connection.localUid} joined");
          _localUserJoined = true;
          notifyListeners();
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("remote user $remoteUid joined");
          if (!_remoteUids.contains(remoteUid)) {
            _remoteUids.add(remoteUid);
          }
          // Set status of participant with matching agoraUid to 'connected'
          for (var entry in _callParticipants.entries) {
            if (entry.value['agoraUid'] == remoteUid) {
              entry.value['status'] = 'connected';
              break;
            }
          }
          notifyListeners();
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint("remote user $remoteUid left channel");
          _remoteUids.remove(remoteUid);
          // Set status to offline/calling or remove if necessary
          for (var entry in _callParticipants.entries) {
            if (entry.value['agoraUid'] == remoteUid) {
              entry.value['status'] = 'calling';
              break;
            }
          }
          notifyListeners();
        },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          debugPrint("leave channel");
          _localUserJoined = false;
          _remoteUids.clear();
          _callParticipants.clear();
        },
      ),
    );

    if (_activeCall!.type == 'video') {
      await _engine!.enableVideo();

      try {
        final profile = Supabase.instance.client.auth.currentUser;
        if (profile != null) {
          final res = await Supabase.instance.client
              .from('users')
              .select('call_quality')
              .eq('id', profile.id)
              .maybeSingle();
          final quality = res?['call_quality'] as String? ?? 'hd';
          VideoDimensions dimensions;
          int bitrate;
          switch (quality) {
            case 'sd':
              dimensions = const VideoDimensions(width: 640, height: 480);
              bitrate = 500;
              break;
            case 'fhd':
              dimensions = const VideoDimensions(width: 1920, height: 1080);
              bitrate = 2080;
              break;
            case '2k':
              dimensions = const VideoDimensions(width: 2560, height: 1440);
              bitrate = 3500;
              break;
            case '4k':
              dimensions = const VideoDimensions(width: 3840, height: 2160);
              bitrate = 6500;
              break;
            case 'hd':
            default:
              dimensions = const VideoDimensions(width: 1280, height: 720);
              bitrate = 1130;
              break;
          }
          await _engine!.setVideoEncoderConfiguration(
            VideoEncoderConfiguration(
              dimensions: dimensions,
              frameRate: 15,
              bitrate: bitrate,
              orientationMode: OrientationMode.orientationModeAdaptive,
            ),
          );
        }
      } catch (e) {
        debugPrint("Failed to set video encoder configuration: $e");
      }

      await _engine!.startPreview();
    } else {
      await _engine!.enableAudio();
    }

    notifyListeners();

    if (join) {
      await _joinChannel();
    }
  }

  Future<void> _joinChannel() async {
    if (_engine == null || _activeCall == null) return;
    
    final token = await _fetchAgoraToken(_activeCall!.channelName);
    final myUser = Supabase.instance.client.auth.currentUser;
    final myUid = myUser != null ? getIntUid(myUser.id) : 0;

    await _engine!.joinChannel(
      token: token ?? '',
      channelId: _activeCall!.channelName,
      uid: myUid,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );
  }

  Future<String?> _fetchAgoraToken(String channelName) async {
    final myUser = Supabase.instance.client.auth.currentUser;
    final myUid = myUser != null ? getIntUid(myUser.id) : 0;
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'agora-token',
        body: {
          'channelName': channelName,
          'uid': myUid,
        },
      );
      
      final data = response.data;
      if (response.status == 200 || response.status == 201) {
        if (data is Map && data['token'] != null) {
          debugPrint("[Agora Token] Successfully fetched token from Supabase Edge Function");
          return data['token'] as String;
        }
      } else {
        debugPrint("[Agora Token] Failed response status from Edge Function: ${response.status}");
      }
    } catch (e) {
      debugPrint('[Agora Token] Error fetching Agora token from Supabase Edge Function: $e');
    }
    return null;
  }

  Future<void> _cleanupAgora() async {
    _localUserJoined = false;
    _remoteUids.clear();
    _callParticipants.clear();
    _isSwitchRequestPending = false;
    _showSwitchRequestDialog = false;
    _switchRequestSenderName = null;
    _switchRequestMessage = null;
    _switchRequestTimer?.cancel();
    _isLocalOnHold = false;
    _isRemoteOnHold = false;
    if (_engine != null) {
      await _engine!.leaveChannel();
      await _engine!.release();
      _engine = null;
    }
  }

  Future<void> requestSwitchToVideo() async {
    if (_activeCall == null) return;
    _isSwitchRequestPending = true;
    _switchRequestMessage = null;
    notifyListeners();

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    _switchRequestTimer?.cancel();
    _switchRequestTimer = Timer(const Duration(seconds: 15), () {
      if (_isSwitchRequestPending) {
        _isSwitchRequestPending = false;
        _switchRequestMessage = 'No response';
        notifyListeners();
        _sendPusherEvent(_activeCall!.userId, 'call-switch-cancel', {});
        Timer(const Duration(seconds: 3), () {
          _switchRequestMessage = null;
          notifyListeners();
        });
      }
    });

    final myName = _callParticipants[currentUser.id]?['name'] ?? 'Someone';
    await _sendPusherEvent(_activeCall!.userId, 'call-switch-request', {
      'senderName': myName,
    });
  }

  Future<void> acceptSwitchToVideo() async {
    if (_activeCall == null) return;
    _showSwitchRequestDialog = false;
    _switchRequestTimer?.cancel();

    _activeCall = GlobalCallState(
      type: 'video',
      mode: _activeCall!.mode,
      userId: _activeCall!.userId,
      userName: _activeCall!.userName,
      userAvatar: _activeCall!.userAvatar,
      channelName: _activeCall!.channelName,
    );

    if (_engine != null) {
      await _engine!.enableVideo();
      await _engine!.startPreview();
    }
    notifyListeners();

    await _sendPusherEvent(_activeCall!.userId, 'call-switch-response', {
      'accepted': true,
    });
  }

  Future<void> declineSwitchToVideo({bool sendSignal = true, bool isTimeout = false}) async {
    if (_activeCall == null) return;
    _showSwitchRequestDialog = false;
    _switchRequestTimer?.cancel();
    notifyListeners();

    if (sendSignal) {
      await _sendPusherEvent(_activeCall!.userId, 'call-switch-response', {
        'accepted': false,
        'reason': isTimeout ? 'timeout' : 'declined',
      });
    }
  }

  Future<void> cancelSwitchRequest() async {
    if (_activeCall == null) return;
    _isSwitchRequestPending = false;
    _switchRequestTimer?.cancel();
    notifyListeners();

    await _sendPusherEvent(_activeCall!.userId, 'call-switch-cancel', {});
  }

  Future<void> toggleCallHold(bool onHold) async {
    if (_activeCall == null || _engine == null) return;

    _isLocalOnHold = onHold;
    notifyListeners();

    await _engine!.muteLocalAudioStream(onHold);
    await _engine!.muteAllRemoteAudioStreams(onHold);

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    for (var participantId in _callParticipants.keys) {
      if (participantId == currentUser.id) continue;
      await _sendPusherEvent(participantId, 'call-hold-changed', {
        'onHold': onHold,
        'userId': currentUser.id,
      });
    }
  }

  /// Re-initialize Pusher after auth is ready. Call this when the user logs in.
  Future<void> reinitPusher() async {
    try {
      await _pusher?.disconnect();
    } catch (_) {}
    _pusher = null;
    await _initPusher();
  }

  /// Called from NotificationService when an FCM push with type 'call_accepted'
  /// arrives. This is the fallback path when Pusher events are missed.
  void handleCallAcceptedFromPush() {
    if (_activeCall?.mode == 'outgoing') {
      debugPrint('[CallManager] Call accepted via FCM push fallback');
      _activeCall = _activeCall!.copyWith(mode: 'connected');
      if (_callParticipants.containsKey(_activeCall!.userId)) {
        _callParticipants[_activeCall!.userId]!['status'] = 'connected';
      }
      try {
        FlutterCallkitIncoming.setCallConnected(_activeCall!.userId);
      } catch (e) {
        debugPrint('[CallKit] Error setting call connected: $e');
      }
      if (_engine == null) {
        _initAgora(join: true);
      } else {
        _joinChannel();
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pusher?.disconnect();
    _cleanupAgora();
    super.dispose();
  }
}

class GlobalCallManager extends ConsumerWidget {
  final Widget child;

  const GlobalCallManager({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCall = ref.watch(callManagerProvider).activeCall;

    return Stack(
      children: [
        child,
        if (activeCall != null)
          Positioned.fill(
            child: Material(
              color: Colors.black,
              child: CallOverlay(callState: activeCall),
            ),
          ),
      ],
    );
  }
}
