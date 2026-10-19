import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/auth/presentation/forgot_password_dialog.dart';

import 'fake_auth_repository.dart';

Future<void> _openDialog(
  WidgetTester tester,
  FakeAuthRepository repository, {
  String? initialEmail,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => ForgotPasswordDialog(
                authRepository: repository,
                initialEmail: initialEmail,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('rejects an invalid email before calling the repository', (
    WidgetTester tester,
  ) async {
    final repository = FakeAuthRepository();
    addTearDown(repository.dispose);

    await _openDialog(tester, repository);
    await tester.enterText(find.byType(TextFormField), 'not-an-email');
    await tester.tap(find.text('Send reset link'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(repository.lastResetEmail, isNull);
  });

  testWidgets('requests a reset email and shows a neutral success message', (
    WidgetTester tester,
  ) async {
    final repository = FakeAuthRepository();
    addTearDown(repository.dispose);

    await _openDialog(tester, repository, initialEmail: 'user@example.com');
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();

    expect(repository.lastResetEmail, 'user@example.com');
    expect(
      find.textContaining('If an account exists for that email address'),
      findsOneWidget,
    );
    expect(find.text('Send reset link'), findsNothing);
  });

  testWidgets('disables the submit button while the request is pending', (
    WidgetTester tester,
  ) async {
    final completer = Completer<void>();
    final repository = FakeAuthRepository()..passwordResetCompleter = completer;
    addTearDown(repository.dispose);

    await _openDialog(tester, repository, initialEmail: 'user@example.com');
    await tester.tap(find.text('Send reset link'));
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    completer.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('shows a distinct error message when the request fails', (
    WidgetTester tester,
  ) async {
    final repository = FakeAuthRepository()
      ..passwordResetRequestError = Exception('network down');
    addTearDown(repository.dispose);

    await _openDialog(tester, repository, initialEmail: 'user@example.com');
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'The reset email could not be sent right now. Check your connection and try again.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('If an account exists for that email address'),
      findsNothing,
    );
  });
}
