import 'package:flutter/material.dart';

/// Legacy shared color tokens, kept for existing screens.
abstract class HC {
  /// Legacy, kept for existing screens: primary brand green.
  static const primary = Color(0xFF0F8A61);

  /// Legacy, kept for existing screens: bright accent green.
  static const bright = Color(0xFF1A9E6B);

  /// Legacy, kept for existing screens: dark brand green.
  static const dark = Color(0xFF064E3B);

  /// Legacy, kept for existing screens: white background.
  static const bg = Colors.white;

  /// Legacy, kept for existing screens: mint surface color.
  static const mint = Color(0xFFE4F7EF);

  /// Legacy, kept for existing screens: primary text color.
  static const ink = Color(0xFF173B30);

  /// Legacy, kept for existing screens: muted text color.
  static const muted = Color(0xFF6B8178);

  /// Legacy, kept for existing screens: border and divider color.
  static const line = Color(0xFFCBE8DC);

  /// Legacy, kept for existing screens: danger and error color.
  static const danger = Color(0xFFDC2626);

  /// Legacy, kept for existing screens: the existing hero gradient.
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [dark, Color(0xFF0B6B4D), bright],
  );
}

/// Responsive breakpoints for the Student Home layout.
///
/// These constants define the size classes and maximum width of the
/// responsive Home content. They do not change the legacy layout rules.
abstract final class HomeBreakpoints {
  /// Widths below this value are classified as small mobile.
  static const double smallMobileMax = 360.0;

  /// Widths at or above this value are classified as tablet or larger.
  static const double tabletMin = 600.0;

  /// Widths at or above this value are classified as desktop.
  static const double desktopMin = 1024.0;

  /// Maximum outer width of the responsive Home content container.
  static const double maxContentWidth = 1200.0;
}

/// Responsive size classification for the Student Home layout.
///
/// Unlike the legacy [HomeLayout.isTablet] getter, this enum distinguishes
/// tablet and desktop layouts.
enum HomeSize {
  /// Width below 360 logical pixels.
  smallMobile,

  /// Width from 360 logical pixels up to, but not including, 600.
  mobile,

  /// Width from 600 logical pixels up to, but not including, 1024.
  tablet,

  /// Width of 1024 logical pixels or greater.
  desktop,
}

/// Provides an optional, locally measured width for Home layout widgets.
///
/// Place this scope around the Home tab content when its available width
/// differs from the full window width, such as when a NavigationRail is
/// displayed beside the Home content.
///
/// Screens outside this scope continue to use their MediaQuery width.
class HomeLayoutScope extends InheritedWidget {
  /// Creates a scope that supplies the available Home layout width.
  const HomeLayoutScope({
    super.key,
    required this.width,
    required super.child,
  });

  /// The locally available width in logical pixels.
  ///
  /// [HomeLayout.fromWidth] normalizes negative and non-finite values
  /// before using them for layout calculations.
  final double width;

  /// Notifies dependents only when the supplied width changes.
  ///
  /// Two NaN widths are treated as unchanged to avoid unnecessary
  /// notifications when the same invalid value is supplied repeatedly.
  @override
  bool updateShouldNotify(covariant HomeLayoutScope oldWidget) {
    if (oldWidget.width == width) {
      return false;
    }

    if (oldWidget.width.isNaN && width.isNaN) {
      return false;
    }

    return true;
  }

  /// Returns the nearest scoped width and registers an inherited dependency.
  ///
  /// Returns null when no [HomeLayoutScope] exists above [context].
  static double? maybeWidthOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<HomeLayoutScope>()?.width;
  }
}

/// Responsive layout helper for the Student Home screen.
///
/// Existing members are legacy, kept for existing screens. New Home-specific
/// layout code should use [homeContentWidth], [homeHPad], and the other
/// responsive Home helpers instead of changing the legacy layout rules.
class HomeLayout {
  /// Creates a layout helper with an already-normalized width.
  const HomeLayout._(this.width);

  /// The available width in logical pixels.
  ///
  /// Instances created through [HomeLayout.fromWidth] or [HomeLayout.of]
  /// have a finite, non-negative width.
  final double width;

  /// Creates a layout helper using the nearest scoped width when available.
  ///
  /// When no [HomeLayoutScope] exists, falls back to
  /// `MediaQuery.sizeOf(context).width`, preserving existing screen behavior.
  ///
  /// When a scope exists, this factory does not also depend on the
  /// MediaQuery size.
  factory HomeLayout.of(BuildContext context) {
    final scopedWidth = HomeLayoutScope.maybeWidthOf(context);

    if (scopedWidth != null) {
      return HomeLayout.fromWidth(scopedWidth);
    }

    return HomeLayout.fromWidth(MediaQuery.sizeOf(context).width);
  }

