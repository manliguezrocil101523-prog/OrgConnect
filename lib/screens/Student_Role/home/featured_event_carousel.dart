import 'home_time_format.dart';
import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart' hide Notification;

import '../../../core/app_state.dart';
import 'home_event_utils.dart';
import 'home_tokens.dart';

// ---------------------------------------------------------------------------
// VISUAL TUNING (safe to change, nothing else depends on these)
// ---------------------------------------------------------------------------

/// How much of the screen width each card takes. Below 1.0 the next card
/// "peeks" in from the side so people know they can swipe.
/// Set to 1.0 to go back to a single full-width card with no peek.
const double _kViewportFraction = 1.0;

/// Space on each side of a card inside its page (creates the gap between
/// neighbouring cards while swiping).
const double _kPageGap = 0;

/// How strongly the poster behind the card is blurred.
const double _kBackdropBlur = 22;

/// Presents up to five campus events in an autoplaying responsive banner.
class FeaturedEventCarousel extends StatefulWidget {
  const FeaturedEventCarousel({
    super.key,
    required this.events,
    required this.onViewDetails,
  });

  final List<Event> events;
  final void Function(Event) onViewDetails;

  @override
  State<FeaturedEventCarousel> createState() => _FeaturedEventCarouselState();
}

class _FeaturedEventCarouselState extends State<FeaturedEventCarousel> {
  final PageController _pageController =
      PageController(viewportFraction: _kViewportFraction);

  Timer? _autoplayTimer;
  DateTime? _pauseAutoplayUntil;

  int _currentPage = 0;
  bool _animationsDisabled = false;

  /// Limits the carousel to the first five supplied events.
  List<Event> get _events => widget.events.take(5).toList(growable: false);

