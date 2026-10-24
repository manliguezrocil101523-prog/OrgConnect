import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../core/app_state.dart';
import '../analytics/event_comments_sheet.dart';
import '../../widgets/app_header.dart';

// ── Design tokens ──────────────────────────────────────────────────────────
class _DT {
  static const bg = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF8FFFB);
  static const primary = Color(0xFF15803D);
  static const brandAccent = Color(0xFF1A9E6B);
  static const ink = Color(0xFF0F0D2E);
  static const inkSecond = Color(0xFF6B6B8E);
  static const inkMuted = Color(0xFFB8B9CC);
  static const border = Color(0xFFE8E9F3);

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
            color: const Color(0xFF1A9E6B).withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6)),
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2)),
      ];
}

enum EventFilter { selectedDay, upcoming, past }

enum _ResponsiveBreakpoint { compact, medium, expanded }

_ResponsiveBreakpoint _responsiveBreakpoint(double width) {
  if (width < 600) return _ResponsiveBreakpoint.compact;
  if (width < 960) return _ResponsiveBreakpoint.medium;
  return _ResponsiveBreakpoint.expanded;
}

// ── Display items for lazy list ───────────────────────────────────────────
abstract class _DisplayItem {}

class _MonthHeaderDisplayItem implements _DisplayItem {
  final String title;
  final int count;
  _MonthHeaderDisplayItem({required this.title, required this.count});
}

class _EventDisplayItem implements _DisplayItem {
  final Event event;
  _EventDisplayItem({required this.event});
}

class _PaginationFooterDisplayItem implements _DisplayItem {
  final int showingCount;
  final int totalCount;
  final VoidCallback onLoadMore;
  _PaginationFooterDisplayItem({
    required this.showingCount,
    required this.totalCount,
    required this.onLoadMore,
  });
}

// ── Filter Chips Persistent Header Delegate ────────────────────────────────
class _FilterChipsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _FilterChipsHeaderDelegate({required this.child, required this.height});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: overlapsContent
            ? const Border(bottom: BorderSide(color: _DT.border, width: 1))
            : null,
        boxShadow: overlapsContent
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: child,
    );
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant _FilterChipsHeaderDelegate oldDelegate) {
    return true;
  }
}

