import 'package:flutter/material.dart' hide Notification;

import '../../../core/app_state.dart';
import 'home_event_utils.dart';
import 'home_tokens.dart';

/// Shows horizontally scrollable cards for upcoming campus events.
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

    final layout = HomeLayout.of(context);
    final cardWidth = layout.cardWidth(min: 200, max: 250);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: layout.hPad),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (var index = 0; index < displayedEvents.length; index++) ...[
              if (index > 0) const SizedBox(width: 12),
              _UpcomingEventCard(
                event: displayedEvents[index],
                width: cardWidth,
                interestedCount: interestCounts[displayedEvents[index].id] ?? 0,
                onTap: () => onOpen(displayedEvents[index]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Renders a single upcoming event card with its date and interest count.
class _UpcomingEventCard extends StatelessWidget {
  const _UpcomingEventCard({
    required this.event,
    required this.width,
    required this.interestedCount,
    required this.onTap,
  });

  final Event event;
  final double width;
  final int interestedCount;
  final VoidCallback onTap;

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
                    style: const TextStyle(
                      color: HC.ink,
                      fontSize: 21,
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
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTime() {
    final time = event.timeLabel.trim();
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
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

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
                  fontSize: 11,
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
      width: width,
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
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0x120F8A61),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
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
                  Padding(
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
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.55,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          event.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: HC.ink,
                            fontSize: 14,
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
                          const SizedBox(height: 10),
                          _buildInterestPill(),
                        ],
                      ],
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