  // ------------------------------------------------------------------------
  // LIFECYCLE AND AUTOPLAY
  // ------------------------------------------------------------------------

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _animationsDisabled = MediaQuery.of(context).disableAnimations;
    _syncAutoplayTimer();
  }

  @override
  void didUpdateWidget(covariant FeaturedEventCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);

    final eventCount = _events.length;
    final oldCount = oldWidget.events.length > 5 ? 5 : oldWidget.events.length;

    // Parent rebuilds with the same number of events need no page jump.
    if (eventCount == oldCount) return;

    if (eventCount == 0) {
      _currentPage = 0;
    } else if (_currentPage >= eventCount) {
      _currentPage = eventCount - 1;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients) {
        _pageController.jumpToPage(_currentPage);
      }
    });

    _syncAutoplayTimer();
  }

  /// Starts autoplay only when permitted and makes repeated calls idempotent.
  void _syncAutoplayTimer() {
    if (_animationsDisabled || _events.length < 2) {
      _autoplayTimer?.cancel();
      _autoplayTimer = null;
      return;
    }

    if (_autoplayTimer != null) {
      return;
    }

    _autoplayTimer = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _advancePage(),
    );
  }

  /// Suspends autoplay for ten seconds after user interaction.
  void _pauseAutoplay() {
    _pauseAutoplayUntil = DateTime.now().add(const Duration(seconds: 10));
  }

  /// Advances automatically, respecting lifecycle, reduced motion and pauses.
  void _advancePage() {
    if (!mounted ||
        _animationsDisabled ||
        _events.length < 2 ||
        !_pageController.hasClients) {
      return;
    }

    final pausedUntil = _pauseAutoplayUntil;
    if (pausedUntil != null && DateTime.now().isBefore(pausedUntil)) {
      return;
    }

    final nextPage = (_currentPage + 1) % _events.length;

    _pageController.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  /// Moves to an adjacent event with wrap-around and reduced-motion support.
  void _movePage(int direction) {
    _pauseAutoplay();

    if (!mounted || !_pageController.hasClients || _events.length < 2) {
      return;
    }

    final targetPage =
        (_currentPage + direction + _events.length) % _events.length;

    if (_animationsDisabled) {
      _pageController.jumpToPage(targetPage);
    } else {
      _pageController.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  // ------------------------------------------------------------------------
  // RESPONSIVE BANNER
  // ------------------------------------------------------------------------

  /// Builds the poster, gradients, metadata and bottom-aligned controls.
  Widget _buildBanner(
    BuildContext context,
    Event event,
    double width,
    double height,
    HomeSize size,
    double textScale,
  ) {
    final cover = eventCoverImage(event);

    final isCompact = width < HomeBreakpoints.tabletMin;
    final isWide = !isCompact;
    final isDesktop = width >= HomeBreakpoints.desktopMin;

    // The content block's outer padding is accounted for separately below.
    final double horizontalPadding;
    final double verticalPadding;
    final double badgeFontSize;
    final double badgeIconSize;
    final double titleFontSize;
    final double metaFontSize;
    final double metaIconSize;
    final double buttonFontSize;

    switch (size) {
      case HomeSize.smallMobile:
        horizontalPadding = 14;
        verticalPadding = 14;
        badgeFontSize = 9;
        badgeIconSize = 10;
        titleFontSize = 18;
        metaFontSize = 10;
        metaIconSize = 12;
        buttonFontSize = 12;
        break;

      case HomeSize.mobile:
        horizontalPadding = 16;
        verticalPadding = 14;
        badgeFontSize = 9;
        badgeIconSize = 10;
        titleFontSize = 19;
        metaFontSize = 10.5;
        metaIconSize = 12;
        buttonFontSize = 12;
        break;

      case HomeSize.tablet:
        horizontalPadding = 22;
        verticalPadding = 20;
        badgeFontSize = 10;
        badgeIconSize = 11;
        titleFontSize = 24;
        metaFontSize = 12;
        metaIconSize = 14;
        buttonFontSize = 13;
        break;

      case HomeSize.desktop:
        horizontalPadding = 32;
        verticalPadding = 28;
        badgeFontSize = 11;
        badgeIconSize = 12;
        titleFontSize = 30;
        metaFontSize = 13.5;
        metaIconSize = 15;
        buttonFontSize = 14;
        break;
    }

    final availableInnerWidth =
        width > horizontalPadding * 2 ? width - horizontalPadding * 2 : 0.0;

    // Wide banners reserve the right side for the event poster.
    final desiredTextBlockWidth = isWide
        ? (width * 0.62 < 640.0 ? width * 0.62 : 640.0)
        : availableInnerWidth;

    final textBlockWidth = desiredTextBlockWidth < availableInnerWidth
        ? desiredTextBlockWidth
        : availableInnerWidth;

    // Compact cards can fit metadata items alongside one another when their
    // labels are short. Wide cards give every item the text block's width.
    final metaMaxWidth =
        isCompact ? availableInnerWidth * 0.60 : textBlockWidth;

    final metaItems = <Widget>[
      _FeaturedMetaItem(
        icon: Icons.calendar_month_outlined,
        label: formatDateShort(event.date),
        maxWidth: metaMaxWidth,
        fontSize: metaFontSize,
        iconSize: metaIconSize,
        filled: true,
      ),
      if (event.timeLabel.trim().isNotEmpty)
        _FeaturedMetaItem(
          icon: Icons.schedule_rounded,
          label: formatTimeLabel12h(event.timeLabel),
          maxWidth: metaMaxWidth,
          fontSize: metaFontSize,
          iconSize: metaIconSize,
        ),
      if (event.venue.trim().isNotEmpty)
        _FeaturedMetaItem(
          icon: Icons.location_on_outlined,
          label: event.venue.trim(),
          maxWidth: metaMaxWidth,
          fontSize: metaFontSize,
          iconSize: metaIconSize,
        ),
    ];

    final badge = Container(
      constraints: BoxConstraints(
        maxWidth: textBlockWidth < 160 ? textBlockWidth : 160,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.40),
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.auto_awesome_rounded,
            size: badgeIconSize,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'FEATURED EVENT',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: badgeFontSize,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );

    final detailsButton = ElevatedButton(
      onPressed: () => widget.onViewDetails(event),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: HC.dark,
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.35),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        minimumSize: const Size(0, 44),
        tapTargetSize: MaterialTapTargetSize.padded,
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'View Details',
            style: TextStyle(
              fontSize: buttonFontSize,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 5),
          const Icon(Icons.arrow_forward_rounded, size: 15),
        ],
      ),
    );

    final Widget? controls = _events.length > 1
        ? _buildControlPill(
            width: width,
          )
        : null;

    // The control width is bounded and known from the number of dots and
    // whether wide-banner arrow buttons are present.
    final dotContentWidth = 16.0 + 9.0 * (_events.length - 1);
    final showArrows = isWide && _events.length > 1;
    final controlsWidth = _events.length <= 1
        ? 0.0
        : dotContentWidth + (showArrows ? 96.0 : 16.0);

    final safeTextScale =
        textScale.isFinite && textScale > 1.0 ? textScale : 1.0;

    // At narrow widths or increased text scale, place controls on a separate
    // line if the action row would be too tight.
    final actionRow = LayoutBuilder(
      builder: (context, actionConstraints) {
        if (controls == null) {
          return Align(
            alignment: Alignment.centerLeft,
            child: detailsButton,
          );
        }

        final estimatedButtonWidth = 128.0 * safeTextScale;
        final requiredRowWidth = estimatedButtonWidth + 8.0 + controlsWidth;

        if (actionConstraints.maxWidth < requiredRowWidth) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: detailsButton,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: controls,
              ),
            ],
          );
        }

        return Row(
          children: <Widget>[
            Flexible(
              fit: FlexFit.loose,
              child: Align(
                alignment: Alignment.centerLeft,
                child: detailsButton,
              ),
            ),
            const SizedBox(width: 8),
            controls,
          ],
        );
      },
    );

    final bottomContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          event.title,
          maxLines: isDesktop ? 3 : 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: titleFontSize,
            height: 1.12,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: metaItems,
        ),
        const SizedBox(height: 10),
        actionRow,
      ],
    );

    return Semantics(
      button: true,
      label: 'Featured event: ${event.title}, button',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onViewDetails(event),
          borderRadius: BorderRadius.circular(22),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  // 1. Brand gradient base, visible when no usable poster exists.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: HC.heroGradient,
                    ),
                  ),

                  // 2. Full-banner poster.
                  if (cover != null)
                    Positioned.fill(
                      child: EventImage(
                        url: cover,
                        fit: BoxFit.cover,
                        fallback: const SizedBox.shrink(),
                      ),
                    )
                  else
                    Positioned(
                      top: 0,
                      bottom: 0,
                      right: 22,
                      child: Center(
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          size: height * 0.55,
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                    ),

                  // 3. Existing top-to-bottom fade.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const <double>[0.0, 0.40, 1.0],
                            colors: <Color>[
                              Colors.black.withValues(alpha: 0.25),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.80),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 4. Additional left-side contrast on wide and desktop cards.
                  if (isWide)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              stops: const <double>[0.0, 0.60, 1.0],
                              colors: <Color>[
                                Colors.black.withValues(alpha: 0.45),
                                Colors.transparent,
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // 5. The text block keeps a width limit and full available
                  // height. The badge remains near the top-left; the title,
                  // metadata and actions are anchored at the bottom-left.
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: verticalPadding,
                      ),
                      child: LayoutBuilder(
                        builder: (context, contentConstraints) {
                          final blockWidth =
                              textBlockWidth < contentConstraints.maxWidth
                                  ? textBlockWidth
                                  : contentConstraints.maxWidth;

                          return Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: blockWidth,
                              height: contentConstraints.maxHeight,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Align(
                                    alignment: Alignment.topLeft,
                                    child: badge,
                                  ),
                                  const Spacer(),
                                  bottomContent,
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // 6. Hairline inner border.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the event indicator and, for wide banners, navigation arrows.
  Widget _buildControlPill({
    required double width,
  }) {
    final showArrows = width >= HomeBreakpoints.tabletMin && _events.length > 1;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showArrows ? 4 : 8,
        vertical: showArrows ? 3 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (showArrows)
            _buildArrowButton(
              icon: Icons.chevron_left_rounded,
              tooltip: 'Previous event',
              direction: -1,
            ),
          IgnorePointer(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List<Widget>.generate(_events.length, (index) {
                final isActive = index == _currentPage;

                return AnimatedContainer(
                  duration: _animationsDisabled
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  margin: EdgeInsets.only(left: index == 0 ? 0 : 4),
                  width: isActive ? 16 : 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: isActive ? 1.0 : 0.50,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                );
              }),
            ),
          ),
          if (showArrows)
            _buildArrowButton(
              icon: Icons.chevron_right_rounded,
              tooltip: 'Next event',
              direction: 1,
            ),
        ],
      ),
    );
  }

  /// Builds an accessible 44-by-44 navigation control that does not activate
  /// the parent card's tap handler.
  Widget _buildArrowButton({
    required IconData icon,
    required String tooltip,
    required int direction,
  }) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _movePage(direction),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _autoplayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final events = _events;

    if (events.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final candidateWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width -
                (HomeLayout.of(context).homeHPad * 2);

        // Normalize invalid widths before computing sizes or PageView geometry.
        final layout = HomeLayout.fromWidth(candidateWidth);
        final width = layout.width;
        final size = layout.size;
        final textScale = HomeLayout.textScaleOf(context);

        final height = HomeLayout.featuredBannerHeight(
          width,
          textScale: textScale,
        );

        // Width of one card after the viewport fraction and page gap.
        final cardWidth = (width * _kViewportFraction) - (_kPageGap * 2);

        return SizedBox(
          width: width,
          height: height,
          child: Listener(
            onPointerDown: (_) => _pauseAutoplay(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: <PointerDeviceKind>{
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                    PointerDeviceKind.stylus,
                  },
                ),
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: events.length,
                  onPageChanged: (index) {
                    if (!mounted) {
                      return;
                    }

                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    return _buildBanner(
                      context,
                      events[index],
                      cardWidth,
                      height,
                      size,
                      textScale,
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Displays a compact icon and label within the featured banner.
/// When [filled] is true it is drawn as a soft pill, used for the event date.
class _FeaturedMetaItem extends StatelessWidget {
  const _FeaturedMetaItem({
    required this.icon,
    required this.label,
    required this.maxWidth,
    required this.fontSize,
    required this.iconSize,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final double maxWidth;
  final double fontSize;
  final double iconSize;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          icon,
          size: iconSize,
          color: Colors.white.withValues(alpha: 0.95),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: fontSize,
              fontWeight: filled ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: filled
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                child: content,
              ),
            )
          : content,
    );
  }
}
