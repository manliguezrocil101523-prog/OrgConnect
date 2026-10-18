import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../core/app_state.dart';
import '../analytics/event_comments_sheet.dart';
import '../../widgets/app_header.dart';

// ── Design tokens ──────────────────────────────────────────────────────────
class _DT {
  static const bg = Color(0xFFF0FDF4);
  static const surface = Color(0xFFF8FFFB);
  static const primary = Color(0xFF15803D);
  static const gradEnd = Color(0xFF22C55E);
  static const ink = Color(0xFF0F0D2E);
  static const inkSecond = Color(0xFF6B6B8E);
  static const inkMuted = Color(0xFFB8B9CC);
  static const border = Color(0xFFE8E9F3);

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
            color: const Color(0xFF15803D).withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6)),
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2)),
      ];
  static List<BoxShadow> get glowShadow => [
        BoxShadow(
            color: primary.withValues(alpha: 0.45),
            blurRadius: 16,
            spreadRadius: 1),
        BoxShadow(color: gradEnd.withValues(alpha: 0.25), blurRadius: 28),
      ];
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
  final ScrollController _scrollController = ScrollController();
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
    _selectedDay = upcoming.isNotEmpty ? upcoming.first.date : now;

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
    _entranceCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Helpers: real data from AppState ──────────────────────────────────

  /// All events from AppState
  List<Event> get _allEvents => AppState.instance.eventsForCurrentStudent();

  /// Events that fall on a given day (date-only comparison)
  List<Event> _eventsForDay(DateTime day) {
    return _allEvents.where((e) => isSameDay(e.date, day)).toList();
  }

  /// Events on the currently selected day
  List<Event> get _selectedDayEvents =>
      _selectedDay != null ? _eventsForDay(_selectedDay!) : [];

  /// Real applications for the current student

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final hPad = (mq.size.width * 0.055).clamp(16.0, 28.0);
    final hp = EdgeInsets.symmetric(horizontal: hPad);

    return Scaffold(
      backgroundColor: _DT.bg,
      body: AnimatedBuilder(
        // Rebuild whenever AppState changes (new events, applications, etc.)
        animation: AppState.instance,
        builder: (context, _) {
          final allEvents = _allEvents;
          final selectedEvents = _selectedDayEvents;

          return FadeTransition(
            opacity: _entranceFade,
            child: SlideTransition(
              position: _entranceSlide,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Keep the greeting/header fixed. The scrollbar starts below it.
                  _buildSectionHeader(),
                  Expanded(
                    child: Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      trackVisibility: true,
                      interactive: true,
                      thickness: 7,
                      radius: const Radius.circular(10),
                      child: CustomScrollView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics()),
                        slivers: [
                          // ── Calendar section label ─────────────────────
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: hp.copyWith(bottom: 12),
                              child: _sectionLabel('Calendar', 'Your schedule'),
                            ),
                          ),
                          // ── Calendar card ──────────────────────────────
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: hp.copyWith(bottom: 0),
                              child: _buildCalendarCard(allEvents),
                            ),
                          ),
                          // ── Selected day events ───────────────────────
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: hp.copyWith(top: 16, bottom: 8),
                              child: _buildSelectedDaySection(selectedEvents),
                            ),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 96)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Selected day section ───────────────────────────────────────────────
  Widget _buildSelectedDaySection(List<Event> events) {
    final day = _selectedDay;
    if (day == null) return const SizedBox.shrink();

    final label = isSameDay(day, DateTime.now())
        ? 'Upcoming Events'
        : DateFormat('MMMM d, yyyy').format(day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with selected date
        Container(
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: _DT.border),
            boxShadow: _DT.cardShadow,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF16A34A), Color(0xFF22C55E)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.event_rounded,
                    color: Colors.white, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _DT.ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      events.isEmpty
                          ? 'No events scheduled'
                          : '${events.length} event${events.length == 1 ? '' : 's'} on this date',
                      style: const TextStyle(
                        fontSize: 11.5,
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

        const SizedBox(height: 14),

        // Events for selected day OR empty state
        if (events.isEmpty)
          _buildEmptyEventsState(
            'Nothing on this day',
            'No events are scheduled\nfor ${DateFormat('MMMM d').format(day)}.',
          )
        else
          ...events.map((e) => _EventFeedCard(event: e)),
      ],
    );
  }

  // ── Empty state widget ─────────────────────────────────────────────────
  Widget _buildEmptyEventsState(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: _DT.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _DT.border),
        boxShadow: _DT.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF16A34A), Color(0xFF0F766E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.event_note_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: _DT.ink)),
          const SizedBox(height: 5),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12.5, color: _DT.inkSecond, height: 1.55)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    final count = _allEvents.length;
    return AppHeader(
      title: 'Events',
      subtitle:
          'Your schedule • ${DateFormat('EEEE, MMMM d').format(DateTime.now())}',
      status: '$count EVENT${count == 1 ? '' : 'S'}',
      icon: Icons.calendar_month_rounded,
    );
  }

  // ── Calendar card ────────────────────────────────────────────────────
  Widget _buildCalendarCard(List<Event> allEvents) {
    return Container(
      decoration: BoxDecoration(
        color: _DT.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _DT.border, width: 1.2),
        boxShadow: _DT.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous month',
                      onPressed: () => _changeCalendarMonth(-1),
                      icon: _chevronBtn(Icons.chevron_left_rounded),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                    Expanded(
                      child: Text(
                        DateFormat.yMMMM().format(_focusedDay),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 16,
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
                          const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                  ],
                ),
              ),
              TableCalendar(
                headerVisible: false,
                availableGestures: AvailableGestures.horizontalSwipe,
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
                onDaySelected: (selected, focused) {
                  setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                  });
                },
                // ── Event dot markers ──────────────────────────────────
                eventLoader: (day) => _eventsForDay(day),
                calendarBuilders: CalendarBuilders(
                  // Selected day circle
                  selectedBuilder: (ctx, day, _) =>
                      LayoutBuilder(builder: (ctx, c) {
                    final size = (c.maxWidth * 0.80).clamp(30.0, 40.0);
                    return Center(
                        child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                          color: const Color(0xFF0F766E),
                          shape: BoxShape.circle,
                          boxShadow: _DT.glowShadow),
                      alignment: Alignment.center,
                      child: Text('${day.day}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14)),
                    ));
                  }),
                  // Today circle
                  todayBuilder: (ctx, day, _) =>
                      LayoutBuilder(builder: (ctx, c) {
                    final size = (c.maxWidth * 0.80).clamp(30.0, 40.0);
                    return Center(
                        child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFF16A34A), width: 1.8)),
                      alignment: Alignment.center,
                      child: Text('${day.day}',
                          style: const TextStyle(
                              color: Color(0xFF16A34A),
                              fontWeight: FontWeight.w800,
                              fontSize: 14)),
                    ));
                  }),
                  // Custom dot marker below days with events
                  markerBuilder: (ctx, day, events) {
                    if (events.isEmpty) return const SizedBox.shrink();
                    return Positioned(
                      bottom: 4,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: events
                            .take(3)
                            .map((_) => Container(
                                  width: 5,
                                  height: 5,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF16A34A),
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
                      fontSize: 13),
                  weekendTextStyle: TextStyle(
                      color: _DT.ink.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w500,
                      fontSize: 13),
                  outsideTextStyle:
                      const TextStyle(color: _DT.inkMuted, fontSize: 13),
                  selectedDecoration: const BoxDecoration(
                      color: Colors.transparent, shape: BoxShape.circle),
                  todayDecoration: const BoxDecoration(
                      color: Colors.transparent, shape: BoxShape.circle),
                  cellMargin: const EdgeInsets.all(4),
                  // Markers config
                  markersMaxCount: 3,
                  markerDecoration: const BoxDecoration(
                      color: Color(0xFF16A34A), shape: BoxShape.circle),
                  markerSize: 5,
                  markerMargin: const EdgeInsets.symmetric(horizontal: 1),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(
                      color: _DT.inkSecond.withValues(alpha: 0.70),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5),
                  weekendStyle: TextStyle(
                      color: _DT.inkSecond.withValues(alpha: 0.50),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5),
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _DT.ink,
                      letterSpacing: -0.3),
                  leftChevronIcon: _chevronBtn(Icons.chevron_left_rounded),
                  rightChevronIcon: _chevronBtn(Icons.chevron_right_rounded),
                  leftChevronPadding: EdgeInsets.zero,
                  rightChevronPadding: EdgeInsets.zero,
                  leftChevronMargin: const EdgeInsets.only(left: 8),
                  rightChevronMargin: const EdgeInsets.only(right: 8),
                  headerPadding: const EdgeInsets.only(bottom: 12),
                  decoration: const BoxDecoration(color: Colors.transparent),
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

  Widget _chevronBtn(IconData icon) => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: const Color(0xFF16A34A).withValues(alpha: 0.25)),
        ),
        child: Icon(icon, color: const Color(0xFF16A34A), size: 18),
      );

  // ── Application card ─────────────────────────────────────────────────

  // ── Section label ────────────────────────────────────────────────────
  Widget _sectionLabel(String title, String sub) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
              color: const Color(0xFF0F766E),
              borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 10),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _DT.ink,
                letterSpacing: -0.4)),
        Text(sub,
            style: const TextStyle(
                fontSize: 11.5,
                color: _DT.inkSecond,
                fontWeight: FontWeight.w400)),
      ])),
    ]);
  }
}

