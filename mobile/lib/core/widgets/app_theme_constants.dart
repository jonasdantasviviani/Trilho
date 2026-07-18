import 'package:flutter/material.dart';

const Duration kAnimFast   = Duration(milliseconds: 200);
const Duration kAnimNormal = Duration(milliseconds: 350);

/// Wraps [child] in an [AnimatedSwitcher] with a fade transition.
/// Use this to animate state changes (loading → data, data → error, etc.).
Widget fadeSwitch(Widget child) {
  return AnimatedSwitcher(
    duration: kAnimNormal,
    transitionBuilder: (child, animation) =>
        FadeTransition(opacity: animation, child: child),
    child: child,
  );
}
