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

  const OverlayPanel({
    super.key,
    required this.title,
    this.titleStyle,
    required this.content,
    this.subtitle,
    this.actions,
    this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    return OverlayAnimationWrapper(
      child: Container(
        constraints: constraints,
        padding: OverlayStyles.panelPadding,
        decoration: OverlayStyles.panelDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
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
    );
  }
}
