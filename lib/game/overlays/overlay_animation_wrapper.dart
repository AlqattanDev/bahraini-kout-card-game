import 'dart:math';

import 'package:flutter/material.dart';
import '../theme/kout_theme.dart';
import 'overlay_styles.dart';

/// Wraps overlay content with scale+fade entry/exit animation.
class OverlayAnimationWrapper extends StatefulWidget {
  final Widget child;
  final Duration entryDuration;
  final Duration exitDuration;
  final Curve entryCurve;
  final Curve exitCurve;

  const OverlayAnimationWrapper({
    super.key,
    required this.child,
    this.entryDuration = const Duration(milliseconds: 250),
    this.exitDuration = OverlayStyles.animNormal,
    this.entryCurve = Curves.easeOutBack,
    this.exitCurve = Curves.easeIn,
  });

  @override
  State<OverlayAnimationWrapper> createState() =>
      _OverlayAnimationWrapperState();
}

class _OverlayAnimationWrapperState extends State<OverlayAnimationWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.entryDuration,
      reverseDuration: widget.exitDuration,
    );
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: widget.entryCurve,
        reverseCurve: widget.exitCurve,
      ),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final landscapeScale = isLandscape
        ? min(1.0, MediaQuery.sizeOf(context).height / 500)
        : 1.0;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          color: KoutTheme.table.withValues(
            alpha: _opacityAnimation.value * 0.4,
          ),
          child: SafeArea(
            child: Center(
              child: Transform.scale(
                scale: _scaleAnimation.value * landscapeScale,
                child: Opacity(opacity: _opacityAnimation.value, child: child),
              ),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
