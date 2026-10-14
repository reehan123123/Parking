import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/parking/data/parking_camera_source.dart';
import 'package:parking_management/features/parking/data/parking_photo.dart';
import 'package:parking_management/features/parking/presentation/parking_capture_dialog.dart';

void main() {
  testWidgets('shows a loading state until the camera is ready', (
    WidgetTester tester,
  ) async {
    final completer = Completer<ParkingCameraSession>();
    final source = FakeParkingCameraSource(openResult: completer.future);
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigatorKey, home: const SizedBox.shrink()),
    );
    final dialogFuture = showDialog<ParkingPhoto?>(
      context: navigatorKey.currentState!.context,
      barrierDismissible: false,
      builder: (context) => ParkingCaptureDialog(cameraSource: source),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final session = FakeParkingCameraSession();
    completer.complete(session);
    await tester.pump();

    expect(find.text('Live camera preview'), findsOneWidget);
    expect(find.text('Capture'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    Navigator.of(navigatorKey.currentState!.context).pop();
    await tester.pump();
    await dialogFuture;
    await tester.pumpAndSettle();
    expect(session.disposeCalls, 1);
  });

  testWidgets('cancelling while initializing disposes a late camera session', (
    WidgetTester tester,
  ) async {
    final completer = Completer<ParkingCameraSession>();
    final source = FakeParkingCameraSource(openResult: completer.future);
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigatorKey, home: const SizedBox.shrink()),
    );
    final dialogFuture = showDialog<ParkingPhoto?>(
      context: navigatorKey.currentState!.context,
      barrierDismissible: false,
      builder: (context) => ParkingCaptureDialog(cameraSource: source),
    );
    await tester.pump();

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(await dialogFuture, isNull);

    final session = FakeParkingCameraSession();
    completer.complete(session);
    await tester.pump();

    expect(session.disposeCalls, 1);
  });

  testWidgets('shows a recoverable error when initialization times out', (
    WidgetTester tester,
  ) async {
    final completer = Completer<ParkingCameraSession>();
    final source = FakeParkingCameraSource(openResult: completer.future);
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigatorKey, home: const SizedBox.shrink()),
    );
    final dialogFuture = showDialog<ParkingPhoto?>(
      context: navigatorKey.currentState!.context,
      barrierDismissible: false,
      builder: (context) => ParkingCaptureDialog(
        cameraSource: source,
        cameraOperationTimeout: const Duration(milliseconds: 1),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2));

    expect(
      find.text(
        'The camera took too long to initialize. Check permissions and try again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);

    final session = FakeParkingCameraSession();
    completer.complete(session);
    await tester.pump();
    expect(session.disposeCalls, 1);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(await dialogFuture, isNull);
  });

  testWidgets('supports capture, retake, use, and camera disposal', (
    WidgetTester tester,
  ) async {
    final session = FakeParkingCameraSession(photo: _photo());
    final source = FakeParkingCameraSource(session: session);
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigatorKey, home: const SizedBox.shrink()),
    );
    final dialogFuture = showDialog<ParkingPhoto?>(
      context: navigatorKey.currentState!.context,
      barrierDismissible: false,
      builder: (context) => ParkingCaptureDialog(cameraSource: source),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Capture'));
    await tester.pump();

    expect(find.text('Retake'), findsOneWidget);
    expect(find.text('Use Photo'), findsOneWidget);
    expect(find.text('Capture'), findsNothing);

    await tester.tap(find.text('Retake'));
    await tester.pump();
    expect(find.text('Capture'), findsOneWidget);

    await tester.tap(find.text('Capture'));
    await tester.pump();
    await tester.tap(find.text('Use Photo'));
    await tester.pump();

    expect(await dialogFuture, same(session.photo));
    await tester.pumpAndSettle();
    expect(session.captureCalls, 2);
    expect(session.disposeCalls, 2);
  });

  testWidgets('cancelling during capture releases the camera', (
    WidgetTester tester,
  ) async {
    final captureCompleter = Completer<ParkingPhoto>();
    final session = FakeParkingCameraSession(
      captureResult: captureCompleter.future,
    );
    final source = FakeParkingCameraSource(session: session);
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigatorKey, home: const SizedBox.shrink()),
    );
    final dialogFuture = showDialog<ParkingPhoto?>(
      context: navigatorKey.currentState!.context,
      barrierDismissible: false,
      builder: (context) => ParkingCaptureDialog(cameraSource: source),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Capture'));
    await tester.pump();
    expect(find.text('Capturing...'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(await dialogFuture, isNull);
    await tester.pumpAndSettle();
    expect(session.disposeCalls, 1);

    captureCompleter.complete(_photo());
    await tester.pump();
  });

  testWidgets('times out capture, disposes the session, and allows retry', (
    WidgetTester tester,
  ) async {
    final captureCompleter = Completer<ParkingPhoto>();
    final session = FakeParkingCameraSession(
      captureResult: captureCompleter.future,
    );
    final source = FakeParkingCameraSource(session: session);
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigatorKey, home: const SizedBox.shrink()),
    );
    final dialogFuture = showDialog<ParkingPhoto?>(
      context: navigatorKey.currentState!.context,
      barrierDismissible: false,
      builder: (context) => ParkingCaptureDialog(
        cameraSource: source,
        cameraOperationTimeout: const Duration(milliseconds: 1),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Capture'));
    await tester.pump();
    expect(session.captureCalls, 1);
    await tester.pump(const Duration(milliseconds: 2));

    expect(
      find.text(
        'The camera capture took too long. Try again or choose a file instead.',
      ),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(session.disposeCalls, 1);

    captureCompleter.complete(_photo());
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(await dialogFuture, isNull);
  });

  testWidgets('cancelling closes the dialog and disposes the camera', (
    WidgetTester tester,
  ) async {
    final session = FakeParkingCameraSession();
    final source = FakeParkingCameraSource(session: session);
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigatorKey, home: const SizedBox.shrink()),
    );
    final dialogFuture = showDialog<ParkingPhoto?>(
      context: navigatorKey.currentState!.context,
      barrierDismissible: false,
      builder: (context) => ParkingCaptureDialog(cameraSource: source),
    );
    await tester.pump();

    await tester.tap(find.text('Cancel'));
    await tester.pump();

    expect(await dialogFuture, isNull);
    expect(session.disposeCalls, 1);
  });

  testWidgets('shows camera initialization errors', (
    WidgetTester tester,
  ) async {
    final source = FakeParkingCameraSource(
      openError: const ParkingCameraException(
        'Camera access was denied or restricted.',
      ),
    );
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigatorKey, home: const SizedBox.shrink()),
    );
    showDialog<ParkingPhoto?>(
      context: navigatorKey.currentState!.context,
      barrierDismissible: false,
      builder: (context) => ParkingCaptureDialog(cameraSource: source),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.text('Camera access was denied or restricted.'),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Capture'), findsNothing);
  });

  testWidgets('shows errors from a synchronous camera open failure', (
    WidgetTester tester,
  ) async {
    final source = FakeParkingCameraSource(
      synchronousOpenError: const ParkingCameraException(
        'The camera could not be accessed.',
      ),
    );
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigatorKey, home: const SizedBox.shrink()),
    );
    showDialog<ParkingPhoto?>(
      context: navigatorKey.currentState!.context,
      barrierDismissible: false,
      builder: (context) => ParkingCaptureDialog(cameraSource: source),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('The camera could not be accessed.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('shows capture errors and keeps the dialog open', (
    WidgetTester tester,
  ) async {
    final session = FakeParkingCameraSession(
      captureError: const ParkingCameraException(
        'The photo could not be captured. Try again.',
      ),
    );
    final source = FakeParkingCameraSource(session: session);
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigatorKey, home: const SizedBox.shrink()),
    );
    final dialogFuture = showDialog<ParkingPhoto?>(
      context: navigatorKey.currentState!.context,
      barrierDismissible: false,
      builder: (context) => ParkingCaptureDialog(cameraSource: source),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Capture'));
    await tester.pump();

    expect(
      find.text('The photo could not be captured. Try again.'),
      findsOneWidget,
    );
    expect(find.text('Capture'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    expect(session.disposeCalls, 1);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(await dialogFuture, isNull);
  });
}

