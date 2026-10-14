import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'parking_photo.dart';
import 'parking_photo_codec.dart';

abstract interface class ParkingPhotoSource {
  Future<ParkingPhoto?> pick({required ImageSource source});
}

class ImagePickerParkingPhotoSource implements ParkingPhotoSource {
  ImagePickerParkingPhotoSource({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  static const double maxImageWidth = 1600;
  static const double maxImageHeight = 1600;
  static const int imageQuality = 85;

  final ImagePicker _picker;

  @override
  Future<ParkingPhoto?> pick({required ImageSource source}) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: maxImageWidth,
        maxHeight: maxImageHeight,
        imageQuality: imageQuality,
        requestFullMetadata: false,
      );

      if (file == null) {
        return null;
      }

      return await ParkingPhotoCodec.fromXFile(file);
    } on ParkingPhotoException {
      rethrow;
    } on PlatformException catch (error) {
      throw ParkingPhotoException(_messageForPlatformError(error));
    } on Exception {
      throw const ParkingPhotoException(
        'The image could not be selected. Try another image or use the file option.',
      );
    }
  }

  String _messageForPlatformError(PlatformException error) {
    switch (error.code) {
      case 'photo_access_denied':
      case 'camera_access_denied':
        return 'Photo access was denied. Allow access or choose a file instead.';
      case 'camera_unavailable':
        return 'The camera is unavailable. Choose an existing image file instead.';
      default:
        return 'The image could not be selected. Try again or choose a file instead.';
    }
  }
}
