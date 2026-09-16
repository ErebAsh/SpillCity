import 'package:firebase_messaging/firebase_messaging.dart';
import 'preferences_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:spillcity/data/repositories/providers.dart';
import 'package:spillcity/presentation/call/providers/global_call_manager.dart';

// ─── Local Notifications Plugin (top-level for background access) ───
final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

// Notification channel for messages
const AndroidNotificationChannel _messageChannel = AndroidNotificationChannel(
  'message_notifications', // id
  'Messages', // name
  description: 'New message notifications',
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
);

/// Initialize flutter_local_notifications (safe to call multiple times)
Future<void> _ensureLocalNotificationsInitialized() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);

  await _localNotifications.initialize(initSettings);

  // Create the notification channel on Android 8+
  final androidPlugin =
      _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  if (androidPlugin != null) {
    await androidPlugin.createNotificationChannel(_messageChannel);
  }
}

/// Show a native notification for a new message
Future<void> _showMessageNotification({
  required String senderName,
  required String messageText,
  String? conversationId,
}) async {
  await _ensureLocalNotificationsInitialized();

  String displayText = messageText;
  if (conversationId != null) {
    try {
      final key = 'unread_count_$conversationId';
      final currentCount = await PreferencesService.instance.getInt(key) ?? 0;
      final newCount = currentCount + 1;
      await PreferencesService.instance.setInt(key, newCount);
      
      if (newCount > 1) {
        displayText = '$messageText (+$newCount new)';
      }
    } catch (e) {
      debugPrint('[Notification] Error updating unread preferences: $e');
    }
  }

  final androidDetails = AndroidNotificationDetails(
    _messageChannel.id,
    _messageChannel.name,
    channelDescription: _messageChannel.description,
    importance: Importance.high,
    priority: Priority.high,
    showWhen: true,
    icon: '@mipmap/ic_launcher',
    category: AndroidNotificationCategory.message,
  );

  final details = NotificationDetails(android: androidDetails);

  // Use conversationId hashCode as notification id so each conversation gets its own slot
  final notifId = conversationId?.hashCode ?? DateTime.now().millisecondsSinceEpoch;

  await _localNotifications.show(
    notifId,
    senderName,
    displayText,
    details,
  );
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final data = message.data;
  debugPrint('[Push Background] Received message data: $data');

  if (data['type'] == 'incoming_call') {
    final callerId = data['callerId'] ?? '';
    final callerName = data['callerName'] ?? 'Incoming Call';
    final avatarUrl = data['avatarUrl'] ?? '';
    final channelName = data['channelName'] ?? '';
    final callType = data['callType'] ?? 'voice';

    if (callerId.isEmpty) return;

    final params = CallKitParams(
      id: callerId,
      nameCaller: callerName,
      appName: 'SpillCity',
      avatar: avatarUrl.isNotEmpty ? avatarUrl : 'https://via.placeholder.com/150',
      handle: callType == 'video' ? 'Video Call' : 'Voice Call',
      type: callType == 'video' ? 1 : 0,
      duration: 30000,
      textAccept: 'Accept',
      textDecline: 'Decline',
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: false,
        subtitle: 'Missed Call',
      ),
      extra: <String, dynamic>{
        'channelName': channelName,
        'callerId': callerId,
        'callerName': callerName,
        'avatarUrl': avatarUrl,
        'callType': callType,
      },
      android: const AndroidParams(
        isCustomNotification: false,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#09090b',
        actionColor: '#4CAF50',
        incomingCallNotificationChannelName: 'Incoming Call',
      ),
      ios: const IOSParams(
        handleType: 'generic',
        supportsVideo: true,
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  } else if (data['type'] == 'call_accepted') {
    // Background: The caller's app receives this when callee accepts.
    // CallKit will handle the connected state transition.
    final callerId = data['callerId'] ?? '';
    if (callerId.isNotEmpty) {
      try {
        await FlutterCallkitIncoming.setCallConnected(callerId);
      } catch (_) {}
    }
  } else if (data['type'] == 'call_ended' || data['type'] == 'call_rejected') {
    final callerId = data['callerId'] ?? '';
    if (callerId.isNotEmpty) {
      await FlutterCallkitIncoming.endCall(callerId);
    } else {
      await FlutterCallkitIncoming.endAllCalls();
    }
  } else if (data['type'] == 'new_message') {
    // Show native notification for new messages when app is in background/killed
    final senderName = data['senderName'] ?? 'New Message';
    final messageText = data['messageText'] ?? '';
    final conversationId = data['conversationId'] ?? '';

    await _showMessageNotification(
      senderName: senderName,
      messageText: messageText,
      conversationId: conversationId,
    );
  }
}

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  bool _initialized = false;

  // Store the ref so foreground handler can access providers
  WidgetRef? _ref;

  Future<void> initialize(WidgetRef ref) async {
    if (_initialized) return;
    _initialized = true;
    _ref = ref;

    try {
      final messaging = FirebaseMessaging.instance;

      // Initialize local notifications for message alerts
      await _ensureLocalNotificationsInitialized();

      // 1. Request notification permissions (required for iOS and Android 13+)
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('[Push] Notification permission granted.');
      } else {
        debugPrint('[Push] Notification permission declined or not granted.');
      }

      // Request CallKit notification permissions explicitly
      try {
        await FlutterCallkitIncoming.requestNotificationPermission({
          "rationaleMessagePermission": "Notification permission is required to show incoming calls.",
          "postNotificationMessagePermission": "Notification permission is required to show incoming calls."
        });
      } catch (e) {
        debugPrint('[Push] CallKit permission request failed: $e');
      }

      // 2. Fetch and upload FCM registration token
      await uploadToken(ref);

      // Listen to auth state changes to upload token when signed in
      Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        if (data.event == AuthChangeEvent.signedIn || data.event == AuthChangeEvent.tokenRefreshed) {
          uploadToken(ref);
        }
      });

      // 3. Listen for token refreshes and update Supabase database
      messaging.onTokenRefresh.listen((token) async {
        debugPrint('[Push] Token refreshed: $token');
        try {
          await ref.read(authRepositoryProvider).updateFcmToken(token);
        } catch (e) {
          debugPrint('[Push] Failed to upload refreshed token: $e');
        }
      });

      // 4. Foreground notifications handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        debugPrint('[Push] Received foreground message: ${message.data}');
        final data = message.data;
        if (data['type'] == 'incoming_call') {
          final callerId = data['callerId'] ?? '';
          final callerName = data['callerName'] ?? 'Incoming Call';
          final avatarUrl = data['avatarUrl'] ?? '';
          final channelName = data['channelName'] ?? '';
          final callType = data['callType'] ?? 'voice';

          if (callerId.isEmpty) return;

          final params = CallKitParams(
            id: callerId,
            nameCaller: callerName,
            appName: 'SpillCity',
            avatar: avatarUrl.isNotEmpty ? avatarUrl : 'https://via.placeholder.com/150',
            handle: callType == 'video' ? 'Video Call' : 'Voice Call',
            type: callType == 'video' ? 1 : 0,
            duration: 30000,
            textAccept: 'Accept',
            textDecline: 'Decline',
            missedCallNotification: const NotificationParams(
              showNotification: true,
              isShowCallback: false,
              subtitle: 'Missed Call',
            ),
            extra: <String, dynamic>{
              'channelName': channelName,
              'callerId': callerId,
              'callerName': callerName,
              'avatarUrl': avatarUrl,
              'callType': callType,
            },
            android: const AndroidParams(
              isCustomNotification: false,
              isShowLogo: false,
              ringtonePath: 'system_ringtone_default',
              backgroundColor: '#09090b',
              actionColor: '#4CAF50',
              incomingCallNotificationChannelName: 'Incoming Call',
            ),
            ios: const IOSParams(
              handleType: 'generic',
              supportsVideo: true,
              maximumCallGroups: 1,
              maximumCallsPerCallGroup: 1,
            ),
          );
          await FlutterCallkitIncoming.showCallkitIncoming(params);
        } else if (data['type'] == 'call_accepted') {
          // Foreground: Caller receives this when callee accepts.
          // Trigger the call manager to transition to connected state.
          final callManager = _ref?.read(callManagerProvider.notifier);
          callManager?.handleCallAcceptedFromPush();
        } else if (data['type'] == 'call_ended' || data['type'] == 'call_rejected') {
          final callerId = data['callerId'] ?? '';
          if (callerId.isNotEmpty) {
            await FlutterCallkitIncoming.endCall(callerId);
          } else {
            await FlutterCallkitIncoming.endAllCalls();
          }
        } else if (data['type'] == 'new_message') {
          // Foreground: suppress notification if user is viewing that conversation
          final conversationId = data['conversationId'] ?? '';
          final activeConvId = _ref?.read(activeConversationIdProvider);

          if (activeConvId != null && activeConvId == conversationId) {
            debugPrint('[Push] Suppressing message notification — conversation is open');
            return;
          }

          final senderName = data['senderName'] ?? 'New Message';
          final messageText = data['messageText'] ?? '';

          await _showMessageNotification(
            senderName: senderName,
            messageText: messageText,
            conversationId: conversationId,
          );
        } else if (data['type'] == 'in_app_notification') {
          final title = data['title'] ?? 'SpillCity';
          final body = data['body'] ?? '';
          await _showMessageNotification(
            senderName: title,
            messageText: body,
          );
        }
      });

      // 5. App opened via push notification in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[Push] App opened via notification: ${message.data}');
      });

      // 6. App opened via push notification from terminated state
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[Push] Initial message that opened app: ${initialMessage.data}');
      }
    } catch (e) {
      debugPrint('[Push] Notification service initialization failed: $e');
    }
  }

  Future<void> uploadToken(WidgetRef ref) async {
    try {
      final authRepo = ref.read(authRepositoryProvider);
      if (authRepo.currentSupabaseUser == null) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        debugPrint('[Push] Current token: $token');
        await authRepo.updateFcmToken(token);
      }
    } catch (e) {
      debugPrint('[Push] Failed to retrieve/upload FCM token: $e');
    }
  }
}
