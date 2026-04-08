import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void delayIfMounted(State state, Duration duration, VoidCallback callback) {
  Future.delayed(duration, () {
    if (state.mounted) {
      callback();
    }
  });
}

class OneShotHapticAction {
  bool _hasRun = false;

  void run(VoidCallback action) {
    if (_hasRun) return;
    _hasRun = true;
    HapticFeedback.mediumImpact();
    action();
  }
}
