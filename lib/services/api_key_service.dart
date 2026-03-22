import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kApiKey = 'gemini_api_key';

class ApiKeyService {
  static Future<String?> getKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kApiKey);
  }

  static Future<bool> saveKey(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_kApiKey, key);
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_kApiKey);
    } catch (e) {
      return false;
    }
  }
}

class ApiKeyNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() => ApiKeyService.getKey();

  Future<bool> save(String key) async {
    final success = await ApiKeyService.saveKey(key);
    if (success) state = AsyncValue.data(key);
    return success;
  }

  Future<bool> delete() async {
    final success = await ApiKeyService.deleteKey();
    if (success) state = const AsyncValue.data(null);
    return success;
  }
}

final apiKeyProvider = AsyncNotifierProvider<ApiKeyNotifier, String?>(
  ApiKeyNotifier.new,
);