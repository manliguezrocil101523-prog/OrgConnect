import 'package:flutter/material.dart' hide Notification;

import '../../../core/app_state.dart';
import 'event_details_sheet.dart';
import 'featured_event_carousel.dart';
import 'home_data.dart';
import 'home_tokens.dart';
import 'upcoming_events_row.dart';

/// Coordinates the featured banner, upcoming event cards, and interest counts.
class HomeEventsSection extends StatefulWidget {
  const HomeEventsSection({
    super.key,
    required this.onViewAll,
  });

  final VoidCallback onViewAll;

  @override
  State<HomeEventsSection> createState() => _HomeEventsSectionState();
}

class _HomeEventsSectionState extends State<HomeEventsSection> {
  Map<String, int> _interest = <String, int>{};
  String? _interestKey;

  void _scheduleInterestLoad(List<String> ids) {
    final key = ids.join('|');

    if (key == _interestKey) {
      return;
    }

    // Record the key before scheduling the load to avoid repeated requests
    // during subsequent builds.
    _interestKey = key;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _loadInterestForKey(ids, key);
    });
  }

  Future<void> _loadInterestForKey(
    List<String> ids,
    String key,
  ) async {
    if (ids.isEmpty) {
      if (!mounted || _interestKey != key) {
        return;
      }

      setState(() {
        _interest = <String, int>{};
      });
      return;
    }

    try {
      final counts = await HomeData.fetchEventInterestCounts(ids);

      if (!mounted) {
        return;
      }

      if (_interestKey != key) {
        return;
      }

      setState(() {
        _interest = <String, int>{
          for (final id in ids) id: counts[id] ?? 0,
        };
      });
    } catch (error, stackTrace) {
      debugPrint('Unable to load event interest counts: $error\n$stackTrace');

      if (!mounted) {
        return;
      }

      if (_interestKey != key) {
        return;
      }

      setState(() {
        _interest = <String, int>{
          for (final id in ids) id: 0,
        };
      });
    }
  }

  /// Reloads interest counts after an event's reaction has changed.
  void _reloadInterest() {
    final ids = HomeData.upcomingEvents()
        .map((event) => event.id)
        .toList(growable: false);
    final key = ids.join('|');

    _interestKey = key;
    _loadInterestForKey(ids, key);
  }

  void _openEvent(BuildContext context, Event event) {
    showEventDetailsSheet(
      context,
      event: event,
      interestedCount: _interest[event.id] ?? 0,
      onInterestChanged: _reloadInterest,
    );
  }

  Widget _buildSectionHeader(BuildContext context, double horizontalPadding) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: HC.mint,
              borderRadius: BorderRadius.circular(13),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.calendar_month_rounded,
              color: HC.primary,
              size: 23,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Upcoming Events',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: HC.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Latest posts from campus organizations',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: HC.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: widget.onViewAll,
            style: TextButton.styleFrom(
              foregroundColor: HC.primary,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(44, 44),
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            child: const Text(
              'View All →',
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(double horizontalPadding) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: HC.mint,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: HC.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.event_available_rounded,
                size: 27,
                color: HC.primary,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'No upcoming events yet',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: HC.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Events from campus organizations will appear here.',
                    style: TextStyle(
                      color: HC.muted,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final events = HomeData.upcomingEvents();
    final horizontalPadding = HomeLayout.of(context).hPad;

    _scheduleInterestLoad(
      events.map((event) => event.id).toList(growable: false),
    );

    if (events.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 24),
          _buildEmptyState(horizontalPadding),
          const SizedBox(height: 32),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 24),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: FeaturedEventCarousel(
            events: events,
            onViewDetails: (event) => _openEvent(context, event),
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionHeader(context, horizontalPadding),
        const SizedBox(height: 12),
        UpcomingEventsRow(
          events: events,
          interestCounts: _interest,
          onOpen: (event) => _openEvent(context, event),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
