import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _defaultEndpoint = 'https://translate.cutie.dating/translate';
const _maxAttempts = 3;

const _protectedTerms = [
  'SUPABASE_PUBLISHABLE_KEY',
  'SUPABASE_URL',
  'PARKING_LOCAL_API_URL',
  'PARKING_BACKEND',
  '--dart-define',
  'owner@example.com',
  'Central Parking',
  'ABC 123',
  '+919876543210',
  '9876543210',
  '+91',
  'PostgreSQL',
  'Supabase',
  'JPEG',
  'WebP',
  'PWA',
  'PNG',
  'OTP',
  'API',
];

Future<void> main() async {
  final sourceFile = File('lib/l10n/app_en.arb');
  final targetFile = File('lib/l10n/app_hi.arb');
  final endpoint = _translationEndpoint();
  final apiKey = Platform.environment['LIBRETRANSLATE_API_KEY'];
  final client = http.Client();

  try {
    final source = jsonDecode(await sourceFile.readAsString());
    if (source is! Map<String, dynamic>) {
      throw const FormatException(
        'The English ARB root must be a JSON object.',
      );
    }

    final translated = <String, dynamic>{'@@locale': 'hi'};
    var translatedCount = 0;
    for (final entry in source.entries) {
      if (entry.key == '@@locale') {
        continue;
      }
      if (entry.key.startsWith('@')) {
        translated[entry.key] = entry.value;
        continue;
      }
      if (entry.value is! String) {
        throw FormatException('ARB value ${entry.key} must be a string.');
      }

      translated[entry.key] = await _translateEntry(
        entry.key,
        entry.value as String,
        client: client,
        endpoint: endpoint,
        apiKey: apiKey,
      );
      translatedCount++;
      if (translatedCount % 25 == 0) {
        stdout.writeln('Translated $translatedCount entries.');
      }
    }

    final encoded = const JsonEncoder.withIndent('  ').convert(translated);
    await targetFile.writeAsString('$encoded\n', flush: true);
    stdout.writeln('Wrote ${targetFile.path} ($translatedCount entries).');
  } finally {
    client.close();
  }
}

Uri _translationEndpoint() {
  final endpoint = Uri.tryParse(
    Platform.environment['LIBRETRANSLATE_URL'] ?? _defaultEndpoint,
  );
  final isLoopback = const {
    'localhost',
    '127.0.0.1',
    '::1',
  }.contains(endpoint?.host);
  if (endpoint == null ||
      (endpoint.scheme != 'https' &&
          !(endpoint.scheme == 'http' && isLoopback)) ||
      endpoint.host.isEmpty ||
      !endpoint.path.endsWith('/translate') ||
      endpoint.userInfo.isNotEmpty ||
      endpoint.query.isNotEmpty ||
      endpoint.fragment.isNotEmpty) {
    throw const FormatException(
      'LIBRETRANSLATE_URL must be an HTTP(S) /translate endpoint.',
    );
  }
  return endpoint;
}

Future<String> _translateEntry(
  String key,
  String value, {
  required http.Client client,
  required Uri endpoint,
  required String? apiKey,
}) async {
  if (key == 'appTitle') {
    return value;
  }
  if (key == 'languageEnglish') {
    return 'English';
  }
  if (key == 'languageHindi') {
    return 'हिंदी';
  }
  if (value.isEmpty) {
    return value;
  }

  final protectedValue = _protect(value);
  final requestBody = <String, Object?>{
    'q': protectedValue.value,
    'source': 'en',
    'target': 'hi',
    'format': 'text',
  };
  if (apiKey != null && apiKey.isNotEmpty) {
    requestBody['api_key'] = apiKey;
  }

  for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
    try {
      final response = await client
          .post(
            endpoint,
            headers: const {'content-type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 408 ||
          response.statusCode == 429 ||
          response.statusCode >= 500) {
        throw _TransientTranslationException(response.statusCode);
      }
      if (response.statusCode != 200) {
        throw HttpException(
          'LibreTranslate returned HTTP ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['translatedText'] is! String) {
        throw const FormatException(
          'LibreTranslate returned an invalid response.',
        );
      }
      return protectedValue.restore(decoded['translatedText'] as String);
    } on _TransientTranslationException {
      if (attempt == _maxAttempts) {
        rethrow;
      }
      await Future<void>.delayed(Duration(seconds: attempt));
    } on TimeoutException {
      if (attempt == _maxAttempts) {
        rethrow;
      }
      await Future<void>.delayed(Duration(seconds: attempt));
    } on SocketException {
      if (attempt == _maxAttempts) {
        rethrow;
      }
      await Future<void>.delayed(Duration(seconds: attempt));
    } on http.ClientException {
      if (attempt == _maxAttempts) {
        rethrow;
      }
      await Future<void>.delayed(Duration(seconds: attempt));
    }
  }

  throw StateError('LibreTranslate did not translate ARB entry $key.');
}

_ProtectedValue _protect(String value) {
  final replacements = <String, String>{};
  var nextToken = 0;

  String protect(String original) {
    final token = 'ZXQ${nextToken++}QXZ';
    replacements[token] = original;
    return token;
  }

  var protected = value.replaceAllMapped(
    RegExp(r'\{[A-Za-z][A-Za-z0-9_]*\}'),
    (match) => protect(match.group(0)!),
  );
  for (final term in _protectedTerms) {
    protected = protected.replaceAllMapped(
      RegExp(RegExp.escape(term)),
      (match) => protect(match.group(0)!),
    );
  }
  return _ProtectedValue(protected, replacements);
}

class _ProtectedValue {
  const _ProtectedValue(this.value, this.replacements);

  final String value;
  final Map<String, String> replacements;

  String restore(String translated) {
    var restored = translated;
    for (final replacement in replacements.entries) {
      final occurrences = RegExp(RegExp.escape(replacement.key))
          .allMatches(restored)
          .length;
      if (occurrences != 1) {
        throw const FormatException(
          'LibreTranslate changed a placeholder or protected term.',
        );
      }
      restored = restored.replaceFirst(replacement.key, replacement.value);
    }
    return restored;
  }
}

class _TransientTranslationException implements Exception {
  const _TransientTranslationException(this.statusCode);

  final int statusCode;

  @override
  String toString() => 'LibreTranslate returned HTTP $statusCode.';
}
