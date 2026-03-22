import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kApiKey = 'gemini_api_key';

class ApiKeyService {
  static Future<String?> getKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kApiKey);
  }

  static Future<void> saveKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kApiKey, key);
  }

  static Future<void> deleteKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kApiKey);
  }
}

// Riverpod provider - API 키 상태 관리
class ApiKeyNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() => ApiKeyService.getKey();

  Future<void> save(String key) async {
    await ApiKeyService.saveKey(key);
    state = AsyncValue.data(key);
  }

  Future<void> delete() async {
    await ApiKeyService.deleteKey();
    state = const AsyncValue.data(null);
  }
}

final apiKeyProvider = AsyncNotifierProvider<ApiKeyNotifier, String?>(
  ApiKeyNotifier.new,
);