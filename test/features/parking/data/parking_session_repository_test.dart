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

    test('lists mapped sessions with a server-side plate search', () async {
      final store = FakeParkingSessionStore()
        ..rows = [_row(id: 'session-5', plateNumber: 'AB 123')];
      final repository = _repository(store: store);

      final result = await repository.list(search: 'ab 12');

      expect(result, isA<ParkingSessionListSuccess>());
      final success = result as ParkingSessionListSuccess;
      expect(success.sessions.single.id, 'session-5');
      expect(success.sessions.single.plateNumber, 'AB 123');
      expect(store.lastSearch, 'ab 12');
    });

    test('calculates summary counts at the active expiry boundary', () async {
      final store = FakeParkingSessionStore()
        ..summaryRows = [
          {'expires_at': '2026-10-14T10:30:01.000Z'},
          {'expires_at': '2026-10-14T10:30:00.000Z'},
        ];
      final repository = _repository(
        store: store,
        now: () => DateTime.utc(2026, 10, 14, 10, 30),
      );

      final result = await repository.summary();

      expect(result, isA<ParkingSessionSummarySuccess>());
      final summary = (result as ParkingSessionSummarySuccess).summary;
      expect(summary.activeCount, 1);
      expect(summary.expiredCount, 1);
    });

    test('loads an owned session and creates a signed photo URL', () async {
      final store = FakeParkingSessionStore()
        ..rows = [_row(id: 'session-6', photoPath: 'user-1/session-6/car.jpg')];
      final storage = FakeVehiclePhotoStorage();
      final repository = _repository(store: store, storage: storage);

      final result = await repository.createSignedPhotoUrl(
        sessionId: 'session-6',
        photoPath: 'user-1/session-6/car.jpg',
      );

      expect(result, isA<ParkingSessionPhotoUrlSuccess>());
      expect(
        (result as ParkingSessionPhotoUrlSuccess).url,
        'https://example.test/user-1/session-6/car.jpg',
      );
      expect(storage.events, ['signedUrl']);
    });

    test(
      'does not sign a photo path that is not on the owned session',
      () async {
        final store = FakeParkingSessionStore()
          ..rows = [
            _row(id: 'session-6b', photoPath: 'user-1/session-6b/car.jpg'),
          ];
        final storage = FakeVehiclePhotoStorage();
        final repository = _repository(store: store, storage: storage);

        final result = await repository.createSignedPhotoUrl(
          sessionId: 'session-6b',
          photoPath: 'user-1/session-6b/other.jpg',
        );

        expect(result, isA<ParkingSessionPhotoUrlFailure>());
        expect(storage.events, isEmpty);
      },
    );

    test('replaces an existing photo with an upsert update', () async {
      final store = FakeParkingSessionStore()
        ..rows = [_row(id: 'session-7', photoPath: 'user-1/session-7/car.jpg')];
      final storage = FakeVehiclePhotoStorage();
      final repository = _repository(store: store, storage: storage);

      final result = await repository.update(
        session: _sessionWithId(id: 'session-7', plateNumber: 'CD 456'),
        replacementPhoto: _photo(),
      );

      expect(result, isA<ParkingSessionUpdateSuccess>());
      expect(storage.lastUploadWasUpsert, isTrue);
      expect(store.events, ['find', 'update']);
      expect(store.lastUpdatedValues?['plate_number'], 'CD 456');
    });

    test('cleans up a new photo when adding it to a session fails', () async {
      final store = FakeParkingSessionStore()
        ..rows = [_row(id: 'session-7b')]
        ..updateError = Exception('row update failed');
      final storage = FakeVehiclePhotoStorage();
      final repository = _repository(store: store, storage: storage);

      final result = await repository.update(
        session: _sessionWithId(id: 'session-7b'),
        replacementPhoto: _photo(),
      );

      expect(result, isA<ParkingSessionUpdateFailure>());
      expect(storage.events, ['upload', 'remove']);
      expect(store.events, ['find', 'update']);
    });

    test('deletes the photo before deleting the owned session row', () async {
      final store = FakeParkingSessionStore()
        ..rows = [_row(id: 'session-8', photoPath: 'user-1/session-8/car.jpg')];
      final storage = FakeVehiclePhotoStorage();
      final repository = _repository(store: store, storage: storage);

      final result = await repository.delete(
        session: _sessionWithId(id: 'session-8'),
      );

      expect(result, isA<ParkingSessionDeleteSuccess>());
      expect(storage.events, ['remove']);
      expect(store.events, ['find', 'delete']);
    });

    test('does not delete the row when photo cleanup fails', () async {
      final store = FakeParkingSessionStore()
        ..rows = [_row(id: 'session-9', photoPath: 'user-1/session-9/car.jpg')];
      final storage = FakeVehiclePhotoStorage()
        ..removeError = Exception('storage unavailable');
      final repository = _repository(store: store, storage: storage);

      final result = await repository.delete(
        session: _sessionWithId(id: 'session-9'),
      );

      expect(result, isA<ParkingSessionDeleteFailure>());
      expect(store.events, ['find']);
      expect(storage.events, ['remove']);
    });
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

