import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parking_management/core/network/local_api_client.dart';
import 'package:parking_management/features/auth/data/local_auth_repository.dart';
import 'package:parking_management/features/auth/presentation/auth_gate.dart';
import 'package:parking_management/features/auth/presentation/sign_in_page.dart';
import 'package:parking_management/features/auth/presentation/temporary_password_reset_page.dart';

void main() {
  testWidgets(
    'local sign-in requires a password change before opening the app',
    (tester) async {
      final client = MockClient((request) async {
        if (request.url.path == '/api/auth/sign-in') {
          expect(jsonDecode(request.body), {
            'email': 'local-admin@parking.test',
            'password': 'temporary-password',
          });
          return _jsonResponse({
            'accessToken': 'local-test-access-token',
            'user': {
              'id': 'local-admin-id',
              'requiresTemporaryPasswordChange': true,
            },
          });
        }
        if (request.url.path == '/api/auth/change-password') {
          expect(
            request.headers['authorization'],
            'Bearer local-test-access-token',
          );
          return _jsonResponse({'success': true});
        }
        throw StateError('Unexpected request: ${request.url}');
      });
      addTearDown(client.close);
      final repository = LocalAuthRepository(
        LocalApiClient(
          baseUri: Uri.parse('http://127.0.0.1:8765'),
          client: client,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authRepository: repository,
            authenticatedBuilder: (context, onSignOut) =>
                const Text('Local parking dashboard'),
          ),
        ),
      );
      expect(find.byType(SignInPage), findsOneWidget);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'local-admin@parking.test',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'temporary-password',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.byType(TemporaryPasswordResetPage), findsOneWidget);
      expect(find.text('Local parking dashboard'), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('new-password')),
        'a-new-local-password-123',
      );
      await tester.enterText(
        find.byKey(const ValueKey('confirm-new-password')),
        'a-new-local-password-123',
      );
      await tester.tap(find.text('Change password'));
      await tester.pumpAndSettle();

      expect(find.byType(TemporaryPasswordResetPage), findsNothing);
      expect(find.text('Local parking dashboard'), findsOneWidget);
    },
  );
}

http.Response _jsonResponse(Map<String, Object?> value) {
  return http.Response(
    jsonEncode(value),
    200,
    headers: const {'content-type': 'application/json'},
  );
}
