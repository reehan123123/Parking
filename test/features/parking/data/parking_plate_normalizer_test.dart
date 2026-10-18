import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/parking/data/parking_plate_normalizer.dart';

void main() {
  test('trims and uppercases manual registration input', () {
    expect(ParkingPlateNormalizer.normalize('  ab 123  '), 'AB 123');
  });

  test('does not guess or rewrite registration characters', () {
    expect(ParkingPlateNormalizer.normalize('mh43-br 2323'), 'MH43-BR 2323');
  });
}