ParkingSession _sessionWithId({
  required String id,
  String plateNumber = 'AB 123',
}) {
  return ParkingSession(
    id: id,
    plateNumber: plateNumber,
    entryTime: DateTime.utc(2026, 10, 14, 10, 30),
    allowedDuration: const ParkingDuration(
      value: 2,
      unit: ParkingDurationUnit.hours,
    ),
    expiresAt: DateTime.utc(2026, 10, 14, 12, 30),
  );
}

Map<String, dynamic> _row({
  required String id,
  String plateNumber = 'AB 123',
  String? photoPath,
}) {
  return {
    'id': id,
    'plate_number': plateNumber,
    'photo_path': photoPath,
    'entry_time': '2026-10-14T10:30:00.000Z',
    'allowed_duration_value': 2,
    'allowed_duration_unit': 'hours',
    'expires_at': '2026-10-14T12:30:00.000Z',
  };
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
  DateTime Function()? now,
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
    now: now,
  );
}

class FakeParkingSessionStore implements ParkingSessionStore {
  String insertedId = 'session-id';
  final List<String> events = [];
  Map<String, dynamic>? insertedValues;
  List<Map<String, dynamic>> rows = [];
  List<Map<String, dynamic>> summaryRows = [];
  String? lastSearch;
  Map<String, dynamic>? lastUpdatedValues;
  Exception? updateError;

  @override
  Future<String> insert(Map<String, dynamic> values) async {
    events.add('insert');
    insertedValues = values;
    return insertedId;
  }

  @override
  Future<List<Map<String, dynamic>>> list({
    required String userId,
    String? search,
  }) async {
    events.add('list');
    lastSearch = search;
    return rows;
  }

  @override
  Future<List<Map<String, dynamic>>> summary({required String userId}) async {
    events.add('summary');
    return summaryRows.isEmpty ? rows : summaryRows;
  }

  @override
  Future<Map<String, dynamic>?> find({
    required String userId,
    required String sessionId,
  }) async {
    events.add('find');
    for (final row in rows) {
      if (row['id'] == sessionId) {
        return row;
      }
    }
    return null;
  }

  @override
  Future<void> setPhotoPath({
    required String sessionId,
    required String photoPath,
  }) async {
    events.add('setPhotoPath');
  }

  @override
  Future<void> update({
    required String sessionId,
    required Map<String, dynamic> values,
  }) async {
    events.add('update');
    lastUpdatedValues = values;
    final error = updateError;
    if (error != null) {
      throw error;
    }
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
  bool lastUploadWasUpsert = false;

  @override
  Future<void> upload({
    required String path,
    required ParkingPhoto photo,
    bool upsert = false,
  }) async {
    events.add('upload');
    uploadedPath = path;
    lastUploadWasUpsert = upsert;
    final error = uploadError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<String> createSignedUrl({
    required String path,
    required int expiresInSeconds,
  }) async {
    events.add('signedUrl');
    return 'https://example.test/$path';
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
