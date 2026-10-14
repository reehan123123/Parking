import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/auth/presentation/auth_gate.dart';
import 'package:parking_management/features/auth/presentation/sign_in_page.dart';

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
}
