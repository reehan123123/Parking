import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parking_management/features/parking/data/parking_photo.dart';
import 'package:parking_management/features/parking/data/parking_session_repository.dart';
import 'package:parking_management/features/parking/data/supabase_parking_session_repository.dart';
import 'package:parking_management/features/parking/domain/parking_duration.dart';
import 'package:parking_management/features/parking/domain/parking_duration_unit.dart';
import 'package:parking_management/features/parking/domain/parking_session.dart';
import 'package:parking_management/features/tenants/domain/parking_tenant_scope.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _tenantScope = ParkingTenantScope(
  isSuperAdmin: false,
  tenantId: 'tenant-1',
);

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

    test(
      'rejects unauthenticated payment actions before store access',
      () async {
        final store = FakeParkingSessionStore();
        final repository = SupabaseParkingSessionRepository(
          null,
          currentUserId: () => null,
          sessionStore: store,
          photoStorage: FakeVehiclePhotoStorage(),
        );

        final result = await repository.markFullyPaid(sessionId: 'session-1');

        expect(result, isA<ParkingSessionPaymentFailure>());
        expect(store.events, isEmpty);
      },
    );

    test('marks the full balance through the authorized store', () async {
      final store = FakeParkingSessionStore()..fullyPaidResult = true;
      final repository = _repository(store: store);

      final result = await repository.markFullyPaid(sessionId: ' session-1 ');

      expect(result, isA<ParkingSessionPaymentSuccess>());
      expect((result as ParkingSessionPaymentSuccess).wasMarkedPaid, isTrue);
      expect(store.lastFullyPaidSessionId, 'session-1');
      expect(store.events, ['markFullyPaid']);
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
        'tenant_id': 'tenant-1',
        'entry_time': '2026-10-14T10:30:00.000Z',
        'allowed_duration_value': 2,
        'allowed_duration_unit': 'hours',
        'expires_at': '2026-10-14T12:30:00.000Z',
        'created_by': 'user-1',
        'total_charge': 0.0,
        'paid_amount': 0.0,
        'contact_number': '+919876543210',
        'has_photo': false,
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
        expect(store.events, ['insert', 'setPhotoPath', 'completePhotoUpload']);
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

      final result = await repository.list(
        scope: _tenantScope,
        search: 'ab 12',
      );

      expect(result, isA<ParkingSessionListSuccess>());
      final success = result as ParkingSessionListSuccess;
      expect(success.sessions.single.id, 'session-5');
      expect(success.sessions.single.plateNumber, 'AB 123');
      expect(store.lastSearch, 'ab 12');
      expect(store.lastListOffset, 0);
      expect(store.lastListLimit, 51);
    });

    test(
      'requests a bounded page and reports when more sessions exist',
      () async {
        final store = FakeParkingSessionStore()
          ..rows = [
            _row(id: 'session-10'),
            _row(id: 'session-11'),
            _row(id: 'session-12'),
          ];
        final repository = _repository(store: store);

        final result = await repository.list(
          scope: _tenantScope,
          offset: 20,
          pageSize: 2,
        );

        expect(result, isA<ParkingSessionListSuccess>());
        final success = result as ParkingSessionListSuccess;
        expect(success.sessions.map((session) => session.id), [
          'session-10',
          'session-11',
        ]);
        expect(success.hasMore, isTrue);
        expect(store.lastListOffset, 20);
        expect(store.lastListLimit, 3);
      },
    );

    test('rejects invalid page bounds before querying the store', () async {
      final store = FakeParkingSessionStore();
      final repository = _repository(store: store);

      final result = await repository.list(
        scope: _tenantScope,
        offset: -1,
        pageSize: 101,
      );

      expect(result, isA<ParkingSessionListFailure>());
      expect(store.events, isEmpty);
    });

    test('passes one UTC expiry cutoff to the summary store', () async {
      final asOf = DateTime.utc(2026, 10, 14, 10, 30);
      final store = FakeParkingSessionStore()
        ..summaryValue = const ParkingSessionSummary(
          activeCount: 1,
          expiredCount: 1,
        );
      final repository = _repository(store: store, now: () => asOf);

      final result = await repository.summary(scope: _tenantScope);

      expect(result, isA<ParkingSessionSummarySuccess>());
      final summary = (result as ParkingSessionSummarySuccess).summary;
      expect(summary.activeCount, 1);
      expect(summary.expiredCount, 1);
      expect(store.lastSummaryScope, _tenantScope);
      expect(store.lastSummaryAsOf, asOf);
    });

    test(
      'uses tenant-filtered exact HEAD counts for the expiry summary',
      () async {
        final requests = <http.Request>[];
        final mockClient = MockClient((request) async {
          requests.add(request);
          final expiryFilter = request.url.queryParameters['expires_at'];
          final count = expiryFilter?.startsWith('gt.') == true ? 2 : 3;
          return http.Response(
            '',
            200,
            headers: {'content-range': '*/$count'},
            request: request,
          );
        });
        final client = SupabaseClient(
          'https://parking-test.supabase.co',
          'test-publishable-key',
          httpClient: mockClient,
        );
        addTearDown(() async {
          await client.dispose();
          mockClient.close();
        });
        final asOf = DateTime.utc(2026, 10, 14, 10, 30);
        final repository = SupabaseParkingSessionRepository(
          client,
          currentUserId: () => 'user-1',
          now: () => asOf,
        );

        final result = await repository.summary(scope: _tenantScope);

        expect(result, isA<ParkingSessionSummarySuccess>());
        final summary = (result as ParkingSessionSummarySuccess).summary;
        expect(summary.activeCount, 2);
        expect(summary.expiredCount, 3);
        expect(requests, hasLength(2));
        expect(requests.map((request) => request.method), everyElement('HEAD'));
        for (final request in requests) {
          expect(request.url.path, '/rest/v1/parking_sessions');
          expect(request.url.queryParameters['tenant_id'], 'eq.tenant-1');
        }
        expect(
          requests
              .map((request) => request.url.queryParameters['expires_at'])
              .toSet(),
          {'gt.2026-10-14T10:30:00.000Z', 'lte.2026-10-14T10:30:00.000Z'},
        );
      },
    );

    test(
      'uses tenant-filtered stable ordering and bounded list ranges',
      () async {
        final requests = <http.Request>[];
        final mockClient = MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode([
              _row(id: 'session-20'),
              _row(id: 'session-21'),
              _row(id: 'session-22'),
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        });
        final client = SupabaseClient(
          'https://parking-test.supabase.co',
          'test-publishable-key',
          httpClient: mockClient,
        );
        addTearDown(() async {
          await client.dispose();
          mockClient.close();
        });
        final repository = SupabaseParkingSessionRepository(
          client,
          currentUserId: () => 'user-1',
        );

        final result = await repository.list(
          scope: _tenantScope,
          search: ' AB 12 ',
          offset: 50,
          pageSize: 2,
        );

        expect(result, isA<ParkingSessionListSuccess>());
        final success = result as ParkingSessionListSuccess;
        expect(success.sessions, hasLength(2));
        expect(success.hasMore, isTrue);
        expect(requests, hasLength(1));
        final request = requests.single;
        expect(request.method, 'GET');
        expect(request.url.queryParameters['tenant_id'], 'eq.tenant-1');
        expect(
          request.url.queryParameters['order'],
          'entry_time.desc.nullslast,id.desc.nullslast',
        );
        expect(request.url.queryParameters['offset'], '50');
        expect(request.url.queryParameters['limit'], '3');
        expect(request.url.queryParameters['plate_number'], contains('ilike.'));
        expect(request.url.queryParameters['plate_number'], contains('AB 12'));
      },
    );

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
    tenantId: 'tenant-1',
    plateNumber: plateNumber,
    entryTime: entryTime,
    allowedDuration: const ParkingDuration(
      value: 2,
      unit: ParkingDurationUnit.hours,
    ),
    expiresAt: DateTime.utc(2026, 10, 14, 12, 30),
    contactNumber: '+919876543210',
  );
}

