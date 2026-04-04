import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;
import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock iPhone to landscape. iPad/macOS/other: unrestricted.
  if (Platform.isIOS) {
    // Use shortestSide heuristic at startup — phones < 500, tablets >= 500.
    // This runs before the first frame, so we use the physical size.
    final physicalSize = PlatformDispatcher.instance.views.first.physicalSize;
    final devicePixelRatio = PlatformDispatcher.instance.views.first.devicePixelRatio;
    final shortestSide = (physicalSize.shortestSide / devicePixelRatio);
    if (shortestSide < 500) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  runApp(const KoutApp());
}
