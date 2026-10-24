import 'home_time_format.dart';
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart' hide Notification;

import '../../../core/app_state.dart';
import 'home_event_utils.dart';
import 'home_tokens.dart';

/// Displays upcoming event cards responsively on mobile, tablet, and desktop.
///
/// Uses the available width of this widget to choose between a horizontal
/// mobile scroller and a responsive grid on wider layouts.
class UpcomingEventsRow extends StatelessWidget {
  const UpcomingEventsRow({
    super.key,
    required this.events,
    required this.interestCounts,
    required this.onOpen,
  });

  final List<Event> events;
  final Map<String, int> interestCounts;
  final void Function(Event) onOpen;

  @override
  Widget build(BuildContext context) {
    final displayedEvents = events.take(10).toList(growable: false);

    if (displayedEvents.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final fallbackWidth = MediaQuery.sizeOf(context).width;
        final rowWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : fallbackWidth;

        final layout = HomeLayout.of(context);
        final homeHPad = layout.homeHPad;
        final gap = layout.cardGap;
        final innerWidth = math
            .max(
              0.0,
              rowWidth - (2 * homeHPad),
            )
            .toDouble();

        if (rowWidth < HomeBreakpoints.tabletMin) {
          final desiredCardWidth =
              (innerWidth * 0.82).clamp(200.0, 260.0).toDouble();

          final cardWidth = math
              .min(
                innerWidth,
                desiredCardWidth,
              )
              .toDouble();

          return SizedBox(
            width: rowWidth,
            child: _buildMobileScroller(
              context: context,
              events: displayedEvents,
              homeHPad: homeHPad,
              cardWidth: cardWidth,
              gap: gap,
            ),
          );
        }

        final columns = HomeLayout.gridColumns(
          innerWidth,
          minItemWidth: 220,
          gap: gap,
          maxColumns: 4,
        );

        final visibleCount = math
            .min(
              displayedEvents.length,
              columns * 2,
            )
            .toInt();

        final cardWidth = HomeLayout.gridItemWidth(
          innerWidth,
          columns,
          gap: gap,
        );

        return SizedBox(
          width: rowWidth,
          child: _buildWideGrid(
            context: context,
            events: displayedEvents,
            visibleCount: visibleCount,
            columns: columns,
            cardWidth: cardWidth,
            homeHPad: homeHPad,
            gap: gap,
          ),
        );
      },
    );
  }

  /// Builds the horizontally scrollable layout used below the tablet breakpoint.
  Widget _buildMobileScroller({
    required BuildContext context,
    required List<Event> events,
    required double homeHPad,
    required double cardWidth,
    required double gap,
  }) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: const <PointerDeviceKind>{
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        },
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: homeHPad),
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (var index = 0; index < events.length; index++) ...<Widget>[
                if (index > 0) SizedBox(width: gap),
                _UpcomingEventCard(
                  event: events[index],
                  cardWidth: cardWidth,
                  interestedCount: interestCounts[events[index].id] ?? 0,
                  onTap: () => onOpen(events[index]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a responsive grid with equal-width cards and a maximum of two rows.
  Widget _buildWideGrid({
    required BuildContext context,
    required List<Event> events,
    required int visibleCount,
    required int columns,
    required double cardWidth,
    required double homeHPad,
    required double gap,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: homeHPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var rowStart = 0;
              rowStart < visibleCount;
              rowStart += columns) ...<Widget>[
            if (rowStart > 0) SizedBox(height: gap),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (var column = 0; column < columns; column++) ...<Widget>[
                    if (column > 0) SizedBox(width: gap),
                    if (rowStart + column < visibleCount)
                      Expanded(
                        child: _UpcomingEventCard(
                          event: events[rowStart + column],
                          cardWidth: cardWidth,
                          interestedCount:
                              interestCounts[events[rowStart + column].id] ?? 0,
                          onTap: () => onOpen(events[rowStart + column]),
                        ),
                      )
                    else
                      const Expanded(
                        child: SizedBox.shrink(),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Renders one event card with its cover image, event metadata, and interest count.
///
/// The card's own width determines its text sizes. Its height is content-driven,
/// allowing rows to accommodate different text lengths and system text scales.
class _UpcomingEventCard extends StatelessWidget {
  const _UpcomingEventCard({
    required this.event,
    required this.cardWidth,
    required this.interestedCount,
    required this.onTap,
  });

  final Event event;
  final double cardWidth;
  final int interestedCount;
  final VoidCallback onTap;

  /// Whether the card is wide enough to use the larger title and date sizes.
  bool get _isLargeCard => cardWidth >= 280;

  /// Builds the cover image and its overlaid date badge.
  Widget _buildImage() {
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          EventImage(
            url: eventCoverImage(event) ?? '',
            fit: BoxFit.cover,
            fallback: eventGradientFallback(),
          ),
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              constraints: const BoxConstraints(minWidth: 48),
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(11),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: HC.dark.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    monthShortUpper(event.date.month),
                    style: const TextStyle(
                      color: HC.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${event.date.day}',
                    style: TextStyle(
                      color: HC.ink,
                      fontSize: _isLargeCard ? 22 : 21,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the venue row, omitting it when the venue is empty.
  Widget _buildVenue() {
    final venue = event.venue.trim();

    if (venue.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      children: <Widget>[
        const Icon(
          Icons.location_on_outlined,
          size: 15,
          color: HC.muted,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            venue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: HC.muted,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the time row, falling back to the formatted event date.
  Widget _buildTime() {
    final time = formatTimeLabel12h(event.timeLabel);
    final label = time.isNotEmpty ? time : formatDateShort(event.date);

    return Row(
      children: <Widget>[
        const Icon(
          Icons.schedule_rounded,
          size: 15,
          color: HC.muted,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: HC.muted,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the interest pill, truncating its label when space is limited.
  Widget _buildInterestPill() {
    if (interestedCount <= 0) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 9,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: HC.mint,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.people_alt_outlined,
              size: 14,
              color: HC.primary,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                '$interestedCount interested',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: HC.dark,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orgName = event.orgName.trim();

    return SizedBox(
      width: cardWidth,
      child: Semantics(
        button: true,
        label: 'Event: ${event.title}, ${formatDateShort(event.date)}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(17),
            child: Ink(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: HC.line),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x120F8A61),
                    blurRadius: 14,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: _buildImage(),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 13),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            orgName.isEmpty
                                ? 'CAMPUS ORGANIZATION'
                                : orgName.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: HC.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.55,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            event.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: HC.ink,
                              fontSize: _isLargeCard ? 16 : 15,
                              height: 1.25,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 9),
                          _buildVenue(),
                          if (event.venue.trim().isNotEmpty)
                            const SizedBox(height: 6),
                          _buildTime(),
                          if (interestedCount > 0) ...<Widget>[
                            const Spacer(),
                            _buildInterestPill(),
                          ],
                        ],
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
}
