import 'package:flutter/material.dart';

/// Colors shared by the new Home widgets.
abstract class HC {
  static const primary = Color(0xFF0F8A61);
  static const bright = Color(0xFF1A9E6B);
  static const dark = Color(0xFF064E3B);
  static const bg = Colors.white;
  static const mint = Color(0xFFE4F7EF);
  static const ink = Color(0xFF173B30);
  static const muted = Color(0xFF6B8178);
  static const line = Color(0xFFCBE8DC);
  static const danger = Color(0xFFDC2626);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [dark, Color(0xFF0B6B4D), bright],
  );
}

/// Responsive helper: build it once per widget with HomeLayout.of(context).
class HomeLayout {
  final double width;
  const HomeLayout._(this.width);

  factory HomeLayout.of(BuildContext context) =>
      HomeLayout._(MediaQuery.sizeOf(context).width);

  bool get isNarrow => width < 360;
  bool get isTablet => width >= 600;

  /// Page content never gets wider than this (keeps tablets tidy).
  double get contentWidth => width > 640 ? 640 : width;

  /// Side padding that grows slightly with screen width.
  double get hPad => isNarrow ? 14 : (isTablet ? 24 : 18);

  /// Width of horizontally scrolling cards (about 1.15 cards visible).
  double cardWidth({double min = 220, double max = 300}) {
    final w = (contentWidth - hPad * 2) * 0.82;
    return w < min ? min : (w > max ? max : w);
  }

  /// Caps system font scaling so large-text users don't break layouts.
  static Widget capText(BuildContext context, Widget child) {
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(
        textScaler: mq.textScaler.clamp(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.15,
        ),
      ),
      child: child,
    );
  }
}