ParkingSession _sessionWithId({
  required String id,
  String plateNumber = 'AB 123',
}) {
  return ParkingSession(
    id: id,
    tenantId: 'tenant-1',
    createdBy: 'user-1',
    plateNumber: plateNumber,
    entryTime: DateTime.utc(2026, 10, 14, 10, 30),
    allowedDuration: const ParkingDuration(
      value: 2,
      unit: ParkingDurationUnit.hours,
    ),
    expiresAt: DateTime.utc(2026, 10, 14, 12, 30),
    contactNumber: '+919876543210',
  );
}

Map<String, dynamic> _row({
  required String id,
  String plateNumber = 'AB 123',
  String? photoPath,
}) {
  return {
    'id': id,
    'tenant_id': 'tenant-1',
    'created_by': 'user-1',
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
  ParkingSessionSummary summaryValue = const ParkingSessionSummary(
    activeCount: 0,
    expiredCount: 0,
  );
  String? lastSearch;
  int? lastListOffset;
  int? lastListLimit;
  ParkingTenantScope? lastSummaryScope;
  DateTime? lastSummaryAsOf;
  Map<String, dynamic>? lastUpdatedValues;
  Exception? updateError;
  bool fullyPaidResult = false;
  String? lastFullyPaidSessionId;

  @override
  Future<String> insert(Map<String, dynamic> values) async {
    events.add('insert');
    insertedValues = values;
    return insertedId;
  }

  @override
  Future<List<Map<String, dynamic>>> list({
    required ParkingTenantScope scope,
    required int offset,
    required int limit,
    String? search,
  }) async {
    events.add('list');
    lastSearch = search;
    lastListOffset = offset;
    lastListLimit = limit;
    return rows;
  }

  @override
  Future<ParkingSessionSummary> summary({
    required ParkingTenantScope scope,
    required DateTime asOf,
  }) async {
    events.add('summary');
    lastSummaryScope = scope;
    lastSummaryAsOf = asOf;
    return summaryValue;
  }

  @override
  Future<Map<String, dynamic>?> find({required String sessionId}) async {
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
  Future<void> completePhotoUpload({required String sessionId}) async {
    events.add('completePhotoUpload');
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

  @override
  Future<bool> markFullyPaid({required String sessionId}) async {
    events.add('markFullyPaid');
    lastFullyPaidSessionId = sessionId;
    return fullyPaidResult;
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
