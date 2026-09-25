import 'package:flutter/material.dart';

class CatchifyBrandIcon extends StatelessWidget {
  const CatchifyBrandIcon({
    super.key,
    required this.size,
    this.color,
    this.fit = BoxFit.contain,
    this.semanticLabel,
  });

  static const _asset = 'assets/icons/catchify_icon.png';
  static const _innerMaskAsset = 'assets/icons/catchify_icon_inner_mask.png';

  final double size;
  final Color? color;
  final BoxFit fit;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final noteColor = color ?? Theme.of(context).colorScheme.primary;

    return Semantics(
      image: semanticLabel != null,
      label: semanticLabel,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(_asset, fit: fit, excludeFromSemantics: true),
            Image.asset(
              _innerMaskAsset,
              fit: fit,
              color: noteColor,
              colorBlendMode: BlendMode.srcIn,
              excludeFromSemantics: true,
            ),
          ],
        ),
      ),
    );
  }
}
