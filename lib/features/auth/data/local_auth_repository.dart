import 'dart:async';

import '../../../core/network/local_api_client.dart';
import 'auth_repository.dart';

class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository(this._api);

  final LocalApiClient _api;
  final StreamController<bool> _signedInChanges =
      StreamController<bool>.broadcast();
  String? _userId;
  bool _requiresPasswordChange = false;

  String? get currentUserId => _userId;

  @override
  bool get isSignedIn => _api.accessToken != null && _userId != null;

  @override
  bool get requiresTemporaryPasswordChange => _requiresPasswordChange;

  @override
  Stream<bool> get signedInChanges => _signedInChanges.stream;

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      final response = await _api.requestJson(
        'POST',
        '/api/auth/sign-in',
        authenticated: false,
        body: {'email': email, 'password': password},
      );
      final token = response['accessToken'];
      final user = response['user'];
      if (token is! String || user is! Map) {
        throw const FormatException('The local sign-in response is invalid.');
      }

      final userId = user['id'];
      final requiresPasswordChange = user['requiresTemporaryPasswordChange'];
      if (userId is! String || requiresPasswordChange is! bool) {
        throw const FormatException('The local sign-in response is invalid.');
      }

      _api.accessToken = token;
      _userId = userId;
      _requiresPasswordChange = requiresPasswordChange;
      _signedInChanges.add(true);
    } on LocalApiException catch (error) {
      throw AuthRepositoryException(
        error.code == 'invalid_credentials'
            ? 'The email or password is incorrect.'
            : 'Local sign-in failed. Check the local API and try again.',
      );
    }
  }

  @override
  Future<void> changeTemporaryPassword({required String newPassword}) async {
    if (!_requiresPasswordChange) {
      throw const AuthRepositoryException(
        'This account does not require a temporary password change.',
      );
    }
    if (newPassword.length < 12 || newPassword.length > 128) {
      throw const AuthRepositoryException(
        'Use a password between 12 and 128 characters.',
      );
    }

    try {
      final response = await _api.requestJson(
        'POST',
        '/api/auth/change-password',
        body: {'newPassword': newPassword},
      );
      if (response['success'] != true) {
        throw const AuthRepositoryException(
          'The password change could not be confirmed. Try again.',
        );
      }

      _requiresPasswordChange = false;
      _signedInChanges.add(isSignedIn);
    } on LocalApiException catch (error) {
      throw AuthRepositoryException(
        error.code == 'invalid_password'
            ? 'Use a password between 12 and 128 characters.'
            : 'The password could not be changed. Check the local API and retry.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      if (_api.accessToken != null) {
        await _api.requestJson('POST', '/api/auth/sign-out');
      }
    } on LocalApiException catch (error) {
      if (error.statusCode != 401) {
        rethrow;
      }
    } finally {
      _api.accessToken = null;
      _userId = null;
      _requiresPasswordChange = false;
      _signedInChanges.add(false);
    }
  }
}
