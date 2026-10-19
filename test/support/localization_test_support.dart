import 'package:flutter/material.dart';
import 'package:parking_management/core/locale/locale_controller.dart';

const testLocale = Locale('en');

final LocaleController _testLocaleController = LocaleController();

Widget testLocalizationBuilder(BuildContext _, Widget? child) {
  if (child == null) {
    throw StateError('MaterialApp did not build a localization child.');
  }
  return LocaleScope(controller: _testLocaleController, child: child);
}
