import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/parking/data/parking_photo.dart';
import 'package:parking_management/features/parking/data/parking_session_repository.dart';
import 'package:parking_management/features/parking/data/supabase_parking_session_repository.dart';
import 'package:parking_management/features/parking/domain/parking_duration.dart';
import 'package:parking_management/features/parking/domain/parking_duration_unit.dart';
import 'package:parking_management/features/parking/domain/parking_session.dart';

void main() {
  group('SupabaseParkingSessionRepository', () {
    test('rejects unauthenticated saves before inserting a row', () async {
      final store = FakeParkingSessionStore();
      final storage = FakeVehiclePhotoStorage();
      final repository = SupabaseParkingSessionRepository(
        null,
        currentUserId: () => null,
        sessionStore: store,
        photoStorage: storage,
      );

      final result = await repository.save(session: _session());

      expect(result, isA<ParkingSessionSaveFailure>());
      expect(store.events, isEmpty);
      expect(storage.events, isEmpty);
    });

    test('normalizes the plate and maps the exact migration columns', () async {
      final store = FakeParkingSessionStore()..insertedId = 'session-1';
      final repository = _repository(store: store);

      final result = await repository.save(
        session: _session(plateNumber: '  ab 123  '),
      );

      expect(result, isA<ParkingSessionSaveSuccess>());
      expect(store.insertedValues, {
        'plate_number': 'AB 123',
        'photo_path': null,
        'entry_time': '2026-10-14T10:30:00.000Z',
        'allowed_duration_value': 2,
        'allowed_duration_unit': 'hours',
        'expires_at': '2026-10-14T12:30:00.000Z',
        'created_by': 'user-1',
      });
      expect(store.events, ['insert']);
    });

    test(
      'inserts the row before setting and uploading the photo path',
      () async {
        final store = FakeParkingSessionStore()..insertedId = 'session-2';
        final storage = FakeVehiclePhotoStorage();
        final repository = _repository(store: store, storage: storage);

        final result = await repository.save(
          session: _session(),
          photo: _photo(),
        );

        expect(result, isA<ParkingSessionSaveSuccess>());
        expect(store.events, ['insert', 'setPhotoPath']);
        expect(storage.events, ['upload']);
        expect(storage.uploadedPath, 'user-1/session-2/car_photo.jpg');
        final success = result as ParkingSessionSaveSuccess;
        expect(success.session.photoPath, 'user-1/session-2/car_photo.jpg');
      },
    );

    test(
      'removes the object before deleting the row after upload failure',
      () async {
        final store = FakeParkingSessionStore()..insertedId = 'session-3';
        final storage = FakeVehiclePhotoStorage()
          ..uploadError = Exception('upload failed');
        final repository = _repository(store: store, storage: storage);

        final result = await repository.save(
          session: _session(),
          photo: _photo(),
        );

        expect(result, isA<ParkingSessionSaveFailure>());
        final failure = result as ParkingSessionSaveFailure;
        expect(failure.cleanupRequired, isFalse);
        expect(store.events, ['insert', 'setPhotoPath', 'delete']);
        expect(storage.events, ['upload', 'remove']);
      },
    );

    test(
      'retains the row and supports cleanup retry when removal fails',
      () async {
        final store = FakeParkingSessionStore()..insertedId = 'session-4';
        final storage = FakeVehiclePhotoStorage()
          ..uploadError = Exception('upload failed')
          ..removeError = Exception('remove failed');
        final repository = _repository(store: store, storage: storage);

        final result = await repository.save(
          session: _session(),
          photo: _photo(),
        );

        expect(result, isA<ParkingSessionSaveFailure>());
        final failure = result as ParkingSessionSaveFailure;
        expect(failure.cleanupRequired, isTrue);
        expect(failure.sessionId, 'session-4');
        expect(failure.photoPath, 'user-1/session-4/car_photo.jpg');
        expect(store.events, ['insert', 'setPhotoPath']);

        storage.removeError = null;
        final cleanup = await repository.retryCleanup(
          sessionId: failure.sessionId!,
          photoPath: failure.photoPath!,
        );

        expect(cleanup, isA<ParkingSessionCleanupSuccess>());
        expect(storage.events, ['upload', 'remove', 'remove']);
        expect(store.events, ['insert', 'setPhotoPath', 'delete']);
      },
    );
  });
}

ParkingSession _session({String plateNumber = 'AB 123'}) {
  final entryTime = DateTime.utc(2026, 10, 14, 10, 30);
  return ParkingSession(
    plateNumber: plateNumber,
    entryTime: entryTime,
    allowedDuration: const ParkingDuration(
      value: 2,
      unit: ParkingDurationUnit.hours,
    ),
    expiresAt: DateTime.utc(2026, 10, 14, 12, 30),
  );
}

ParkingPhoto _photo() {
  return ParkingPhoto(
    bytes: Uint8List.fromList([1, 2, 3]),
    fileName: 'car photo.jpg',
    mimeType: 'image/jpeg',
  );
}

SupabaseParkingSessionRepository _repository({
  FakeParkingSessionStore? store,
  FakeVehiclePhotoStorage? storage,
}) {
  final sessionStore = store ?? FakeParkingSessionStore();
  if (store == null) {
    sessionStore.insertedId = 'session-1';
  }

  return SupabaseParkingSessionRepository(
    null,
    currentUserId: () => 'user-1',
    sessionStore: sessionStore,
    photoStorage: storage ?? FakeVehiclePhotoStorage(),
  );
}

class FakeParkingSessionStore implements ParkingSessionStore {
  String insertedId = 'session-id';
  final List<String> events = [];
  Map<String, dynamic>? insertedValues;

  @override
  Future<String> insert(Map<String, dynamic> values) async {
    events.add('insert');
    insertedValues = values;
    return insertedId;
  }

  @override
  Future<void> setPhotoPath({
    required String sessionId,
    required String photoPath,
  }) async {
    events.add('setPhotoPath');
  }

  @override
  Future<void> delete({required String sessionId}) async {
    events.add('delete');
  }
}

class FakeVehiclePhotoStorage implements VehiclePhotoStorage {
  final List<String> events = [];
  Exception? uploadError;
  Exception? removeError;
  String? uploadedPath;

  @override
  Future<void> upload({
    required String path,
    required ParkingPhoto photo,
  }) async {
    events.add('upload');
    uploadedPath = path;
    final error = uploadError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> remove({required String path}) async {
    events.add('remove');
    final error = removeError;
    if (error != null) {
      throw error;
    }
  }
}
