import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/shared/widgets/parking_brand_title.dart';

void main() {
  testWidgets('shows the logo and title without overflow at common widths', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: const ParkingBrandTitle(title: 'Parking Management'),
            actions: const [SizedBox(width: 48)],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Parking Management'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(
      tester.widget<Image>(find.byType(Image)).excludeFromSemantics,
      isTrue,
    );
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
