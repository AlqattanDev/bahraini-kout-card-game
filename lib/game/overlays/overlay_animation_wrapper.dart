import 'package:flutter/material.dart';

/// Wraps overlay content with scale+fade entry/exit animation.
class OverlayAnimationWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onDismissed;
  final Duration entryDuration;
  final Duration exitDuration;
  final Curve entryCurve;
  final Curve exitCurve;

  const OverlayAnimationWrapper({
    super.key,
    required this.child,
    this.onDismissed,
    this.entryDuration = const Duration(milliseconds: 250),
    this.exitDuration = const Duration(milliseconds: 150),
    this.entryCurve = Curves.easeOutBack,
    this.exitCurve = Curves.easeIn,
  });

  @override
  State<OverlayAnimationWrapper> createState() =>
      OverlayAnimationWrapperState();
}

class OverlayAnimationWrapperState extends State<OverlayAnimationWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;
  bool _dismissing = false;

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

  /// Call this to play the exit animation, then remove the overlay.
  Future<void> dismiss() async {
    if (_dismissing) return;
    _dismissing = true;
    await _controller.reverse();
    widget.onDismissed?.call();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final landscapeScale = isLandscape ? 0.75 : 1.0;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          color: Colors.black.withValues(alpha: _opacityAnimation.value * 0.4),
          child: SafeArea(
            child: Center(
              child: Transform.scale(
                scale: _scaleAnimation.value * landscapeScale,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
