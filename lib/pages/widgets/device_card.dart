// lib/pages/widgets/device_card.dart
import 'package:flutter/material.dart';

class DeviceCard extends StatelessWidget {
  final String title;

  const DeviceCard({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromARGB(255, 70, 135, 170),
            Color.fromARGB(255, 60, 119, 170),
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
