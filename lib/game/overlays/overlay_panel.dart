import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../game/theme/kout_theme.dart';
import 'overlay_animation_wrapper.dart';
import 'overlay_styles.dart';

class OverlayPanel extends StatelessWidget {
  final String title;
  final TextStyle? titleStyle;
  final Widget content;
  final Widget? subtitle;
  final List<Widget>? actions;
  final BoxConstraints? constraints;
  final EdgeInsets? padding;
  final BoxDecoration? decoration;

  const OverlayPanel({
    super.key,
    required this.title,
    this.titleStyle,
    required this.content,
    this.subtitle,
    this.actions,
    this.constraints,
    this.padding,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final screenH = MediaQuery.sizeOf(context).height;
    final maxPanelW = math.max(0.0, screenW - 24);
    final maxPanelH = screenH * 0.92;

    BoxConstraints effective = constraints ?? const BoxConstraints();
    final capW = math.min(
      effective.maxWidth.isFinite ? effective.maxWidth : maxPanelW,
      maxPanelW,
    );
    final minW = math.min(effective.minWidth, capW);
    effective = effective.copyWith(
      minWidth: minW,
      maxWidth: capW,
      maxHeight: maxPanelH,
    );

    return OverlayAnimationWrapper(
      child: Container(
        constraints: effective,
        padding: padding ?? OverlayStyles.panelPadding,
        decoration: decoration ?? OverlayStyles.panelDecoration(),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style:
                    titleStyle ??
                    KoutTheme.headingStyle.copyWith(
                      color: KoutTheme.accent,
                      fontSize: 18,
                    ),
              ),
              if (subtitle != null) ...[const SizedBox(height: 8), subtitle!],
              OverlayStyles.sectionGap,
              content,
              if (actions != null && actions!.isNotEmpty) ...[
                const SizedBox(height: 16),
                ...actions!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
