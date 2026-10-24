import 'package:flutter/material.dart';

/// Shows the parking logo next to the localized app title.
class ParkingBrandTitle extends StatelessWidget {
  const ParkingBrandTitle({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          'assets/branding/parking-icon.png',
          width: 24,
          height: 24,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
