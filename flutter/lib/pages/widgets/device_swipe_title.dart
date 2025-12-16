import 'package:flutter/material.dart';

class DeviceSwipeTile extends StatelessWidget {
  final String deviceName;
  final bool isOpen;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  // ✅ new
  final Widget? badge;

  const DeviceSwipeTile({
    super.key,
    required this.deviceName,
    required this.isOpen,
    required this.onOpen,
    required this.onClose,
    required this.onEdit,
    required this.onDelete,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    const double actionWidth = 56 * 2 + 16;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v < -50) onOpen();
        if (v > 50) onClose();
      },
      child: SizedBox(
        height: 56,
        child: Stack(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 8),
                  _btn(
                    icon: Icons.edit,
                    color: const Color(0xFF4C6FEA),
                    onTap: onEdit,
                  ),
                  const SizedBox(width: 8),
                  _btn(
                    icon: Icons.delete,
                    color: const Color(0xFFE43F3F),
                    onTap: onDelete,
                  ),
                ],
              ),
            ),

            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              left: 0,
              right: isOpen ? actionWidth : 0,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.fromARGB(255, 70, 135, 170),
                      Color.fromARGB(255, 60, 119, 170),
                    ],
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        deviceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (badge != null) ...[const SizedBox(width: 10), badge!],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _btn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 56,
      height: 56,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: color,
          child: InkWell(
            onTap: onTap,
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}
