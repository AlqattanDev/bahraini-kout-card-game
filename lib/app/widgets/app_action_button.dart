import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../game/theme/kout_theme.dart';

double appButtonWidth(
  BuildContext context, {
  double maxWidth = 220,
  double screenFactor = 0.6,
}) {
  return math.min(maxWidth, MediaQuery.sizeOf(context).width * screenFactor);
}

VoidCallback withLightHaptic(VoidCallback action) {
  return () {
    HapticFeedback.lightImpact();
    action();
  };
}

class AppPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final double? width;
  final double? height;
  final TextStyle? textStyle;

  const AppPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.width,
    this.height,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    Widget button = ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: KoutTheme.primary,
        foregroundColor: KoutTheme.accent,
        disabledBackgroundColor: KoutTheme.primary.withValues(alpha: 0.5),
        disabledForegroundColor: KoutTheme.accent.withValues(alpha: 0.3),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: onPressed != null
                ? KoutTheme.accent
                : KoutTheme.accent.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        textStyle: KoutTheme.bodyStyle.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      child: Text(label, style: textStyle),
    );

    if (width != null || height != null) {
      return SizedBox(width: width, height: height, child: button);
    }
    return button;
  }
}

class AppSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final double? width;
  final double? height;
  final bool withBorder;

  const AppSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.width,
    this.height,
    this.withBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget button = TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(foregroundColor: KoutTheme.cream),
      child: Text(label),
    );

    if (withBorder) {
      button = Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          border: Border.all(color: KoutTheme.goldAccent),
          borderRadius: BorderRadius.circular(12),
        ),
        child: button,
      );
    } else if (width != null || height != null) {
      button = SizedBox(width: width, height: height, child: button);
    }

    return button;
  }
}
