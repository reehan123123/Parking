import 'dart:typed_data';

class ParkingPhoto {
  const ParkingPhoto({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String fileName;
  final String? mimeType;

  int get sizeInBytes => bytes.lengthInBytes;
}
