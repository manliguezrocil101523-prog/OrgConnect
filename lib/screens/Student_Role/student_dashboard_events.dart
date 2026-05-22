import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'dart:ui';

class _DT {
  static const bg = Color(0xFFF6F7FB);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF0F2F8);

  static const primary = Color(0xFF6C63FF);
  static const primaryLight = Color(0xFFEEEDFF);
  static const primaryMid = Color(0xFF9C96FF);
  static const primaryDark = Color(0xFF4B44D6);

  static const gradStart = Color(0xFF7C74FF);
  static const gradEnd = Color(0xFF9F6EFF);

  static const emerald = Color(0xFF10B981);
  static const emeraldBg = Color(0xFFECFDF5);
  static const emeraldFg = Color(0xFF065F46);
  static const emeraldRing = Color(0xFFA7F3D0);

  static const amberBg = Color(0xFFFFFBEB);
  static const amberFg = Color(0xFF92400E);
  static const amberRing = Color(0xFFFDE68A);

  static const roseBg = Color(0xFFFFF1F2);
  static const roseFg = Color(0xFF9F1239);
  static const roseRing = Color(0xFFFFCDD3);

  static const indigoBg = Color(0xFFEEF2FF);
  static const indigoFg = Color(0xFF3730A3);
  static const indigoRing = Color(0xFFC7D2FE);

  static const ink = Color(0xFF0F0D2E); // near-black with a purple hint
  static const inkSecond = Color(0xFF6B6B8E);
  static const inkMuted = Color(0xFFB8B9CC);

  static const border = Color(0xFFE8E9F3);
  static const borderStrong = Color(0xFFD0D2E8);

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF6C63FF).withOpacity(0.06),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get glowShadow => [
        BoxShadow(
          color: primary.withOpacity(0.45),
          blurRadius: 16,
          spreadRadius: 1,
        ),
        BoxShadow(
          color: gradEnd.withOpacity(0.25),
          blurRadius: 28,
        ),
      ];

  static List<BoxShadow> get heroShadow => [
        BoxShadow(
          color: primary.withOpacity(0.30),
          blurRadius: 32,
          offset: const Offset(0, 12),
          spreadRadius: -4,
        ),
      ];
}

