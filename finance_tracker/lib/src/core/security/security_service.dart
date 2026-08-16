import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final securityServiceProvider = Provider<SecurityService>((ref) {
  return SecurityService();
});

class SecurityService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _pinKey = "app_pin";
  static const String _pinConfiguredKey = "pin_configured";

  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: "Silahkan autentikasi untuk membuka aplikasi",
      );
    } on PlatformException {
      return false;
    }
  }

  Future<void> savePin(String pin) async {
    await _secureStorage.write(key: _pinKey, value: pin);
    await _secureStorage.write(key: _pinConfiguredKey, value: 'true');
  }

  Future<String?> getPin() async {
    return await _secureStorage.read(key: _pinKey);
  }

  Future<bool> verifyPin(String inputPin) async {
    final storedPin = await getPin();
    return storedPin == inputPin;
  }

  Future<bool> isPinConfigured() async {
    final configured = await _secureStorage.read(key: _pinConfiguredKey);
    return configured == 'true';
  }

  Future<void> clearPin() async {
    await _secureStorage.delete(key: _pinKey);
    await _secureStorage.delete(key: _pinConfiguredKey);
  }

  Future<bool> authenticate() async {
    final canBiometric = await canCheckBiometrics();
    final isSupported = await isDeviceSupported();

    if (canBiometric && isSupported) {
      final biometricResult = await authenticateWithBiometrics();
      if (biometricResult) return true;
    }

    return false;
  }
}
