import 'package:flutter/material.dart';
import '../../game/theme/kout_theme.dart';

extension AppSnackbarX on BuildContext {
  void showInfoSnack(String message, {Duration? duration}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration ?? const Duration(seconds: 2),
      ),
    );
  }

  void showErrorSnack(String message, {Duration? duration}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: KoutTheme.lossColor,
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }
}
