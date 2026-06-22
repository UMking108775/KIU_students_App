import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provides a stable per-install device id and a human-friendly device name,
/// used to enforce/communicate single active sessions.
///
/// The id is stored in SharedPreferences (NOT secure storage) on purpose: it
/// must survive logout, which wipes secure storage via [StorageService.clearAll].
/// It is not a secret — it only labels which device currently owns the session.
class DeviceService {
  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;
  DeviceService._internal();

  static const String _deviceIdKey = 'device_install_id';

  String? _cachedId;
  String? _cachedName;

  /// Stable random id for this installation. Generated once, then reused.
  Future<String> getDeviceId() async {
    if (_cachedId != null && _cachedId!.isNotEmpty) return _cachedId!;

    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdKey);
    if (id == null || id.isEmpty) {
      id = _generateId();
      await prefs.setString(_deviceIdKey, id);
    }
    _cachedId = id;
    return id;
  }

  String _generateId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Best-effort friendly name, e.g. "Samsung SM-A525F". Falls back gracefully.
  Future<String> getDeviceName() async {
    if (_cachedName != null) return _cachedName!;

    var name = 'Mobile device';
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        name = '${_capitalize(a.manufacturer)} ${a.model}'.trim();
      } else if (Platform.isIOS) {
        final i = await info.iosInfo;
        name = i.name.isNotEmpty ? i.name : i.model;
      }
    } catch (_) {
      // Keep the fallback name.
    }
    if (name.trim().isEmpty) name = 'Mobile device';
    _cachedName = name;
    return name;
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
