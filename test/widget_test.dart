import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parking_management/app.dart';
import 'package:parking_management/shared/widgets/empty_state_view.dart';
import 'package:parking_management/shared/widgets/error_state_view.dart';
import 'package:parking_management/shared/widgets/loading_view.dart';

void main() {
  testWidgets('renders the dashboard shell', (WidgetTester tester) async {
    await tester.pumpWidget(const ParkingManagementApp());

    expect(find.text('Parking Management'), findsOneWidget);
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Your parking overview will appear here'), findsOneWidget);
  });

  testWidgets('navigates between placeholder destinations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ParkingManagementApp());

    await tester.tap(find.text('History').last);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Historical parking sessions will be available after Supabase integration.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders the narrow-screen navigation bar', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(480, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ParkingManagementApp());

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('renders the wide-screen navigation rail', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ParkingManagementApp());

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('renders reusable loading empty and error states', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            LoadingView(message: 'Loading sessions'),
            EmptyStateView(title: 'No sessions', message: 'Nothing to show'),
            ErrorStateView(message: 'The connection failed'),
          ],
        ),
      ),
    );

    expect(find.text('Loading sessions'), findsOneWidget);
    expect(find.text('No sessions'), findsOneWidget);
    expect(find.text('The connection failed'), findsOneWidget);
    expect(find.text('Something went wrong'), findsOneWidget);
  });
}
