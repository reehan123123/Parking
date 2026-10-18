import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parking_management/features/parking/data/parking_camera_source.dart';
import 'package:parking_management/features/parking/data/parking_photo.dart';
import 'package:parking_management/features/parking/data/parking_photo_source.dart';
import 'package:parking_management/features/parking/data/parking_session_repository.dart';
import 'package:parking_management/features/parking/domain/parking_duration.dart';
import 'package:parking_management/features/parking/domain/parking_duration_unit.dart';
import 'package:parking_management/features/parking/domain/parking_session.dart';
import 'package:parking_management/features/parking/presentation/parking_entry_page.dart';

void main() {
  testWidgets('calculates an expiry preview from the entered duration', (
    WidgetTester tester,
  ) async {
    final repository = FakeParkingSessionRepository();
    await _pumpEntryPage(tester, repository: repository);

    await tester.enterText(find.byType(TextFormField).at(0), 'AB 123');
    await tester.enterText(find.byType(TextFormField).at(1), '2');
    await tester.pump();

    expect(find.text('Calculated expiry'), findsOneWidget);
  });

  testWidgets('requires an explicit choice when no photo is selected', (
    WidgetTester tester,
  ) async {
    final repository = FakeParkingSessionRepository();
    await _pumpEntryPage(tester, repository: repository);

    await tester.enterText(find.byType(TextFormField).at(0), 'AB 123');
    await tester.enterText(find.byType(TextFormField).at(1), '2');
    await _tapVisible(tester, 'Save parking entry');
    await tester.pump();

    expect(
      find.text(
        'Select a vehicle photo or explicitly choose Continue without photo.',
      ),
      findsOneWidget,
    );
    expect(repository.savedSession, isNull);
  });

  testWidgets('passes normalized values and an explicit no-photo choice', (
    WidgetTester tester,
  ) async {
    final repository = FakeParkingSessionRepository();
    await _pumpEntryPage(tester, repository: repository);

    await tester.enterText(find.byType(TextFormField).at(0), ' ab 123 ');
    await tester.enterText(find.byType(TextFormField).at(1), '2');
    await _tapVisible(tester, 'Continue without photo');
    await _tapVisible(tester, 'Save parking entry');
    await tester.pump();

    expect(repository.savedSession?.plateNumber, 'AB 123');
    expect(repository.savedSession?.allowedDuration.value, 2);
    expect(repository.savedPhoto, isNull);
    expect(find.text('Save failed for testing.'), findsOneWidget);
  });

  testWidgets('shows a selected photo and offers cleanup retry on failure', (
    WidgetTester tester,
  ) async {
    final repository = FakeParkingSessionRepository(
      saveResult: const ParkingSessionSaveFailure(
        message: 'Upload failed for testing.',
        sessionId: 'session-1',
        photoPath: 'user-1/session-1/photo.jpg',
        cleanupRequired: true,
      ),
      cleanupResult: const ParkingSessionCleanupSuccess(),
    );
    final photoSource = FakeParkingPhotoSource(photo: _photo());
    await _pumpEntryPage(
      tester,
      repository: repository,
      photoSource: photoSource,
    );

    await _tapVisible(tester, 'Choose file');
    await tester.pump();
    expect(find.text('car.jpg (0.1 KB)'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'AB 123');
    await tester.enterText(find.byType(TextFormField).at(1), '2');
    await _tapVisible(tester, 'Save parking entry');
    await tester.pump();

    expect(find.text('Upload failed for testing.'), findsOneWidget);
    expect(find.text('Retry cleanup'), findsOneWidget);

    await _tapVisible(tester, 'Retry cleanup');
    await tester.pump();

    expect(
      find.text(
        'Cleanup completed. The incomplete session was removed. You can try again.',
      ),
      findsOneWidget,
    );
    expect(repository.retryCleanupCalls, 1);
  });

  testWidgets('passes a captured camera photo into the existing save flow', (
    WidgetTester tester,
  ) async {
    final repository = FakeParkingSessionRepository();
    final cameraSession = FakeParkingCameraSession(photo: _cameraPhoto());
    await _pumpEntryPage(
      tester,
      repository: repository,
      cameraSource: FakeParkingCameraSource(session: cameraSession),
    );

    await _tapVisible(tester, 'Take photo');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Capture'));
    await tester.pump();
    await tester.tap(find.text('Use Photo'));
    await tester.pumpAndSettle();

    expect(find.text('camera.jpg (0.1 KB)'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'AB 123');
    await tester.enterText(find.byType(TextFormField).at(1), '2');
    await _tapVisible(tester, 'Save parking entry');
    await tester.pump();

    expect(repository.savedPhoto?.fileName, 'camera.jpg');
    expect(cameraSession.disposeCalls, 1);
  });

  testWidgets('reuses the form to update an existing session', (
    WidgetTester tester,
  ) async {
    final session = ParkingSession(
      id: 'session-1',
      plateNumber: 'AB 123',
      entryTime: DateTime(2026, 10, 14, 10, 30),
      allowedDuration: const ParkingDuration(
        value: 2,
        unit: ParkingDurationUnit.hours,
      ),
      expiresAt: DateTime(2026, 10, 14, 12, 30),
    );
    final repository = FakeParkingSessionRepository(
      updateResult: ParkingSessionUpdateSuccess(session: session),
    );
    await _pumpEntryPage(
      tester,
      repository: repository,
      initialSession: session,
    );

    expect(find.text('Edit Parking Entry'), findsOneWidget);
    await _tapWidgetWithText(tester, FilledButton, 'Update parking entry');
    await tester.pump();

    expect(repository.updatedSession?.id, 'session-1');
    expect(repository.updatedSession?.plateNumber, 'AB 123');
  });
}

Future<void> _tapVisible(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
}

Future<void> _tapWidgetWithText(
  WidgetTester tester,
  Type widgetType,
  String text,
) async {
  final finder = find.widgetWithText(widgetType, text);
  await _makeVisible(tester, finder);
  await tester.pump();
  await tester.tap(finder);
}

Future<void> _makeVisible(WidgetTester tester, Finder finder) async {
  final scrollable = find.byWidgetPredicate(
    (widget) => widget is Scrollable && widget.axis == Axis.vertical,
  );
  final viewportHeight =
      tester.view.physicalSize.height / tester.view.devicePixelRatio;
  for (var attempt = 0; attempt < 20; attempt++) {
    final rect = tester.getRect(finder);
    if (rect.top >= 0 && rect.bottom <= viewportHeight) {
      return;
    }

    final offset = rect.bottom > viewportHeight
        ? const Offset(0, -300)
        : const Offset(0, 300);
    await tester.drag(scrollable, offset);
    await tester.pump();
  }
}

Future<void> _pumpEntryPage(
  WidgetTester tester, {
  required FakeParkingSessionRepository repository,
  FakeParkingPhotoSource? photoSource,
  FakeParkingCameraSource? cameraSource,
  ParkingSession? initialSession,
}) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: ParkingEntryPage(
        repository: repository,
        photoSource: photoSource,
        cameraSource: cameraSource,
        initialSession: initialSession,
        now: () => DateTime(2026, 10, 14, 10, 30),
      ),
    ),
  );
}

