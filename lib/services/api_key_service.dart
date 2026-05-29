import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kApiKey = 'hermes_api_key';
const String _kServerUrl = 'hermes_server_url';
const String _kLegacyKey = 'gemini_api_key';

const String defaultHermesServerUrl = 'http://localhost:8642';

// ── Server URL ─────────────────────────────────────────────

class ServerUrlNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kServerUrl) ?? defaultHermesServerUrl;
  }

  Future<void> save(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kServerUrl, url);
    state = AsyncValue.data(url);
  }
}

final serverUrlProvider = AsyncNotifierProvider<ServerUrlNotifier, String>(
  ServerUrlNotifier.new,
);

// ── API Key ────────────────────────────────────────────────

class ApiKeyNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    final prefs = await SharedPreferences.getInstance();

    // 레거시 키 제거 (OpenRouter 키를 Hermes에 사용하면 안 됨)
    if (prefs.containsKey(_kLegacyKey)) {
      await prefs.remove(_kLegacyKey);
    }

    return prefs.getString(_kApiKey);
  }

  Future<bool> save(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setString(_kApiKey, key);
    if (ok) state = AsyncValue.data(key);
    return ok;
  }

  Future<bool> delete() async {
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.remove(_kApiKey);
    if (ok) state = const AsyncValue.data(null);
    return ok;
  }
}

final apiKeyProvider = AsyncNotifierProvider<ApiKeyNotifier, String?>(
  ApiKeyNotifier.new,
);

// ── OpenRouter API Key ────────────────────────────────────

const String _kOpenRouterKey = 'openrouter_api_key';

class OpenRouterApiKeyNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kOpenRouterKey);
  }

  Future<bool> save(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setString(_kOpenRouterKey, key);
    if (ok) state = AsyncValue.data(key);
    return ok;
  }

  Future<bool> delete() async {
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.remove(_kOpenRouterKey);
    if (ok) state = const AsyncValue.data(null);
    return ok;
  }
}

final openRouterApiKeyProvider =
    AsyncNotifierProvider<OpenRouterApiKeyNotifier, String?>(
  OpenRouterApiKeyNotifier.new,
);

// ── OpenRouter Model ──────────────────────────────────────

const String _kOpenRouterModel = 'openrouter_model';
const String defaultOpenRouterModel = 'google/gemini-2.5-flash-preview';

class OpenRouterModelNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kOpenRouterModel) ?? defaultOpenRouterModel;
  }

  Future<void> save(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kOpenRouterModel, model);
    state = AsyncValue.data(model);
  }
}

final openRouterModelProvider =
    AsyncNotifierProvider<OpenRouterModelNotifier, String>(
  OpenRouterModelNotifier.new,
);
