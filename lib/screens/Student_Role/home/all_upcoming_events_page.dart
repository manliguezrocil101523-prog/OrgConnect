import 'package:flutter/material.dart' hide Notification;
import '../../../core/app_state.dart';
import 'home_tokens.dart';
import 'home_data.dart';
import 'home_event_utils.dart';
import 'event_details_sheet.dart';

class AllUpcomingEventsPage extends StatefulWidget {
  const AllUpcomingEventsPage({super.key});

  @override
  State<AllUpcomingEventsPage> createState() => _AllUpcomingEventsPageState();
}

class _AllUpcomingEventsPageState extends State<AllUpcomingEventsPage> {
  Map<String, int> _interest = {};
  String _lastLoadedKey = '';
  int _sortChoice = 0; // 0: Soonest first, 1: Newest posts

  Future<void> _fetchInterests(List<String> ids) async {
    if (ids.isEmpty) return;
    final key = ids.join(',');
    _lastLoadedKey = key;
    try {
      final counts = await HomeData.fetchEventInterestCounts(ids);
      if (!mounted) return;
      setState(() {
        _interest = counts;
      });
    } catch (e) {
      debugPrint('Error fetching event interest counts: $e');
    }
  }

  Future<void> _reloadInterest() async {
    _lastLoadedKey = '';
    final events = HomeData.upcomingEvents();
    final ids = events.map((e) => e.id).toList()..sort();
    await _fetchInterests(ids);
  }

  @override
  Widget build(BuildContext context) {
    return HomeLayout.capText(
      context,
      AnimatedBuilder(
        animation: AppState.instance,
        builder: (context, child) {
          final events = HomeData.upcomingEvents();
          final ids = events.map((e) => e.id).toList()..sort();
          final currentKey = ids.join(',');

          if (currentKey != _lastLoadedKey) {
            _lastLoadedKey = currentKey;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _fetchInterests(ids);
            });
          }

          final displayEvents = List<Event>.from(events);
          if (_sortChoice == 1) {
            displayEvents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          }

          return Scaffold(
            backgroundColor: HC.bg,
            body: RefreshIndicator(
              color: HC.primary,
              onRefresh: () async {
                try {
                  await AppState.instance.fetchEvents();
                  await _reloadInterest();
                } catch (e) {
                  debugPrint('Error refreshing upcoming events: $e');
                }
              },
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: EdgeInsets.only(
                  bottom: 32 + MediaQuery.paddingOf(context).bottom,
                ),
                itemCount:
                    2 + (displayEvents.isEmpty ? 1 : displayEvents.length),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildHeader(context, displayEvents.length);
                  }
                  if (index == 1) {
                    return Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: HomeLayout.of(context).contentWidth,
                        ),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            HomeLayout.of(context).hPad,
                            16,
                            HomeLayout.of(context).hPad,
                            8,
                          ),
                          child: _buildSortChips(),
                        ),
                      ),
                    );
                  }

                  if (displayEvents.isEmpty) {
                    return Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: HomeLayout.of(context).contentWidth,
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: HomeLayout.of(context).hPad,
                            vertical: 24,
                          ),
                          child: const _EmptyStateCard(),
                        ),
                      ),
                    );
                  }

                  final eventIndex = index - 2;
                  final event = displayEvents[eventIndex];
                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: HomeLayout.of(context).contentWidth,
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: HomeLayout.of(context).hPad,
                          vertical: 7,
                        ),
                        child: _EventCard(
                          event: event,
                          interestedCount: _interest[event.id] ?? 0,
                          onTap: () {
                            showEventDetailsSheet(
                              context,
                              event: event,
                              interestedCount: _interest[event.id] ?? 0,
                              onInterestChanged: _reloadInterest,
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int count) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final width = HomeLayout.of(context).contentWidth;
    final hPad = HomeLayout.of(context).hPad;
    final subtitle = count == 1 ? '1 event' : '$count events';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: HC.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      padding: EdgeInsets.fromLTRB(hPad, topPadding + 12, hPad, 20),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      tooltip: 'Back',
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Upcoming Events',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 52),
                child: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortChips() {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('Soonest first'),
            selected: _sortChoice == 0,
            onSelected: (selected) {
              if (selected) {
                setState(() {
                  _sortChoice = 0;
                });
              }
            },
            selectedColor: HC.mint,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: _sortChoice == 0 ? HC.dark : HC.ink,
              fontWeight:
                  _sortChoice == 0 ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(width: 10),
          ChoiceChip(
            label: const Text('Newest posts'),
            selected: _sortChoice == 1,
            onSelected: (selected) {
              if (selected) {
                setState(() {
                  _sortChoice = 1;
                });
              }
            },
            selectedColor: HC.mint,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: _sortChoice == 1 ? HC.dark : HC.ink,
              fontWeight:
                  _sortChoice == 1 ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: HC.mint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HC.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(
            Icons.event_busy_rounded,
            size: 48,
            color: HC.primary,
          ),
          SizedBox(height: 16),
          Text(
            'No upcoming events yet',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: HC.ink,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Events from campus organizations will appear here.',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: HC.muted,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Event event;
  final int interestedCount;
  final VoidCallback onTap;

  const _EventCard({
    required this.event,
    required this.interestedCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final coverUrl = eventCoverImage(event);
    final semanticsLabel =
        '${event.title}, ${formatDateShort(event.date)}, button';

    return Semantics(
      label: semanticsLabel,
      button: true,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: HC.line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120F8A61),
              blurRadius: 14,
              offset: Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: coverUrl != null
                        ? EventImage(url: coverUrl)
                        : eventGradientFallback(),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            monthShortUpper(event.date.month),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: HC.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            event.date.day.toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: HC.ink,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.orgName.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: HC.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: HC.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                      ),
                    ),
                    if (event.venue.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 16,
                            color: HC.muted,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              event.venue,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: HC.muted,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 16,
                          color: HC.muted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            event.timeLabel.isNotEmpty
                                ? event.timeLabel
                                : formatDateShort(event.date),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: HC.muted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (interestedCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: HC.mint,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.people_alt_rounded,
                                  size: 14,
                                  color: HC.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$interestedCount interested',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: HC.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
