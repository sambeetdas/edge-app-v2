import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:uuid/uuid.dart';

class UserProfile {
  final String name;
  final String phone;
  final String email;

  const UserProfile({
    this.name = '',
    this.phone = '',
    this.email = '',
  });
}

class CountryCode {
  final String code;
  final String name;
  final String flag;

  const CountryCode({
    required this.code,
    required this.name,
    required this.flag,
  });

  String get displayLabel => '$flag $code  $name';
}

class AuthService {
  static const _keyPhone = 'auth_phone';
  static const _keyPin = 'auth_pin';
  static const _keyToken = 'auth_token';
  static const _keyExpiry = 'auth_expiry';
  static const _keyAppLock = 'auth_app_lock_enabled';
  static const _keyProfileName = 'profile_name';
  static const _keyProfilePhone = 'profile_phone';
  static const _keyProfileEmail = 'profile_email';

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  AuthService({
    FlutterSecureStorage? storage,
    LocalAuthentication? localAuth,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _localAuth = localAuth ?? LocalAuthentication();

  static const List<CountryCode> allCountries = [
    CountryCode(code: '+1', name: 'United States', flag: '🇺🇸'),
    CountryCode(code: '+1', name: 'Canada', flag: '🇨🇦'),
    CountryCode(code: '+7', name: 'Russia', flag: '🇷🇺'),
    CountryCode(code: '+20', name: 'Egypt', flag: '🇪🇬'),
    CountryCode(code: '+27', name: 'South Africa', flag: '🇿🇦'),
    CountryCode(code: '+33', name: 'France', flag: '🇫🇷'),
    CountryCode(code: '+44', name: 'United Kingdom', flag: '🇬🇧'),
    CountryCode(code: '+49', name: 'Germany', flag: '🇩🇪'),
    CountryCode(code: '+52', name: 'Mexico', flag: '🇲🇽'),
    CountryCode(code: '+55', name: 'Brazil', flag: '🇧🇷'),
    CountryCode(code: '+60', name: 'Malaysia', flag: '🇲🇾'),
    CountryCode(code: '+61', name: 'Australia', flag: '🇦🇺'),
    CountryCode(code: '+62', name: 'Indonesia', flag: '🇮🇩'),
    CountryCode(code: '+64', name: 'New Zealand', flag: '🇳🇿'),
    CountryCode(code: '+65', name: 'Singapore', flag: '🇸🇬'),
    CountryCode(code: '+66', name: 'Thailand', flag: '🇹🇭'),
    CountryCode(code: '+81', name: 'Japan', flag: '🇯🇵'),
    CountryCode(code: '+82', name: 'South Korea', flag: '🇰🇷'),
    CountryCode(code: '+86', name: 'China', flag: '🇨🇳'),
    CountryCode(code: '+91', name: 'India', flag: '🇮🇳'),
    CountryCode(code: '+92', name: 'Pakistan', flag: '🇵🇰'),
    CountryCode(code: '+234', name: 'Nigeria', flag: '🇳🇬'),
    CountryCode(code: '+254', name: 'Kenya', flag: '🇰🇪'),
    CountryCode(code: '+966', name: 'Saudi Arabia', flag: '🇸🇦'),
    CountryCode(code: '+971', name: 'UAE', flag: '🇦🇪'),
  ];

  Future<bool> isAuthenticated() async {
    final token = await _storage.read(key: _keyToken);
    final expiryStr = await _storage.read(key: _keyExpiry);
    if (token == null || token.isEmpty || expiryStr == null) return false;
    final expiry = DateTime.tryParse(expiryStr);
    if (expiry == null) return false;
    return DateTime.now().toUtc().isBefore(expiry);
  }

  Future<String?> getPhoneNumber() => _storage.read(key: _keyPhone);

  /// Returns true if a local PIN is already configured for [fullPhoneNumber].
  Future<bool> hasPinForPhone(String fullPhoneNumber) async {
    final storedPhone = await _storage.read(key: _keyPhone);
    final storedPin = await _storage.read(key: _keyPin);
    return storedPhone == fullPhoneNumber &&
        storedPin != null &&
        storedPin.isNotEmpty;
  }

  /// Saves a new 4–6 digit local PIN and creates a 30-day session.
  Future<void> setupPin(String fullPhoneNumber, String pin) async {
    final trimmed = pin.trim();
    if (!RegExp(r'^\d{4,6}$').hasMatch(trimmed)) {
      throw ArgumentError('PIN must be 4 to 6 digits.');
    }
    await _storage.write(key: _keyPhone, value: fullPhoneNumber);
    await _storage.write(key: _keyPin, value: trimmed);
    await _issueSession();
  }

  /// Verifies the entered PIN against the stored PIN and creates a 30-day session.
  Future<bool> verifyPin(String pin) async {
    final trimmed = pin.trim();
    if (!RegExp(r'^\d{4,6}$').hasMatch(trimmed)) return false;
    final storedPin = await _storage.read(key: _keyPin);
    if (storedPin == null || storedPin != trimmed) return false;
    await _issueSession();
    return true;
  }

  Future<void> _issueSession() async {
    final token = const Uuid().v4().replaceAll('-', '');
    final expiry =
        DateTime.now().toUtc().add(const Duration(days: 30)).toIso8601String();
    await _storage.write(key: _keyToken, value: token);
    await _storage.write(key: _keyExpiry, value: expiry);
  }

  /// Clears the stored PIN and session so the user can set a new PIN.
  Future<void> resetPin() async {
    await _storage.delete(key: _keyPin);
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyExpiry);
  }

  Future<void> signOut() async {
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyExpiry);
  }

  Future<bool> isAppLockEnabled() async {
    final val = await _storage.read(key: _keyAppLock);
    return val != 'false';
  }

  Future<void> setAppLockEnabled(bool enabled) async {
    await _storage.write(
      key: _keyAppLock,
      value: enabled ? 'true' : 'false',
    );
  }

  Future<bool> isDeviceLockSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithDevice({
    String reason = 'Unlock Edged using your phone credentials',
  }) async {
    try {
      final supported = await isDeviceLockSupported();
      if (!supported) return true;
      return await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  Future<UserProfile> getProfile() async {
    final name = await _storage.read(key: _keyProfileName) ?? '';
    final phone = await _storage.read(key: _keyProfilePhone) ?? '';
    final email = await _storage.read(key: _keyProfileEmail) ?? '';
    return UserProfile(name: name, phone: phone, email: email);
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _storage.write(key: _keyProfileName, value: profile.name.trim());
    await _storage.write(key: _keyProfilePhone, value: profile.phone.trim());
    await _storage.write(key: _keyProfileEmail, value: profile.email.trim());
  }
}
