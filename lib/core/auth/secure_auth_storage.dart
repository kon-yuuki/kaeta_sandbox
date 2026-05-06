import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stores Supabase Auth sessions in the platform secure store.
///
/// Supabase's default Flutter storage persists sessions in SharedPreferences.
/// This adapter keeps the same storage key but writes the session to Keychain
/// on iOS and the platform secure storage elsewhere.
class SecureAuthStorage extends LocalStorage {
  SecureAuthStorage({required this.persistSessionKey});

  final String persistSessionKey;

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,
    ),
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,
    ),
    aOptions: AndroidOptions(),
  );

  late final SharedPreferences _legacyPrefs;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    WidgetsFlutterBinding.ensureInitialized();

    if (!kIsWeb) {
      _legacyPrefs = await SharedPreferences.getInstance();
      await _migrateLegacySessionIfNeeded();
    }

    _initialized = true;
  }

  @override
  Future<bool> hasAccessToken() async {
    await _ensureInitialized();
    final session = await accessToken();
    return session != null && session.isNotEmpty;
  }

  @override
  Future<String?> accessToken() async {
    await _ensureInitialized();
    return _storage.read(key: persistSessionKey);
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    await _ensureInitialized();
    await _storage.write(key: persistSessionKey, value: persistSessionString);
  }

  @override
  Future<void> removePersistedSession() async {
    await _ensureInitialized();
    await _storage.delete(key: persistSessionKey);
    if (!kIsWeb) {
      await _legacyPrefs.remove(persistSessionKey);
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  Future<void> _migrateLegacySessionIfNeeded() async {
    final secureSession = await _storage.read(key: persistSessionKey);
    if (secureSession != null && secureSession.isNotEmpty) {
      await _legacyPrefs.remove(persistSessionKey);
      return;
    }

    final legacySession = _legacyPrefs.getString(persistSessionKey);
    if (legacySession == null || legacySession.isEmpty) return;

    await _storage.write(key: persistSessionKey, value: legacySession);
    await _legacyPrefs.remove(persistSessionKey);
  }
}
