import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Thin client over the Claude Messages API (raw HTTP — Dart has no official
/// Anthropic SDK). The user pastes their own key in Settings; it's stored
/// locally and sent directly from the device. We never ship a key in the APK.
///
/// Model: claude-opus-4-8 — this powers Miko the thinking partner, where
/// reasoning quality is the whole point. The user pays their own key; if cost
/// matters they can switch [model] to claude-sonnet-4-6 or claude-haiku-4-5.
class LlmClient {
  static const String _endpoint = 'https://api.anthropic.com/v1/messages';
  static const String _apiVersion = '2023-06-01';
  static const String model = 'claude-opus-4-8';

  final String apiKey;
  LlmClient(this.apiKey);

  bool get hasKey => apiKey.trim().isNotEmpty;

  /// Send a single-turn request. Returns the concatenated text of all `text`
  /// content blocks. When [webSearch] is true, Claude may search the live web
  /// (server-side) and return cited findings — used for the "pull stats" deep dives.
  ///
  /// Throws [LlmException] on auth/network/parse failure so callers can fall back.
  Future<String> complete({
    required String system,
    required String userText,
    bool webSearch = false,
    int maxTokens = 4096,
  }) async {
    if (!hasKey) {
      throw const LlmException('No API key set');
    }

    final body = <String, dynamic>{
      'model': model,
      'max_tokens': maxTokens,
      'system': system,
      'messages': [
        {'role': 'user', 'content': userText},
      ],
    };
    if (webSearch) {
      body['tools'] = [
        {'type': 'web_search_20260209', 'name': 'web_search'},
      ];
    }

    http.Response res;
    try {
      res = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'content-type': 'application/json',
              'x-api-key': apiKey.trim(),
              'anthropic-version': _apiVersion,
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 90));
    } catch (e) {
      throw LlmException('Network error: $e');
    }

    if (res.statusCode != 200) {
      String msg = 'HTTP ${res.statusCode}';
      try {
        final err = jsonDecode(res.body) as Map<String, dynamic>;
        msg = (err['error']?['message'] as String?) ?? msg;
      } catch (_) {}
      debugPrint('LlmClient error: ${res.statusCode} ${res.body}');
      throw LlmException(msg);
    }

    try {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final content = decoded['content'] as List? ?? [];
      final buffer = StringBuffer();
      for (final block in content) {
        if (block is Map && block['type'] == 'text') {
          buffer.write(block['text'] as String? ?? '');
        }
      }
      final text = buffer.toString().trim();
      if (text.isEmpty) throw const LlmException('Empty response');
      return text;
    } catch (e) {
      if (e is LlmException) rethrow;
      throw LlmException('Parse error: $e');
    }
  }
}

class LlmException implements Exception {
  final String message;
  const LlmException(this.message);
  @override
  String toString() => 'LlmException: $message';
}