// ── Main widget ────────────────────────────────────────────────────────────
class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard>
    with TickerProviderStateMixin {
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  EventFilter _currentFilter = EventFilter.selectedDay;

  final ScrollController _scrollController = ScrollController();
  late final TextEditingController _searchController;
  late final ValueNotifier<bool> _backToTopNotifier;
  int _visibleCount = 10;

  late final AnimationController _entranceCtrl;
  late final Animation<double> _entranceFade;
  late final Animation<Offset> _entranceSlide;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedDay = now;
    final today = DateTime(now.year, now.month, now.day);
    final upcoming = _allEvents
        .where((e) =>
            !DateTime(e.date.year, e.date.month, e.date.day).isBefore(today))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    _selectedDay = upcoming.isNotEmpty ? upcoming.first.date : today;

    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);

    _backToTopNotifier = ValueNotifier<bool>(false);
    _scrollController.addListener(_onScroll);

    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _entranceFade =
        CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _entranceSlide =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
            CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic));

    _entranceCtrl.forward();

    // Ensure events are loaded
    AppState.instance.fetchEvents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _backToTopNotifier.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final show = _scrollController.offset > 600;
      if (_backToTopNotifier.value != show) {
        _backToTopNotifier.value = show;
      }
    }
  }

  void _onSearchChanged() {
    setState(() {
      _visibleCount = 10;
    });
  }

  void _changeFilter(EventFilter filter) {
    setState(() {
      _currentFilter = filter;
      _visibleCount = 10;
      if (filter == EventFilter.selectedDay) {
        _searchController.clear();
      }
    });
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients && mounted) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  // ── Helpers: real data from AppState ──────────────────────────────────

  List<Event> get _allEvents => AppState.instance.eventsForCurrentStudent();

  List<Event> _eventsForDay(DateTime day) {
    return _allEvents.where((e) => isSameDay(e.date, day)).toList();
  }

  List<Event> get _selectedDayEvents =>
      _selectedDay != null ? _eventsForDay(_selectedDay!) : [];

  List<_DisplayItem> _buildDisplayItems(List<Event> allEvents) {
    final items = <_DisplayItem>[];
    if (_currentFilter == EventFilter.selectedDay) {
      for (final e in _selectedDayEvents) {
        items.add(_EventDisplayItem(event: e));
      }
    } else {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final baseEvents = allEvents.where((e) {
        final d = DateTime(e.date.year, e.date.month, e.date.day);
        return _currentFilter == EventFilter.upcoming
            ? !d.isBefore(today)
            : d.isBefore(today);
      }).toList();

      if (_currentFilter == EventFilter.upcoming) {
        baseEvents.sort((a, b) => a.date.compareTo(b.date));
      } else {
        baseEvents.sort((a, b) => b.date.compareTo(a.date));
      }

      final query = _searchController.text.trim().toLowerCase();
      final searched = query.isEmpty
          ? baseEvents
          : baseEvents
              .where((e) =>
                  e.title.toLowerCase().contains(query) ||
                  e.orgName.toLowerCase().contains(query))
              .toList();

      if (searched.isNotEmpty) {
        final visibleEvents = searched.take(_visibleCount).toList();

        String? currentMonthKey;
        List<Event> currentMonthEvents = [];

        void flushMonth() {
          if (currentMonthKey != null && currentMonthEvents.isNotEmpty) {
            final firstDate = currentMonthEvents.first.date;
            final monthTitle = DateFormat('MMMM yyyy').format(firstDate);
            final monthTotal = searched
                .where((e) =>
                    DateFormat('yyyy-MM').format(e.date) == currentMonthKey)
                .length;
            items.add(
                _MonthHeaderDisplayItem(title: monthTitle, count: monthTotal));
            for (final e in currentMonthEvents) {
              items.add(_EventDisplayItem(event: e));
            }
            currentMonthEvents = [];
          }
        }

        for (final e in visibleEvents) {
          final mKey = DateFormat('yyyy-MM').format(e.date);
          if (mKey != currentMonthKey) {
            flushMonth();
            currentMonthKey = mKey;
          }
          currentMonthEvents.add(e);
        }
        flushMonth();

        if (_visibleCount < searched.length) {
          items.add(_PaginationFooterDisplayItem(
            showingCount: visibleEvents.length,
            totalCount: searched.length,
            onLoadMore: () {
              setState(() {
                _visibleCount += 10;
              });
            },
          ));
        }
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      minScaleFactor: 1.0,
      maxScaleFactor: 1.3,
      child: Scaffold(
        backgroundColor: _DT.bg,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final breakpoint = _responsiveBreakpoint(width);
            final sidePadding = breakpoint == _ResponsiveBreakpoint.compact
                ? 16.0
                : breakpoint == _ResponsiveBreakpoint.medium
                    ? 24.0
                    : 32.0;
            const contentMaxW = 1100.0;
            final centeredInset =
                width > contentMaxW ? (width - contentMaxW) / 2 : 0.0;
            final hPad = centeredInset + sidePadding;
            final hp = EdgeInsets.symmetric(horizontal: hPad);

            return AnimatedBuilder(
              animation: AppState.instance,
              builder: (context, _) {
                final allEvents = _allEvents;
                final displayedItems = _buildDisplayItems(allEvents);

                return FadeTransition(
                  opacity: _entranceFade,
                  child: SlideTransition(
                    position: _entranceSlide,
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildSectionHeader(
                              hPad,
                              showRefresh:
                                  breakpoint != _ResponsiveBreakpoint.compact,
                            ),
                            Expanded(
                              child: breakpoint ==
                                      _ResponsiveBreakpoint.expanded
                                  ? Padding(
                                      padding: hp,
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          SizedBox(
                                            width: 360,
                                            child: CustomScrollView(
                                              physics:
                                                  const BouncingScrollPhysics(),
                                              slivers: [
                                                SliverToBoxAdapter(
                                                  child: _buildScheduleInfo(
                                                    EdgeInsets.zero,
                                                    allEvents.length,
                                                  ),
                                                ),
                                                SliverToBoxAdapter(
                                                  child: AnimatedSize(
                                                    duration: const Duration(
                                                        milliseconds: 250),
                                                    curve: Curves.easeInOut,
                                                    alignment:
                                                        Alignment.topCenter,
                                                    child: ClipRect(
                                                      child: _currentFilter ==
                                                              EventFilter
                                                                  .selectedDay
                                                          ? Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .only(
                                                                top: 6,
                                                                bottom: 4,
                                                              ),
                                                              child:
                                                                  _buildCalendarCard(
                                                                      allEvents),
                                                            )
                                                          : const SizedBox
                                                              .shrink(),
                                                    ),
                                                  ),
                                                ),
                                                SliverToBoxAdapter(
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                      top: 10,
                                                      bottom: 6,
                                                    ),
                                                    child:
                                                        _buildFilterChipsContent(),
                                                  ),
                                                ),
                                                if (_currentFilter !=
                                                    EventFilter.selectedDay)
                                                  _buildSearchField(
                                                      EdgeInsets.zero),
                                                const SliverToBoxAdapter(
                                                  child: SizedBox(height: 24),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 24),
                                          Expanded(
                                            child: RefreshIndicator(
                                              color: _DT.brandAccent,
                                              onRefresh: _refreshEvents,
                                              child: Scrollbar(
                                                controller: _scrollController,
                                                thumbVisibility: false,
                                                child: CustomScrollView(
                                                  controller: _scrollController,
                                                  keyboardDismissBehavior:
                                                      ScrollViewKeyboardDismissBehavior
                                                          .onDrag,
                                                  physics:
                                                      const AlwaysScrollableScrollPhysics(
                                                    parent:
                                                        BouncingScrollPhysics(),
                                                  ),
                                                  slivers: [
                                                    SliverPadding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                        top: 10,
                                                        bottom: 8,
                                                      ),
                                                      sliver:
                                                          _buildSliverEventList(
                                                        displayedItems,
                                                        allEvents,
                                                        expanded: true,
                                                        showDialogDetails: true,
                                                      ),
                                                    ),
                                                    const SliverToBoxAdapter(
                                                      child:
                                                          SizedBox(height: 24),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : RefreshIndicator(
                                      color: _DT.brandAccent,
                                      onRefresh: _refreshEvents,
                                      child: Scrollbar(
                                        controller: _scrollController,
                                        thumbVisibility: false,
                                        child: CustomScrollView(
                                          controller: _scrollController,
                                          keyboardDismissBehavior:
                                              ScrollViewKeyboardDismissBehavior
                                                  .onDrag,
                                          physics:
                                              const AlwaysScrollableScrollPhysics(
                                            parent: BouncingScrollPhysics(),
                                          ),
                                          slivers: [
                                            SliverToBoxAdapter(
                                              child: _buildScheduleInfo(
                                                hp,
                                                allEvents.length,
                                              ),
                                            ),
                                            SliverToBoxAdapter(
                                              child: AnimatedSize(
                                                duration: const Duration(
                                                    milliseconds: 250),
                                                curve: Curves.easeInOut,
                                                alignment: Alignment.topCenter,
                                                child: ClipRect(
                                                  child: _currentFilter ==
                                                          EventFilter
                                                              .selectedDay
                                                      ? Padding(
                                                          padding: hp.copyWith(
                                                              top: 6,
                                                              bottom: 4),
                                                          child:
                                                              _buildCalendarCard(
                                                                  allEvents),
                                                        )
                                                      : const SizedBox.shrink(),
                                                ),
                                              ),
                                            ),
                                            _buildPinnedFilterChips(hp),
                                            if (_currentFilter !=
                                                EventFilter.selectedDay)
                                              _buildSearchField(hp),
                                            SliverPadding(
                                              padding: hp.copyWith(
                                                  top: 10, bottom: 8),
                                              sliver: _buildSliverEventList(
                                                displayedItems,
                                                allEvents,
                                                showDialogDetails: false,
                                              ),
                                            ),
                                            const SliverToBoxAdapter(
                                              child: SizedBox(height: 96),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                        // Back to top floating button
                        ValueListenableBuilder<bool>(
                          valueListenable: _backToTopNotifier,
                          builder: (context, show, child) {
                            final bottomOffset =
                                breakpoint == _ResponsiveBreakpoint.compact
                                    ? 96.0
                                    : 24.0;
                            return AnimatedPositioned(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              right: hPad,
                              bottom: show ? bottomOffset : -60,
                              child: AnimatedOpacity(
                                opacity: show ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 200),
                                child: IgnorePointer(
                                  ignoring: !show,
                                  child: Tooltip(
                                    message: 'Back to top',
                                    child: Material(
                                      color: _DT.brandAccent,
                                      elevation: 4,
                                      shape: const CircleBorder(),
                                      child: InkWell(
                                        onTap: () {
                                          if (_scrollController.hasClients) {
                                            _scrollController.animateTo(
                                              0,
                                              duration: const Duration(
                                                  milliseconds: 400),
                                              curve: Curves.easeInOut,
                                            );
                                          }
                                        },
                                        customBorder: const CircleBorder(),
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                              minWidth: 40, minHeight: 40),
                                          child: const Center(
                                            child: Icon(
                                              Icons.arrow_upward_rounded,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _refreshEvents() async {
    await Future.sync(() => AppState.instance.fetchEvents());
    if (mounted) {
      setState(() {
        _visibleCount = 10;
      });
    }
  }

  // ── Pinned Filter Chips Sliver (Optimized Compact Size) ───────────────────
  Widget _buildPinnedFilterChips(EdgeInsets hp) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _FilterChipsHeaderDelegate(
        height: 44, // Professional compact height for mobile screens
        child: Padding(
          padding: hp,
          child: _buildFilterChipsContent(),
        ),
      ),
    );
  }

  Widget _buildFilterChipsContent() {
    return MediaQuery.withClampedTextScaling(
      minScaleFactor: 1.0,
      maxScaleFactor: 1.1,
      child: Row(
        children: [
          _buildChipItem('Selected day', EventFilter.selectedDay),
          const SizedBox(width: 6),
          _buildChipItem('Upcoming', EventFilter.upcoming),
          const SizedBox(width: 6),
          _buildChipItem('Past', EventFilter.past),
        ],
      ),
    );
  }

  Widget _buildChipItem(String label, EventFilter filter) {
    final isSelected = _currentFilter == filter;
    return Expanded(
      child: Semantics(
        selected: isSelected,
        button: true,
        label: '$label filter',
        child: GestureDetector(
          onTap: () => _changeFilter(filter),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            constraints: const BoxConstraints(minHeight: 32),
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            decoration: BoxDecoration(
              color: isSelected ? _DT.brandAccent : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? _DT.brandAccent : const Color(0xFFE8E9F3),
                width: 1,
              ),
              boxShadow: isSelected ? _DT.cardShadow : null,
            ),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF6B6B8E),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Search Field Sliver (Compact Height) ───────────────────────────────
  Widget _buildSearchField(EdgeInsets hp) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: hp.copyWith(top: 6, bottom: 4),
        child: Container(
          constraints: const BoxConstraints(minHeight: 42),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _DT.border),
            boxShadow: _DT.cardShadow,
          ),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(
                fontSize: 13, color: _DT.ink, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'Search by title or organization',
              hintStyle: const TextStyle(fontSize: 12.5, color: _DT.inkMuted),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: _DT.inkSecond, size: 18),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded,
                          size: 16, color: _DT.inkSecond),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            ),
          ),
        ),
      ),
    );
  }

  // ── Event List Sliver Builder ──────────────────────────────────────────
  Widget _buildSliverEventList(
    List<_DisplayItem> items,
    List<Event> allEvents, {
    bool expanded = false,
    required bool showDialogDetails,
  }) {
    final day = _selectedDay ?? DateTime.now();
    String title;
    String subtitle;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    int totalFilteredCount = 0;
    if (_currentFilter == EventFilter.selectedDay) {
      totalFilteredCount = _selectedDayEvents.length;
      final isToday = isSameDay(day, DateTime.now());
      title = isToday ? 'Today' : DateFormat('EEEE, MMM d').format(day);
      subtitle = totalFilteredCount == 0
          ? 'No events scheduled'
          : '$totalFilteredCount event${totalFilteredCount == 1 ? '' : 's'} on this date';
    } else {
      final baseEvents = allEvents.where((e) {
        final d = DateTime(e.date.year, e.date.month, e.date.day);
        return _currentFilter == EventFilter.upcoming
            ? !d.isBefore(today)
            : d.isBefore(today);
      }).toList();
      final query = _searchController.text.trim().toLowerCase();
      final searched = query.isEmpty
          ? baseEvents
          : baseEvents
              .where((e) =>
                  e.title.toLowerCase().contains(query) ||
                  e.orgName.toLowerCase().contains(query))
              .toList();
      totalFilteredCount = searched.length;

      if (_currentFilter == EventFilter.upcoming) {
        title = 'Upcoming Events';
        subtitle =
            '$totalFilteredCount upcoming event${totalFilteredCount == 1 ? '' : 's'}';
      } else {
        title = 'Past Events';
        subtitle =
            '$totalFilteredCount past event${totalFilteredCount == 1 ? '' : 's'}';
      }
    }

    final displayRows = expanded
        ? _groupDisplayItems(items)
        : items.map((item) => <_DisplayItem>[item]).toList();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _DT.border),
                  boxShadow: _DT.cardShadow,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _DT.brandAccent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.event_rounded,
                          color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _DT.ink,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: _DT.inkSecond,
                              fontWeight: FontWeight.w400,
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

          if (items.isEmpty) {
            if (index == 1) {
              final query = _searchController.text.trim();
              if (query.isNotEmpty) {
                return _buildEmptySearchState(query);
              }
              return _buildEmptyEventsState(
                _currentFilter == EventFilter.selectedDay
                    ? 'Nothing on this day'
                    : _currentFilter == EventFilter.upcoming
                        ? 'No upcoming events'
                        : 'No past events',
                _currentFilter == EventFilter.selectedDay
                    ? 'No events are scheduled for ${DateFormat('MMMM d').format(day)}.'
                    : 'Check back later for new events or switch your filter.',
              );
            }
            return const SizedBox.shrink();
          }

          final rowIndex = index - 1;
          if (rowIndex >= displayRows.length) return const SizedBox.shrink();
          final row = displayRows[rowIndex];

          if (expanded && row.first is _EventDisplayItem) {
            // Variable-height rows avoid forcing event content into a fixed
            // grid extent when descriptions and accessibility text vary.
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildEventListItem(
                      context,
                      row[0] as _EventDisplayItem,
                      showDialogDetails: showDialogDetails,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: row.length > 1
                        ? _buildEventListItem(
                            context,
                            row[1] as _EventDisplayItem,
                            showDialogDetails: showDialogDetails,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            );
          }

          final item = row.first;
          if (item is _MonthHeaderDisplayItem) {
            return Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _DT.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${item.count} event${item.count == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _DT.inkSecond,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  const Divider(height: 1, color: _DT.border),
                ],
              ),
            );
          } else if (item is _EventDisplayItem) {
            final child = _buildEventListItem(
              context,
              item,
              showDialogDetails: showDialogDetails,
            );
            if (_currentFilter == EventFilter.past && !expanded) {
              return child;
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: child,
            );
          } else if (item is _PaginationFooterDisplayItem) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                children: [
                  Text(
                    'Showing ${item.showingCount} of ${item.totalCount} events',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _DT.inkSecond,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton(
                      onPressed: item.onLoadMore,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _DT.brandAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Show 10 more',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
        childCount: 1 + (items.isEmpty ? 1 : displayRows.length),
      ),
    );
  }

  List<List<_DisplayItem>> _groupDisplayItems(List<_DisplayItem> items) {
    final rows = <List<_DisplayItem>>[];
    var index = 0;
    while (index < items.length) {
      final item = items[index];
      if (item is _EventDisplayItem) {
        final row = <_DisplayItem>[item];
        if (index + 1 < items.length && items[index + 1] is _EventDisplayItem) {
          row.add(items[index + 1]);
          index++;
        }
        rows.add(row);
      } else {
        rows.add([item]);
      }
      index++;
    }
    return rows;
  }

  Widget _buildEventListItem(
    BuildContext context,
    _EventDisplayItem item, {
    required bool showDialogDetails,
  }) {
    final event = item.event;
    if (_currentFilter == EventFilter.past) {
      return KeyedSubtree(
        key: ValueKey(event.id),
        child: _CompactEventRow(
          event: event,
          inGrid: showDialogDetails,
          onTap: () => _openEventDetailSheet(
            context,
            event,
            useDialog: showDialogDetails,
          ),
        ),
      );
    }
    return KeyedSubtree(
      key: ValueKey(event.id),
      child: _EventFeedCard(event: event),
    );
  }

  void _openEventDetailSheet(
    BuildContext context,
    Event event, {
    required bool useDialog,
  }) {
    if (useDialog) {
      showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 720,
              maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.9,
            ),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Close event details',
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _EventFeedCard(
                      event: event,
                      showFullDescription: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _DT.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    _EventFeedCard(
                      event: event,
                      showFullDescription: true,
                    ),
                    const SizedBox(height: 96),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Empty state widgets ────────────────────────────────────────────────
  Widget _buildEmptyEventsState(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
      decoration: BoxDecoration(
        color: _DT.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _DT.border),
        boxShadow: _DT.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _DT.brandAccent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.event_note_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(height: 10),
          Text(title,
              style: const TextStyle(
                  fontSize: 14.5, fontWeight: FontWeight.w700, color: _DT.ink)),
          const SizedBox(height: 4),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, color: _DT.inkSecond, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildEmptySearchState(String query) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
      decoration: BoxDecoration(
        color: _DT.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _DT.border),
        boxShadow: _DT.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded, size: 36, color: _DT.inkSecond),
          const SizedBox(height: 10),
          Text(
            'No results for "$query"',
            style: const TextStyle(
                fontSize: 14.5, fontWeight: FontWeight.w700, color: _DT.ink),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () => _searchController.clear(),
            style: ElevatedButton.styleFrom(
              backgroundColor: _DT.brandAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Clear search',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(double hPad, {required bool showRefresh}) {
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      height: 72 + topInset,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        gradient: AppHeader.brandGradient,
      ),
      child: Stack(
        children: [
          Positioned(right: -45, top: -70, child: _headerOrb(170)),
          Positioned(right: 45, bottom: -70, child: _headerOrb(125)),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(hPad, topInset, hPad, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Events',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  if (showRefresh)
                    IconButton(
                      tooltip: 'Refresh events',
                      onPressed: () => _refreshEvents(),
                      icon: const Icon(Icons.refresh_rounded,
                          color: Colors.white, size: 21),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerOrb(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: .07),
        ),
      );

  Widget _buildScheduleInfo(EdgeInsets hp, int totalCount) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcomingCount = _allEvents.where((e) {
      final d = DateTime(e.date.year, e.date.month, e.date.day);
      return !d.isBefore(today);
    }).length;
    final dateText = DateFormat('EEEE, MMMM d, yyyy').format(now);
    final countBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.upcoming_rounded,
              size: 12, color: Color(0xFF1A9E6B)),
          const SizedBox(width: 4),
          Text(
            'Upcoming: $upcomingCount ($totalCount total)',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: .2,
              color: Color(0xFF0F766E),
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: hp.copyWith(top: 12, bottom: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 470;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Discover what's happening on campus",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _DT.inkSecond,
                ),
              ),
              const SizedBox(height: 6),
              if (narrow) ...[
                Text(
                  dateText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _DT.inkSecond,
                  ),
                ),
                const SizedBox(height: 6),
                Align(alignment: Alignment.centerLeft, child: countBadge),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        dateText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _DT.inkSecond,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    countBadge,
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  // ── Calendar card ────────────────────────────────────────────────────
  Widget _buildCalendarCard(List<Event> allEvents) {
    return Container(
      decoration: BoxDecoration(
        color: _DT.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _DT.border, width: 1.2),
        boxShadow: _DT.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous month',
                      onPressed: () => _changeCalendarMonth(-1),
                      icon: _chevronBtn(Icons.chevron_left_rounded),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    Expanded(
                      child: Text(
                        DateFormat('MMMM yyyy').format(_focusedDay),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _DT.ink,
                            letterSpacing: -0.3),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next month',
                      onPressed: () => _changeCalendarMonth(1),
                      icon: _chevronBtn(Icons.chevron_right_rounded),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: () {
                        final now = DateTime.now();
                        setState(() {
                          _focusedDay = now;
                          _selectedDay = DateTime(now.year, now.month, now.day);
                          _currentFilter = EventFilter.selectedDay;
                        });
                      },
                      // Icon before today text is set to Color(0xFF1A9E6B)
                      icon: const Icon(Icons.today_rounded,
                          size: 12, color: Color(0xFF1A9E6B)),
                      label: const Text('Today',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A9E6B))),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: const Color(0xFFDCFCE7),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                    const SizedBox(width: 5),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _calendarFormat =
                              _calendarFormat == CalendarFormat.month
                                  ? CalendarFormat.week
                                  : CalendarFormat.month;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _calendarFormat == CalendarFormat.month
                              ? 'Week'
                              : 'Month',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              TableCalendar(
                headerVisible: false,
                availableGestures: AvailableGestures.horizontalSwipe,
                calendarFormat: _calendarFormat,
                onFormatChanged: (format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                },
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
                onDaySelected: (selected, focused) {
                  setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                    _currentFilter = EventFilter.selectedDay;
                  });
                },
                eventLoader: (day) => _eventsForDay(day),
                calendarBuilders: CalendarBuilders(
                  selectedBuilder: (ctx, day, _) =>
                      LayoutBuilder(builder: (ctx, c) {
                    final size = (c.maxWidth * 0.78).clamp(26.0, 34.0);
                    return Center(
                        child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: _DT.brandAccent, width: 1.6)),
                      alignment: Alignment.center,
                      child: Text('${day.day}',
                          style: const TextStyle(
                              color: _DT.brandAccent,
                              fontWeight: FontWeight.w800,
                              fontSize: 12)),
                    ));
                  }),
                  todayBuilder: (ctx, day, _) => Center(
                    child: Text('${day.day}',
                        style: const TextStyle(
                            color: _DT.brandAccent,
                            fontWeight: FontWeight.w800,
                            fontSize: 12)),
                  ),
                  markerBuilder: (ctx, day, events) {
                    if (events.isEmpty) return const SizedBox.shrink();
                    final isSelected = isSameDay(_selectedDay, day);
                    return Positioned(
                      bottom: 2,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: events
                            .take(3)
                            .map((_) => Container(
                                  width: 4,
                                  height: 4,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white
                                        : _DT.brandAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ))
                            .toList(),
                      ),
                    );
                  },
                ),
                calendarStyle: CalendarStyle(
                  defaultTextStyle: const TextStyle(
                      color: _DT.ink,
                      fontWeight: FontWeight.w500,
                      fontSize: 12),
                  weekendTextStyle: TextStyle(
                      color: _DT.ink.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w500,
                      fontSize: 12),
                  outsideTextStyle:
                      const TextStyle(color: _DT.inkMuted, fontSize: 12),
                  selectedDecoration: const BoxDecoration(
                      color: Colors.transparent, shape: BoxShape.circle),
                  todayDecoration: const BoxDecoration(
                      color: Colors.transparent, shape: BoxShape.circle),
                  cellMargin: const EdgeInsets.all(1.5),
                  markersMaxCount: 3,
                  markerDecoration: const BoxDecoration(
                      color: _DT.brandAccent, shape: BoxShape.circle),
                  markerSize: 4,
                  markerMargin: const EdgeInsets.symmetric(horizontal: 1),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(
                      color: _DT.inkSecond.withValues(alpha: 0.70),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4),
                  weekendStyle: TextStyle(
                      color: _DT.inkSecond.withValues(alpha: 0.50),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4),
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _changeCalendarMonth(int offset) {
    final nextMonth = DateTime(_focusedDay.year, _focusedDay.month + offset, 1);
    final firstAllowed = DateTime(2020, 1, 1);
    final lastAllowed = DateTime(2030, 12, 1);
    if (nextMonth.isBefore(firstAllowed) || nextMonth.isAfter(lastAllowed)) {
      return;
    }
    setState(() {
      _focusedDay = nextMonth;
    });
  }

  Widget _chevronBtn(IconData icon) => Icon(
        icon,
        color: Colors.black,
        size: 16,
      );
}

// =============================================================================
// _CompactEventRow — lightweight row for past events
// =============================================================================
class _CompactEventRow extends StatefulWidget {
  final Event event;
  final VoidCallback onTap;
  final bool inGrid;

  const _CompactEventRow({
    required this.event,
    required this.onTap,
    this.inGrid = false,
  });

  @override
  State<_CompactEventRow> createState() => _CompactEventRowState();
}

class _CompactEventRowState extends State<_CompactEventRow> {
  Uint8List? _cachedBytes;
  String? _lastUrl;

  @override
  void initState() {
    super.initState();
    _processImage();
  }

  @override
  void didUpdateWidget(covariant _CompactEventRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newUrl = _getActiveUrl();
    if (newUrl != _lastUrl) {
      _processImage();
    }
  }

  String? _getActiveUrl() {
    if (widget.event.imageUrls.isNotEmpty) return widget.event.imageUrls.first;
    if (widget.event.imageUrl != null && widget.event.imageUrl!.isNotEmpty) {
      return widget.event.imageUrl;
    }
    return null;
  }

  void _processImage() {
    final url = _getActiveUrl();
    _lastUrl = url;
    _cachedBytes = null;
    if (url != null && url.startsWith('data:')) {
      try {
        final comma = url.indexOf(',');
        if (comma >= 0) {
          _cachedBytes = base64Decode(url.substring(comma + 1));
        }
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final url = _getActiveUrl();
    final dateStr = _formatDate(widget.event.date);

    return Semantics(
      label:
          'Past event: ${widget.event.title}, by ${widget.event.orgName}, on $dateStr. Double tap to open.',
      button: true,
      child: Container(
        margin:
            widget.inGrid ? EdgeInsets.zero : const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _DT.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 80),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: _buildThumbnail(url),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.event.orgName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            widget.event.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: _DT.ink,
                              letterSpacing: -0.2,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.calendar_today_rounded,
                                      size: 9.5,
                                      color: Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 3.5),
                                    Text(
                                      dateStr,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.forum_outlined,
                                    size: 12,
                                    color: Color(0xFF1A9E6B),
                                  ),
                                  const SizedBox(width: 3.5),
                                  EventCommentCountLabel(
                                    eventId: widget.event.id,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF6B6B8E),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right_rounded,
                        color: _DT.inkMuted, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(String? url) {
    if (url == null || url.isEmpty) {
      return _placeholder();
    }
    if (url.startsWith('data:')) {
      if (_cachedBytes != null) {
        return Image.memory(
          _cachedBytes!,
          fit: BoxFit.cover,
          cacheWidth: 128,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _placeholder(),
        );
      }
      return _placeholder();
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      cacheWidth: 128,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() {
    final firstLetter = widget.event.orgName.isNotEmpty
        ? widget.event.orgName[0].toUpperCase()
        : 'E';
    return Container(
      color: const Color(0xFFDCFCE7),
      alignment: Alignment.center,
      child: Text(
        firstLetter,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: Color(0xFF1A9E6B),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

// =============================================================================
// _EventFeedCard — rich card with multi-image carousel + zoom
// =============================================================================
class _EventFeedCard extends StatefulWidget {
  final Event event;
  final bool showFullDescription;

  const _EventFeedCard({
    required this.event,
    this.showFullDescription = false,
  });

  @override
  State<_EventFeedCard> createState() => _EventFeedCardState();
}

class _EventFeedCardState extends State<_EventFeedCard> {
  int _currentImageIndex = 0;

  List<String> get _imageUrls {
    if (widget.event.imageUrls.isNotEmpty) return widget.event.imageUrls;
    if (widget.event.imageUrl != null && widget.event.imageUrl!.isNotEmpty) {
      return [widget.event.imageUrl!];
    }
    return [];
  }

  ImageProvider _imageProvider(String url) {
    if (url.startsWith('data:')) {
      try {
        final comma = url.indexOf(',');
        if (comma >= 0) {
          return MemoryImage(base64Decode(url.substring(comma + 1)));
        }
      } catch (_) {}
    }
    return NetworkImage(url);
  }

  void _openZoom(BuildContext context, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: Image(image: _imageProvider(url), fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isUpcoming = !DateTime(
      widget.event.date.year,
      widget.event.date.month,
      widget.event.date.day,
    ).isBefore(today);
    final urls = _imageUrls;
    final hasImages = urls.isNotEmpty;
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth >= 520;
        return Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isUpcoming
                  ? const Color(0xFF1A9E6B).withValues(alpha: 0.18)
                  : const Color(0xFFE8E9F3),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1A9E6B).withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: horizontal
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasImages) _buildImageGallery(urls, horizontal: true),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildCardContent(isUpcoming),
                          const Divider(height: 1, color: Color(0xFFE8E9F3)),
                          _buildCommentsFooter(horizontal: true),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (hasImages) _buildImageGallery(urls, horizontal: false),
                    _buildCardContent(isUpcoming),
                    const Divider(height: 1, color: Color(0xFFE8E9F3)),
                    _buildCommentsFooter(horizontal: false),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildImageGallery(
    List<String> urls, {
    required bool horizontal,
  }) {
    final hasMultiple = urls.length > 1;
    final gallery = Stack(
      fit: StackFit.expand,
      children: [
        if (hasMultiple)
          PageView.builder(
            itemCount: urls.length,
            onPageChanged: (index) =>
                setState(() => _currentImageIndex = index),
            itemBuilder: (_, index) => GestureDetector(
              onTap: () => _openZoom(context, urls[index]),
              child: _buildImage(urls[index]),
            ),
          )
        else
          GestureDetector(
            onTap: () => _openZoom(context, urls.first),
            child: _buildImage(urls.first),
          ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 44,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.5),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.zoom_in_rounded, color: Colors.white, size: 12),
                SizedBox(width: 3.5),
                Text(
                  'Tap to expand',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasMultiple)
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: urls.asMap().entries.map((entry) {
                final isActive = entry.key == _currentImageIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isActive ? 14 : 5,
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                );
              }).toList(),
            ),
          ),
        if (hasMultiple)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_currentImageIndex + 1} / ${urls.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );

    return ClipRRect(
      borderRadius: horizontal
          ? const BorderRadius.only(topLeft: Radius.circular(16))
          : const BorderRadius.vertical(top: Radius.circular(16)),
      child: horizontal
          ? SizedBox(width: 240, height: 220, child: gallery)
          : LayoutBuilder(
              builder: (context, constraints) {
                final imageHeight = (constraints.maxWidth * 9 / 16)
                    .clamp(150.0, 220.0)
                    .toDouble();
                return SizedBox(
                  width: double.infinity,
                  height: imageHeight,
                  child: gallery,
                );
              },
            ),
    );
  }

  Widget _buildCardContent(bool isUpcoming) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.event.orgName.isNotEmpty
                      ? widget.event.orgName[0].toUpperCase()
                      : 'O',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A9E6B),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  widget.event.orgName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F766E),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isUpcoming
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isUpcoming ? 'Upcoming' : 'Past',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isUpcoming
                        ? const Color(0xFF1A9E6B)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            widget.event.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F0D2E),
              letterSpacing: -0.3,
              height: 1.2,
            ),
          ),
          if (widget.event.description.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              widget.event.description,
              maxLines: widget.showFullDescription ? null : 2,
              overflow: widget.showFullDescription
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF6B6B8E),
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isUpcoming
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 10.5,
                  color: isUpcoming
                      ? const Color(0xFF1A9E6B)
                      : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDate(widget.event.date),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isUpcoming
                        ? const Color(0xFF1A9E6B)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsFooter({required bool horizontal}) {
    return InkWell(
      onTap: () {
        showEventComments(
          context,
          eventId: widget.event.id,
          eventTitle: widget.event.title,
        );
      },
      borderRadius: horizontal
          ? const BorderRadius.only(bottomRight: Radius.circular(16))
          : const BorderRadius.vertical(bottom: Radius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: const [
                  Icon(Icons.forum_outlined,
                      size: 15, color: Color(0xFF1A9E6B)),
                  SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      'Discussion & Comments',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A9E6B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            EventCommentCountLabel(
              eventId: widget.event.id,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B6B8E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String url) {
    if (url.startsWith('data:')) {
      try {
        final base64Str = url.substring(url.indexOf(',') + 1);
        return Image.memory(
          base64Decode(base64Str),
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _imageFallback(),
        );
      } catch (_) {
        return _imageFallback();
      }
    }

    return Image.network(
      url,
      width: double.infinity,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: const Color(0xFFDCFCE7),
          child: const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF1A9E6B),
              strokeWidth: 2,
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) => _imageFallback(),
    );
  }

  Widget _imageFallback() => Container(
        color: const Color(0xFFDCFCE7),
        child: const Center(
          child: Icon(Icons.broken_image_rounded,
              color: Color(0xFF1A9E6B), size: 32),
        ),
      );

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
