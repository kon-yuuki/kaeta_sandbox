import 'package:flutter/material.dart';

class AppActionIcon extends StatelessWidget {
  const AppActionIcon._({
    super.key,
    required this.assetPath,
    required this.size,
    this.color,
    this.semanticLabel,
  });

  const AppActionIcon.pen({
    Key? key,
    double size = 20,
    Color? color,
    String? semanticLabel,
  }) : this._(
         key: key,
         assetPath: 'assets/icons/pen.png',
         size: size,
         color: color,
         semanticLabel: semanticLabel,
       );

  const AppActionIcon.trash({
    Key? key,
    double size = 20,
    Color? color,
    String? semanticLabel,
  }) : this._(
         key: key,
         assetPath: 'assets/icons/trash.png',
         size: size,
         color: color,
         semanticLabel: semanticLabel,
       );

  final String assetPath;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      color: color,
      semanticLabel: semanticLabel,
    );
  }
}
