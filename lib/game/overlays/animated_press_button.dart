import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'overlay_styles.dart';
import 'overlay_utils.dart';

class AnimatedPressButton extends StatefulWidget {
  final Widget? child;
  final Widget Function(BuildContext context, bool isPressed)? builder;
  final VoidCallback onPressed;
  final double pressScale;
  final Future<void> Function()? hapticFeedback;
  final Duration? animationDuration;
  final Duration? delayDuration;

  const AnimatedPressButton({
    super.key,
    this.child,
    this.builder,
    required this.onPressed,
    this.pressScale = 0.92,
    this.hapticFeedback,
    this.animationDuration,
    this.delayDuration,
  }) : assert(
         child != null || builder != null,
         'Either child or builder must be provided.',
       );

  @override
  State<AnimatedPressButton> createState() => _AnimatedPressButtonState();
}

class _AnimatedPressButtonState extends State<AnimatedPressButton> {
  bool _isPressed = false;
  bool _hasTriggered = false;

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    if (_hasTriggered) return;
    _hasTriggered = true;
    if (widget.hapticFeedback != null) {
      widget.hapticFeedback!();
    } else {
      HapticFeedback.selectionClick();
    }
    setState(() => _isPressed = false);

    // Give time for the release animation to start
    delayIfMounted(
      this,
      widget.delayDuration ?? OverlayStyles.animFast,
      widget.onPressed,
    );
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedScale(
        scale: _isPressed ? widget.pressScale : 1.0,
        duration: widget.animationDuration ?? OverlayStyles.animFast,
        curve: Curves.easeOutBack,
        child: widget.builder != null
            ? widget.builder!(context, _isPressed)
            : widget.child,
      ),
    );
  }
}
