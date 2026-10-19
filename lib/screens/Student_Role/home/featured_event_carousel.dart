import 'dart:async';

import 'package:flutter/material.dart' hide Notification;

import '../../../core/app_state.dart';
import 'home_event_utils.dart';
import 'home_tokens.dart';

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
  final PageController _pageController = PageController(viewportFraction: 1);

  Timer? _autoplayTimer;
  DateTime? _pauseAutoplayUntil;

  int _currentPage = 0;
  bool _animationsDisabled = false;

  List<Event> get _events => widget.events.take(5).toList(growable: false);

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

  Widget _buildBanner(
    BuildContext context,
    Event event,
    double width,
    double height,
  ) {
    final isWide = width >= 340;
    final cover = eventCoverImage(event);
    final description = event.description.trim();
    final imageWidth = width * 0.42;
    final textRightPadding = isWide ? imageWidth + 8 : 16.0;
    final metaMaxWidth = isWide ? 105.0 : 132.0;

    final metaItems = <Widget>[
      _FeaturedMetaItem(
        icon: Icons.calendar_month_outlined,
        label: formatDateShort(event.date),
        maxWidth: metaMaxWidth,
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
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: HC.heroGradient,
                    ),
                  ),
                  if (isWide)
                    Positioned(
                      top: 0,
                      right: 0,
                      bottom: 0,
                      width: imageWidth,
                      child: EventImage(
                        url: cover ?? '',
                        fit: BoxFit.cover,
                        fallback: eventGradientFallback(),
                      ),
                    )
                  else if (cover != null)
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.35,
                        child: EventImage(
                          url: cover,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  if (isWide)
                    Positioned(
                      top: 0,
                      right: 0,
                      bottom: 0,
                      width: imageWidth,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              stops: const <double>[0, 0.44, 1],
                              colors: <Color>[
                                HC.dark,
                                HC.dark.withValues(alpha: 0.58),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                HC.dark.withValues(alpha: 0.92),
                                HC.dark.withValues(alpha: 0.85),
                                HC.dark.withValues(alpha: 0.90),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        14,
                        textRightPadding,
                        14,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            constraints: BoxConstraints(
                              maxWidth: isWide ? 145 : 170,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.55),
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
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
                          const SizedBox(height: 7),
                          Text(
                            event.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              height: 1.12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: metaItems,
                          ),
                          if (description.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 4),
                            Text(
                              description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.88),
                                fontSize: 11,
                                height: 1.2,
                              ),
                            ),
                          ],
                          const Spacer(),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ElevatedButton(
                              onPressed: () => widget.onViewDetails(event),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: HC.dark,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
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
                  if (_events.length > 1)
                    Positioned(
                      right: 14,
                      bottom: 13,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List<Widget>.generate(_events.length, (
                          index,
                        ) {
                          final isActive = index == _currentPage;

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            margin: const EdgeInsets.only(left: 4),
                            width: isActive ? 16 : 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(
                                alpha: isActive ? 1 : 0.45,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          );
                        }),
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

        final height = (width * 0.58).clamp(190.0, 250.0).toDouble();

        return SizedBox(
          width: width,
          height: height,
          child: Listener(
            onPointerDown: (_) => _pauseAutoplay(),
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
                  width,
                  height,
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// Displays a compact icon and label within the featured banner.
class _FeaturedMetaItem extends StatelessWidget {
  const _FeaturedMetaItem({
    required this.icon,
    required this.label,
    required this.maxWidth,
  });

  final IconData icon;
  final String label;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Row(
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
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
