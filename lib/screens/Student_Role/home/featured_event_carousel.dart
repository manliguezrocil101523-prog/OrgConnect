import 'dart:async';

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

/// Presents up to five campus events in an autoplaying featured banner.
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

  List<Event> get _events => widget.events.take(5).toList(growable: false);

  // ------------------------------------------------------------------------
  // LOGIC (unchanged): lifecycle, autoplay timer, pause on touch
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

  void _pauseAutoplay() {
    _pauseAutoplayUntil = DateTime.now().add(const Duration(seconds: 10));
  }

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

  /// Clean banner: the poster fills the whole card, with a dark fade only at
  /// the bottom so the white text stays readable on any image.
  Widget _buildBanner(
    BuildContext context,
    Event event,
    double width,
    double height,
  ) {
    final cover = eventCoverImage(event);
    final metaMaxWidth = (width - 32) * 0.5;

    final metaItems = <Widget>[
      _FeaturedMetaItem(
        icon: Icons.calendar_month_outlined,
        label: formatDateShort(event.date),
        maxWidth: metaMaxWidth,
        filled: true,
      ),
      if (event.timeLabel.trim().isNotEmpty)
        _FeaturedMetaItem(
          icon: Icons.schedule_rounded,
          label: event.timeLabel.trim(),
          maxWidth: metaMaxWidth,
        ),
      if (event.venue.trim().isNotEmpty)
        _FeaturedMetaItem(
          icon: Icons.location_on_outlined,
          label: event.venue.trim(),
          maxWidth: metaMaxWidth,
        ),
    ];

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
                  // 1. Base: brand green (only visible if there is no image
                  //    or the image fails to load).
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: HC.heroGradient,
                    ),
                  ),

                  // 2. The poster, full card, no color tint.
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

                  // 3. Neutral dark fade: light at the top (badge), clear in
                  //    the middle (poster stays visible), strong at the bottom
                  //    (text).
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

                  // 4. Content: badge on top, details at the bottom.
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            constraints: const BoxConstraints(maxWidth: 160),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.40),
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 10,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'FEATURED EVENT',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            event.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              height: 1.1,
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
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ElevatedButton(
                              onPressed: () => widget.onViewDetails(event),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: HC.dark,
                                elevation: 3,
                                shadowColor:
                                    Colors.black.withValues(alpha: 0.35),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                  vertical: 8,
                                ),
                                minimumSize: const Size(0, 34),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: const StadiumBorder(),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    'View Details',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(width: 5),
                                  Icon(Icons.arrow_forward_rounded, size: 15),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 5. Page indicator (unchanged).
                  if (_events.length > 1)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.30),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List<Widget>.generate(_events.length, (
                            index,
                          ) {
                            final isActive = index == _currentPage;

                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              margin: EdgeInsets.only(left: index == 0 ? 0 : 4),
                              width: isActive ? 16 : 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(
                                  alpha: isActive ? 1 : 0.50,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),

                  // 6. Hairline inner border (unchanged).
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
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width -
                (HomeLayout.of(context).hPad * 2);

        final height = (width * 0.60).clamp(200.0, 260.0).toDouble();

        // Width of one card after the peek fraction and the gap are applied.
        final cardWidth = (width * _kViewportFraction) - (_kPageGap * 2);

        return SizedBox(
          width: width,
          height: height,
          child: Listener(
            onPointerDown: (_) => _pauseAutoplay(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
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
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Displays a compact icon and label within the featured banner.
/// When [filled] is true it is drawn as a soft pill (used for the date).
class _FeaturedMetaItem extends StatelessWidget {
  const _FeaturedMetaItem({
    required this.icon,
    required this.label,
    required this.maxWidth,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final double maxWidth;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          icon,
          size: 12,
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
              fontSize: 10,
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
