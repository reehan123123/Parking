import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/auth/data/auth_repository.dart';
import 'package:parking_management/features/auth/presentation/password_recovery_page.dart';
import 'package:parking_management/l10n/app_localizations.dart';

import 'fake_auth_repository.dart';

Widget _buildPage(
  FakeAuthRepository repository, {
  required Future<void> Function() onRecoveryComplete,
  required Future<void> Function() onCancel,
}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: PasswordRecoveryPage(
      authRepository: repository,
      onRecoveryComplete: onRecoveryComplete,
      onCancel: onCancel,
    ),
  );
}

void main() {
  testWidgets('rejects a password shorter than 12 characters', (
    WidgetTester tester,
  ) async {
    final repository = FakeAuthRepository();
    addTearDown(repository.dispose);
    var completed = false;

    await tester.pumpWidget(
      _buildPage(
        repository,
        onRecoveryComplete: () async => completed = true,
        onCancel: () async {},
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('recovery-new-password')),
      'short',
    );
    await tester.enterText(
      find.byKey(const ValueKey('recovery-confirm-password')),
      'short',
    );
    await tester.tap(find.text('Update password'));
    await tester.pumpAndSettle();

    expect(find.text('Use at least 12 characters.'), findsOneWidget);
    expect(completed, isFalse);
    expect(repository.lastRecoveryPassword, isNull);
  });

  testWidgets('rejects mismatched password confirmation', (
    WidgetTester tester,
  ) async {
    final repository = FakeAuthRepository();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      _buildPage(
        repository,
        onRecoveryComplete: () async {},
        onCancel: () async {},
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('recovery-new-password')),
      'a-new-password-123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('recovery-confirm-password')),
      'a-different-password-123',
    );
    await tester.tap(find.text('Update password'));
    await tester.pumpAndSettle();

    expect(find.text('The passwords do not match.'), findsOneWidget);
    expect(repository.lastRecoveryPassword, isNull);
  });

  testWidgets('updates the password and calls onRecoveryComplete on success', (
    WidgetTester tester,
  ) async {
    final repository = FakeAuthRepository();
    addTearDown(repository.dispose);
    var completed = false;

    await tester.pumpWidget(
      _buildPage(
        repository,
        onRecoveryComplete: () async => completed = true,
        onCancel: () async {},
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('recovery-new-password')),
      'a-new-password-123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('recovery-confirm-password')),
      'a-new-password-123',
    );
    await tester.tap(find.text('Update password'));
    await tester.pumpAndSettle();

    expect(repository.lastRecoveryPassword, 'a-new-password-123');
    expect(completed, isTrue);
  });

  testWidgets(
    'shows an error and does not claim success when the update fails',
    (WidgetTester tester) async {
      final repository = FakeAuthRepository()
        ..passwordRecoveryCompletionError = const AuthRepositoryException(
          'This reset link has expired or was already used. Request a new password reset email.',
        );
      addTearDown(repository.dispose);
      var completed = false;

      await tester.pumpWidget(
        _buildPage(
          repository,
          onRecoveryComplete: () async => completed = true,
          onCancel: () async {},
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('recovery-new-password')),
        'a-new-password-123',
      );
      await tester.enterText(
        find.byKey(const ValueKey('recovery-confirm-password')),
        'a-new-password-123',
      );
      await tester.tap(find.text('Update password'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'This reset link has expired or was already used. Request a new password reset email.',
        ),
        findsOneWidget,
      );
      expect(completed, isFalse);
    },
  );

  testWidgets('tapping back to sign in calls onCancel', (
    WidgetTester tester,
  ) async {
    final repository = FakeAuthRepository();
    addTearDown(repository.dispose);
    var cancelled = false;

    await tester.pumpWidget(
      _buildPage(
        repository,
        onRecoveryComplete: () async {},
        onCancel: () async => cancelled = true,
      ),
    );

    await tester.tap(find.text('Back to sign in'));
    await tester.pumpAndSettle();

    expect(cancelled, isTrue);
  });
}