  /// Creates a layout helper from a measured width.
  ///
  /// Negative, NaN, and infinite widths are normalized to zero.
  /// Use this factory with a [LayoutBuilder] width when the available
  /// layout width is known locally.
  factory HomeLayout.fromWidth(double width) {
    final normalizedWidth = width.isFinite && width >= 0.0 ? width : 0.0;

    return HomeLayout._(normalizedWidth);
  }

  /// Legacy, kept for existing screens: true when width is below 360.
  bool get isNarrow => width < 360;

  /// Legacy, kept for existing screens: true when width is at least 600.
  ///
  /// This remains true on desktop; use [isDesktop] to identify desktop
  /// layouts separately.
  bool get isTablet => width >= 600;

  /// Legacy, kept for existing screens: caps content width at 640.
  ///
  /// The existing 640-pixel cap is intentionally unchanged.
  double get contentWidth => width > 640 ? 640 : width;

  /// Legacy, kept for existing screens: returns the existing horizontal
  /// padding rule based on [isNarrow] and [isTablet].
  double get hPad => isNarrow ? 14 : (isTablet ? 24 : 18);

  /// Legacy, kept for existing screens: calculates the existing
  /// horizontally scrolling card width using the 640-pixel content cap.
  double cardWidth({double min = 220, double max = 300}) {
    final w = (contentWidth - hPad * 2) * 0.82;
    return w < min ? min : (w > max ? max : w);
  }

  /// Legacy, kept for existing screens: clamps text scaling to the existing
  /// default range of 0.9 to 1.15.
  ///
  /// The optional parameters let responsive Home widgets allow larger text
  /// without disabling system text scaling. Calls using only the two
  /// positional arguments retain the existing default behavior.
  static Widget capText(
    BuildContext context,
    Widget child, {
    double minScale = 0.9,
    double maxScale = 1.15,
  }) {
    final mq = MediaQuery.of(context);

    return MediaQuery(
      data: mq.copyWith(
        textScaler: mq.textScaler.clamp(
          minScaleFactor: minScale,
          maxScaleFactor: maxScale,
        ),
      ),
      child: child,
    );
  }

  /// Returns the responsive size class corresponding to a given width.
  ///
  /// Widths below 360 are small mobile; widths from 360 to below 600
  /// are mobile; widths from 600 to below 1024 are tablet; and widths
  /// of 1024 or greater are desktop.
  static HomeSize sizeForWidth(double width) {
    if (width < HomeBreakpoints.smallMobileMax) {
      return HomeSize.smallMobile;
    }

    if (width < HomeBreakpoints.tabletMin) {
      return HomeSize.mobile;
    }

    if (width < HomeBreakpoints.desktopMin) {
      return HomeSize.tablet;
    }

    return HomeSize.desktop;
  }

  /// The responsive size class for this layout's available width.
  HomeSize get size => sizeForWidth(width);

  /// True when the available width is below 360 logical pixels.
  bool get isSmallMobile => width < HomeBreakpoints.smallMobileMax;

  /// True when the available width is below 600 logical pixels.
  ///
  /// This includes both small-mobile and mobile sizes.
  bool get isMobile => width < HomeBreakpoints.tabletMin;

  /// True when the available width is at least 1024 logical pixels.
  bool get isDesktop => width >= HomeBreakpoints.desktopMin;

  /// Maximum outer width of the responsive Home content container.
  ///
  /// This width includes horizontal padding and never exceeds
  /// [HomeBreakpoints.maxContentWidth].
  double get homeContentWidth {
    return width < HomeBreakpoints.maxContentWidth
        ? width
        : HomeBreakpoints.maxContentWidth;
  }

  /// Horizontal padding for the responsive Home content container.
  ///
  /// Returns 14 for small mobile, 18 for mobile, 24 for tablet,
  /// and 32 for desktop.
  double get homeHPad {
    switch (size) {
      case HomeSize.smallMobile:
        return 14.0;
      case HomeSize.mobile:
        return 18.0;
      case HomeSize.tablet:
        return 24.0;
      case HomeSize.desktop:
        return 32.0;
    }
  }

  /// Usable Home content width after removing horizontal padding.
  ///
  /// Returns zero rather than a negative value if the outer width is
  /// smaller than the combined horizontal padding.
  double get homeInnerWidth {
    final innerWidth = homeContentWidth - homeHPad * 2;
    return innerWidth > 0.0 ? innerWidth : 0.0;
  }

  /// Vertical spacing between Home content sections.
  ///
  /// Returns 20 for small mobile, 24 for mobile, 28 for tablet,
  /// and 32 for desktop.
  double get sectionGap {
    switch (size) {
      case HomeSize.smallMobile:
        return 20.0;
      case HomeSize.mobile:
        return 24.0;
      case HomeSize.tablet:
        return 28.0;
      case HomeSize.desktop:
        return 32.0;
    }
  }

