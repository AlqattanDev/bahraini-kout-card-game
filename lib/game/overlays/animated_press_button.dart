import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'overlay_styles.dart';

class AnimatedPressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final double pressScale;

  const AnimatedPressButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.pressScale = 0.92,
  });

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
    HapticFeedback.selectionClick();
    setState(() => _isPressed = false);

    // Give time for the release animation to start
    Future.delayed(OverlayStyles.animFast, () {
      if (mounted) {
        widget.onPressed();
      }
    });
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
        duration: OverlayStyles.animFast,
        curve: Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}
