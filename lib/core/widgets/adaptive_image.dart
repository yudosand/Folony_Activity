import 'dart:io';

import 'package:flutter/material.dart';

class AdaptiveImage extends StatelessWidget {
  const AdaptiveImage({
    super.key,
    required this.path,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String path;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final image = _isRemote(path)
        ? Image.network(
            path,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => _fallback(),
          )
        : Image.file(
            File(path),
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => _fallback(),
          );

    if (borderRadius == null) {
      return image;
    }

    return ClipRRect(
      borderRadius: borderRadius!,
      child: image,
    );
  }

  Widget _fallback() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFF5F5F4),
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported_rounded),
    );
  }

  bool _isRemote(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }
}