ParkingPhoto _photo() {
  return ParkingPhoto(
    bytes: Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    ),
    fileName: 'car.jpg',
    mimeType: 'image/jpeg',
  );
}

ParkingPhoto _cameraPhoto() {
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

class FakeParkingSessionRepository implements ParkingSessionRepository {
  FakeParkingSessionRepository({
    this.saveResult = const ParkingSessionSaveFailure(
      message: 'Save failed for testing.',
    ),
    this.cleanupResult = const ParkingSessionCleanupSuccess(),
    this.updateResult = const ParkingSessionUpdateFailure(
      message: 'Update failed for testing.',
      sessionId: 'session-1',
    ),
    this.deleteResult = const ParkingSessionDeleteFailure(
      message: 'Delete failed for testing.',
      sessionId: 'session-1',
    ),
  });

  final ParkingSessionSaveResult saveResult;
  final ParkingSessionCleanupResult cleanupResult;
  final ParkingSessionUpdateResult updateResult;
  final ParkingSessionDeleteResult deleteResult;
  ParkingSession? savedSession;
  ParkingPhoto? savedPhoto;
  ParkingSession? updatedSession;
  ParkingPhoto? replacementPhoto;
  int retryCleanupCalls = 0;

  @override
  Future<ParkingSessionSaveResult> save({
    required ParkingSession session,
    ParkingPhoto? photo,
  }) async {
    savedSession = session;
    savedPhoto = photo;
    return saveResult;
  }

  @override
  Future<ParkingSessionListResult> list({String search = ''}) async {
    return const ParkingSessionListSuccess(sessions: []);
  }

  @override
  Future<ParkingSessionSummaryResult> summary() async {
    return const ParkingSessionSummarySuccess(
      summary: ParkingSessionSummary(activeCount: 0, expiredCount: 0),
    );
  }

  @override
  Future<ParkingSessionDetailResult> getById({
    required String sessionId,
  }) async {
    return const ParkingSessionDetailFailure(
      message: 'Session not found for testing.',
    );
  }

  @override
  Future<ParkingSessionPhotoUrlResult> createSignedPhotoUrl({
    required String sessionId,
    required String photoPath,
    int expiresInSeconds = 300,
  }) async {
    return const ParkingSessionPhotoUrlFailure(
      message: 'Photo not found for testing.',
    );
  }

  @override
  Future<ParkingSessionUpdateResult> update({
    required ParkingSession session,
    ParkingPhoto? replacementPhoto,
  }) async {
    updatedSession = session;
    this.replacementPhoto = replacementPhoto;
    return updateResult;
  }

  @override
  Future<ParkingSessionDeleteResult> delete({
    required ParkingSession session,
  }) async {
    return deleteResult;
  }

  @override
  Future<ParkingSessionCleanupResult> retryCleanup({
    required String sessionId,
    required String photoPath,
  }) async {
    retryCleanupCalls++;
    return cleanupResult;
  }

  @override
  Future<ParkingPhotoCleanupResult> retryPhotoCleanup({
    required String photoPath,
  }) async {
    return const ParkingPhotoCleanupSuccess();
  }
}

class FakeParkingPhotoSource implements ParkingPhotoSource {
  const FakeParkingPhotoSource({required this.photo});

  final ParkingPhoto? photo;

  @override
  Future<ParkingPhoto?> pick({required ImageSource source}) async => photo;
}

class FakeParkingCameraSource implements ParkingCameraSource {
  const FakeParkingCameraSource({required this.session});

  final FakeParkingCameraSession session;

  @override
  Future<ParkingCameraSession> open() async => session;
}

class FakeParkingCameraSession implements ParkingCameraSession {
  FakeParkingCameraSession({required this.photo});

  final ParkingPhoto photo;
  int disposeCalls = 0;

  @override
  Widget get preview => const Center(child: Text('Live camera preview'));

  @override
  Future<ParkingPhoto> capture() async => photo;

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}
