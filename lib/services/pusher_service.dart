import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

class PusherService {
  static final PusherService instance = PusherService._init();
  PusherChannelsFlutter pusher = PusherChannelsFlutter.getInstance();
  bool _isInitialized = false;

  PusherService._init();

  Future<void> init({
    required String apiKey,
    required String cluster,
    required String authEndpoint,
    required String userToken,
  }) async {
    if (_isInitialized) return;

    try {
      await pusher.init(
        apiKey: apiKey,
        cluster: cluster,
        authEndpoint: authEndpoint,
        // Send JWT tokens for private channels authorization
        authParams: {
          'headers': {
            'Authorization': 'Bearer $userToken',
          }
        },
        onConnectionStateChange: (currentState, previousState) {
          debugPrint("[Pusher] Connection State: $previousState -> $currentState");
        },
        onError: (message, code, exception) {
          debugPrint("[Pusher] Error ($code): $message");
        },
      );
      await pusher.connect();
      _isInitialized = true;
    } catch (e) {
      debugPrint("[Pusher] Init Exception: $e");
    }
  }

  Future<void> subscribeToUserChannel({
    required String userId,
    required Function(Map<String, dynamic> eventData) onIncomingCall,
    required VoidCallback onCallAccepted,
    required VoidCallback onCallRejected,
    required VoidCallback onCallEnded,
    required Function(Map<String, dynamic> msgData) onNewMessage,
  }) async {
    final userChannelName = 'private-user-$userId';
    
    await pusher.subscribe(
      channelName: userChannelName,
      onEvent: (event) {
        debugPrint("[Pusher] Event: ${event.eventName}");
        final Map<String, dynamic> data = jsonDecode(event.data);

        switch (event.eventName) {
          case 'incoming-call':
            onIncomingCall(data);
            break;
          case 'call-accepted':
            onCallAccepted();
            break;
          case 'call-rejected':
            onCallRejected();
            break;
          case 'call-ended':
            onCallEnded();
            break;
          case 'new-message':
            onNewMessage(data);
            break;
          default:
            break;
        }
      },
    );
  }

  Future<void> unsubscribe(String channelName) async {
    await pusher.unsubscribe(channelName: channelName);
  }

  Future<void> disconnect() async {
    await pusher.disconnect();
    _isInitialized = false;
  }
}
