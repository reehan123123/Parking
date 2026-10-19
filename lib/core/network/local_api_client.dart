import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class LocalApiException implements Exception {
  const LocalApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => message;
}

class LocalApiClient {
  LocalApiClient({
    required this.baseUri,
    http.Client? client,
    this.timeout = const Duration(seconds: 60),
  }) : _client = client ?? http.Client();

  final Uri baseUri;
  final http.Client _client;
  final Duration timeout;

  String? accessToken;

  Future<Map<String, dynamic>> requestJson(
    String method,
    String path, {
    Map<String, String>? queryParameters,
    Map<String, Object?>? body,
    bool authenticated = true,
  }) async {
    final response = await send(
      method,
      path,
      queryParameters: queryParameters,
      jsonBody: body,
      authenticated: authenticated,
    );
    if (response.statusCode == 204) {
      return const {};
    }

    final decoded = _decodeJson(response.body);
    ensureSuccessful(response, decoded: decoded);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    throw const FormatException('The local API returned an invalid response.');
  }

  Future<http.Response> send(
    String method,
    String path, {
    Map<String, String>? queryParameters,
    Map<String, Object?>? jsonBody,
    Uint8List? bodyBytes,
    String? contentType,
    Map<String, String> headers = const {},
    bool authenticated = true,
  }) async {
    if (jsonBody != null && bodyBytes != null) {
      throw ArgumentError('Send either JSON or bytes, not both.');
    }
    final token = accessToken;
    if (authenticated && (token == null || token.isEmpty)) {
      throw const LocalApiException(
        statusCode: 401,
        code: 'authentication_required',
        message: 'Sign in to continue.',
      );
    }

    final request = http.Request(
      method,
      baseUri.replace(path: path, queryParameters: queryParameters),
    );
    request.headers.addAll(headers);
    request.headers['Accept'] = 'application/json';
    if (authenticated) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (jsonBody != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(jsonBody);
    } else if (bodyBytes != null) {
      request.headers['Content-Type'] =
          contentType ?? 'application/octet-stream';
      request.bodyBytes = bodyBytes;
    }

    final streamedResponse = await _client.send(request).timeout(timeout);
    return http.Response.fromStream(streamedResponse);
  }

  void ensureSuccessful(http.Response response, {Object? decoded}) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    final body = decoded ?? _decodeJson(response.body);
    final error = body is Map ? body['error'] : null;
    final errorMap = error is Map ? error : const <Object?, Object?>{};
    throw LocalApiException(
      statusCode: response.statusCode,
      code: errorMap['code'] is String
          ? errorMap['code'] as String
          : 'request_failed',
      message: errorMap['message'] is String
          ? errorMap['message'] as String
          : 'The local API request failed.',
    );
  }

  Object? _decodeJson(String body) {
    if (body.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }
}