// ─────────────────────────────────────────────────────────────────────────
// Legacy constants preserved so nothing else in the codebase breaks.
// ─────────────────────────────────────────────────────────────────────────
class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  static const Color mintBg = Color(0xFFF6F7FB);
  static const Color tealHeader = Color(0xFF6C63FF);
  static const Color accent = Color(0xFF6C63FF);
  static const Color cardColor = Colors.white;

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard>
    with TickerProviderStateMixin {
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  late Map<DateTime, List<Event>> _events;

  // ── Entrance animation ────────────────────────────────────────────────
  late final AnimationController _entranceCtrl;
  late final Animation<double> _entranceFade;
  late final Animation<Offset> _entranceSlide;

  // ── Hero pulse ────────────────────────────────────────────────────────
  // Subtle breathing glow on the hero card; runs once on mount.
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = _focusedDay;
    _loadEvents();

    // Entrance: 600 ms fade + 40 dp upward slide
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _entranceFade =
        CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _entranceSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic));

    // Pulse: gentle 2 s loop for the hero decorative orbs.
    // Keep duration long so it never feels distracting.
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);

    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── UNTOUCHED data helpers ───────────────────────────────────────────

  void _loadEvents() {
    final events = AppState.instance.eventsForCurrentStudent();
    _events = {};
    for (var event in events) {
      final day = DateTime(event.date.year, event.date.month, event.date.day);
      _events[day] = (_events[day] ?? [])..add(event);
    }
  }

  void _showEventsForDay(DateTime day) {
    final events = _events[day] ?? [];
    if (events.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DayEventsSheet(day: day, events: events),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final sw = mq.size.width;
    // Responsive horizontal padding: 5.5% of width, clamped for tablets.
    final hPad = (sw * 0.055).clamp(16.0, 28.0);
    final hp = EdgeInsets.symmetric(horizontal: hPad);

    return Scaffold(
      backgroundColor: _DT.bg,
      // No traditional AppBar — we overlay a blur bar inside the scroll.
      extendBodyBehindAppBar: true,
      appBar: _buildGhostAppBar(context),
      body: AnimatedBuilder(
        animation: AppState.instance,
        builder: (context, _) {
          _loadEvents();

          final events = AppState.instance.eventsForCurrentStudent();
          final applications = AppState.instance.applications
              .where((a) =>
                  a.studentId == AppState.instance.currentStudent?.studentId)
              .toList();

          // UNTOUCHED: interview filter
          final regularEvents = events
              .where((e) => !e.title.toLowerCase().contains('interview'))
              .toList();

          return FadeTransition(
            opacity: _entranceFade,
            child: SlideTransition(
              position: _entranceSlide,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Space for the blurred AppBar
                  SliverToBoxAdapter(
                    child:
                        SizedBox(height: mq.padding.top + kToolbarHeight + 4),
                  ),

                  // ── HERO CARD ──────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: hp.copyWith(top: 4, bottom: 24),
                      child: _buildHeroCard(mq),
                    ),
                  ),

                  // ── CALENDAR ───────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: hp.copyWith(bottom: 12),
                      child: _sectionLabel('Calendar', 'Your schedule'),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: hp.copyWith(bottom: 32),
                      child: _buildCalendarCard(),
                    ),
                  ),

                  // ── APPLICATIONS ───────────────────────────────────
                  if (applications.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: hp.copyWith(bottom: 14),
                        child: _sectionLabel(
                            'My Applications', '${applications.length} total'),
                      ),
                    ),
                    SliverPadding(
                      padding: hp,
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => _buildApplicationCard(applications[i]),
                          childCount: applications.length,
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 28)),
                  ],

                  // ── EVENTS ─────────────────────────────────────────
                  if (regularEvents.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: hp.copyWith(bottom: 14),
                        child: _sectionLabel(
                            'Upcoming Events', 'Organisation schedule'),
                      ),
                    ),
                    SliverPadding(
                      padding: hp,
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => _buildEventCard(regularEvents[i]),
                          childCount: regularEvents.length,
                        ),
                      ),
                    ),
                  ],

                  // ── EMPTY STATE ────────────────────────────────────
                  if (events.isEmpty && applications.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: hp,
                        child: _buildEmptyState(),
                      ),
                    ),

                  // Bottom FAB clearance
                  const SliverToBoxAdapter(child: SizedBox(height: 96)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // GHOST APP BAR
  // Frosted glass strip; uses BackdropFilter for depth without a heavy
  // elevation shadow that would clash with the hero card below.
  // ═══════════════════════════════════════════════════════════════════════
  PreferredSizeWidget _buildGhostAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: AppBar(
            backgroundColor: _DT.bg.withOpacity(0.80),
            elevation: 0,
            centerTitle: true,
            title: const Text(
              'Dashboard',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _DT.inkSecond,
                letterSpacing: 0.2,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: _PressableScale(
                  onTap: () {
                    AppState.instance.setRole(null);
                    Navigator.of(context)
                        .pushNamedAndRemoveUntil('/login', (r) => false);
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _DT.surface,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: _DT.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.home_rounded,
                      size: 18,
                      color: _DT.inkSecond,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HERO CARD
  // Full-bleed gradient card that sets the tone. The decorative orbs use
  // the pulse animation for subtle life — they're clipped so they never
  // overflow. AnimatedBuilder rebuilds ONLY this subtree.
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildHeroCard(MediaQueryData mq) {
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    // Emoji that matches the time of day — a small youthful touch.
    final greetEmoji = hour < 12
        ? '☀️'
        : hour < 17
            ? '👋'
            : '🌙';

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: _DT.heroShadow,
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              // ── Decorative orb top-right ──────────────────────────
              Positioned(
                top: -30,
                right: -20,
                child: Opacity(
                  opacity: 0.18 + _pulseAnim.value * 0.07,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              // ── Decorative orb bottom-left ────────────────────────
              Positioned(
                bottom: -40,
                left: -24,
                child: Opacity(
                  opacity: 0.10 + (1 - _pulseAnim.value) * 0.06,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),

              // ── Content ───────────────────────────────────────────
              child!,
            ],
          ),
        );
      },
      // child is built once and passed through AnimatedBuilder for perf.
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row: greeting pill + avatar
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Greeting pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.30)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        greetEmoji,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        greeting,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Avatar / user icon
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.50), width: 1.5),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Main heading
            const Text(
              'Welcome Back',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.08,
                letterSpacing: -1.0,
              ),
            ),
            const SizedBox(height: 6),

            // Date line
            Row(
              children: [
                Flexible(
                  child: Text(
                    DateFormat('EEEE, MMMM d').format(DateTime.now()),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.78),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            // Divider line
            Container(
              height: 1,
              color: Colors.white.withOpacity(0.20),
            ),
            const SizedBox(height: 16),

            // Motivational tagline
            Row(
              children: [
                const Icon(
                  Icons.rocket_launch_rounded,
                  color: Colors.white,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Your path to great organisations starts here.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.82),
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // CALENDAR CARD
  // Wrapped in a clean surface card. Custom builders override every
  // visible element so the calendar matches the design system exactly.
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildCalendarCard() {
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
          child: TableCalendar<Event>(
            availableGestures: AvailableGestures.horizontalSwipe,
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
            eventLoader: (d) => _events[d] ?? [],
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
              _showEventsForDay(selected);
            },
            calendarBuilders: CalendarBuilders(
              // Selected day — gradient circle with glow
              selectedBuilder: (ctx, day, _) => LayoutBuilder(
                builder: (ctx, constraints) {
                  final size = (constraints.maxWidth * 0.80).clamp(30.0, 40.0);
                  return Center(
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        color: const Color(0xFF06B6D4),
                        shape: BoxShape.circle,
                        boxShadow: _DT.glowShadow,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${day.day}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Today — soft ring, no fill
              todayBuilder: (ctx, day, _) => LayoutBuilder(
                builder: (ctx, constraints) {
                  final size = (constraints.maxWidth * 0.80).clamp(30.0, 40.0);
                  return Center(
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF4F46E5), width: 1.8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${day.day}',
                        style: const TextStyle(
                          color: Color(0xFF4F46E5),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Event marker — clean indigo dot
              markerBuilder: (ctx, day, events) {
                if (events.isEmpty) return const SizedBox.shrink();
                return Positioned(
                  bottom: 5,
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                        color: _DT.primary, shape: BoxShape.circle),
                  ),
                );
              },
            ),
            calendarStyle: CalendarStyle(
              defaultTextStyle: const TextStyle(
                color: _DT.ink,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              weekendTextStyle: TextStyle(
                color: _DT.ink.withOpacity(0.55),
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              outsideTextStyle: const TextStyle(
                color: _DT.inkMuted,
                fontSize: 13,
              ),
              // Suppress default decorations; our builders handle these.
              selectedDecoration: const BoxDecoration(
                  color: Colors.transparent, shape: BoxShape.circle),
              todayDecoration: const BoxDecoration(
                  color: Colors.transparent, shape: BoxShape.circle),
              markerDecoration: const BoxDecoration(
                  color: Colors.transparent, shape: BoxShape.circle),
              cellMargin: const EdgeInsets.all(4),
              markersMaxCount: 1,
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                color: _DT.inkSecond.withOpacity(0.70),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
              weekendStyle: TextStyle(
                color: _DT.inkSecond.withOpacity(0.50),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _DT.ink,
                letterSpacing: -0.3,
              ),
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
          border: Border.all(color: Color(0xFF4F46E5).withOpacity(0.25)),
        ),
        child: Icon(icon, color: const Color(0xFF4F46E5), size: 18),
      );

  // ═══════════════════════════════════════════════════════════════════════
  // APPLICATION CARD
  // Left accent bar (color-coded by status) gives each card instant
  // scanability without relying solely on the pill badge.
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildApplicationCard(Application app) {
    final cfg = _statusConfig(app.status);

    return _PressableScale(
      onTap: () {},
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _DT.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _DT.border),
          boxShadow: _DT.cardShadow,
        ),
        clipBehavior: Clip.hardEdge,
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Accent bar — status color at a glance
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: cfg.fg,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                  child: Row(
                    children: [
                      // Icon badge
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: _DT.primaryLight,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.business_center_rounded,
                          color: _DT.primary,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Text
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              app.orgName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _DT.ink,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _getStatusText(app.status),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: _DT.inkSecond,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _buildStatusPill(app.status),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // EVENT CARD
  // Date badge design: upcoming events use primary tint; past use muted.
  // A thin top border in the primary color on upcoming events adds urgency.
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildEventCard(Event event) {
    final isUpcoming = event.date.isAfter(DateTime.now());

    return _PressableScale(
      onTap: () {},
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _DT.surface,
          borderRadius: BorderRadius.circular(20),
          // Upcoming events get a subtle primary top-border accent.
          border: Border.all(
            color: isUpcoming ? _DT.primary.withOpacity(0.18) : _DT.border,
          ),
          boxShadow: _DT.cardShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date badge
              Container(
                width: 52,
                height: 58,
                decoration: BoxDecoration(
                  gradient: isUpcoming
                      ? const LinearGradient(
                          colors: [_DT.primaryLight, Color(0xFFE4E2FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isUpcoming ? null : _DT.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: isUpcoming
                      ? Border.all(color: _DT.primary.withOpacity(0.20))
                      : Border.all(color: _DT.border),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('d').format(event.date),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isUpcoming ? _DT.primary : _DT.inkMuted,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      DateFormat('MMM').format(event.date).toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: isUpcoming ? _DT.primaryMid : _DT.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _DT.ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      event.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _DT.inkSecond,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Time pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: isUpcoming ? _DT.primaryLight : _DT.surfaceAlt,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 10,
                            color: isUpcoming ? _DT.primary : _DT.inkSecond,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTime(event.date),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                              color: isUpcoming ? _DT.primary : _DT.inkSecond,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: isUpcoming ? _DT.primaryMid : _DT.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STATUS PILL
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildStatusPill(ApplicationStatus status) {
    final s = _statusConfig(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: s.ring, width: 1),
      ),
      child: Text(
        s.label,
        style: TextStyle(
          color: s.fg,
          fontWeight: FontWeight.w700,
          fontSize: 10.5,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  _StatusCfg _statusConfig(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.pending:
        return const _StatusCfg(
            'Pending', _DT.amberBg, _DT.amberFg, _DT.amberRing);
      case ApplicationStatus.for_approval:
        return const _StatusCfg(
            'Approval', _DT.amberBg, _DT.amberFg, _DT.amberRing);
      case ApplicationStatus.accepted:
        return const _StatusCfg(
            'Accepted', _DT.emeraldBg, _DT.emeraldFg, _DT.emeraldRing);
      case ApplicationStatus.interview_scheduled:
        return const _StatusCfg(
            'Interview', _DT.indigoBg, _DT.indigoFg, _DT.indigoRing);
      case ApplicationStatus.declined:
        return const _StatusCfg(
            'Declined', _DT.roseBg, _DT.roseFg, _DT.roseRing);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SECTION LABEL
  // ═══════════════════════════════════════════════════════════════════════
  Widget _sectionLabel(String title, String sub) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Primary accent pip
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0xFF06B6D4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _DT.ink,
                  letterSpacing: -0.4,
                ),
              ),
              Text(
                sub,
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
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // EMPTY STATE
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF06B6D4),
              borderRadius: BorderRadius.circular(24),
              boxShadow: _DT.heroShadow,
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              size: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'All clear!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: _DT.ink,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No events or applications yet.\nOrganisation updates will show here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: _DT.inkSecond,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // ── UNTOUCHED logic helpers ──────────────────────────────────────────

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final per = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $per';
  }

  String _getStatusText(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.pending:
        return 'Pending Review';
      case ApplicationStatus.for_approval:
        return 'For Approval';
      case ApplicationStatus.accepted:
        return 'Accepted';
      case ApplicationStatus.interview_scheduled:
        return 'Interview Scheduled';
      case ApplicationStatus.declined:
        return 'Declined';
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DAY EVENTS SHEET
// ═══════════════════════════════════════════════════════════════════════════
class _DayEventsSheet extends StatelessWidget {
  final DateTime day;
  final List<Event> events;

  const _DayEventsSheet({required this.day, required this.events});

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sidePad = (sw * 0.06).clamp(16.0, 28.0);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: EdgeInsets.fromLTRB(
        sidePad,
        12,
        sidePad,
        MediaQuery.of(context).viewInsets.bottom + 36,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag pill
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: _DT.inkMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 22),

          // Day heading with gradient accent
          Row(
            children: [
              Container(
                width: 4,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_DT.gradStart, _DT.gradEnd],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE').format(day),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _DT.ink,
                      letterSpacing: -0.6,
                    ),
                  ),
                  Text(
                    DateFormat('MMMM d, yyyy').format(day),
                    style: const TextStyle(
                      fontSize: 13,
                      color: _DT.inkSecond,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          Container(height: 1, color: _DT.border),
          const SizedBox(height: 16),

          ...events.map((e) => _SheetRow(event: e)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SHEET ROW
// ═══════════════════════════════════════════════════════════════════════════
class _SheetRow extends StatelessWidget {
  final Event event;
  const _SheetRow({required this.event});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_DT.gradStart, _DT.gradEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child:
                const Icon(Icons.event_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _DT.ink,
                    )),
                Text(event.description,
                    style: const TextStyle(fontSize: 12, color: _DT.inkSecond),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _DT.primaryLight,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              _fmt(event.date),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _DT.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final per = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $per';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PRESSABLE SCALE — tap feedback via scale transform
// Performance: uses a dedicated AnimationController instead of
// GestureDetector + implicit animations to keep rebuild scope minimal.
// ═══════════════════════════════════════════════════════════════════════════
class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PressableScale({required this.child, required this.onTap});

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      lowerBound: 0,
      upperBound: 1,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) {
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: AnimatedBuilder(
          animation: _scale,
          builder: (_, child) =>
              Transform.scale(scale: _scale.value, child: child),
          child: widget.child,
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// STATUS CONFIG — value object, const-safe
// ═══════════════════════════════════════════════════════════════════════════
class _StatusCfg {
  final String label;
  final Color bg, fg, ring;
  const _StatusCfg(this.label, this.bg, this.fg, this.ring);
}