ParkingPhoto _photo() {
  return ParkingPhoto(
    bytes: Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    ),
    fileName: 'camera.jpg',
    mimeType: 'image/jpeg',
  );
}

class FakeParkingCameraSource implements ParkingCameraSource {
  FakeParkingCameraSource({
    this.session,
    this.openResult,
    this.openError,
    this.synchronousOpenError,
  });

  final ParkingCameraSession? session;
  final Future<ParkingCameraSession>? openResult;
  final ParkingCameraException? openError;
  final ParkingCameraException? synchronousOpenError;

  @override
  Future<ParkingCameraSession> open() {
    final synchronousError = synchronousOpenError;
    if (synchronousError != null) {
      throw synchronousError;
    }

    final error = openError;
    if (error != null) {
      return Future.error(error);
    }

    final pendingResult = openResult;
    if (pendingResult != null) {
      return pendingResult;
    }

    return Future.value(session!);
  }
}

class FakeParkingCameraSession implements ParkingCameraSession {
  FakeParkingCameraSession({this.photo, this.captureError, this.captureResult});

  final ParkingPhoto? photo;
  final ParkingCameraException? captureError;
  final Future<ParkingPhoto>? captureResult;
  int captureCalls = 0;
  int disposeCalls = 0;

  @override
  Widget get preview => const Center(child: Text('Live camera preview'));

  @override
  Future<ParkingPhoto> capture() async {
    captureCalls++;
    final pendingResult = captureResult;
    if (pendingResult != null) {
      return pendingResult;
    }

    final error = captureError;
    if (error != null) {
      throw error;
    }

    return photo!;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}
