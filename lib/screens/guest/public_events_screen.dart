import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/analytics_service.dart';
import '../../core/app_state.dart';
import '../auth/unified_login_page.dart';
import '../analytics/event_comments_sheet.dart';
import '../organizations/org_list_screen.dart';
import '../organizations/org_profile_screen.dart';
import '../../widgets/app_header.dart';

const _kGreen = Color(0xFF128058);
const _kGreenDark = Color(0xFF075A3D);
const _kGreenBright = Color(0xFF20B77D);
const _kBg = Color(0xFFF3F8F5);
const _kMint = Color(0xFFF0F9F5);
const _kInk = Color(0xFF17382C);
const _kMuted = Color(0xFF6B8178);
const _kLine = Color(0xFFD7EBE2);

/// Horizontal gutter that keeps content centered with a max width
/// while the scroll view itself stays full width.
double _gutter(double w) =>
    w < 600 ? 14 : math.max(24.0, (w - (w < 900 ? 860 : 1160)) / 2);

BoxDecoration _cardDeco(double r) => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(r),
      border: Border.all(color: _kLine),
      boxShadow: [
        BoxShadow(
            color: _kGreenDark.withValues(alpha: .05),
            blurRadius: 14,
            offset: const Offset(0, 5)),
      ],
    );

Widget _orb(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color));

Widget _ph() => Container(
      decoration: const BoxDecoration(
        gradient:
            LinearGradient(colors: [Color(0xFFDDF5E9), Color(0xFFB6E5D0)]),
      ),
      child: const Center(
          child: Icon(Icons.event_rounded, color: _kGreenDark, size: 28)),
    );

class PublicEventsScreen extends StatefulWidget {
  const PublicEventsScreen({super.key});

  @override
  State<PublicEventsScreen> createState() => _PublicEventsScreenState();
}

class _PublicEventsScreenState extends State<PublicEventsScreen> {
  static const Duration _postLifetime = Duration(days: 30);

  List<Event> _events = <Event>[];
  bool _loading = true;
  bool _showAllEvents = false;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _eventsKey = GlobalKey();
  RealtimeChannel? _eventsChannel;

