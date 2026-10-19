import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/auth/presentation/auth_gate.dart';
import 'package:parking_management/features/auth/presentation/sign_in_page.dart';
import 'package:parking_management/features/auth/presentation/temporary_password_reset_page.dart';

import 'fake_auth_repository.dart';

void main() {
  testWidgets('shows sign-in for an unauthenticated user', (
    WidgetTester tester,
  ) async {
    final repository = FakeAuthRepository();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          authRepository: repository,
          authenticatedBuilder: (context, onSignOut) =>
              const Text('Authenticated content'),
        ),
      ),
    );

    expect(find.byType(SignInPage), findsOneWidget);
    expect(find.text('Authenticated content'), findsNothing);
  });

  testWidgets('shows authenticated content and responds to auth changes', (
    WidgetTester tester,
  ) async {
    final repository = FakeAuthRepository(isSignedIn: true);
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          authRepository: repository,
          authenticatedBuilder: (context, onSignOut) =>
              const Text('Authenticated content'),
        ),
      ),
    );

    expect(find.text('Authenticated content'), findsOneWidget);

    repository.emitSignedIn(false);
    await tester.pump();

    expect(find.byType(SignInPage), findsOneWidget);
    expect(find.text('Authenticated content'), findsNothing);
  });

  testWidgets('requires a temporary password change before app access', (
    WidgetTester tester,
  ) async {
    final repository = FakeAuthRepository(
      isSignedIn: true,
      requiresTemporaryPasswordChange: true,
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          authRepository: repository,
          authenticatedBuilder: (context, onSignOut) =>
              const Text('Authenticated content'),
        ),
      ),
    );

    expect(find.byType(TemporaryPasswordResetPage), findsOneWidget);
    expect(find.text('Authenticated content'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('new-password')),
      'a-new-password-123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('confirm-new-password')),
      'a-new-password-123',
    );
    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();

    expect(repository.lastNewPassword, 'a-new-password-123');
    expect(find.byType(TemporaryPasswordResetPage), findsNothing);
    expect(find.text('Authenticated content'), findsOneWidget);
  });

  testWidgets('does not accept a mismatched password confirmation', (
    WidgetTester tester,
  ) async {
    final repository = FakeAuthRepository(
      isSignedIn: true,
      requiresTemporaryPasswordChange: true,
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          authRepository: repository,
          authenticatedBuilder: (context, onSignOut) =>
              const Text('Authenticated content'),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('new-password')),
      'a-new-password-123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('confirm-new-password')),
      'a-different-password-123',
    );
    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();

    expect(find.text('The passwords do not match.'), findsOneWidget);
    expect(repository.lastNewPassword, isNull);
    expect(find.text('Authenticated content'), findsNothing);
  });
}
