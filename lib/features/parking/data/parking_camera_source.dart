import 'package:camera/camera.dart' as camera;
import 'package:flutter/material.dart';

import 'parking_photo.dart';
import 'parking_photo_codec.dart';

abstract interface class ParkingCameraSource {
  Future<ParkingCameraSession> open();
}

abstract interface class ParkingCameraSession {
  Widget get preview;

  Future<ParkingPhoto> capture();

  Future<void> dispose();
}

class ParkingCameraException implements Exception {
  const ParkingCameraException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CameraPackageParkingCameraSource implements ParkingCameraSource {
  const CameraPackageParkingCameraSource();

  @override
  Future<ParkingCameraSession> open() async {
    late final List<camera.CameraDescription> cameras;
    try {
      cameras = await camera.availableCameras();
    } on camera.CameraException catch (error) {
      throw ParkingCameraException(_messageForCameraError(error));
    } on Exception {
      throw const ParkingCameraException(
        'The camera could not be accessed. Check browser permissions and try again.',
      );
    }

    if (cameras.isEmpty) {
      throw const ParkingCameraException(
        'No camera is available on this device. Choose an existing photo instead.',
      );
    }

    final controller = camera.CameraController(
      cameras.first,
      camera.ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await controller.initialize();
      return CameraPackageParkingCameraSession(controller);
    } on camera.CameraException catch (error) {
      await controller.dispose();
      throw ParkingCameraException(_messageForCameraError(error));
    } on Exception {
      await controller.dispose();
      throw const ParkingCameraException(
        'The camera could not be initialized. Check browser permissions and try again.',
      );
    }
  }

  static String _messageForCameraError(camera.CameraException error) {
    switch (error.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
      case 'permissionDenied':
      case 'NotAllowedError':
        return 'Camera access was denied or restricted. Allow access or choose an existing photo instead.';
      case 'CameraNotFound':
      case 'cameraNotFound':
        return 'No camera is available on this device. Choose an existing photo instead.';
      default:
        return 'The camera could not be initialized. Check browser permissions and try again.';
    }
  }
}

class CameraPackageParkingCameraSession implements ParkingCameraSession {
  CameraPackageParkingCameraSession(this._controller);

  final camera.CameraController _controller;

  @override
  Widget get preview => camera.CameraPreview(_controller);

  @override
  Future<ParkingPhoto> capture() async {
    try {
      final file = await _controller.takePicture();
      return await ParkingPhotoCodec.fromXFile(
        file,
        fallbackFileName: 'vehicle-camera.jpg',
        fallbackMimeType: 'image/jpeg',
      );
    } on camera.CameraException catch (error) {
      throw ParkingCameraException(
        'The photo could not be captured. ${error.description ?? 'Try again.'}',
      );
    } on ParkingPhotoException {
      rethrow;
    } on Exception {
      throw const ParkingCameraException(
        'The photo could not be captured. Try again.',
      );
    }
  }

  @override
  Future<void> dispose() => _controller.dispose();
}
