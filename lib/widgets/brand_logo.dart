import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    required this.logoUrl,
    this.size = 76,
  });

  final String? logoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = logoUrl?.trim() ?? '';
    if (url.isEmpty) {
      return Icon(
        Icons.shopping_bag_outlined,
        size: size,
        color: Theme.of(context).colorScheme.primary,
      );
    }

    return SizedBox(
      width: size * 2.2,
      height: size,
      child: Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          Icons.shopping_bag_outlined,
          size: size,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
