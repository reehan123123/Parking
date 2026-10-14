import 'package:image_picker/image_picker.dart';

import 'parking_photo.dart';

class ParkingPhotoException implements Exception {
  const ParkingPhotoException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ParkingPhotoCodec {
  const ParkingPhotoCodec._();

  static const int maxImageBytes = 10 * 1024 * 1024;
  static const _mimeTypesByExtension = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  static Future<ParkingPhoto> fromXFile(
    XFile file, {
    String? fallbackFileName,
    String? fallbackMimeType,
  }) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw const ParkingPhotoException('The selected image is empty.');
    }

    if (bytes.length > maxImageBytes) {
      throw const ParkingPhotoException('Choose an image smaller than 10 MB.');
    }

    final resolvedMetadata = _resolveMetadata(
      file,
      fallbackFileName: fallbackFileName,
      fallbackMimeType: fallbackMimeType,
    );
    if (resolvedMetadata == null) {
      throw const ParkingPhotoException('Choose a JPEG, PNG, or WebP image.');
    }

    return ParkingPhoto(
      bytes: bytes,
      fileName: resolvedMetadata.fileName,
      mimeType: resolvedMetadata.mimeType,
    );
  }

  static _ResolvedPhotoMetadata? _resolveMetadata(
    XFile file, {
    String? fallbackFileName,
    String? fallbackMimeType,
  }) {
    final mimeType = file.mimeType?.trim().toLowerCase();
    if (mimeType != null && mimeType.isNotEmpty) {
      if (!_mimeTypesByExtension.values.contains(mimeType)) {
        return null;
      }

      return _ResolvedPhotoMetadata(fileName: file.name, mimeType: mimeType);
    }

    final fileName = file.name.toLowerCase();
    final extensionIndex = fileName.lastIndexOf('.');
    if (extensionIndex != -1 && extensionIndex < fileName.length - 1) {
      final extension = fileName.substring(extensionIndex + 1);
      final resolvedMimeType = _mimeTypesByExtension[extension];
      if (resolvedMimeType != null) {
        return _ResolvedPhotoMetadata(
          fileName: file.name,
          mimeType: resolvedMimeType,
        );
      }
    }

    final normalizedFallbackMimeType = fallbackMimeType?.trim().toLowerCase();
    if (fallbackFileName == null ||
        fallbackFileName.isEmpty ||
        normalizedFallbackMimeType == null ||
        !_mimeTypesByExtension.values.contains(normalizedFallbackMimeType)) {
      return null;
    }

    return _ResolvedPhotoMetadata(
      fileName: fallbackFileName,
      mimeType: normalizedFallbackMimeType,
    );
  }
}

class _ResolvedPhotoMetadata {
  const _ResolvedPhotoMetadata({
    required this.fileName,
    required this.mimeType,
  });

  final String fileName;
  final String mimeType;
}
