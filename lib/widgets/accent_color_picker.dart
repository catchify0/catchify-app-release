/*
 *     Copyright (C) 2026 Thamodharan Ganesan
 *
 *     Catchify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Catchify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Catchify, including how to contribute,
 *     please visit: https://github.com/catchify0/catchify0.github.io
 */

import 'dart:math';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:catchify/theme/app_colors.dart';

class AccentColorPickerSheet extends StatelessWidget {
  const AccentColorPickerSheet({
    super.key,
    required this.initialColor,
    required this.onColorSelected,
  });

  final Color initialColor;
  final ValueChanged<Color> onColorSelected;

  bool get _isCustomActive => !curatedAccentColors.any(
    (item) => item.color.toARGB32() == initialColor.toARGB32(),
  );

  void _openRoundedColorWheel(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => _RoundedColorWheelDialog(
        initialColor: initialColor,
        onColorApplied: (color) {
          Navigator.pop(dialogContext);
          onColorSelected(color);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Header (No Hex Code, purely clean) ───────────────────────────
          Row(
            children: [
              Icon(FluentIcons.color_24_filled, color: initialColor, size: 22),
              const SizedBox(width: 8),
              Text(
                'Accent color',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ─── 12 Curated Colors Grid (6 Columns × 2 Rows) ─────────────────
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemCount: curatedAccentColors.length,
            itemBuilder: (context, index) {
              final item = curatedAccentColors[index];
              final isSelected =
                  item.color.toARGB32() == initialColor.toARGB32();

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onColorSelected(item.color);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: item.color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: colorScheme.onSurface, width: 3)
                        : Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: item.color.withValues(alpha: 0.45),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? Icon(
                          FluentIcons.checkmark_20_filled,
                          color: item.color.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                          size: 20,
                        )
                      : null,
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // ─── Rounded Custom Color Palette Action ─────────────────────────
          GestureDetector(
            onTap: () => _openRoundedColorWheel(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _isCustomActive
                    ? initialColor.withValues(alpha: 0.15)
                    : colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.45,
                      ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isCustomActive
                      ? initialColor
                      : colorScheme.outlineVariant.withValues(alpha: 0.4),
                  width: _isCustomActive ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          Color(0xFFFF0000),
                          Color(0xFFFFFF00),
                          Color(0xFF00FF00),
                          Color(0xFF00FFFF),
                          Color(0xFF0000FF),
                          Color(0xFFFF00FF),
                          Color(0xFFFF0000),
                        ],
                      ),
                    ),
                    child: _isCustomActive
                        ? const Icon(
                            FluentIcons.checkmark_16_filled,
                            color: Colors.white,
                            size: 14,
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Custom Color Palette',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Interactive Rounded Color Wheel Palette
// ─────────────────────────────────────────────────────────────────────────────

class _RoundedColorWheelDialog extends StatefulWidget {
  const _RoundedColorWheelDialog({
    required this.initialColor,
    required this.onColorApplied,
  });

  final Color initialColor;
  final ValueChanged<Color> onColorApplied;

  @override
  State<_RoundedColorWheelDialog> createState() =>
      _RoundedColorWheelDialogState();
}

class _RoundedColorWheelDialogState extends State<_RoundedColorWheelDialog> {
  late Color _currentColor;
  late double _angle;
  late double _radiusRatio;

  static const double _wheelDiameter = 210;

  @override
  void initState() {
    super.initState();
    _currentColor = widget.initialColor;

    final hsv = HSVColor.fromColor(widget.initialColor);
    _angle = hsv.hue * pi / 180;
    _radiusRatio = hsv.saturation.clamp(0.1, 0.95);
  }

  void _updateColorFromOffset(Offset localPosition, double radius) {
    final dx = localPosition.dx - radius;
    final dy = localPosition.dy - radius;
    final dist = sqrt(dx * dx + dy * dy);
    final angle = atan2(dy, dx);

    final ratio = (dist / radius).clamp(0.0, 0.95);
    final hue = (angle * 180 / pi + 360) % 360;

    setState(() {
      _angle = angle;
      _radiusRatio = ratio;
      _currentColor = HSVColor.fromAHSV(1, hue, ratio, 0.95).toColor();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onColor = _currentColor.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      title: Text(
        'Color Palette',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── Circular Wheel Canvas ─────────────────────────────────────────
          SizedBox(
            width: _wheelDiameter,
            height: _wheelDiameter,
            child: GestureDetector(
              onPanStart: (details) => _updateColorFromOffset(
                details.localPosition,
                _wheelDiameter / 2,
              ),
              onPanUpdate: (details) => _updateColorFromOffset(
                details.localPosition,
                _wheelDiameter / 2,
              ),
              onTapDown: (details) => _updateColorFromOffset(
                details.localPosition,
                _wheelDiameter / 2,
              ),
              child: CustomPaint(
                painter: _ColorWheelPainter(
                  thumbAngle: _angle,
                  thumbRadiusRatio: _radiusRatio,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── Live Selected Color Indicator ─────────────────────────────────
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _currentColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.6),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _currentColor.withValues(alpha: 0.4),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
        FilledButton(
          onPressed: () => widget.onColorApplied(_currentColor),
          style: FilledButton.styleFrom(
            backgroundColor: _currentColor,
            foregroundColor: onColor,
          ),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class _ColorWheelPainter extends CustomPainter {
  _ColorWheelPainter({
    required this.thumbAngle,
    required this.thumbRadiusRatio,
  });

  final double thumbAngle;
  final double thumbRadiusRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Hue sweep gradient around circle
    const sweepGradient = SweepGradient(
      colors: [
        Color(0xFFFF0000), // 0°
        Color(0xFFFFFF00), // 60°
        Color(0xFF00FF00), // 120°
        Color(0xFF00FFFF), // 180°
        Color(0xFF0000FF), // 240°
        Color(0xFFFF00FF), // 300°
        Color(0xFFFF0000), // 360°
      ],
    );

    final huePaint = Paint()
      ..shader = sweepGradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, huePaint);

    // 2. Radial gradient overlay (center white, edge transparent)
    final radialPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, Colors.white.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, radialPaint);

    // 3. Thumb position
    final thumbDist = radius * thumbRadiusRatio.clamp(0.0, 0.95);
    final thumbOffset = Offset(
      center.dx + thumbDist * cos(thumbAngle),
      center.dy + thumbDist * sin(thumbAngle),
    );

    // Thumb outer ring
    canvas
      ..drawCircle(
        thumbOffset,
        10,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      )
      ..drawCircle(
        thumbOffset,
        8,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
  }

  @override
  bool shouldRepaint(covariant _ColorWheelPainter oldDelegate) =>
      oldDelegate.thumbAngle != thumbAngle ||
      oldDelegate.thumbRadiusRatio != thumbRadiusRatio;
}