  @override
  void initState() {
    super.initState();
    _load();
    _eventsChannel = Supabase.instance.client.channel('public-events-screen')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'events',
        callback: (_) {
          if (mounted) _load();
        },
      )
      ..subscribe();
  }

  @override
  void dispose() {
    final channel = _eventsChannel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await Supabase.instance.client
          .from('events')
          .select('*')
          .order('created_at', ascending: false)
          .limit(100);

      final result = <Event>[];
      for (final row in rows as List) {
        final imageUrls = row['image_urls'] is List
            ? List<String>.from(row['image_urls'] as List)
            : <String>[];
        final eventDate = DateTime.tryParse(row['date']?.toString() ?? '');
        if (eventDate == null) continue;
        result.add(Event(
          id: row['id'].toString(),
          title: row['title']?.toString() ?? '',
          date: eventDate,
          description: row['description']?.toString() ?? '',
          orgName: row['org_name']?.toString() ?? '',
          orgId: row['org_id']?.toString(),
          imageUrl: row['image_url']?.toString(),
          imageUrls: imageUrls,
          createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '')
                  ?.toLocal() ??
              eventDate.toLocal(),
        ));
      }

      if (mounted) {
        setState(() {
          result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _events = result;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }

    await AnalyticsService.instance
        .logUsage('guest_open', route: 'guest/events');
  }

  void _openLogin() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const UnifiedLoginPage()));
  }

  void _openOrganizations() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const OrgListScreen(showBackButton: true)));
  }

  List<Event> get _upcomingEvents {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cutoff = now.subtract(_postLifetime);
    // Compare calendar days, not the current clock time: events dated today
    // must remain visible even when their stored date is midnight.
    final result = _events.where((e) {
      final eventDay = DateTime(e.date.year, e.date.month, e.date.day);
      return !eventDay.isBefore(today) && !e.createdAt.isBefore(cutoff);
    }).toList();
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  List<Event> get _pastEvents {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cutoff = now.subtract(_postLifetime);
    final result = _events.where((e) {
      final eventDay = DateTime(e.date.year, e.date.month, e.date.day);
      return eventDay.isBefore(today) || e.createdAt.isBefore(cutoff);
    }).toList();
    result.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
    });
    return result;
  }

  void _scrollToEvents() {
    final targetContext = _eventsKey.currentContext;
    if (targetContext == null) return;

    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openComments(Event e) async {
    await AnalyticsService.instance.logEventView(e.id);
    if (!mounted) return;
    await showEventComments(context, eventId: e.id, eventTitle: e.title);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final mediaSize = MediaQuery.sizeOf(context);
          final w = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : mediaSize.width;
          final g = _gutter(w);
          final isMobile = w < 600;
          final ts = MediaQuery.textScalerOf(context)
              .scale(1.0)
              .clamp(1.0, 1.4)
              .toDouble();
          final upcoming = _upcomingEvents;
          final visible = _showAllEvents ? upcoming : upcoming.take(5).toList();
          final history = _pastEvents;

          SliverToBoxAdapter pad(Widget child,
                  [double top = 0, double bottom = 0]) =>
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(g, top, g, bottom),
                  child: child,
                ),
              );

          return RefreshIndicator(
            color: _kGreen,
            onRefresh: _load,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: const <PointerDeviceKind>{
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                  PointerDeviceKind.stylus,
                },
              ),
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: w >= 600,
                trackVisibility: w >= 600,
                interactive: true,
                thickness: 7,
                radius: const Radius.circular(10),
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    pad(_hero(w), 14),
                    pad(const _InterestMatchCard(), 14),
                    pad(_sectionHeader(upcoming.length)),
                    if (_loading)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: CircularProgressIndicator(color: _kGreen),
                        ),
                      )
                    else if (upcoming.isEmpty && !_showAllEvents)
                      pad(_emptyState(), 0, 20)
                    else ...[
                      ..._eventSlivers(
                        visible,
                        g: g,
                        mobile: isMobile,
                        ts: ts,
                        w: w,
                        featuredFirst: true,
                      ),
                      if (!_showAllEvents && upcoming.length > 5)
                        pad(
                          Center(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  setState(() => _showAllEvents = true),
                              icon:
                                  const Icon(Icons.grid_view_rounded, size: 18),
                              label: Text('View all ${upcoming.length} events'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _kGreenDark,
                                side: const BorderSide(color: _kGreen),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          4,
                          24,
                        ),
                      if (_showAllEvents) ...[
                        pad(
                          const Text(
                            'Event history',
                            style: TextStyle(
                              color: _kInk,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.3,
                            ),
                          ),
                          8,
                          12,
                        ),
                        if (history.isEmpty)
                          pad(_emptyHistoryState(), 0, 12)
                        else
                          ..._eventSlivers(
                            history,
                            g: g,
                            mobile: isMobile,
                            ts: ts,
                            w: w,
                            featuredFirst: false,
                          ),
                      ],
                    ],
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ============================================================
  // HERO
  // ============================================================

  Widget _hero(double w) {
    final m = w < 600;
    final d = w >= 1024;
    final pad = m ? 18.0 : 28.0;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppHeader.brandGradient,
        borderRadius: BorderRadius.circular(m ? 26 : 30),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF0B6B4D).withValues(alpha: .22),
              blurRadius: 26,
              offset: const Offset(0, 12)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
              top: -45,
              right: -35,
              child: _orb(m ? 150 : 230, Colors.white.withValues(alpha: .09))),
          Positioned(
              top: m ? 95 : 150,
              right: m ? 35 : 100,
              child: _orb(52, Colors.white.withValues(alpha: .07))),
          Positioned(
              bottom: -70,
              left: -45,
              child: _orb(145, Colors.black.withValues(alpha: .08))),
          Padding(
            padding: EdgeInsets.fromLTRB(pad, m ? 16 : 22, pad, pad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: .12),
                              blurRadius: 10,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Image.asset(
                        'assets/icon/login_logo.png',
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.groups_rounded,
                            size: 24,
                            color: _kGreen),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ORGCONNECT',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5)),
                          SizedBox(height: 2),
                          Text('Campus community hub',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _openLogin,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: .5)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                        padding: EdgeInsets.symmetric(
                            horizontal: m ? 15 : 20, vertical: 10),
                      ),
                      child: const Text('Log in',
                          style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                SizedBox(height: m ? 18 : 30),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(30),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: .17)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_rounded,
                          size: 14, color: Colors.white),
                      SizedBox(width: 6),
                      Text('OPEN CAMPUS ACCESS',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .7)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Text(
                    'Discover campus life\nbefore you log in.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: m ? 27 : (d ? 40 : 34),
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.9,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: Text(
                    'Find organizations, discover what is happening next, and choose where you want to belong.',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: .84),
                        height: 1.42,
                        fontSize: m ? 14 : 15),
                  ),
                ),
                SizedBox(height: m ? 18 : 24),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: m ? 9999 : 420),
                  child: Row(
                    children: [
                      Expanded(
                          child: _heroAction(
                              Icons.event_available_rounded, 'Explore events',
                              filled: true, onTap: _scrollToEvents)),
                      const SizedBox(width: 9),
                      Expanded(
                          child: _heroAction(
                              Icons.groups_rounded, 'Organizations',
                              filled: false, onTap: _openOrganizations)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    _miniTrust(Icons.visibility_outlined, 'Browse freely'),
                    _miniTrust(Icons.login_rounded, 'Join when ready'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroAction(IconData icon, String label,
      {required bool filled, required VoidCallback onTap}) {
    return Material(
      color: filled ? Colors.white : Colors.white.withValues(alpha: .11),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Colors.white.withValues(alpha: filled ? .1 : .2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: filled ? _kGreenDark : Colors.white),
              const SizedBox(width: 7),
              Flexible(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: filled ? _kGreenDark : Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniTrust(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white.withValues(alpha: .72)),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: .72),
                fontSize: 10.5,
                fontWeight: FontWeight.w700)),
      ],
    );
  }

  // ============================================================
  // EVENTS
  // ============================================================

  Widget _sectionHeader(int count) {
    return Padding(
      key: _eventsKey,
      padding: const EdgeInsets.fromLTRB(2, 22, 2, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Upcoming events',
                    style: TextStyle(
                        color: _kInk,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.3)),
                const SizedBox(height: 4),
                Text(
                  _showAllEvents
                      ? 'Showing all posted events.'
                      : 'Latest posts from campus organizations.',
                  style: const TextStyle(color: _kMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          if (_showAllEvents)
            TextButton(
              onPressed: () => setState(() => _showAllEvents = false),
              child: const Text('Latest 5'),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: const Color(0xFFE2F6ED),
                  borderRadius: BorderRadius.circular(18)),
              child: Text('$count',
                  style: const TextStyle(
                      color: _kGreenDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 11.5)),
            ),
        ],
      ),
    );
  }

  List<Widget> _eventSlivers(
    List<Event> list, {
    required double g,
    required bool mobile,
    required double ts,
    required double w,
    required bool featuredFirst,
  }) {
    if (list.isEmpty) return const <Widget>[];

    if (mobile) {
      final hasFeatured = featuredFirst && list.isNotEmpty;
      final rest = hasFeatured ? list.sublist(1) : list;
      final thumb = w < 360 ? 76.0 : 88.0;
      return [
        if (hasFeatured)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(g, 0, g, 12),
            sliver: SliverToBoxAdapter(
              child: _featured(
                list.first,
                imageCacheWidth: math.max(1.0, w - (g * 2)),
              ),
            ),
          ),
        if (rest.isNotEmpty)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(g, 0, g, 12),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _tile(rest[index], thumb),
                ),
                childCount: rest.length,
              ),
            ),
          ),
      ];
    }

    // Tablet uses two columns; desktop uses three. The grid's main-axis extent
    // is calculated once per viewport and then scaled consistently for text.
    final crossAxisCount = w < 900 ? 2 : 3;
    final contentWidth = math.max(0.0, w - (g * 2));
    final cardWidth =
        (contentWidth - (16.0 * (crossAxisCount - 1))) / crossAxisCount;
    final baseExtent = math.max(380.0, (cardWidth / 1.6) + 190.0);

    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(g, 0, g, 16),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _verticalEventCard(
              list[index],
              isFeatured: featuredFirst && index == 0,
              imageCacheWidth: cardWidth,
            ),
            childCount: list.length,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            mainAxisExtent: baseExtent * ts,
          ),
        ),
      ),
    ];
  }

  String? _img(Event e) =>
      e.imageUrl ?? (e.imageUrls.isNotEmpty ? e.imageUrls.first : null);

  Widget _thumb(String? url, {required double cacheLogicalWidth}) {
    if (url == null || url.isEmpty) return _ph();

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (cacheLogicalWidth * dpr).round().clamp(1, 4096).toInt();
    return Stack(
      fit: StackFit.expand,
      children: [
        _ph(),
        Image.network(
          url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          cacheWidth: cacheWidth,
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: child,
            );
          },
          errorBuilder: (_, __, ___) => _ph(),
        ),
      ],
    );
  }

  Widget _surface({required VoidCallback onTap, required Widget child}) {
    return _HoverSurface(onTap: onTap, child: child);
  }

  Widget _org(Event e) => Text(
        e.orgName.isEmpty ? 'Campus organization' : e.orgName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: _kGreen,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      );

  Widget _dateRow(Event e) => Row(
        children: [
          const Icon(Icons.calendar_today_rounded, size: 15, color: _kGreen),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              DateFormat('MMM d, yyyy • h:mm a').format(e.date),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _kInk,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );

  Widget _commentBtn(Event e) => IconButton(
        tooltip: 'Comments',
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        onPressed: () => _openComments(e),
        icon: const Icon(Icons.forum_outlined, size: 20, color: _kGreen),
      );

  /// Compact horizontal card used on phones.
  Widget _tile(Event e, double thumb) {
    return _surface(
      onTap: () => _showDetails(e),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: thumb,
                height: thumb,
                child: _thumb(_img(e), cacheLogicalWidth: thumb),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _org(e),
                  const SizedBox(height: 3),
                  Text(
                    e.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _kInk,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _dateRow(e),
                ],
              ),
            ),
            _commentBtn(e),
          ],
        ),
      ),
    );
  }

  /// Short featured card retained for mobile screens.
  Widget _featured(
    Event e, {
    required double imageCacheWidth,
  }) {
    final image = Stack(
      fit: StackFit.expand,
      children: [
        _thumb(_img(e), cacheLogicalWidth: imageCacheWidth),
        Positioned(
          top: 10,
          left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Featured',
              style: TextStyle(
                color: _kGreenDark,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );

    final text = Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _org(e),
          const SizedBox(height: 5),
          Text(
            e.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _kInk,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          if (e.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              e.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _kMuted, height: 1.4, fontSize: 13),
            ),
          ],
          const SizedBox(height: 6),
          Row(children: [Expanded(child: _dateRow(e)), _commentBtn(e)]),
        ],
      ),
    );

    return _surface(
      onTap: () => _showDetails(e),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 160, child: image),
          text,
        ],
      ),
    );
  }

  /// Vertical event card for tablet and desktop grids.
  Widget _verticalEventCard(
    Event e, {
    required bool isFeatured,
    required double imageCacheWidth,
  }) {
    final image = AspectRatio(
      aspectRatio: 16 / 10,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
            child: _thumb(_img(e), cacheLogicalWidth: imageCacheWidth),
          ),
          if (isFeatured)
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Featured',
                  style: TextStyle(
                    color: _kGreenDark,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return _surface(
      onTap: () => _showDetails(e),
      child: SizedBox.expand(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            image,
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _org(e),
                    const SizedBox(height: 4),
                    Text(
                      e.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _kInk,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        height: 1.18,
                      ),
                    ),
                    if (e.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        e.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _kMuted,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(child: _dateRow(e)),
                        _commentBtn(e),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyHistoryState() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 2),
        child: Text(
          'No past events to show yet.',
          style: const TextStyle(color: _kMuted, fontSize: 13),
        ),
      );

  /// Full event details (full description, uncropped image, comments).
  void _showDetails(Event e) {
    final img = _img(e);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      constraints: const BoxConstraints(maxWidth: 560),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (img != null && img.isNotEmpty)
              SizedBox(
                height: 220,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _ph(),
                    Image.network(
                      img,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                      cacheWidth: (MediaQuery.devicePixelRatioOf(ctx) * 560)
                          .round()
                          .clamp(1, 4096)
                          .toInt(),
                      gaplessPlayback: true,
                      frameBuilder:
                          (context, child, frame, wasSynchronouslyLoaded) {
                        if (wasSynchronouslyLoaded) return child;
                        return AnimatedOpacity(
                          opacity: frame == null ? 0 : 1,
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          child: child,
                        );
                      },
                      errorBuilder: (_, __, ___) => _ph(),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _org(e),
                  const SizedBox(height: 6),
                  Text(e.title,
                      style: const TextStyle(
                          color: _kInk,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          height: 1.2)),
                  const SizedBox(height: 10),
                  _dateRow(e),
                  if (e.description.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(e.description,
                        style: const TextStyle(
                            color: _kMuted, fontSize: 14, height: 1.5)),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openComments(e);
                      },
                      icon: const Icon(Icons.forum_outlined, size: 18),
                      label: const Text('View comments'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _kGreen,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
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

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDeco(24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
                color: const Color(0xFFE2F6ED),
                borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.event_available_rounded,
                color: _kGreen, size: 30),
          ),
          const SizedBox(height: 14),
          const Text('No upcoming events',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: _kInk,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  height: 1.15)),
          const SizedBox(height: 6),
          const Text(
              'There are no upcoming events right now. Please check back later.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _kMuted, height: 1.45, fontSize: 13)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
                color: const Color(0xFFE2F6ED),
                borderRadius: BorderRadius.circular(14)),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, size: 15, color: _kGreenDark),
                SizedBox(width: 7),
                Flexible(
                  child: Text('New campus events will appear here',
                      style: TextStyle(
                          color: _kGreenDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// INTEREST QUIZ CARD
// ============================================================

class _InterestMatchCard extends StatefulWidget {
  const _InterestMatchCard();
  @override
  State<_InterestMatchCard> createState() => _InterestMatchCardState();
}

class _InterestMatchCardState extends State<_InterestMatchCard> {
  List<String>? _answers;
  final List<String> _answerCategories = <String>[];

  // Six dimensions are used instead of four broad buckets so the result can
  // distinguish, for example, theater/music from journalism and coding.
  static const _dimensions = <String>[
    'Leadership & Service',
    'Arts & Performance',
    'Media & Creativity',
    'Academic & Technology',
    'Faith & Community',
    'Support & Mentoring',
    'Sports & Wellness',
  ];

  final _questions = const <Map<String, dynamic>>[
    {
      'question':
          'When you picture your ideal campus experience, which moment would make you feel most fulfilled?',
      'options': <String>[
        'Leading a project that helps students or the campus',
        'Creating a performance, artwork, or music people remember',
        'Writing, filming, designing, or sharing stories with others',
        'Building a useful solution with technology or academic skills',
      ],
      'categories': <String>[
        'Leadership & Service',
        'Arts & Performance',
        'Media & Creativity',
        'Academic & Technology',
      ],
    },
    {
      'question':
          'When a group needs someone to step forward, which kind of role feels most natural to you?',
      'options': <String>[
        'Organizing people, projects, and community activities',
        'Performing, rehearsing, or directing a creative production',
        'Writing articles, creating media, or documenting events',
        'Helping classmates, mentoring others, or building a support network',
      ],
      'categories': <String>[
        'Leadership & Service',
        'Arts & Performance',
        'Media & Creativity',
        'Support & Mentoring',
      ],
    },
    {
      'question':
          'If you could spend your free time doing one thing on campus, what would leave you feeling that your time mattered?',
      'options': <String>[
        'Advocating for students and helping improve campus life',
        'Making art, music, theater, dance, or crafts',
        'Reading, writing, photography, video, or digital storytelling',
        'Coding, research, problem-solving, or learning new technology',
      ],
      'categories': <String>[
        'Leadership & Service',
        'Arts & Performance',
        'Media & Creativity',
        'Academic & Technology',
      ],
    },
    {
      'question':
          'After a difficult week, what kind of campus activity would you naturally want to return to?',
      'options': <String>[
        'An active group where I can train, compete, or stay healthy',
        'A creative space where I can express myself through performance',
        'A community where I can reflect, serve, and reconnect with others',
        'A supportive group where I can mentor, encourage, or be encouraged',
      ],
      'categories': <String>[
        'Sports & Wellness',
        'Arts & Performance',
        'Faith & Community',
        'Support & Mentoring',
      ],
    },
    {
      'question':
          'Which community would you still choose to belong to even if nobody asked you to join?',
      'options': <String>[
        'A community that creates change and serves students',
        'A community that celebrates creativity and expression',
        'A community built around faith, care, and service',
        'A community built around wellness, teamwork, and active challenges',
      ],
      'categories': <String>[
        'Leadership & Service',
        'Arts & Performance',
        'Faith & Community',
        'Sports & Wellness',
      ],
    },
  ];

  Future<void> _startQuiz() async {
    final answers = <String>[];
    final categories = <String>[];

    for (var index = 0; index < _questions.length; index++) {
      final q = _questions[index];
      final question = q['question'] as String;
      final options = List<String>.from(q['options'] as List);
      final optionCategories = List<String>.from(q['categories'] as List);

      if (!mounted) return;
      final answer = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            _questionDialog(context, index, question, options),
      );

      if (!mounted) return;
      if (answer == null) return;
      final selectedIndex = options.indexOf(answer);
      if (selectedIndex < 0) return;
      answers.add(answer);
      categories.add(optionCategories[selectedIndex]);
    }

    if (mounted) {
      setState(() {
        _answers = answers;
        _answerCategories
          ..clear()
          ..addAll(categories);
      });
    }
  }

  Widget _questionDialog(
      BuildContext context, int index, String question, List<String> options) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      scrollable: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF075A42), Color(0xFF20B77D)],
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.psychology_alt_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Question ${index + 1} of ${_questions.length}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0F8A61),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .4,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.black,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(question,
              style: const TextStyle(
                  color: _kInk,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  height: 1.25)),
          const SizedBox(height: 7),
          const Text('Choose the option that feels most like you.',
              style: TextStyle(color: _kMuted, fontSize: 11.5, height: 1.35)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                child: InkWell(
                  onTap: () => Navigator.pop(context, option),
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: const Color(0xFFCBE8DC)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                              color: const Color(0xFFE4F7EF),
                              borderRadius: BorderRadius.circular(9)),
                          child: const Icon(Icons.arrow_forward_rounded,
                              color: Color(0xFF0F8A61), size: 15),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(option,
                              style: const TextStyle(
                                  color: _kInk,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                  height: 1.25)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Map<String, double> _interestProfile() {
    final profile = <String, double>{
      for (final dimension in _dimensions) dimension: 0.0,
    };
    for (final category in _answerCategories) {
      if (profile.containsKey(category)) {
        profile[category] = profile[category]! + 1.0;
      }
    }
    return profile;
  }

  Map<String, double> _organizationProfile(Organization org) {
    final scores = <String, double>{
      for (final dimension in _dimensions) dimension: 0.0,
    };
    final category = org.category.toLowerCase();

    const categoryMap = <String, Map<String, double>>{
      'arts & performance': {'Arts & Performance': 1.0},
      'arts & crafts': {'Arts & Performance': 1.0},
      'arts & lifestyle': {
        'Arts & Performance': .72,
        'Media & Creativity': .30
      },
      'media & publications': {'Media & Creativity': 1.0},
      'literary & creative': {
        'Media & Creativity': .92,
        'Arts & Performance': .35
      },
      'academic & literary': {
        'Academic & Technology': .75,
        'Media & Creativity': .55
      },
      'academic & communication': {
        'Academic & Technology': .65,
        'Media & Creativity': .75
      },
      'technology & innovation': {
        'Academic & Technology': 1.0,
        'Media & Creativity': .25
      },
      'academic & leadership': {
        'Academic & Technology': .60,
        'Leadership & Service': .90
      },
      'leadership & governance': {'Leadership & Service': 1.0},
      'advocacy & social': {
        'Leadership & Service': .95,
        'Faith & Community': .20
      },
      'support & mentoring': {
        'Support & Mentoring': 1.0,
        'Leadership & Service': .30
      },
      'faith & spirituality': {'Faith & Community': 1.0},
      'health & wellness': {'Sports & Wellness': .92, 'Faith & Community': .18},
      'sports & recreation': {'Sports & Wellness': 1.0},
      'cultural & heritage': {
        'Arts & Performance': .62,
        'Media & Creativity': .50
      },
    };

    for (final entry in categoryMap.entries) {
      if (category == entry.key) {
        entry.value.forEach((key, value) => scores[key] = scores[key]! + value);
      }
    }

    final text =
        '${org.name} ${org.category} ${org.shortDesc} ${org.about} ${org.missionVision} ${org.activitiesHighlights.map((e) => '${e.type} ${e.content} ${e.caption}').join(' ')}'
            .toLowerCase();
    const keywordMap = <String, List<String>>{
      'Leadership & Service': [
        'student government',
        'student council',
        'governance',
        'leadership',
        'advocacy',
        'volunteer',
        'community service',
        'student voice',
        'campus improvement',
        'academic programs'
      ],
      'Arts & Performance': [
        'theater',
        'theatre',
        'music',
        'dance',
        'performance',
        'drama',
        'marching band',
        'drum',
        'lyre',
        'arts',
        'craft',
        'fashion'
      ],
      'Media & Creativity': [
        'publication',
        'journalism',
        'newsletter',
        'writing',
        'literary',
        'poetry',
        'photography',
        'media',
        'storytelling',
        'creative writing'
      ],
      'Academic & Technology': [
        'academic',
        'study',
        'tutoring',
        'research',
        'coding',
        'programming',
        'technology',
        'innovation',
        'hackathon',
        'workshop'
      ],
      'Faith & Community': [
        'christian',
        'faith',
        'spiritual',
        'ministry',
        'bible',
        'fellowship',
        'worship'
      ],
      'Support & Mentoring': [
        'peer support',
        'mentoring',
        'support group',
        'facilitator',
        'student support',
        'peer'
      ],
      'Sports & Wellness': [
        'sport',
        'sports',
        'fitness',
        'wellness',
        'athletic',
        'recreation',
        'motorcycle',
        'riding',
        'competition',
        'training'
      ],
    };

    for (final entry in keywordMap.entries) {
      var hits = 0;
      for (final keyword in entry.value) {
        if (text.contains(keyword)) hits++;
      }
      scores[entry.key] =
          scores[entry.key]! + (hits * .12).clamp(0.0, .42).toDouble();
    }

    return scores;
  }

  double _cosineSimilarity(Map<String, double> a, Map<String, double> b) {
    double dot = 0;
    double normA = 0;
    double normB = 0;
    for (final dimension in _dimensions) {
      final av = a[dimension] ?? 0;
      final bv = b[dimension] ?? 0;
      dot += av * bv;
      normA += av * av;
      normB += bv * bv;
    }
    if (normA == 0 || normB == 0) return 0;
    return dot / (math.sqrt(normA) * math.sqrt(normB));
  }

  List<MapEntry<Organization, int>> _recommendations() {
    if ((_answers ?? []).isEmpty || _answerCategories.isEmpty) return [];

    final profile = _interestProfile();
    final entries = <MapEntry<Organization, int>>[];

    for (final org in AppState.instance.organizations) {
      final organizationProfile = _organizationProfile(org);
      var similarity = _cosineSimilarity(profile, organizationProfile);

      // Give exact category alignment a small extra lift so an exact match is
      // preferred over an organization that only shares generic keywords.
      final topInterest = profile.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (topInterest.isNotEmpty && topInterest.first.value > 0) {
        final dominant = topInterest.first.key;
        final dominantOrgScore = organizationProfile[dominant] ?? 0;
        if (dominantOrgScore >= .9) similarity += .08;
      }

      final percent = (similarity.clamp(0.0, 1.0) * 100).round();
      entries.add(MapEntry(org, percent));
    }

    entries.sort((a, b) {
      final scoreCompare = b.value.compareTo(a.value);
      if (scoreCompare != 0) return scoreCompare;
      return a.key.name.toLowerCase().compareTo(b.key.name.toLowerCase());
    });

    return entries.take(4).toList();
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final recs = _answers == null
        ? const <MapEntry<Organization, int>>[]
        : _recommendations();
    final ts =
        MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.4).toDouble();
    final tileHeight = 84.0 * ts;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_kGreenDark, _kGreenBright],
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.psychology_alt_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Discover what fits you',
                      style: TextStyle(
                        color: _kInk,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Discover your fit through 5 thoughtful questions.',
                      style: TextStyle(color: _kMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (_answers != null)
                IconButton(
                  onPressed: _startQuiz,
                  icon: const Icon(Icons.replay_rounded, color: _kMuted),
                  tooltip: 'Retake quiz',
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_answers == null)
            LayoutBuilder(builder: (_, constraints) {
              final intro = const Text(
                'Your answers create an interest profile and surface organizations whose purpose and activities are closest to what you chose.',
                style: TextStyle(
                  color: _kMuted,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              );
              final button = FilledButton(
                onPressed: _startQuiz,
                style: FilledButton.styleFrom(
                  backgroundColor: _kGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Discover My Fit',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              );
              return constraints.maxWidth < 440
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [intro, const SizedBox(height: 12), button],
                    )
                  : Row(
                      children: [
                        Expanded(child: intro),
                        const SizedBox(width: 16),
                        button,
                      ],
                    );
            })
          else ...[
            const Text(
              'Closest matches to your answers',
              style: TextStyle(
                color: _kInk,
                fontWeight: FontWeight.w900,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Match score is based on your answer pattern and the organization’s category, description, mission, and activities.',
              style: TextStyle(color: _kMuted, fontSize: 11, height: 1.3),
            ),
            const SizedBox(height: 10),
            if (recs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'No organization matches are available yet. Please try again later.',
                  style: TextStyle(color: _kMuted, fontSize: 12),
                ),
              )
            else
              LayoutBuilder(builder: (_, constraints) {
                Widget tileAt(int index) => index < recs.length
                    ? _recTile(recs[index], height: tileHeight)
                    : SizedBox(height: tileHeight);

                if (constraints.maxWidth >= 880) {
                  final children = <Widget>[];
                  for (var i = 0; i < 4; i++) {
                    if (i > 0) children.add(const SizedBox(width: 10));
                    children.add(Expanded(child: tileAt(i)));
                  }
                  return SizedBox(
                    height: tileHeight,
                    child: Row(children: children),
                  );
                }

                if (constraints.maxWidth >= 440) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: tileAt(0)),
                          const SizedBox(width: 10),
                          Expanded(child: tileAt(1)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: tileAt(2)),
                          const SizedBox(width: 10),
                          Expanded(child: tileAt(3)),
                        ],
                      ),
                    ],
                  );
                }

                return SizedBox(
                  height: tileHeight,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: recs.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 9),
                    itemBuilder: (_, index) => SizedBox(
                      width: 215,
                      height: tileHeight,
                      child: _recTile(recs[index], height: tileHeight),
                    ),
                  ),
                );
              }),
          ],
        ],
      ),
    );
  }

  Widget _recTile(MapEntry<Organization, int> r, {required double height}) {
    final org = r.key;
    final logoSize = 46.0;
    final logoCacheWidth = (logoSize * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(1, 1024)
        .toInt();

    Widget logo;
    if (org.logoAsset.startsWith('http')) {
      logo = Image.network(
        org.logoAsset,
        width: logoSize,
        height: logoSize,
        fit: BoxFit.cover,
        cacheWidth: logoCacheWidth,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return Stack(
            fit: StackFit.expand,
            children: [
              _smallLogo(),
              AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: child,
              ),
            ],
          );
        },
        errorBuilder: (_, __, ___) => _smallLogo(),
      );
    } else {
      logo = Image.asset(
        org.logoAsset.isEmpty ? 'assets/primerabida.jpg' : org.logoAsset,
        width: logoSize,
        height: logoSize,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _smallLogo(),
      );
    }

    return SizedBox(
      height: height,
      child: Material(
        color: _kMint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _kLine),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => OrgDetailScreen(orgId: org.id)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: logoSize,
                  height: logoSize,
                  child: ClipOval(
                    child: logo,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${r.value}% match',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _kGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        org.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _kInk,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        org.category.isEmpty
                            ? 'Campus organization'
                            : org.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _kMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _smallLogo() => Container(
      color: const Color(0xFFE4F7EF),
      child:
          const Icon(Icons.groups_rounded, color: Color(0xFF0F8A61), size: 22));
}

/// Adds restrained hover feedback for mouse users without scaling the card.
class _HoverSurface extends StatefulWidget {
  const _HoverSurface({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_HoverSurface> createState() => _HoverSurfaceState();
}

class _HoverSurfaceState extends State<_HoverSurface> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        if (!_hovered) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (_hovered) setState(() => _hovered = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _hovered ? const Color(0xFFB4DCCB) : _kLine,
          ),
          boxShadow: [
            BoxShadow(
              color: _kGreenDark.withValues(alpha: _hovered ? .09 : .05),
              blurRadius: _hovered ? 18 : 14,
              offset: Offset(0, _hovered ? 7 : 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: Colors.transparent,
            child: InkWell(onTap: widget.onTap, child: widget.child),
          ),
        ),
      ),
    );
  }
}
