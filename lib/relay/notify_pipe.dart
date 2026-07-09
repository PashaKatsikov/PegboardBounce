import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'masked_client.dart';
import 'peg_vault.dart';

// -----------------------------------------------------------------
// NotifyPipe — Firebase Messaging + local notification display.
// -----------------------------------------------------------------
// The Android notification channel id here must match the manifest
// meta-data `default_notification_channel_id`. The small icon is a
// dedicated flame drawable — never the launcher icon.
//
// Push URL routing rules:
//   • App killed, user taps push → cold: save URL, boot picks it up.
//   • App backgrounded, user taps → warm: deliver via onUrl (no save).
//   • App foregrounded, push received → show local notif, tap → onUrl.
// -----------------------------------------------------------------

const String kNotifyChannelId = 'pb_pulses';
const String kNotifyChannelName = 'Pegboard Bounce updates';
const String _smallIconRes = '@drawable/ic_pb_flame';

@pragma('vm:entry-point')
Future<void> _isolateBgHandler(RemoteMessage _) async {
  // OS renders background notifications; taps resolve on resume
  // (warm) or boot (cold) — nothing to do in the isolate.
}

class NotifyPipe {
  NotifyPipe(this._vault);

  final PegVault _vault;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  FirebaseMessaging? _fm;
  String? _token;
  bool _prepared = false;

  /// Warm push-tap → load in current WebView (no persistence).
  void Function(String url)? onUrl;

  /// Fired when FCM rotates the token → re-post the gate body.
  void Function(String token)? onTokenSwap;

  String? get token => _token;

  Future<void> arm() async {
    if (_prepared) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _fm = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(_isolateBgHandler);

      await _wireLocal();

      _token = await _fm!.getToken();
      _fm!.onTokenRefresh.listen((String t) {
        _token = t;
        onTokenSwap?.call(t);
      });

      FirebaseMessaging.onMessage.listen(_onForegroundPush);
      FirebaseMessaging.onMessageOpenedApp.listen(_onWarmTap);

      final RemoteMessage? initial = await _fm!.getInitialMessage();
      if (initial != null) _onColdTap(initial);

      _prepared = true;
    } catch (_) {
      // Firebase not configured yet — push stays dormant.
    }
  }

  Future<void> _wireLocal() async {
    const AndroidInitializationSettings android =
        AndroidInitializationSettings(_smallIconRes);
    const DarwinInitializationSettings ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (NotificationResponse r) {
        final String? payload = r.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final Map<String, dynamic> data =
              jsonDecode(payload) as Map<String, dynamic>;
          final String? url = data['url'] as String?;
          if (url != null && url.isNotEmpty) onUrl?.call(url);
        } catch (_) {}
      },
    );
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? plugin =
          _local.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await plugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          kNotifyChannelId,
          kNotifyChannelName,
          description: 'Updates and offers from Pegboard Bounce',
          importance: Importance.high,
        ),
      );
    }
  }

  /// Requests the OS notification permission (Android 13+ dialog).
  /// Records an OS-denied flag so the invite screen never loops.
  Future<bool> requestPermission() async {
    if (_fm == null) return false;
    final NotificationSettings s = await _fm!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final AuthorizationStatus status = s.authorizationStatus;
    final bool granted = status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;

    await _vault.markNotifyGranted(granted);
    if (status == AuthorizationStatus.denied) {
      await _vault.markNotifyBlockedByOs();
    }
    return granted;
  }

  void _onForegroundPush(RemoteMessage message) async {
    final RemoteNotification? note = message.notification;
    if (note == null || !Platform.isAndroid) return;

    AndroidNotificationDetails? details;
    final String? imageUrl = note.android?.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final Uint8List? bytes = await _grabImage(imageUrl);
      if (bytes != null) {
        details = AndroidNotificationDetails(
          kNotifyChannelId,
          kNotifyChannelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: _smallIconRes,
          styleInformation: BigPictureStyleInformation(
            ByteArrayAndroidBitmap(bytes),
            largeIcon:
                const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
        );
      }
    }

    details ??= const AndroidNotificationDetails(
      kNotifyChannelId,
      kNotifyChannelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: _smallIconRes,
    );

    await _local.show(
      id: note.hashCode,
      title: note.title,
      body: note.body,
      notificationDetails: NotificationDetails(android: details),
      payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
    );
  }

  void _onColdTap(RemoteMessage message) {
    final String? url = message.data['url'] as String?;
    if (url != null && url.isNotEmpty) _vault.stashPendingUrl(url);
  }

  void _onWarmTap(RemoteMessage message) {
    final String? url = message.data['url'] as String?;
    if (url != null && url.isNotEmpty) onUrl?.call(url);
  }

  Future<Uint8List?> _grabImage(String url) async {
    try {
      final dynamic res = await maskedWire
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return res.bodyBytes as Uint8List;
    } catch (_) {}
    return null;
  }
}