  /// Spacing between cards in responsive Home layouts.
  ///
  /// Returns 10 for small mobile, 12 for mobile, 14 for tablet,
  /// and 16 for desktop.
  double get cardGap {
    switch (size) {
      case HomeSize.smallMobile:
        return 10.0;
      case HomeSize.mobile:
        return 12.0;
      case HomeSize.tablet:
        return 14.0;
      case HomeSize.desktop:
        return 16.0;
    }
  }

  /// Calculates a responsive grid column count.
  ///
  /// Uses `floor((availableWidth + gap) / (minItemWidth + gap))` and
  /// clamps the result to at least one and at most [maxColumns].
  ///
  /// Negative or non-finite available widths are treated as zero.
  /// Invalid gaps are treated as zero. If the minimum item width or
  /// denominator is invalid, returns one. If [maxColumns] is below one,
  /// returns one to honor the minimum-result guarantee.
  static int gridColumns(
    double availableWidth, {
    required double minItemWidth,
    double gap = 12,
    int maxColumns = 4,
  }) {
    if (maxColumns < 1) {
      return 1;
    }

    if (!minItemWidth.isFinite) {
      return 1;
    }

    final safeWidth =
        availableWidth.isFinite && availableWidth > 0.0 ? availableWidth : 0.0;

    final safeGap = gap.isFinite && gap >= 0.0 ? gap : 0.0;
    final denominator = minItemWidth + safeGap;

    if (!denominator.isFinite || denominator <= 0.0) {
      return 1;
    }

    final numerator = safeWidth + safeGap;

    if (!numerator.isFinite) {
      return maxColumns;
    }

    final quotient = numerator / denominator;

    if (!quotient.isFinite) {
      return quotient > 0.0 ? maxColumns : 1;
    }

    if (quotient >= maxColumns) {
      return maxColumns;
    }

    final columns = quotient.floor();
    return columns < 1 ? 1 : columns;
  }

  /// Calculates the width of an item in a grid.
  ///
  /// Uses `(availableWidth - gap * (columns - 1)) / columns` and
  /// never returns a negative width. Invalid or non-positive column
  /// counts return zero instead of dividing by zero.
  static double gridItemWidth(
    double availableWidth,
    int columns, {
    double gap = 12,
  }) {
    if (columns <= 0) {
      return 0.0;
    }

    final safeWidth =
        availableWidth.isFinite && availableWidth > 0.0 ? availableWidth : 0.0;

    final safeGap = gap.isFinite && gap > 0.0 ? gap : 0.0;

    final itemWidth = (safeWidth - safeGap * (columns - 1)) / columns;

    if (!itemWidth.isFinite || itemWidth <= 0.0) {
      return 0.0;
    }

    return itemWidth;
  }

  /// Returns the effective system text scale factor at [context].
  ///
  /// Calculates the scale at 14 logical pixels divided by 14.
  static double textScaleOf(BuildContext context) {
    return MediaQuery.textScalerOf(context).scale(14) / 14;
  }

  /// Calculates a featured event banner's height using its own width.
  ///
  /// Uses a width-to-height ratio of 1.6 below 600 pixels, 2.0 from
  /// 600 to below 1024 pixels, and 2.4 at 1024 pixels or wider.
  ///
  /// The text scale is clamped to 1.0–1.5. The calculated height is
  /// then clamped to the range from `220 * textFactor` to 480 pixels.
  /// Invalid or negative banner widths are treated as zero, and the
  /// lower height bound is never allowed to exceed the upper bound.
  static double featuredBannerHeight(
    double bannerWidth, {
    double textScale = 1.0,
  }) {
    final safeWidth =
        bannerWidth.isFinite && bannerWidth > 0.0 ? bannerWidth : 0.0;

    final safeTextScale = !textScale.isFinite
        ? 1.0
        : (textScale < 1.0 ? 1.0 : (textScale > 1.5 ? 1.5 : textScale));

    final double aspectRatio;

    if (safeWidth < HomeBreakpoints.tabletMin) {
      aspectRatio = 1.6;
    } else if (safeWidth < HomeBreakpoints.desktopMin) {
      aspectRatio = 2.0;
    } else {
      aspectRatio = 2.4;
    }

    final rawHeight = safeWidth / aspectRatio;
    final lowerBound = 220.0 * safeTextScale;
    const upperBound = 480.0;

    // Keep the lower bound within the valid range.
    final effectiveLowerBound =
        lowerBound > upperBound ? upperBound : lowerBound;

    if (rawHeight < effectiveLowerBound) {
      return effectiveLowerBound;
    }

    if (rawHeight > upperBound) {
      return upperBound;
    }

    return rawHeight;
  }
}
