import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/parking/data/parking_ocr_service.dart';
import 'package:parking_management/features/parking/data/parking_photo.dart';
import 'package:parking_management/features/parking/data/parking_plate_normalizer.dart';

void main() {
  test('normalizes manual and OCR registration candidates safely', () {
    expect(ParkingPlateNormalizer.normalize('  ab 123  '), 'AB 123');
    expect(
      ParkingPlateNormalizer.candidateFromOcr('parking\nab   123\nmore text'),
      'AB 123',
    );
  });

  test('returns no candidate when OCR contains no alphanumeric text', () {
    expect(ParkingPlateNormalizer.candidateFromOcr('---\n   \n...'), isNull);
  });

  test('prefers a mixed letter and number candidate without a format rule', () {
    expect(
      ParkingPlateNormalizer.candidateFromOcr('PARKING\nAB 123\nHELLO'),
      'AB 123',
    );
  });

  test(
    'rejects short incidental OCR text while preserving a plate candidate',
    () {
      expect(ParkingPlateNormalizer.candidateFromOcr('HAS'), isNull);
      expect(
        ParkingPlateNormalizer.candidateFromOcr('HAS\nMH03 V5823'),
        'MH03 V5823',
      );
    },
  );

  test('does not require a country-specific registration format', () {
    expect(ParkingPlateNormalizer.candidateFromOcr('ABCD'), 'ABCD');
  });

  test(
    'cancellation listeners run once and late listeners run immediately',
    () {
      final token = ParkingOcrCancellationToken();
      var listenerCalls = 0;

      token.addCancellationListener(() => listenerCalls++);
      token.cancel();
      token.cancel();
      token.addCancellationListener(() => listenerCalls++);

      expect(token.isCancelled, isTrue);
      expect(listenerCalls, 2);
    },
  );

  test('non-Web fallback reports OCR as unavailable', () async {
    final result = await createParkingOcrService().recognize(
      photo: _photo(),
      cancellationToken: ParkingOcrCancellationToken(),
      onProgress: (_) {},
    );

    expect(result, isA<ParkingOcrUnavailableResult>());
  });
}

ParkingPhoto _photo() {
  return ParkingPhoto(
    bytes: Uint8List.fromList([1, 2, 3]),
    fileName: 'vehicle.jpg',
    mimeType: 'image/jpeg',
  );
}
