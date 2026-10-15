import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/parking/data/parking_camera_source.dart';

void main() {
  test('prefers a rear camera over external and front cameras', () {
    final cameras = [
      _camera('front', CameraLensDirection.front),
      _camera('external', CameraLensDirection.external),
      _camera('rear', CameraLensDirection.back),
    ];

    expect(selectPreferredParkingCamera(cameras).name, 'rear');
  });

  test('prefers an external webcam when no rear camera is available', () {
    final cameras = [
      _camera('front', CameraLensDirection.front),
      _camera('webcam', CameraLensDirection.external),
    ];

    expect(selectPreferredParkingCamera(cameras).name, 'webcam');
  });

  test('falls back to the first camera when lens direction is unavailable', () {
    final cameras = [
      _camera('first', CameraLensDirection.front),
      _camera('second', CameraLensDirection.front),
    ];

    expect(selectPreferredParkingCamera(cameras).name, 'first');
  });

  test('rejects an empty camera list', () {
    expect(() => selectPreferredParkingCamera(const []), throwsArgumentError);
  });
}

CameraDescription _camera(String name, CameraLensDirection lensDirection) {
  return CameraDescription(
    name: name,
    lensDirection: lensDirection,
    sensorOrientation: 0,
  );
}
