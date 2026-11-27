import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Device-local PIN protection. The PIN itself is never persisted.
class StudentPinService {
  StudentPinService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _saltKey = 'student_pin_salt_v1';
  static const _hashKey = 'student_pin_hash_v1';

  final FlutterSecureStorage _storage;

  static bool isValidPinFormat(String pin) =>
      pin.length == 4 && pin.codeUnits.every((c) => c >= 48 && c <= 57);

  Future<bool> isEnabled() async {
    final hash = await _storage.read(key: _hashKey);
    final salt = await _storage.read(key: _saltKey);
    return hash != null && salt != null;
  }

  Future<void> enable(String pin) async {
    _validate(pin);
    final random = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => random.nextInt(256));
    final salt = base64UrlEncode(saltBytes);
    final hash = _digest(salt, pin);
    await _storage.write(key: _saltKey, value: salt);
    await _storage.write(key: _hashKey, value: hash);
  }

  Future<bool> verify(String pin) async {
    if (!isValidPinFormat(pin)) return false;
    final salt = await _storage.read(key: _saltKey);
    final expected = await _storage.read(key: _hashKey);
    if (salt == null || expected == null) return false;
    final actual = _digest(salt, pin);
    if (actual.length != expected.length) return false;
    var difference = 0;
    for (var i = 0; i < actual.length; i++) {
      difference |= actual.codeUnitAt(i) ^ expected.codeUnitAt(i);
    }
    return difference == 0;
  }

  Future<void> disable() async {
    await _storage.delete(key: _hashKey);
    await _storage.delete(key: _saltKey);
  }

  String _digest(String salt, String pin) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  void _validate(String pin) {
    if (!isValidPinFormat(pin)) {
      throw ArgumentError('PIN must contain exactly four digits.');
    }
  }
}
