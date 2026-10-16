import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api/api_client.dart';

class BiometricService {
  @visibleForTesting
  static Future<bool> Function()? authenticateOverride;
  final _auth = LocalAuthentication();

  Future<bool> get enabled async =>
      (await SharedPreferences.getInstance()).getBool('biometric_enabled') ??
      false;
  Future<bool> authenticate() async {
    if (authenticateOverride != null) return authenticateOverride!();
    if (kIsWeb ||
        ![
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.macOS,
        ].contains(defaultTargetPlatform)) {
      return false;
    }
    try {
      if (!await _auth.canCheckBiometrics ||
          (await _auth.getAvailableBiometrics()).isEmpty) {
        return false;
      }
      return await _auth.authenticate(
        localizedReason: 'Xác thực để mở phiên GymFlow đã ghi nhớ',
        biometricOnly: true,
      );
    } on LocalAuthException {
      return false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value &&
        (prefs.getString('refresh_token') == null || !await authenticate())) {
      return false;
    }
    await prefs.setBool('biometric_enabled', value);
    return true;
  }

  Future<bool> unlockSavedSession() async {
    if (!await enabled) return true;
    if (await authenticate()) return true;
    // Cancel, unavailable hardware or lockout all return to password login.
    await ApiClient.clearToken();
    return false;
  }
}
