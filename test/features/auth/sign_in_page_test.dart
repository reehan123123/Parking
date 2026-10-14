import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/auth/presentation/sign_in_page.dart';

import 'fake_auth_repository.dart';

Widget _buildSignInPage(FakeAuthRepository repository) {
  return MaterialApp(home: SignInPage(authRepository: repository));
}

void main() {
  testWidgets('validates required sign-in fields', (WidgetTester tester) async {
    final repository = FakeAuthRepository();
    addTearDown(repository.dispose);

    await tester.pumpWidget(_buildSignInPage(repository));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
  });

  testWidgets('shows a progress indicator while signing in', (
    WidgetTester tester,
  ) async {
    final signInCompleter = Completer<void>();
    final repository = FakeAuthRepository(signInCompleter: signInCompleter);
    addTearDown(repository.dispose);

    await tester.pumpWidget(_buildSignInPage(repository));
    await tester.enterText(
      find.byType(TextFormField).first,
      'user@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'password');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);

    signInCompleter.complete();
    await tester.pump();
  });

  testWidgets('shows a user-facing error when sign-in fails', (
    WidgetTester tester,
  ) async {
    final repository = FakeAuthRepository()
      ..signInError = Exception('invalid credentials');
    addTearDown(repository.dispose);

    await tester.pumpWidget(_buildSignInPage(repository));
    await tester.enterText(
      find.byType(TextFormField).first,
      'user@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'password');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(
      find.text('Unable to sign in. Check your connection and try again.'),
      findsOneWidget,
    );
  });
}
