import 'package:flutter/material.dart';

class DashboardCard extends StatelessWidget {
  final String title;
  final Widget child;
  final double? width;
  final double? height; // ✅ height sekarang opsional, bisa disesuaikan per card

  const DashboardCard({
    super.key,
    required this.title,
    required this.child,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ Responsif: jika width null, ikuti lebar parent
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = width ?? (screenWidth < 800 ? screenWidth - 64 : 360);

    return Container(
      width: cardWidth,
      height: height, // null = wrap content (shrinkWrap)
      constraints: BoxConstraints(
        minHeight: 200,
        maxHeight: height ?? 450,
      ),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Flexible(
            child: child,
          ),
        ],
      ),
    );
  }
}
