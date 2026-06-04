import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:photo_view/photo_view.dart';
import '../../core/app_state.dart';

// ── Design tokens ──────────────────────────────────────────────────────────
class _DT {
  static const bg = Color(0xFFF6F7FB);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF0F2F8);
  static const primary = Color(0xFF6C63FF);
  static const primaryLight = Color(0xFFEEEDFF);
  static const primaryMid = Color(0xFF9C96FF);
  static const gradStart = Color(0xFF7C74FF);
  static const gradEnd = Color(0xFF9F6EFF);
  static const ink = Color(0xFF0F0D2E);
  static const inkSecond = Color(0xFF6B6B8E);
  static const inkMuted = Color(0xFFB8B9CC);
  static const border = Color(0xFFE8E9F3);

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6)),
        BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2)),
      ];
  static List<BoxShadow> get glowShadow => [
        BoxShadow(
            color: primary.withOpacity(0.45), blurRadius: 16, spreadRadius: 1),
        BoxShadow(color: gradEnd.withOpacity(0.25), blurRadius: 28),
      ];
  static List<BoxShadow> get heroShadow => [
        BoxShadow(
            color: primary.withOpacity(0.30),
            blurRadius: 32,
            offset: const Offset(0, 12),
            spreadRadius: -4),
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
  late final AnimationController _entranceCtrl, _pulseCtrl;
  late final Animation<double> _entranceFade, _pulseAnim;
  late final Animation<Offset> _entranceSlide;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();

    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _entranceFade =
        CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _entranceSlide =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
            CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic));

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2800))
      ..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);

    _entranceCtrl.forward();

    // Ensure events are loaded
    AppState.instance.fetchEvents();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _pulseCtrl.dispose();
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
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
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
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                      child: SizedBox(
                          height: mq.padding.top + kToolbarHeight + 4)),

                  // ── Hero card ──────────────────────────────────────
                  SliverToBoxAdapter(
                      child: Padding(
                          padding: hp.copyWith(top: 4, bottom: 24),
                          child: _buildHeroCard(mq))),

                  // ── Calendar section label ─────────────────────────
                  SliverToBoxAdapter(
                      child: Padding(
                          padding: hp.copyWith(bottom: 12),
                          child: _sectionLabel('Calendar', 'Your schedule'))),

                  // ── Calendar card ──────────────────────────────────
                  SliverToBoxAdapter(
                      child: Padding(
                          padding: hp.copyWith(bottom: 0),
                          child: _buildCalendarCard(allEvents))),

                  // ── Selected day events (appears right below calendar)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: hp.copyWith(top: 16, bottom: 8),
                      child: _buildSelectedDaySection(selectedEvents),
                    ),
                  ),

                  // ── Applications section ───────────────────────────

                  const SliverToBoxAdapter(child: SizedBox(height: 96)),
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
        ? 'Today\'s Events'
        : DateFormat('MMMM d, yyyy').format(day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with selected date
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 4,
              height: 22,
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _DT.ink,
                        letterSpacing: -0.4),
                  ),
                  Text(
                    events.isEmpty
                        ? 'No events scheduled'
                        : '${events.length} event${events.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                        fontSize: 11.5,
                        color: _DT.inkSecond,
                        fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
          ],
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
                colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
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

  // ── App bar ──────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: AppBar(
            backgroundColor: _DT.bg.withOpacity(0.80),
            elevation: 0,
            centerTitle: true,
            automaticallyImplyLeading: false,
            title: const Text('Dashboard',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _DT.inkSecond,
                    letterSpacing: 0.2)),
          ),
        ),
      ),
    );
  }

  // ── Hero card ────────────────────────────────────────────────────────
  Widget _buildHeroCard(MediaQueryData mq) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final greetEmoji = hour < 12
        ? '☀️'
        : hour < 17
            ? '👋'
            : '🌙';

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) => Container(
        width: double.infinity,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(28),
          boxShadow: _DT.heroShadow,
        ),
        child: Stack(children: [
          Positioned(
              top: -30,
              right: -20,
              child: Opacity(
                  opacity: 0.18 + _pulseAnim.value * 0.07,
                  child: Container(
                      width: 160,
                      height: 160,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle)))),
          Positioned(
              bottom: -40,
              left: -24,
              child: Opacity(
                  opacity: 0.10 + (1 - _pulseAnim.value) * 0.06,
                  child: Container(
                      width: 130,
                      height: 130,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle)))),
          child!,
        ]),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.22),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.30)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(greetEmoji, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 5),
                Text(greeting,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.2)),
              ]),
            ),
            const Spacer(),
            // Show student name initial in avatar
            ListenableBuilder(
              listenable: AppState.instance,
              builder: (context, _) {
                final name = AppState.instance.currentStudent?.name ?? '';
                final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                return Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.50), width: 1.5),
                  ),
                  child: Center(
                    child: Text(initial,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                  ),
                );
              },
            ),
          ]),
          const SizedBox(height: 18),
          ListenableBuilder(
            listenable: AppState.instance,
            builder: (context, _) {
              final fullName = AppState.instance.currentStudent?.name ?? '';
              final firstName = fullName.trim().split(' ').first;
              return Text(
                firstName.isNotEmpty
                    ? 'Welcome Back, $firstName'
                    : 'Welcome Back',
                style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.08,
                    letterSpacing: -1.0),
              );
            },
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat('EEEE, MMMM d').format(DateTime.now()),
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.78)),
          ),
          const SizedBox(height: 22),
          Container(height: 1, color: Colors.white.withOpacity(0.20)),
          const SizedBox(height: 16),
          Row(children: [
            const Icon(Icons.rocket_launch_rounded,
                color: Colors.white, size: 14),
            const SizedBox(width: 6),
            const Text(
              'Your path to great organizations starts here.',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  letterSpacing: 0.1),
            ),
          ]),
        ]),
      ),
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
          child: TableCalendar(
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
                      color: const Color(0xFF06B6D4),
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
              todayBuilder: (ctx, day, _) => LayoutBuilder(builder: (ctx, c) {
                final size = (c.maxWidth * 0.80).clamp(30.0, 40.0);
                return Center(
                    child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF4F46E5), width: 1.8)),
                  alignment: Alignment.center,
                  child: Text('${day.day}',
                      style: const TextStyle(
                          color: Color(0xFF4F46E5),
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
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: const BoxDecoration(
                                color: Color(0xFF4F46E5),
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
                  color: _DT.ink, fontWeight: FontWeight.w500, fontSize: 13),
              weekendTextStyle: TextStyle(
                  color: _DT.ink.withOpacity(0.55),
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
                  color: Color(0xFF4F46E5), shape: BoxShape.circle),
              markerSize: 5,
              markerMargin: const EdgeInsets.symmetric(horizontal: 1),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                  color: _DT.inkSecond.withOpacity(0.70),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5),
              weekendStyle: TextStyle(
                  color: _DT.inkSecond.withOpacity(0.50),
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
        ),
      ),
    );
  }

  Widget _chevronBtn(IconData icon) => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.25)),
        ),
        child: Icon(icon, color: const Color(0xFF4F46E5), size: 18),
      );

  // ── Application card ─────────────────────────────────────────────────

  // ── Section label ────────────────────────────────────────────────────
  Widget _sectionLabel(String title, String sub) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
              color: const Color(0xFF06B6D4),
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
        final base64Str = url.substring(url.indexOf(',') + 1);
        return MemoryImage(base64Decode(base64Str));
      } catch (_) {}
    }
    return CachedNetworkImageProvider(url);
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
          body: PhotoView(
            imageProvider: _imageProvider(url),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2.5,
            backgroundDecoration: const BoxDecoration(color: Colors.black),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUpcoming = widget.event.date.isAfter(DateTime.now());
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
              ? const Color(0xFF4F46E5).withOpacity(0.18)
              : const Color(0xFFE8E9F3),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
                    CarouselSlider(
                      options: CarouselOptions(
                        height: 200,
                        viewportFraction: 1.0,
                        enableInfiniteScroll: urls.length > 1,
                        autoPlay: false,
                        onPageChanged: (index, _) =>
                            setState(() => _currentImageIndex = index),
                      ),
                      items: urls.map((url) {
                        return GestureDetector(
                          onTap: () => _openZoom(context, url),
                          child: _buildImage(url, 200),
                        );
                      }).toList(),
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
                                  : Colors.white.withOpacity(0.45),
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
                          color: Colors.black.withOpacity(0.45),
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
                        color: Color(0xFF06B6D4),
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
                          ? const Color(0xFFEEF2FF)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isUpcoming ? 'Upcoming' : 'Past',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isUpcoming
                            ? const Color(0xFF4F46E5)
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
                        ? const Color(0xFFEEF2FF)
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
                            ? const Color(0xFF4F46E5)
                            : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _formatDate(widget.event.date),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isUpcoming
                              ? const Color(0xFF4F46E5)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
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
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _imageFallback(height),
        );
      } catch (_) {
        return _imageFallback(height);
      }
    }

    // Network URL
    return CachedNetworkImage(
      imageUrl: url,
      width: double.infinity,
      height: height,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        height: height,
        color: const Color(0xFFEEF2FF),
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF4F46E5),
            strokeWidth: 2,
          ),
        ),
      ),
      errorWidget: (_, __, ___) => _imageFallback(height),
    );
  }

  Widget _imageFallback(double height) => Container(
        height: height,
        color: const Color(0xFFEEF2FF),
        child: const Icon(Icons.broken_image_rounded,
            color: Color(0xFF4F46E5), size: 36),
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
