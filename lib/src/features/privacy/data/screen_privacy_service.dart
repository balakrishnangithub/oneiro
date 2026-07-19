import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Applies (or lifts) Android's `FLAG_SECURE` window flag.
///
/// With the flag set, the window content is treated as secure: the app shows
/// a blank card in the recents/app-switcher, and screenshots plus screen
/// recording are blocked system-wide while Oneiro is in front.
///
/// This is an Android-only concept; on every other platform the service is a
/// deliberate no-op so the rest of the app can call it unconditionally.
abstract class ScreenPrivacyService {
  Future<void> setSecure(bool secure);
}

/// MethodChannel bridge to `MainActivity` on Android; no-op elsewhere.
class MethodChannelScreenPrivacyService implements ScreenPrivacyService {
  MethodChannelScreenPrivacyService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('oneiro/screen_privacy');

  final MethodChannel _channel;

  static bool get _isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> setSecure(bool secure) async {
    if (!_isSupported) return;
    try {
      await _channel.invokeMethod<void>('setSecure', {'secure': secure});
    } on PlatformException catch (error) {
      // A missing handler (e.g. hot restart into an old native shell) must
      // never crash the app — log and carry on.
      debugPrint('Oneiro: screen privacy flag not applied — $error');
    }
  }
}

/// Test/diagnostic double: records every call.
class NoopScreenPrivacyService implements ScreenPrivacyService {
  bool? lastSecure;

  @override
  Future<void> setSecure(bool secure) async {
    lastSecure = secure;
  }
}
