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

abstract interface class ParkingCameraSwitchingSession {
  bool get canSwitchCamera;

  Future<void> switchCamera();
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

    final preferredCamera = selectPreferredParkingCamera(cameras);
    final orderedCameras = <camera.CameraDescription>[
      preferredCamera,
      ...cameras.where((item) => item != preferredCamera),
    ];
    ParkingCameraException? lastError;

    for (final cameraDescription in orderedCameras) {
      final controller = camera.CameraController(
        cameraDescription,
        camera.ResolutionPreset.high,
        enableAudio: false,
      );

      try {
        await controller.initialize();
        return CameraPackageParkingCameraSession(
          controller,
          cameras: cameras,
          currentCameraIndex: cameras.indexOf(cameraDescription),
        );
      } on camera.CameraException catch (error) {
        await _disposeController(controller);
        lastError = ParkingCameraException(_messageForCameraError(error));
        if (_isPermissionError(error)) {
          throw lastError;
        }
      } on Exception {
        await _disposeController(controller);
        lastError = const ParkingCameraException(
          'The camera could not be initialized. Try another camera or choose an existing photo instead.',
        );
      }
    }

    throw lastError ??
        const ParkingCameraException(
          'The camera could not be initialized. Try another camera or choose an existing photo instead.',
        );
  }

  static bool _isPermissionError(camera.CameraException error) {
    return switch (error.code) {
      'CameraAccessDenied' ||
      'CameraAccessDeniedWithoutPrompt' ||
      'CameraAccessRestricted' ||
      'permissionDenied' ||
      'NotAllowedError' ||
      'SecurityError' => true,
      _ => false,
    };
  }

  static Future<void> _disposeController(
    camera.CameraController controller,
  ) async {
    try {
      await controller.dispose();
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'parking camera',
          context: ErrorDescription(
            'while releasing a failed camera initialization',
          ),
        ),
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
      case 'SecurityError':
        return 'Camera access was denied or restricted. Allow access or choose an existing photo instead.';
      case 'CameraNotFound':
      case 'cameraNotFound':
        return 'No camera is available on this device. Choose an existing photo instead.';
      case 'NotReadableError':
      case 'TrackStartError':
        return 'The selected camera is busy or unavailable. Try another camera or choose an existing photo instead.';
      default:
        return 'The selected camera could not be initialized. Try another camera or choose an existing photo instead.';
    }
  }
}

camera.CameraDescription selectPreferredParkingCamera(
  List<camera.CameraDescription> cameras,
) {
  if (cameras.isEmpty) {
    throw ArgumentError.value(
      cameras,
      'cameras',
      'At least one camera is required.',
    );
  }

  return cameras.firstWhere(
    (item) => item.lensDirection == camera.CameraLensDirection.back,
    orElse: () => cameras.firstWhere(
      (item) => item.lensDirection == camera.CameraLensDirection.external,
      orElse: () => cameras.first,
    ),
  );
}

class CameraPackageParkingCameraSession
    implements ParkingCameraSession, ParkingCameraSwitchingSession {
  CameraPackageParkingCameraSession(
    this._controller, {
    required List<camera.CameraDescription> cameras,
    required this._currentCameraIndex,
  }) : _cameras = List<camera.CameraDescription>.unmodifiable(cameras);

  final camera.CameraController _controller;
  final List<camera.CameraDescription> _cameras;
  int _currentCameraIndex;
  bool _isSwitching = false;

  @override
  Widget get preview => camera.CameraPreview(_controller);

  @override
  bool get canSwitchCamera => _cameras.length > 1;

  @override
  Future<void> switchCamera() async {
    if (!canSwitchCamera) {
      throw const ParkingCameraException(
        'No other camera is available. Choose an existing photo instead.',
      );
    }
    if (_isSwitching) {
      throw const ParkingCameraException(
        'The camera is already switching. Try again in a moment.',
      );
    }

    _isSwitching = true;
    final nextCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    try {
      await _controller.setDescription(_cameras[nextCameraIndex]);
      _currentCameraIndex = nextCameraIndex;
    } on camera.CameraException catch (error) {
      throw ParkingCameraException(_messageForSwitchError(error));
    } on Exception {
      throw const ParkingCameraException(
        'The selected camera could not be opened. Try another camera or choose an existing photo instead.',
      );
    } finally {
      _isSwitching = false;
    }
  }

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

  static String _messageForSwitchError(camera.CameraException error) {
    switch (error.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
      case 'permissionDenied':
      case 'NotAllowedError':
      case 'SecurityError':
        return 'Camera access was denied or restricted. Allow access or choose an existing photo instead.';
      case 'CameraNotFound':
      case 'cameraNotFound':
        return 'The selected camera is no longer available. Try another camera or choose an existing photo instead.';
      case 'NotReadableError':
      case 'TrackStartError':
        return 'The selected camera is busy or unavailable. Try another camera or choose an existing photo instead.';
      default:
        return 'The selected camera could not be opened. Try another camera or choose an existing photo instead.';
    }
  }
}