// ── Status config value object ─────────────────────────────────────────────

// =============================================================================
// _EventFeedCard — rich card with multi-image carousel + zoom
// Ported from student_dashboard_screen.dart and adapted for Event model
// =============================================================================
class _EventFeedCard extends StatefulWidget {
  final Event event;
  const _EventFeedCard({required this.event});

  @override
  State<_EventFeedCard> createState() => _EventFeedCardState();
}

class _EventFeedCardState extends State<_EventFeedCard> {
  int _currentImageIndex = 0;

  /// Resolve final list of image URLs (multi > single > empty)
  List<String> get _imageUrls {
    if (widget.event.imageUrls.isNotEmpty) return widget.event.imageUrls;
    if (widget.event.imageUrl != null && widget.event.imageUrl!.isNotEmpty) {
      return [widget.event.imageUrl!];
    }
    return [];
  }

  /// Build the right ImageProvider — handles base64 data URIs and network URLs
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
    final isUpcoming = !DateTime(widget.event.date.year,
            widget.event.date.month, widget.event.date.day)
        .isBefore(today);
    final urls = _imageUrls;
    final hasImages = urls.isNotEmpty;
    final hasMultiple = urls.length > 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUpcoming
              ? const Color(0xFF16A34A).withValues(alpha: 0.18)
              : const Color(0xFFE8E9F3),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Image / Carousel ──────────────────────────────────
          if (hasImages)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                children: [
                  // Multi-image carousel
                  if (hasMultiple)
                    SizedBox(
                      height: 200,
                      child: PageView.builder(
                        itemCount: urls.length,
                        onPageChanged: (index) =>
                            setState(() => _currentImageIndex = index),
                        itemBuilder: (_, index) => GestureDetector(
                          onTap: () => _openZoom(context, urls[index]),
                          child: _buildImage(urls[index], 200),
                        ),
                      ),
                    )
                  else
                    // Single image
                    GestureDetector(
                      onTap: () => _openZoom(context, urls.first),
                      child: _buildImage(urls.first, 200),
                    ),

                  // Dot indicators (multi only)
                  if (hasMultiple)
                    Positioned(
                      bottom: 10,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: urls.asMap().entries.map((entry) {
                          final isActive = entry.key == _currentImageIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: isActive ? 18 : 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  // Image counter badge (multi only)
                  if (hasMultiple)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_currentImageIndex + 1} / ${urls.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // ── Text content ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Org name + status pill
                Row(children: [
                  Expanded(
                    child: Text(
                      widget.event.orgName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F766E),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: isUpcoming
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isUpcoming ? 'Upcoming' : 'Past',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isUpcoming
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ]),

                const SizedBox(height: 8),

                // Title
                Text(
                  widget.event.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F0D2E),
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),

                // Description
                if (widget.event.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    widget.event.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B6B8E),
                      height: 1.55,
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Date chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isUpcoming
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 11,
                        color: isUpcoming
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _formatDate(widget.event.date),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isUpcoming
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      showEventComments(context,
                          eventId: widget.event.id,
                          eventTitle: widget.event.title);
                    },
                    icon: const Icon(Icons.forum_outlined, size: 17),
                    label: EventCommentCountLabel(eventId: widget.event.id, style: const TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF15803D)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Shared image widget with placeholder + error fallback
  Widget _buildImage(String url, double height) {
    // base64 data URI
    if (url.startsWith('data:')) {
      try {
        final base64Str = url.substring(url.indexOf(',') + 1);
        return Image.memory(
          base64Decode(base64Str),
          width: double.infinity,
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _imageFallback(height),
        );
      } catch (_) {
        return _imageFallback(height);
      }
    }

    // Network URL
    return Image.network(
      url,
      width: double.infinity,
      height: height,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          height: height,
          color: const Color(0xFFDCFCE7),
          child: const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF16A34A),
              strokeWidth: 2,
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) => _imageFallback(height),
    );
  }

  Widget _imageFallback(double height) => Container(
        height: height,
        color: const Color(0xFFDCFCE7),
        child: const Icon(Icons.broken_image_rounded,
            color: Color(0xFF16A34A), size: 36),
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
