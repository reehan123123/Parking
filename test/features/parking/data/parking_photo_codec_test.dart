import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parking_management/features/parking/data/parking_photo_codec.dart';

void main() {
  test('accepts supported image MIME types and names', () async {
    final jpeg = await ParkingPhotoCodec.fromXFile(
      XFile.fromData(
        Uint8List.fromList([1, 2, 3]),
        name: 'vehicle.jpeg',
        mimeType: 'image/jpeg',
      ),
    );
    final webp = await ParkingPhotoCodec.fromXFile(
      XFile.fromData(
        Uint8List.fromList([1, 2, 3]),
        name: 'vehicle.bin',
        mimeType: 'image/webp',
      ),
    );

    expect(jpeg.mimeType, 'image/jpeg');
    expect(webp.mimeType, 'image/webp');
  });

  test('accepts camera captures without web MIME metadata', () async {
    final photo = await ParkingPhotoCodec.fromXFile(
      XFile.fromData(
        Uint8List.fromList([1, 2, 3]),
        name: 'blob:https://parking.example.com/camera-capture',
      ),
      fallbackFileName: 'vehicle-camera.jpg',
      fallbackMimeType: 'image/jpeg',
    );

    expect(photo.fileName, 'vehicle-camera.jpg');
    expect(photo.mimeType, 'image/jpeg');
  });

  test('rejects unsupported image types', () async {
    final future = ParkingPhotoCodec.fromXFile(
      XFile.fromData(
        Uint8List.fromList([1, 2, 3]),
        name: 'vehicle.gif',
        mimeType: 'image/gif',
      ),
    );

    await expectLater(
      future,
      throwsA(
        isA<ParkingPhotoException>().having(
          (error) => error.message,
          'message',
          'Choose a JPEG, PNG, or WebP image.',
        ),
      ),
    );
  });

  test('rejects empty images', () async {
    final future = ParkingPhotoCodec.fromXFile(
      XFile.fromData(Uint8List(0), name: 'vehicle.jpg'),
    );

    await expectLater(
      future,
      throwsA(
        isA<ParkingPhotoException>().having(
          (error) => error.message,
          'message',
          'The selected image is empty.',
        ),
      ),
    );
  });

  test('rejects images larger than 10 MB', () async {
    final future = ParkingPhotoCodec.fromXFile(
      XFile.fromData(
        Uint8List(ParkingPhotoCodec.maxImageBytes + 1),
        name: 'vehicle.jpg',
        mimeType: 'image/jpeg',
      ),
    );

    await expectLater(
      future,
      throwsA(
        isA<ParkingPhotoException>().having(
          (error) => error.message,
          'message',
          'Choose an image smaller than 10 MB.',
        ),
      ),
    );
  });
}
