import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, HapticFeedback;
import 'package:intl/intl.dart' show DateFormat;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../widgets/app_header.dart';
import '../../screens/Student_Role/home/home_tokens.dart';

import '../../core/app_state.dart';
import '../../core/app_state.dart' as app_models;

import '../analytics/event_comments_sheet.dart';
import '../community/org_community_chat_screen.dart';
import 'officer_applications_screen.dart';
import 'officer_events_screen.dart';
import 'officer_members_screen.dart';
import 'officer_profile_screen.dart';
import 'officer_org_profile_screen.dart';
import '../organizations/org_list_screen.dart';
import '../../core/new_applications_badge.dart';

// ---------------------------------------------------------------------------
// Design tokens (every color of this screen lives here; light-only for now)
// ---------------------------------------------------------------------------

abstract final class _OfficerColors {
  static const Color background = HC.bg;
  static const Color surface = Colors.white;
  static const Color border = HC.line;
  static const Color ink = HC.ink;
  static const Color muted = HC.muted;

  /// HC.muted is ~4.2:1 on white. This darker tone is used for small text.
  static const Color mutedText = Color(0xFF55695F);
  static const Color primary = HC.primary;

  /// Green used for text on mint/white and for fills carrying white text (>= 4.5:1).
  static const Color primaryStrong = Color(0xFF0B7A55);
  static const Color mint = HC.mint;
  static const Color danger = HC.danger;

  static const Color slate = Color(0xFF475569);
  static const Color slateSoft = Color(0xFFF1F5F9);

  static const Color amber = Color(0xFF92400E);
  static const Color amberSoft = Color(0xFFFEF3C7);
  static const Color amberBorder = Color(0xFFFCD34D);

  static const Color onHeader = Colors.white;
  static const Color onHeaderSoft = Color(0xE6FFFFFF);
  static const Color headerChip = Color(0x24FFFFFF);
  static const Color headerOrb = Color(0x12FFFFFF);
  static const Color statusDot = Color(0xFF86EFAC);

  static const Color shadow = Color(0x0D0F172A);
  static const Color snackbar = Color(0xFF1E293B);
  static const Color skeleton = Color(0xFFEDF2F0);
  static const Color skeletonHighlight = Color(0xFFDDE7E3);
  static const Color avatarBackground = Color(0xFFE0F5E8);
  static const Color currentBorder = Color(0xFF9BD7BA);

  static const Color hover = Color(0x99E4F7EF);
  static const Color focus = Color(0xCCE4F7EF);
  static const Color splash = Color(0x1F0F8A61);
  static const Color pressed = Color(0x140F8A61);
}

abstract final class _OfficerText {
  static const TextStyle section = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: _OfficerColors.ink,
    height: 1.25,
  );
  static const TextStyle cardTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: _OfficerColors.ink,
    height: 1.3,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: _OfficerColors.ink,
    height: 1.45,
  );
  static const TextStyle bodyMuted = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: _OfficerColors.mutedText,
    height: 1.45,
  );
  static const TextStyle meta = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: _OfficerColors.mutedText,
    height: 1.4,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: _OfficerColors.mutedText,
    height: 1.35,
  );
}

abstract final class _OfficerDecor {
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(16));
  static const List<BoxShadow> softShadow = [
    BoxShadow(
      color: _OfficerColors.shadow,
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];
}

/// Scoped to this screen only: lets mouse and trackpad drag scrollables.
class _OfficerScrollBehavior extends MaterialScrollBehavior {
  const _OfficerScrollBehavior({this.autoScrollbar = true});

  final bool autoScrollbar;

  @override
  Set<PointerDeviceKind> get dragDevices => const <PointerDeviceKind>{
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return autoScrollbar
        ? super.buildScrollbar(context, child, details)
        : child;
  }
}

// ---------------------------------------------------------------------------
// Small helpers and data
// ---------------------------------------------------------------------------

String _cleanOrgName(String name) =>
    name.replaceAll(RegExp(r'tiatro', caseSensitive: false), 'teatro').trim();

String _greetingFor(DateTime now) {
  final hour = now.hour;
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

String _firstNameOf(String fullName) {
  final first = fullName.trim().split(RegExp(r'\s+')).first;
  return first.isEmpty ? 'Officer' : first;
}

String _relativeDayLabel(int days) {
  if (days == 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  return 'in $days days';
}

String _formatTimeText(String raw) {
  final value = raw.trim();
  final match = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(value);
  if (match == null) return value;
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour > 23 || minute > 59) return value;
  return DateFormat('h:mm a').format(DateTime(2000, 1, 1, hour, minute));
}

enum _EventFilter { upcoming, past, all }

class _OfficerEvent {
  const _OfficerEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.venue,
    required this.startTime,
    required this.endTime,
    required this.date,
    required this.images,
  });

  factory _OfficerEvent.fromRow(Map<String, dynamic> row) {
    String text(String key) => row[key]?.toString().trim() ?? '';

    final images = <String>{};
    final single = text('image_url');
    if (single.isNotEmpty) images.add(single);
    final raw = row['image_urls'];
    if (raw is List) {
      for (final value in raw) {
        final url = value?.toString().trim() ?? '';
        if (url.isNotEmpty) images.add(url);
      }
    }
    final title = text('title');
    return _OfficerEvent(
      id: text('id'),
      title: title.isEmpty ? 'Untitled event' : title,
      description: text('description'),
      venue: text('venue'),
      startTime: text('start_time'),
      endTime: text('end_time'),
      date: DateTime.tryParse(text('date'))?.toLocal(),
      images: List<String>.unmodifiable(images),
    );
  }

  final String id;
  final String title;
  final String description;
  final String venue;
  final String startTime;
  final String endTime;
  final DateTime? date;
  final List<String> images;

  int get sortKey => date?.millisecondsSinceEpoch ?? 0;

  /// Calendar-day difference from [today]; null when the date is unparseable.
  int? daysFrom(DateTime today) {
    final d = date;
    if (d == null) return null;
    return DateTime.utc(d.year, d.month, d.day)
        .difference(DateTime.utc(today.year, today.month, today.day))
        .inDays;
  }

  String get timeLabel {
    final start = _formatTimeText(startTime);
    final end = _formatTimeText(endTime);
    if (start.isNotEmpty && end.isNotEmpty) return '$start – $end';
    if (start.isNotEmpty) return start;
    if (end.isNotEmpty) return end;
    final d = date;
    if (d != null && (d.hour != 0 || d.minute != 0)) {
      return DateFormat('h:mm a').format(d);
    }
    return '';
  }

  String get dateLabel {
    final d = date;
    return d == null
        ? 'Date to be announced'
        : DateFormat('EEE, MMM d, y').format(d);
  }

  String get whenLabel =>
      timeLabel.isEmpty ? dateLabel : '$dateLabel • $timeLabel';
}

class _EventBuckets {
  const _EventBuckets._(this.upcoming, this.past, this.undated);

  factory _EventBuckets.from(List<_OfficerEvent> events, DateTime now) {
    final upcoming = <_OfficerEvent>[];
    final past = <_OfficerEvent>[];
    final undated = <_OfficerEvent>[];
    for (final event in events) {
      final days = event.daysFrom(now);
      if (days == null) {
        undated.add(event);
      } else if (days >= 0) {
        upcoming.add(event);
      } else {
        past.add(event);
      }
    }
    upcoming.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    past.sort((a, b) => b.sortKey.compareTo(a.sortKey));
    return _EventBuckets._(upcoming, past, undated);
  }

  final List<_OfficerEvent> upcoming;
  final List<_OfficerEvent> past;
  final List<_OfficerEvent> undated;

  List<_OfficerEvent> forFilter(_EventFilter filter) => switch (filter) {
        _EventFilter.upcoming => upcoming,
        _EventFilter.past => past,
        _EventFilter.all => <_OfficerEvent>[...upcoming, ...past, ...undated],
      };
}

// ---------------------------------------------------------------------------
// Dashboard shell
// ---------------------------------------------------------------------------

class BaseOfficerDashboard extends StatefulWidget {
  final String orgId;
  final String orgName;

  const BaseOfficerDashboard({
    super.key,
    required this.orgId,
    required this.orgName,
  });

  @override
  State<BaseOfficerDashboard> createState() => _BaseOfficerDashboardState();
}

class _BaseOfficerDashboardState extends State<BaseOfficerDashboard> {
  final GlobalKey _pagesKey = GlobalKey(debugLabel: 'officerPages');

  int _selectedIndex = 0;
  Timer? _exitTimer;
  bool _exitArmed = false;

  List<_OfficerEvent> _events = const <_OfficerEvent>[];
  bool _loadingEvents = true;
  bool _refreshing = false;
  String? _eventsError;
  DateTime? _lastUpdated;
  int? _pendingApplicationsCount;

  String _avatarUrl = '';
  String _userName = '';
  String _position = 'Officer';

  @override
  void initState() {
    super.initState();
    unawaited(_loadOfficerHome());
    unawaited(NewApplicationsBadge.instance.start(widget.orgId));
  }

  @override
  void dispose() {
    _exitTimer?.cancel();
    unawaited(NewApplicationsBadge.instance.stop());
    super.dispose();
  }

  Future<void> _loadOfficerHome() async {
    // This optional count is intentionally fire-and-forget so it cannot delay
    // the event refresh or turn an otherwise successful refresh into a failure.
    unawaited(_loadPendingApplications());
    await Future.wait([
      _loadPublishedEvents(),
      _loadOfficerProfile(),
    ]);
    if (!mounted) return;
  }

  Future<void> _loadPendingApplications() async {
    try {
      final rows = await Supabase.instance.client
          .from('applications')
          .select('id')
          .eq('org_id', widget.orgId)
          .eq('status', 'pending');
      if (!mounted) return;
      setState(() => _pendingApplicationsCount = (rows as List).length);
    } catch (e) {
      debugPrint('Officer pending applications count unavailable: $e');
      if (!mounted) return;
      // Unknown is distinct from zero; do not show a misleading badge.
      setState(() => _pendingApplicationsCount = null);
    }
  }

  Future<void> _loadOfficerProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) return;
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('name,avatar_url')
          .eq('id', userId)
          .maybeSingle();
      if (!mounted) return;
      final membership = await Supabase.instance.client
          .from('members')
          .select('position')
          .eq('org_id', widget.orgId)
          .eq('profile_id', userId)
          .maybeSingle();
      if (!mounted) return;
      final position = membership?['position']?.toString().trim();
      setState(() {
        _userName = profile?['name']?.toString().trim() ?? '';
        _avatarUrl = profile?['avatar_url']?.toString().trim() ?? '';
        _position = position == null || position.isEmpty ? 'Officer' : position;
      });
    } catch (_) {
      // The dashboard remains usable even when profile details cannot load.
    }
  }

  Future<void> _loadPublishedEvents() async {
    if (_refreshing) return;
    _refreshing = true;
    if (mounted && !_loadingEvents) {
      setState(() {
        // A retry after a failed first load goes back to the skeleton.
        if (_lastUpdated == null) {
          _loadingEvents = true;
          _eventsError = null;
        }
      });
    }

    try {
      final response = await Supabase.instance.client
          .from('events')
          .select('*')
          .eq('org_id', widget.orgId)
          .order('date', ascending: true);
      if (!mounted) return;

      final parsed = (response as List)
          .map((row) => _OfficerEvent.fromRow(
                Map<String, dynamic>.from(row as Map),
              ))
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _events = parsed;
        _loadingEvents = false;
        _refreshing = false;
        _eventsError = null;
        _lastUpdated = DateTime.now();
      });
    } catch (e) {
      debugPrint('Officer events load failed: $e');
      if (!mounted) return;
      setState(() {
        // Previously loaded events are intentionally kept.
        _loadingEvents = false;
        _refreshing = false;
        _eventsError = _lastUpdated == null
            ? 'We could not load your events. Check your connection and try again.'
            : 'Could not refresh. Showing the events loaded earlier.';
      });
    }
  }

  void _handleBack() {
    if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
      return;
    }
    if (_exitArmed) return;

    setState(() => _exitArmed = true);
    _exitTimer?.cancel();
    _exitTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _exitArmed = false);
    });

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: const Text(
          'Press back again to exit',
          textAlign: TextAlign.center,
          style: TextStyle(color: _OfficerColors.onHeader),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        width: 240,
        backgroundColor: _OfficerColors.snackbar,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _selectTab(int index) {
    if (_selectedIndex == index) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _selectedIndex = index);
  }

  void _openEvents() => _selectTab(2);

  String _currentOrganizationLogo() {
    for (final org in AppState.instance.organizations) {
      if (org.id == widget.orgId) {
        return org.logoAsset.trim();
      }
    }
    return '';
  }

  Widget _buildPages(double width) {
    return HomeLayoutScope(
      key: _pagesKey,
      width: width,
      child: IndexedStack(
        index: _selectedIndex,
        children: [
          _HomeTab(
            orgId: widget.orgId,
            orgName: widget.orgName,
            events: _events,
            loading: _loadingEvents,
            refreshing: _refreshing,
            error: _eventsError,
            lastUpdated: _lastUpdated,
            pendingApplicationsCount: _pendingApplicationsCount,
            onRefresh: _loadOfficerHome,
            onRequestEvent: _openEvents,
            userName: _userName,
            avatarUrl: _avatarUrl,
            position: _position,
          ),
          _OfficerOrganizationsTab(
            orgId: widget.orgId,
            orgName: widget.orgName,
            position: _position,
          ),
          AnimatedBuilder(
            animation: AppState.instance,
            builder: (context, _) => OfficerEventsScreen(
              orgId: widget.orgId,
              orgName: widget.orgName,
              logoAsset: _currentOrganizationLogo(),
              embedded: true,
            ),
          ),
          OfficerProfileScreen(
            initialName: _userName,
            initialAvatarUrl: _avatarUrl,
            embedded: true,
            organizationId: widget.orgId,
            organizationName: widget.orgName,
          ),
        ],
      ),
    );
  }

  Widget _buildShell(BuildContext context, BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final layout = HomeLayout.fromWidth(width);

    if (layout.isMobile) {
      return Column(
        children: [
          Expanded(child: _buildPages(width)),
          AnimatedBuilder(
            animation: AppState.instance,
            builder: (context, _) => _OfficerBottomNav(
              selectedIndex: _selectedIndex,
              onSelected: _selectTab,
              communityUnread: _unreadOrganizationUpdatesCount(widget.orgId),
            ),
          ),
        ],
      );
    }

    final extended = layout.isDesktop;
    final railWidth =
        extended ? _OfficerRail.extendedWidth : _OfficerRail.compactWidth;
    return Row(
      children: [
        AnimatedBuilder(
          animation: AppState.instance,
          builder: (context, _) => _OfficerRail(
            selectedIndex: _selectedIndex,
            onSelected: _selectTab,
            extended: extended,
            communityUnread: _unreadOrganizationUpdatesCount(widget.orgId),
          ),
        ),
        const VerticalDivider(
          width: 1,
          thickness: 1,
          color: _OfficerColors.border,
        ),
        Expanded(child: _buildPages(width - railWidth - 1)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: kIsWeb || (_selectedIndex == 0 && _exitArmed),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: _OfficerColors.background,
        body: LayoutBuilder(builder: _buildShell),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Navigation widgets
// ---------------------------------------------------------------------------

class _NavDef {
  const _NavDef(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const List<_NavDef> _kNavItems = <_NavDef>[
  _NavDef('Home', Icons.home_outlined, Icons.home_rounded),
  _NavDef('Organizations', Icons.business_outlined, Icons.business_rounded),
  _NavDef('Events', Icons.event_outlined, Icons.event_rounded),
  _NavDef('Profile', Icons.person_outline_rounded, Icons.person_rounded),
];

class _OfficerBottomNav extends StatelessWidget {
  const _OfficerBottomNav({
    required this.selectedIndex,
    required this.onSelected,
    required this.communityUnread,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final int communityUnread;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _OfficerColors.surface,
        border: Border(top: BorderSide(color: _OfficerColors.border)),
      ),
      child: HomeLayout.capText(
        context,
        Builder(
          builder: (inner) => MediaQuery.removePadding(
            context: inner,
            removeTop: true,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;

                final iconSize = (width * 0.065).clamp(22.0, 30.0).toDouble();

                final fontSize = (width * 0.028).clamp(10.0, 13.0).toDouble();

                final barHeight = (width * 0.18).clamp(56.0, 72.0).toDouble();

                return NavigationBarTheme(
                  data: NavigationBarThemeData(
                    backgroundColor: _OfficerColors.surface,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,

                    // Remove the background behind the selected icon.
                    indicatorColor: Colors.transparent,

                    labelTextStyle: WidgetStateProperty.resolveWith((states) {
                      final selected = states.contains(WidgetState.selected);

                      return TextStyle(
                        fontSize: fontSize,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                        color: selected
                            ? _OfficerColors.primaryStrong
                            : _OfficerColors.mutedText,
                      );
                    }),

                    iconTheme: WidgetStateProperty.resolveWith((states) {
                      final selected = states.contains(WidgetState.selected);

                      return IconThemeData(
                        size: iconSize,
                        color: selected
                            ? const Color(0xFF0F8A61)
                            : _OfficerColors.mutedText,
                      );
                    }),
                  ),
                  child: NavigationBar(
                    height: barHeight,
                    selectedIndex: selectedIndex,
                    onDestinationSelected: onSelected,
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysShow,
                    destinations: [
                      for (var i = 0; i < _kNavItems.length; i++)
                        NavigationDestination(
                          icon: i == 1
                              ? Badge(
                                  isLabelVisible: communityUnread > 0,
                                  label: Text('$communityUnread'),
                                  child: Icon(_kNavItems[i].icon),
                                )
                              : Icon(_kNavItems[i].icon),
                          selectedIcon: i == 1
                              ? Badge(
                                  isLabelVisible: communityUnread > 0,
                                  label: Text('$communityUnread'),
                                  child: Icon(_kNavItems[i].selectedIcon),
                                )
                              : Icon(_kNavItems[i].selectedIcon),
                          label: _kNavItems[i].label,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        maxScale: 1.2,
      ),
    );
  }
}

class _OfficerRail extends StatelessWidget {
  const _OfficerRail({
    required this.selectedIndex,
    required this.onSelected,
    required this.extended,
    required this.communityUnread,
  });

  static const double compactWidth = 88;
  static const double extendedWidth = 232;

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool extended;
  final int communityUnread;

  @override
  Widget build(BuildContext context) {
    final labelSize = extended ? 14.0 : 12.0;
    return SizedBox(
      width: extended ? extendedWidth : compactWidth,
      child: ColoredBox(
        color: _OfficerColors.surface,
        child: SafeArea(
          right: false,
          child: HomeLayout.capText(
            context,
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: NavigationRail(
                      backgroundColor: _OfficerColors.surface,
                      selectedIndex: selectedIndex,
                      onDestinationSelected: onSelected,
                      extended: extended,
                      minWidth: compactWidth,
                      minExtendedWidth: extendedWidth,
                      labelType: extended
                          ? NavigationRailLabelType.none
                          : NavigationRailLabelType.all,
                      groupAlignment: -1,
                      indicatorColor: Colors.transparent,
                      selectedIconTheme: const IconThemeData(
                        color: Color(0xFF0F8A61),
                        size: 24,
                      ),
                      unselectedIconTheme: const IconThemeData(
                        color: _OfficerColors.mutedText,
                        size: 24,
                      ),
                      selectedLabelTextStyle: TextStyle(
                        fontSize: labelSize,
                        fontWeight: FontWeight.w800,
                        color: _OfficerColors.primaryStrong,
                      ),
                      unselectedLabelTextStyle: TextStyle(
                        fontSize: labelSize,
                        fontWeight: FontWeight.w600,
                        color: _OfficerColors.mutedText,
                      ),
                      leading: const SizedBox(height: 8),
                      destinations: [
                        for (var i = 0; i < _kNavItems.length; i++)
                          NavigationRailDestination(
                            icon: i == 1
                                ? Badge(
                                    isLabelVisible: communityUnread > 0,
                                    label: Text('$communityUnread'),
                                    child: Icon(_kNavItems[i].icon),
                                  )
                                : Icon(_kNavItems[i].icon),
                            selectedIcon: i == 1
                                ? Badge(
                                    isLabelVisible: communityUnread > 0,
                                    label: Text('$communityUnread'),
                                    child: Icon(_kNavItems[i].selectedIcon),
                                  )
                                : Icon(_kNavItems[i].selectedIcon),
                            label: Text(
                              _kNavItems[i].label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            maxScale: 1.2,
          ),
        ),
      ),
    );
  }
}

/// Navigation shared by the Organizations tab and the Home quick actions.
abstract final class _OfficerNav {
  static void applications(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OfficerApplicationsScreen()),
    );
  }

  static void members(BuildContext context, String orgId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OfficerMembersScreen(organizationId: orgId),
      ),
    );
  }

  static void orgProfile(BuildContext context, String orgId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OfficerOrgProfileScreen(orgId: orgId),
      ),
    );
  }

  static void community(BuildContext context, String orgId, String orgName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrgCommunityChatScreen(
          orgId: orgId,
          orgName: orgName,
          showBackButton: true,
        ),
      ),
    );
  }

  static void joinedOrganizations(
    BuildContext context,
    String orgId,
    String orgName,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _OfficerJoinedOrganizationsScreen(
          currentOrgId: orgId,
          currentOrgName: orgName,
        ),
      ),
    );
  }

  static void browseOrganizations(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const OrgListScreen(showBackButton: true),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _OfficerHeader extends StatelessWidget {
  const _OfficerHeader({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.leading,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final String status;
  final Widget leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final layout = HomeLayout.of(context);
    final top = MediaQuery.paddingOf(context).top;
    final titleSize = layout.isMobile ? 22.0 : 26.0;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        gradient: AppHeader.brandGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Stack(
        children: [
          const Positioned(right: -48, top: -64, child: _HeaderOrb(size: 176)),
          Padding(
            padding: EdgeInsets.only(top: top + 20, bottom: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: HomeBreakpoints.maxContentWidth,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: layout.homeHPad),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      leading,
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _OfficerColors.onHeader,
                                  fontSize: titleSize,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _OfficerColors.onHeaderSoft,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 8,
                                  height: 8,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: _OfficerColors.statusDot,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Flexible(
                                  child: Text(
                                    status,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _OfficerColors.onHeader,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (trailing != null) ...[
                        const SizedBox(width: 8),
                        trailing!,
                      ],
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
}

class _HeaderOrb extends StatelessWidget {
  const _HeaderOrb({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _OfficerColors.headerOrb,
        ),
      ),
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  const _HeaderAvatar({required this.avatarUrl});

  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    final hasImage = avatarUrl.isNotEmpty;
    return Semantics(
      label: 'Profile photo',
      image: true,
      child: Container(
        width: AppHeader.leadingSize,
        height: AppHeader.leadingSize,
        padding: const EdgeInsets.all(3),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: _OfficerColors.headerChip,
        ),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: _OfficerColors.surface,
          ),
          child: CircleAvatar(
            backgroundColor: _OfficerColors.avatarBackground,
            backgroundImage: hasImage ? NetworkImage(avatarUrl) : null,
            onBackgroundImageError: hasImage ? (_, __) {} : null,
            child: hasImage
                ? null
                : const Icon(
                    Icons.person_rounded,
                    color: _OfficerColors.primary,
                    size: 30,
                  ),
          ),
        ),
      ),
    );
  }
}

class _HeaderLogo extends StatelessWidget {
  const _HeaderLogo({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppHeader.leadingSize,
      height: AppHeader.leadingSize,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _OfficerColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: _OfficerOrgLogo(asset: asset, size: AppHeader.leadingSize - 6),
    );
  }
}

class _HeaderRefreshButton extends StatelessWidget {
  const _HeaderRefreshButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: busy ? 'Refreshing…' : 'Refresh',
      onPressed: busy ? null : onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: Colors.transparent,
        foregroundColor: _OfficerColors.onHeader,
        disabledBackgroundColor: Colors.transparent,
        disabledForegroundColor: _OfficerColors.onHeaderSoft,
      ),
      icon: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _OfficerColors.onHeader,
              ),
            )
          : const Icon(Icons.refresh_rounded),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared building blocks
// ---------------------------------------------------------------------------

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.child,
    this.onTap,
    this.highlight = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: _OfficerDecor.cardRadius,
        boxShadow: _OfficerDecor.softShadow,
      ),
      child: Material(
        color: _OfficerColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: _OfficerDecor.cardRadius,
          side: BorderSide(
            color: highlight ? _OfficerColors.primary : _OfficerColors.border,
            width: highlight ? 1.5 : 1,
          ),
        ),
        child: onTap == null
            ? child
            : InkWell(
                onTap: onTap,
                hoverColor: _OfficerColors.hover,
                focusColor: _OfficerColors.focus,
                splashColor: _OfficerColors.splash,
                highlightColor: _OfficerColors.pressed,
                child: child,
              ),
      ),
    );
  }
}

class _IconCircle extends StatelessWidget {
  const _IconCircle({
    required this.icon,
    this.size = 40,
    this.neutral = false,
  });

  final IconData icon;
  final double size;
  final bool neutral;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: neutral ? _OfficerColors.slateSoft : _OfficerColors.mint,
        ),
        child: Center(
          child: Icon(
            icon,
            size: size * 0.5,
            color: neutral ? _OfficerColors.slate : _OfficerColors.primary,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(text, style: _OfficerText.section),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text, this.maxLines = 1});

  final IconData icon;
  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: _OfficerColors.muted),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: _OfficerText.meta,
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(
      {required this.label,
      required this.background,
      required this.foreground});

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({
    required this.date,
    this.past = false,
    this.onImage = false,
  });

  final DateTime? date;
  final bool past;
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    final d = date;
    final accent = past ? _OfficerColors.slate : _OfficerColors.primaryStrong;
    final background = onImage
        ? _OfficerColors.surface
        : (past ? _OfficerColors.slateSoft : _OfficerColors.mint);

    return Container(
      constraints: const BoxConstraints(minWidth: 52),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        boxShadow: onImage ? _OfficerDecor.softShadow : null,
      ),
      child: d == null
          ? Icon(Icons.calendar_today_rounded, size: 22, color: accent)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('MMM').format(d).toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: accent,
                  ),
                ),
                Text(
                  '${d.day}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: _OfficerColors.ink,
                  ),
                ),
              ],
            ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({this.showIcon = true});

  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _OfficerColors.slateSoft,
      child: showIcon
          ? const Center(
              child: Icon(
                Icons.image_outlined,
                size: 36,
                color: _OfficerColors.muted,
              ),
            )
          : null,
    );
  }
}

class _EventImage extends StatelessWidget {
  const _EventImage({required this.url, this.memCacheWidth = 800});

  final String url;
  final int memCacheWidth;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: url.isEmpty
          ? const _ImageFallback()
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              memCacheWidth: memCacheWidth,
              fadeInDuration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              placeholder: (_, __) => const _ImageFallback(showIcon: false),
              errorWidget: (_, __, ___) => const _ImageFallback(),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Home tab
// ---------------------------------------------------------------------------

class _HomeTab extends StatefulWidget {
  const _HomeTab({
    required this.orgId,
    required this.orgName,
    required this.events,
    required this.loading,
    required this.refreshing,
    required this.error,
    required this.lastUpdated,
    required this.pendingApplicationsCount,
    required this.onRefresh,
    required this.onRequestEvent,
    required this.userName,
    required this.avatarUrl,
    required this.position,
  });

  final String orgId;
  final String orgName;
  final List<_OfficerEvent> events;
  final bool loading;
  final bool refreshing;
  final String? error;
  final DateTime? lastUpdated;
  final int? pendingApplicationsCount;
  final Future<void> Function() onRefresh;
  final VoidCallback onRequestEvent;
  final String userName;
  final String avatarUrl;
  final String position;

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  _EventFilter _filter = _EventFilter.upcoming;
  String _search = '';
  bool _latestFirst = false;

  @override
  void dispose() {
    _scroll.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _setFilter(_EventFilter filter) {
    if (filter == _filter) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _filter = filter);
  }

  void _clearSearch() {
    if (_searchController.text.isNotEmpty) {
      _searchController.clear(); // onChanged updates _search.
    } else if (_search.isNotEmpty) {
      setState(() => _search = '');
    }
  }

  void _retry() => unawaited(widget.onRefresh());

  Widget _buildEventsArea({
    required HomeLayout layout,
    required List<_OfficerEvent> shown,
    required bool hasLoaded,
    required DateTime now,
    required bool hasSearchQuery,
  }) {
    final columns = HomeLayout.gridColumns(
      layout.homeInnerWidth,
      minItemWidth: 300,
      gap: layout.cardGap,
      maxColumns: 3,
    );
    final error = widget.error;

    if (!hasLoaded && widget.loading) {
      return _EventsSkeleton(
        columns: columns,
        itemWidth: HomeLayout.gridItemWidth(
          layout.homeInnerWidth,
          columns,
          gap: layout.cardGap,
        ),
        gap: layout.cardGap,
      );
    }
    if (!hasLoaded && error != null) {
      return _StateCard(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load events',
        message: error,
        actionLabel: 'Retry',
        onAction: _retry,
      );
    }
    if (widget.events.isEmpty) {
      return _StateCard(
        icon: Icons.event_note_rounded,
        title: 'No events posted yet',
        message:
            'When the adviser publishes an event for your organization, it will appear here.',
        actionLabel: 'Request an event',
        onAction: widget.onRequestEvent,
      );
    }
    if (shown.isEmpty && hasSearchQuery) {
      return _StateCard(
        icon: Icons.search_off_rounded,
        title: 'No events match',
        message:
            'Try another title, venue, or description, or clear your search.',
        actionLabel: 'Clear search',
        onAction: _clearSearch,
      );
    }
    if (shown.isEmpty) {
      return switch (_filter) {
        _EventFilter.upcoming => const _StateCard(
            icon: Icons.event_available_rounded,
            title: 'No upcoming events',
            message:
                'Nothing is scheduled right now. Request an event or check the Past filter.',
          ),
        _EventFilter.past => const _StateCard(
            icon: Icons.history_rounded,
            title: 'No past events yet',
            message: 'Events will show up here after their date has passed.',
          ),
        _EventFilter.all => const _StateCard(
            icon: Icons.event_busy_rounded,
            title: 'No events to show',
            message: 'Posted events will appear here.',
          ),
      };
    }

    final animationDisabled = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration:
          animationDisabled ? Duration.zero : const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      child: KeyedSubtree(
        key: ValueKey<String>('${_filter.name}|$_search|$_latestFirst'),
        child: _EventGrid(
          events: shown,
          today: now,
          columns: columns,
          width: layout.homeInnerWidth,
          gap: layout.cardGap,
          onOpen: (event) => _OfficerEventDetailsSheet.show(context, event),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final layout = HomeLayout.of(context);
    final now = DateTime.now();
    final buckets = _EventBuckets.from(widget.events, now);
    final baseShown = buckets.forFilter(_filter);
    final hasLoaded = widget.lastUpdated != null;
    final error = widget.error;
    final updated = widget.lastUpdated;
    final next = buckets.upcoming.isEmpty ? null : buckets.upcoming.first;
    final nextDays = next?.daysFrom(now);
    final canSearch = hasLoaded && widget.events.length >= 6;
    final query = canSearch ? _search.trim().toLowerCase() : '';
    var shown = baseShown.where((event) {
      if (query.isEmpty) return true;
      return event.title.toLowerCase().contains(query) ||
          event.venue.toLowerCase().contains(query) ||
          event.description.toLowerCase().contains(query);
    }).toList(growable: false);
    if (_latestFirst) shown = shown.reversed.toList(growable: false);

    final displayName = _firstNameOf(widget.userName);
    final cleanPosition =
        widget.position.trim().isEmpty ? 'Officer' : widget.position.trim();
    final subtitle = widget.loading && !hasLoaded
        ? 'Your organization at a glance'
        : (nextDays == 0
            ? 'Event today'
            : nextDays != null
                ? 'Next event: ${_relativeDayLabel(nextDays)}'
                : (buckets.past.isNotEmpty
                    ? 'No upcoming events scheduled'
                    : 'No events scheduled yet'));

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasLoaded && error != null) ...[
          _StaleBanner(message: error, onRetry: _retry),
          SizedBox(height: layout.sectionGap),
        ],
        _AttentionStrip(
          orgId: widget.orgId,
          orgName: widget.orgName,
          pendingApplicationsCount: widget.pendingApplicationsCount,
        ),
        if (next != null && nextDays != null) ...[
          SizedBox(height: layout.sectionGap),
          _NextEventCard(
            event: next,
            daysUntil: nextDays,
            onTap: () => _OfficerEventDetailsSheet.show(context, next),
          ),
        ],
        SizedBox(height: layout.sectionGap),
        const _SectionTitle('Quick actions'),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: AppState.instance,
          builder: (context, _) => _QuickActions(
            width: layout.homeInnerWidth,
            gap: layout.cardGap,
            actions: [
              _QuickActionData(
                icon: Icons.event_available_rounded,
                label: 'Request event',
                onTap: widget.onRequestEvent,
              ),
              _QuickActionData(
                icon: Icons.assignment_rounded,
                label: 'Applications',
                onTap: () => _OfficerNav.applications(context),
              ),
              _QuickActionData(
                icon: Icons.groups_rounded,
                label: 'Members',
                onTap: () => _OfficerNav.members(context, widget.orgId),
              ),
              _QuickActionData(
                icon: Icons.forum_rounded,
                label: 'Community chat',
                badgeCount: _unreadOrganizationUpdatesCount(widget.orgId),
                onTap: () => _OfficerNav.community(
                  context,
                  widget.orgId,
                  widget.orgName,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: layout.sectionGap),
        const _SectionTitle('Posted events'),
        const SizedBox(height: 2),
        if (updated != null)
          Text(
            'Updated ${DateFormat('h:mm a').format(updated)}',
            style: _OfficerText.caption,
          )
        else
          const Text('Your published event list', style: _OfficerText.caption),
        const SizedBox(height: 12),
        _StatsRow(
          posted: hasLoaded ? widget.events.length : null,
          upcoming: hasLoaded ? buckets.upcoming.length : null,
          past: hasLoaded ? buckets.past.length : null,
          filter: _filter,
          compact: layout.isSmallMobile,
          gap: layout.cardGap,
          onSelect: _setFilter,
        ),
        const SizedBox(height: 12),
        _FilterBar(
          filter: _filter,
          posted: hasLoaded ? widget.events.length : null,
          upcoming: hasLoaded ? buckets.upcoming.length : null,
          past: hasLoaded ? buckets.past.length : null,
          onChanged: _setFilter,
        ),
        if (canSearch) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _search = value),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search title, venue, or description',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: _clearSearch,
                            icon: const Icon(Icons.close_rounded),
                          ),
                    filled: true,
                    fillColor: _OfficerColors.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: _OfficerColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: _OfficerColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: _OfficerColors.primaryStrong,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message:
                    _latestFirst ? 'Show soonest first' : 'Show latest first',
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _latestFirst = !_latestFirst),
                  icon: Icon(
                    _latestFirst ? Icons.south_rounded : Icons.north_rounded,
                  ),
                  label: Text(_latestFirst ? 'Latest' : 'Soonest'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _OfficerColors.primaryStrong,
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    side: const BorderSide(color: _OfficerColors.border),
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        _buildEventsArea(
          layout: layout,
          shown: shown,
          hasLoaded: hasLoaded,
          now: now,
          hasSearchQuery: query.isNotEmpty,
        ),
      ],
    );

    return HomeLayout.capText(
      context,
      ScrollConfiguration(
        behavior: const _OfficerScrollBehavior(autoScrollbar: false),
        child: Scrollbar(
          controller: _scroll,
          thumbVisibility: layout.isDesktop,
          child: RefreshIndicator(
            color: _OfficerColors.primary,
            backgroundColor: _OfficerColors.surface,
            onRefresh: widget.onRefresh,
            child: ListView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                _OfficerHeader(
                  title: '${_greetingFor(now)}, $displayName',
                  subtitle: subtitle,
                  status: '${_cleanOrgName(widget.orgName)} • $cleanPosition',
                  leading: _HeaderAvatar(avatarUrl: widget.avatarUrl),
                  trailing: _HeaderRefreshButton(
                    busy: widget.refreshing || widget.loading,
                    onPressed: _retry,
                  ),
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: HomeBreakpoints.maxContentWidth,
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        layout.homeHPad,
                        layout.sectionGap,
                        layout.homeHPad,
                        40,
                      ),
                      child: body,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      maxScale: 1.3,
    );
  }
}

class _AttentionStrip extends StatelessWidget {
  const _AttentionStrip({
    required this.orgId,
    required this.orgName,
    required this.pendingApplicationsCount,
  });

  final String orgId;
  final String orgName;
  final int? pendingApplicationsCount;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final updates = _unreadOrganizationUpdatesCount(orgId);
        final pending = pendingApplicationsCount;
        if (updates == 0 && (pending == null || pending == 0)) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: _SurfaceCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.notifications_active_outlined,
                        size: 18,
                        color: _OfficerColors.primaryStrong,
                      ),
                      SizedBox(width: 8),
                      Text('Needs your attention',
                          style: _OfficerText.cardTitle),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (updates > 0)
                        OutlinedButton.icon(
                          onPressed: () => _OfficerNav.community(
                            context,
                            orgId,
                            orgName,
                          ),
                          icon: const Icon(Icons.forum_outlined, size: 18),
                          label: Text(
                            '$updates new community update${updates == 1 ? '' : 's'}',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _OfficerColors.primaryStrong,
                            minimumSize: const Size(48, 48),
                            side:
                                const BorderSide(color: _OfficerColors.border),
                          ),
                        ),
                      if (pending != null && pending > 0)
                        OutlinedButton.icon(
                          onPressed: () => _OfficerNav.applications(context),
                          icon: const Icon(Icons.assignment_outlined, size: 18),
                          label: Text(
                            '$pending pending application${pending == 1 ? '' : 's'}',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _OfficerColors.primaryStrong,
                            minimumSize: const Size(48, 48),
                            side:
                                const BorderSide(color: _OfficerColors.border),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.posted,
    required this.upcoming,
    required this.past,
    required this.filter,
    required this.compact,
    required this.gap,
    required this.onSelect,
  });

  final int? posted;
  final int? upcoming;
  final int? past;
  final _EventFilter filter;
  final bool compact;
  final double gap;
  final ValueChanged<_EventFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.event_rounded,
              label: 'Posted',
              value: posted,
              selected: filter == _EventFilter.all,
              compact: compact,
              onTap: () => onSelect(_EventFilter.all),
            ),
          ),
          SizedBox(width: gap),
          Expanded(
            child: _StatCard(
              icon: Icons.upcoming_rounded,
              label: 'Upcoming',
              value: upcoming,
              selected: filter == _EventFilter.upcoming,
              compact: compact,
              onTap: () => onSelect(_EventFilter.upcoming),
            ),
          ),
          SizedBox(width: gap),
          Expanded(
            child: _StatCard(
              icon: Icons.history_rounded,
              label: 'Past',
              value: past,
              selected: filter == _EventFilter.past,
              compact: compact,
              neutral: true,
              onTap: () => onSelect(_EventFilter.past),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.selected,
    required this.compact,
    required this.onTap,
    this.neutral = false,
  });

  final IconData icon;
  final String label;
  final int? value;
  final bool selected;
  final bool compact;
  final bool neutral;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      onTap: onTap,
      label: '$label events: ${value ?? 'loading'}. Tap to filter the list.',
      excludeSemantics: true,
      child: _SurfaceCard(
        onTap: onTap,
        highlight: selected,
        child: Padding(
          padding: EdgeInsets.all(compact ? 10 : 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconCircle(
                icon: icon,
                size: compact ? 32 : 40,
                neutral: neutral,
              ),
              SizedBox(height: compact ? 8 : 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value?.toString() ?? '–',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _OfficerColors.ink,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _OfficerText.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextEventCard extends StatelessWidget {
  const _NextEventCard({
    required this.event,
    required this.daysUntil,
    required this.onTap,
  });

  final _OfficerEvent event;
  final int daysUntil;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final relative = _relativeDayLabel(daysUntil);
    final isToday = daysUntil == 0;
    return Semantics(
      button: true,
      onTap: onTap,
      label: 'Next event: ${event.title}, $relative. Open details.',
      excludeSemantics: true,
      child: _SurfaceCard(
        onTap: onTap,
        highlight: isToday,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isToday ? _OfficerColors.mint : _OfficerColors.surface,
            borderRadius: _OfficerDecor.cardRadius,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DateBadge(date: event.date),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'NEXT EVENT',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: _OfficerColors.mutedText,
                            ),
                          ),
                          _Pill(
                            label: relative,
                            background: isToday
                                ? _OfficerColors.primaryStrong
                                : _OfficerColors.mint,
                            foreground: isToday
                                ? _OfficerColors.onHeader
                                : _OfficerColors.primaryStrong,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _OfficerText.cardTitle,
                      ),
                      const SizedBox(height: 6),
                      _InfoLine(
                        icon: Icons.schedule_rounded,
                        text: event.whenLabel,
                        maxLines: 2,
                      ),
                      if (event.venue.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        _InfoLine(
                          icon: Icons.place_outlined,
                          text: event.venue,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: _OfficerColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionData {
  const _QuickActionData({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? badgeCount;
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.actions,
    required this.width,
    required this.gap,
  });

  final List<_QuickActionData> actions;
  final double width;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final suggestedColumns = HomeLayout.gridColumns(
      width,
      minItemWidth: 136,
      gap: gap,
      maxColumns: actions.length,
    );
    // Four tiles are always either 2 x 2 or a single row; never 3 + 1.
    final columns = suggestedColumns >= 4 && width >= 590 ? 4 : 2;
    final itemWidth = HomeLayout.gridItemWidth(width, columns, gap: gap);
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (final action in actions)
          SizedBox(
            width: itemWidth,
            child: _QuickActionTile(data: action, stacked: columns == 2),
          ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.data, required this.stacked});

  final _QuickActionData data;
  final bool stacked;

  Widget _actionIcon() {
    final count = data.badgeCount ?? 0;
    final icon = _IconCircle(icon: data.icon, size: 36);
    return Badge(
      isLabelVisible: count > 0,
      label: Text(count > 99 ? '99+' : '$count'),
      child: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = Text(
      data.label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: _OfficerColors.ink,
        height: 1.25,
      ),
    );
    return Semantics(
      button: true,
      onTap: data.onTap,
      label: data.label,
      excludeSemantics: true,
      child: _SurfaceCard(
        onTap: data.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _actionIcon(),
                      const SizedBox(height: 8),
                      label,
                    ],
                  )
                : Row(
                    children: [
                      _actionIcon(),
                      const SizedBox(width: 10),
                      Expanded(child: label),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.posted,
    required this.upcoming,
    required this.past,
    required this.onChanged,
  });

  final _EventFilter filter;
  final int? posted;
  final int? upcoming;
  final int? past;
  final ValueChanged<_EventFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final entries = <(_EventFilter, String, int?)>[
      (_EventFilter.upcoming, 'Upcoming', upcoming),
      (_EventFilter.past, 'Past', past),
      (_EventFilter.all, 'All', posted),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in entries)
          ChoiceChip(
            label:
                Text('${entry.$2} ${entry.$3 == null ? '–' : '(${entry.$3})'}'),
            selected: filter == entry.$1,
            onSelected: (_) => onChanged(entry.$1),
            showCheckmark: false,
            selectedColor: _OfficerColors.primaryStrong,
            backgroundColor: _OfficerColors.surface,
            side: BorderSide(
              color: filter == entry.$1
                  ? _OfficerColors.primaryStrong
                  : _OfficerColors.border,
            ),
            labelStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: filter == entry.$1
                  ? _OfficerColors.onHeader
                  : _OfficerColors.ink,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            materialTapTargetSize: MaterialTapTargetSize.padded,
          ),
      ],
    );
  }
}

class _EventGrid extends StatelessWidget {
  const _EventGrid({
    required this.events,
    required this.today,
    required this.columns,
    required this.width,
    required this.gap,
    required this.onOpen,
  });

  final List<_OfficerEvent> events;
  final DateTime today;
  final int columns;
  final double width;
  final double gap;
  final ValueChanged<_OfficerEvent> onOpen;

  @override
  Widget build(BuildContext context) {
    final itemWidth = HomeLayout.gridItemWidth(width, columns, gap: gap);
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (final event in events)
          SizedBox(
            width: itemWidth,
            child: _EventCard(
              event: event,
              isPast: (event.daysFrom(today) ?? 0) < 0,
              onTap: () => onOpen(event),
            ),
          ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.isPast,
    required this.onTap,
  });

  final _OfficerEvent event;
  final bool isPast;
  final VoidCallback onTap;

  String _statusLabel(DateTime today) {
    final days = event.daysFrom(today);
    if (days == null) return 'Date to be announced';
    if (days < 0) return 'Past';
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    return 'In $days days';
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = event.daysFrom(today);
    final isToday = days == 0;
    final status = _statusLabel(today);
    final imageUrl = event.images.isEmpty ? '' : event.images.first;

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            onTap: onTap,
            label: 'Open details for ${event.title}',
            excludeSemantics: true,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                hoverColor: _OfficerColors.hover,
                focusColor: _OfficerColors.focus,
                splashColor: _OfficerColors.splash,
                highlightColor: _OfficerColors.pressed,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      children: [
                        if (isPast)
                          ColorFiltered(
                            colorFilter: const ColorFilter.matrix(<double>[
                              0.2126,
                              0.7152,
                              0.0722,
                              0,
                              0,
                              0.2126,
                              0.7152,
                              0.0722,
                              0,
                              0,
                              0.2126,
                              0.7152,
                              0.0722,
                              0,
                              0,
                              0,
                              0,
                              0,
                              1,
                              0,
                            ]),
                            child: _EventImage(url: imageUrl),
                          )
                        else
                          _EventImage(url: imageUrl),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.16),
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.08),
                                  ],
                                  stops: const [0, 0.52, 1],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 12,
                          top: 12,
                          child: _DateBadge(
                            date: event.date,
                            past: isPast,
                            onImage: true,
                          ),
                        ),
                        Positioned(
                          right: 12,
                          top: 12,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: _Pill(
                              label: status,
                              background: isPast
                                  ? _OfficerColors.slateSoft
                                  : (isToday
                                      ? _OfficerColors.primaryStrong
                                      : Colors.white),
                              foreground: isPast
                                  ? _OfficerColors.slate
                                  : (isToday
                                      ? _OfficerColors.onHeader
                                      : _OfficerColors.primaryStrong),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: _OfficerText.cardTitle,
                          ),
                          const SizedBox(height: 8),
                          _InfoLine(
                            icon: Icons.schedule_rounded,
                            text: event.whenLabel,
                            maxLines: 2,
                          ),
                          if (event.venue.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            _InfoLine(
                              icon: Icons.place_outlined,
                              text: event.venue,
                            ),
                          ],
                          if (event.description.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              event.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: _OfficerText.meta,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (event.id.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: TextButton.icon(
                  onPressed: () => showEventComments(
                    context,
                    eventId: event.id,
                    eventTitle: event.title,
                  ),
                  icon: const Icon(Icons.forum_outlined, size: 18),
                  label: EventCommentCountLabel(
                    eventId: event.id,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: _OfficerColors.primaryStrong,
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    final action = onAction;
    return _SurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconCircle(icon: icon, size: 48, neutral: true),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: _OfficerText.cardTitle,
              ),
              const SizedBox(height: 4),
              Text(
                message,
                textAlign: TextAlign.center,
                style: _OfficerText.bodyMuted,
              ),
              if (label != null && action != null) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: action,
                  style: FilledButton.styleFrom(
                    backgroundColor: _OfficerColors.primaryStrong,
                    foregroundColor: _OfficerColors.onHeader,
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  child: Text(label),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _OfficerColors.amberSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _OfficerColors.amberBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 20,
              color: _OfficerColors.amber,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _OfficerColors.amber,
                  height: 1.35,
                ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: _OfficerColors.amber,
                minimumSize: const Size(48, 48),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventsSkeleton extends StatefulWidget {
  const _EventsSkeleton({
    required this.columns,
    required this.itemWidth,
    required this.gap,
  });

  final int columns;
  final double itemWidth;
  final double gap;

  @override
  State<_EventsSkeleton> createState() => _EventsSkeletonState();
}

class _EventsSkeletonState extends State<_EventsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final Animation<Color?> _color =
      _controller.drive(CurveTween(curve: Curves.easeInOut)).drive(ColorTween(
            begin: _OfficerColors.skeleton,
            end: _OfficerColors.skeletonHighlight,
          ));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _bar(Color color, double height, double widthFactor) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        child: SizedBox(
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.columns < 2 ? 2 : widget.columns;
    return Semantics(
      label: 'Loading events',
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _color,
          builder: (context, _) {
            final color = _color.value ?? _OfficerColors.skeleton;
            return Wrap(
              spacing: widget.gap,
              runSpacing: widget.gap,
              children: [
                for (var i = 0; i < count; i++)
                  SizedBox(
                    width: widget.itemWidth,
                    child: _SurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: ColoredBox(color: color),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _bar(color, 16, 0.8),
                                const SizedBox(height: 12),
                                _bar(color, 12, 0.55),
                                const SizedBox(height: 8),
                                _bar(color, 12, 0.9),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Event details sheet
// ---------------------------------------------------------------------------

class _OfficerEventDetailsSheet extends StatefulWidget {
  const _OfficerEventDetailsSheet({required this.event});

  final _OfficerEvent event;

  static Future<void> show(BuildContext context, _OfficerEvent event) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _OfficerColors.surface,
      clipBehavior: Clip.antiAlias,
      constraints: const BoxConstraints(maxWidth: 720),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _OfficerEventDetailsSheet(event: event),
    );
  }

  @override
  State<_OfficerEventDetailsSheet> createState() =>
      _OfficerEventDetailsSheetState();
}

class _OfficerEventDetailsSheetState extends State<_OfficerEventDetailsSheet> {
  int _currentPhoto = 0;

  Future<void> _copyDetails() async {
    final event = widget.event;
    final lines = <String>[
      event.title,
      'Date: ${event.dateLabel}',
      if (event.timeLabel.isNotEmpty) 'Time: ${event.timeLabel}',
      if (event.venue.isNotEmpty) 'Venue: ${event.venue}',
      if (event.description.isNotEmpty) 'Description: ${event.description}',
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Event details copied')),
    );
  }

  void _openPhoto(String url) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                    memCacheWidth: 1800,
                    placeholder: (context, _) =>
                        MediaQuery.disableAnimationsOf(context)
                            ? const _ImageFallback(showIcon: false)
                            : const Center(
                                child: CircularProgressIndicator(
                                  color: _OfficerColors.onHeader,
                                ),
                              ),
                    errorWidget: (_, __, ___) => const _ImageFallback(),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(dialogContext).top + 8,
              right: 8,
              child: Semantics(
                button: true,
                label: 'Close photo viewer',
                child: IconButton(
                  tooltip: 'Close photo viewer',
                  onPressed: () => Navigator.of(dialogContext).maybePop(),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    backgroundColor: const Color(0x55000000),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.close_rounded),
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
    final event = widget.event;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final days = event.daysFrom(DateTime.now());
    final animationDisabled = MediaQuery.disableAnimationsOf(context);

    return HomeLayout.capText(
      context,
      ScrollConfiguration(
        behavior: const _OfficerScrollBehavior(),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottomInset),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _OfficerColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Semantics(
                        header: true,
                        child: Text(
                          event.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _OfficerColors.ink,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: _OfficerColors.ink,
                    ),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              if (days != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: days >= 0
                      ? _Pill(
                          label: _relativeDayLabel(days),
                          background: days == 0
                              ? _OfficerColors.primaryStrong
                              : _OfficerColors.mint,
                          foreground: days == 0
                              ? _OfficerColors.onHeader
                              : _OfficerColors.primaryStrong,
                        )
                      : const _Pill(
                          label: 'Past',
                          background: _OfficerColors.slateSoft,
                          foreground: _OfficerColors.slate,
                        ),
                ),
              ],
              const SizedBox(height: 16),
              _InfoLine(
                icon: Icons.calendar_today_rounded,
                text: event.dateLabel,
                maxLines: 3,
              ),
              if (event.timeLabel.isNotEmpty) ...[
                const SizedBox(height: 8),
                _InfoLine(
                  icon: Icons.schedule_rounded,
                  text: event.timeLabel,
                  maxLines: 3,
                ),
              ],
              if (event.venue.isNotEmpty) ...[
                const SizedBox(height: 8),
                _InfoLine(
                  icon: Icons.place_outlined,
                  text: event.venue,
                  maxLines: 3,
                ),
              ],
              if (event.description.isNotEmpty) ...[
                const SizedBox(height: 20),
                const _SectionTitle('About'),
                const SizedBox(height: 8),
                SelectableText(event.description, style: _OfficerText.body),
              ],
              if (event.images.isNotEmpty) ...[
                const SizedBox(height: 20),
                const _SectionTitle('Photos'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  child: PageView.builder(
                    itemCount: event.images.length,
                    onPageChanged: (index) =>
                        setState(() => _currentPhoto = index),
                    itemBuilder: (context, index) {
                      final url = event.images[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Semantics(
                          button: true,
                          label: 'View photo ${index + 1} full screen',
                          child: GestureDetector(
                            onTap: () => _openPhoto(url),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: CachedNetworkImage(
                                imageUrl: url,
                                fit: BoxFit.cover,
                                memCacheWidth: 1200,
                                placeholder: (_, __) =>
                                    const _ImageFallback(showIcon: false),
                                errorWidget: (_, __, ___) =>
                                    const _ImageFallback(),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (event.images.length > 1) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < event.images.length; i++)
                        AnimatedContainer(
                          duration: animationDisabled
                              ? Duration.zero
                              : const Duration(milliseconds: 180),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: _currentPhoto == i ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _currentPhoto == i
                                ? _OfficerColors.primaryStrong
                                : _OfficerColors.border,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      'Swipe to browse photos · Tap to zoom',
                      style: _OfficerText.caption,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Center(
                    child:
                        Text('Tap photo to zoom', style: _OfficerText.caption),
                  ),
                ],
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _copyDetails,
                icon: const Icon(Icons.copy_all_rounded, size: 18),
                label: const Text('Copy details'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _OfficerColors.primaryStrong,
                  minimumSize: const Size(double.infinity, 48),
                  side: const BorderSide(color: _OfficerColors.border),
                ),
              ),
              if (event.id.isNotEmpty) ...[
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => showEventComments(
                    context,
                    eventId: event.id,
                    eventTitle: event.title,
                  ),
                  icon: const Icon(Icons.forum_outlined, size: 18),
                  label: EventCommentCountLabel(
                    eventId: event.id,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _OfficerColors.primaryStrong,
                    foregroundColor: _OfficerColors.onHeader,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      maxScale: 1.3,
    );
  }
}

// ---------------------------------------------------------------------------
// Organizations tab
// ---------------------------------------------------------------------------

class _OfficerOrganizationsTab extends StatefulWidget {
  final String orgId;
  final String orgName;
  final String position;

  const _OfficerOrganizationsTab({
    required this.orgId,
    required this.orgName,
    required this.position,
  });

  @override
  State<_OfficerOrganizationsTab> createState() =>
      _OfficerOrganizationsTabState();
}

class _OfficerOrganizationsTabState extends State<_OfficerOrganizationsTab> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String _logo() {
    final org =
        AppState.instance.organizations.cast<Organization?>().firstWhere(
              (item) => item?.id == widget.orgId,
              orElse: () => null,
            );
    return org?.logoAsset.trim() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final layout = HomeLayout.of(context);
    final columns = layout.isMobile ? 1 : (layout.isDesktop ? 3 : 2);
    final gap = layout.cardGap;
    final itemWidth =
        HomeLayout.gridItemWidth(layout.homeInnerWidth, columns, gap: gap);

    Widget group(List<_HubTile> tiles) {
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final tile in tiles) SizedBox(width: itemWidth, child: tile),
        ],
      );
    }

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OfficerOrgSummaryCard(
          orgId: widget.orgId,
          orgName: widget.orgName,
          position: widget.position,
        ),
        SizedBox(height: layout.sectionGap),
        const _SectionTitle('Manage'),
        const SizedBox(height: 12),
        group([
          _HubTile(
            icon: Icons.assignment_rounded,
            title: 'Applications',
            subtitle: 'Review and manage applications for your organization.',
            onTap: () => _OfficerNav.applications(context),
          ),
          _HubTile(
            icon: Icons.groups_rounded,
            title: 'Members',
            subtitle: 'Review organization membership and activity.',
            onTap: () => _OfficerNav.members(context, widget.orgId),
          ),
          _HubTile(
            icon: Icons.badge_rounded,
            title: 'Organization profile',
            subtitle: 'Edit public information, officers, and highlights.',
            onTap: () => _OfficerNav.orgProfile(context, widget.orgId),
          ),
        ]),
        SizedBox(height: layout.sectionGap),
        const _SectionTitle('Community'),
        const SizedBox(height: 12),
        group([
          _HubTile(
            icon: Icons.forum_rounded,
            title: 'Community chat',
            subtitle: 'Talk with members and officers of your organization.',
            unreadOrgId: widget.orgId,
            onTap: () => _OfficerNav.community(
              context,
              widget.orgId,
              widget.orgName,
            ),
          ),
          _HubTile(
            icon: Icons.workspaces_rounded,
            title: 'Orgs joined',
            subtitle: 'See every organization you belong to and your position.',
            onTap: () => _OfficerNav.joinedOrganizations(
              context,
              widget.orgId,
              widget.orgName,
            ),
          ),
          _HubTile(
            icon: Icons.explore_rounded,
            title: 'Browse organizations',
            subtitle: 'Explore other organizations and apply to join them.',
            onTap: () => _OfficerNav.browseOrganizations(context),
          ),
        ]),
      ],
    );

    return HomeLayout.capText(
      context,
      ScrollConfiguration(
        behavior: const _OfficerScrollBehavior(autoScrollbar: false),
        child: Scrollbar(
          controller: _scroll,
          thumbVisibility: layout.isDesktop,
          child: ListView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              _OfficerHeader(
                title: 'Organization',
                subtitle: _cleanOrgName(widget.orgName),
                status: 'OFFICER ORGANIZATION HUB',
                leading: AnimatedBuilder(
                  animation: AppState.instance,
                  builder: (context, _) => _HeaderLogo(asset: _logo()),
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: HomeBreakpoints.maxContentWidth,
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      layout.homeHPad,
                      layout.sectionGap,
                      layout.homeHPad,
                      40,
                    ),
                    child: body,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      maxScale: 1.3,
    );
  }
}

class _OfficerOrgSummaryCard extends StatelessWidget {
  const _OfficerOrgSummaryCard({
    required this.orgId,
    required this.orgName,
    required this.position,
  });

  final String orgId;
  final String orgName;
  final String position;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        Organization? organization;
        for (final item in AppState.instance.organizations) {
          if (item.id == orgId) {
            organization = item;
            break;
          }
        }
        final description = organization?.shortDesc.trim() ?? '';
        return _SurfaceCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _OfficerOrgLogo(
                  asset: organization?.logoAsset ?? '',
                  size: 64,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _cleanOrgName(orgName),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _OfficerText.cardTitle,
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _OfficerText.meta,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _Pill(
                          label: position.trim().isEmpty
                              ? 'Officer'
                              : position.trim(),
                          background: _OfficerColors.mint,
                          foreground: _OfficerColors.primaryStrong,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.unreadOrgId,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? unreadOrgId;

  Widget _leading() {
    final orgId = unreadOrgId;
    if (orgId == null) return _IconCircle(icon: icon, size: 44);
    final count = _unreadOrganizationUpdatesCount(orgId);
    return Badge(
      isLabelVisible: count > 0,
      label: Text(count > 99 ? '99+' : '$count'),
      child: _IconCircle(icon: icon, size: 44),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      onTap: onTap,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: _SurfaceCard(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                if (unreadOrgId == null)
                  _leading()
                else
                  AnimatedBuilder(
                    animation: AppState.instance,
                    builder: (context, _) => _leading(),
                  ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _OfficerColors.ink,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _OfficerText.meta,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: _OfficerColors.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Orgs Joined flow (restyled; logic unchanged)
// ---------------------------------------------------------------------------

const double _kJoinedMaxWidth = 720;

double _joinedSidePadding(double width) {
  final extra = (width - _kJoinedMaxWidth) / 2;
  return (extra > 0 ? extra : 0) + 18;
}

class _JoinedOrganizationsSkeleton extends StatelessWidget {
  const _JoinedOrganizationsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(18),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => const _SurfaceCard(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Row(
            children: [
              _SkeletonBlock(width: 62, height: 62, radius: 18),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBlock(width: 190, height: 14, radius: 7),
                    SizedBox(height: 10),
                    _SkeletonBlock(width: 135, height: 11, radius: 6),
                    SizedBox(height: 10),
                    _SkeletonBlock(width: 110, height: 11, radius: 6),
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

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    required this.width,
    required this.height,
    this.radius = 8,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: _OfficerColors.skeleton,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

class _OfficerJoinedOrganizationsScreen extends StatefulWidget {
  final String currentOrgId;
  final String currentOrgName;

  const _OfficerJoinedOrganizationsScreen({
    required this.currentOrgId,
    required this.currentOrgName,
  });

  @override
  State<_OfficerJoinedOrganizationsScreen> createState() =>
      _OfficerJoinedOrganizationsScreenState();
}

class _OfficerJoinedOrganizationsScreenState
    extends State<_OfficerJoinedOrganizationsScreen> {
  bool _loading = true;
  final Set<String> _joinedOrgIds = <String>{};
  final Set<String> _joinedOrgNames = <String>{};

  @override
  void initState() {
    super.initState();
    _loadJoinedOrganizations();
  }

  Future<void> _loadJoinedOrganizations() async {
    final ids = <String>{};
    final names = <String>{};

    // The organization that opened this Officer account is always a real
    // membership. Keep it in Orgs Joined even if the membership query is
    // temporarily delayed or an older row has incomplete profile_id data.
    if (widget.currentOrgId.trim().isNotEmpty) {
      ids.add(widget.currentOrgId.trim());
    }
    if (widget.currentOrgName.trim().isNotEmpty) {
      names.add(widget.currentOrgName.trim().toLowerCase());
    }

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null && userId.isNotEmpty) {
        final rows = await Supabase.instance.client
            .from('members')
            .select('org_id, org_name, position')
            .eq('profile_id', userId);
        if (!mounted) return;

        for (final raw in (rows as List)) {
          final row = Map<String, dynamic>.from(raw as Map);
          final id = row['org_id']?.toString().trim();
          final name = row['org_name']?.toString().trim() ?? '';
          if (id != null && id.isNotEmpty) ids.add(id);
          if (name.isNotEmpty) names.add(name.toLowerCase());
        }
      }
    } catch (e) {
      debugPrint('Error loading Officer Orgs Joined: $e');
    }

    // Resolve legacy rows that have the organization name but no org_id.
    for (final org in AppState.instance.organizations) {
      if (names.contains(org.name.trim().toLowerCase())) {
        ids.add(org.id);
      }
    }

    if (!mounted) return;
    setState(() {
      _joinedOrgIds
        ..clear()
        ..addAll(ids);
      _joinedOrgNames
        ..clear()
        ..addAll(names);
      _loading = false;
    });
  }

  Future<String> _fetchPosition(String orgId) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return 'Member';
      final rows = await Supabase.instance.client
          .from('members')
          .select('position')
          .eq('profile_id', userId)
          .eq('org_id', orgId)
          .limit(1);
      if (!mounted) return orgId == widget.currentOrgId ? 'Officer' : 'Member';
      if ((rows as List).isNotEmpty) {
        final p = rows.first['position']?.toString().trim();
        if (p != null && p.isNotEmpty) return p;
      }
    } catch (_) {}
    return orgId == widget.currentOrgId ? 'Officer' : 'Member';
  }

  void _openCommunity(BuildContext context, Organization org) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrgCommunityChatScreen(
          orgId: org.id,
          orgName: org.name,
          showBackButton: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final joined = AppState.instance.organizations
            .where((org) =>
                _joinedOrgIds.contains(org.id) ||
                _joinedOrgNames.contains(org.name.trim().toLowerCase()))
            .toList();

        // Make absolutely sure the organization that owns this Officer
        // account is visible even when the organization cache is still loading.
        if (widget.currentOrgId.isNotEmpty &&
            !joined.any((org) => org.id == widget.currentOrgId)) {
          final current =
              AppState.instance.organizations.cast<Organization?>().firstWhere(
                    (org) => org?.id == widget.currentOrgId,
                    orElse: () => null,
                  );
          if (current != null) joined.insert(0, current);
        }

        return Scaffold(
          backgroundColor: _OfficerColors.background,
          body: HomeLayout.capText(
            context,
            Column(
              children: [
                const _OfficerJoinedHeader(),
                Expanded(
                  child: _loading
                      ? const _JoinedOrganizationsSkeleton()
                      : ScrollConfiguration(
                          behavior: const _OfficerScrollBehavior(),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final side =
                                  _joinedSidePadding(constraints.maxWidth);
                              return RefreshIndicator(
                                color: _OfficerColors.primary,
                                backgroundColor: _OfficerColors.surface,
                                onRefresh: _loadJoinedOrganizations,
                                child: joined.isEmpty
                                    ? ListView(
                                        physics:
                                            const AlwaysScrollableScrollPhysics(),
                                        padding: EdgeInsets.fromLTRB(
                                            side, 18, side, 36),
                                        children: [
                                          const SizedBox(height: 64),
                                          const Center(
                                            child: _IconCircle(
                                              icon: Icons.groups_outlined,
                                              size: 64,
                                              neutral: true,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          const Text(
                                            'No organizations joined yet',
                                            textAlign: TextAlign.center,
                                            style: _OfficerText.cardTitle,
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Browse organizations to discover more campus communities.',
                                            textAlign: TextAlign.center,
                                            style: _OfficerText.bodyMuted,
                                          ),
                                          const SizedBox(height: 16),
                                          Center(
                                            child: FilledButton.icon(
                                              onPressed: () => _OfficerNav
                                                  .browseOrganizations(context),
                                              icon: const Icon(
                                                  Icons.explore_rounded),
                                              label: const Text(
                                                  'Browse organizations'),
                                              style: FilledButton.styleFrom(
                                                backgroundColor: _OfficerColors
                                                    .primaryStrong,
                                                foregroundColor:
                                                    _OfficerColors.onHeader,
                                                minimumSize: const Size(48, 48),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : ListView.separated(
                                        physics:
                                            const AlwaysScrollableScrollPhysics(),
                                        padding: EdgeInsets.fromLTRB(
                                            side, 18, side, 36),
                                        itemCount: joined.length,
                                        separatorBuilder: (_, __) =>
                                            const SizedBox(height: 12),
                                        itemBuilder: (context, i) {
                                          final org = joined[i];
                                          final isCurrent =
                                              org.id == widget.currentOrgId;
                                          return _OfficerJoinedOrgCard(
                                            org: org,
                                            isCurrentOrganization: isCurrent,
                                            onCommunity: isCurrent
                                                ? () => _OfficerNav.community(
                                                      context,
                                                      widget.currentOrgId,
                                                      widget.currentOrgName,
                                                    )
                                                : () => _openCommunity(
                                                    context, org),
                                            fetchPosition: _fetchPosition,
                                          );
                                        },
                                      ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
            maxScale: 1.3,
          ),
        );
      },
    );
  }
}

class _OfficerJoinedHeader extends StatelessWidget {
  const _OfficerJoinedHeader();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        gradient: AppHeader.brandGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Stack(
        children: [
          const Positioned(right: -48, top: -64, child: _HeaderOrb(size: 176)),
          Padding(
            padding: EdgeInsets.only(top: top + 8, bottom: 20),
            child: Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: _kJoinedMaxWidth + 36),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).maybePop(),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          foregroundColor: _OfficerColors.onHeader,
                        ),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Organizations Joined',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _OfficerColors.onHeader,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Your organization communities',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _OfficerColors.onHeaderSoft,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
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
          ),
        ],
      ),
    );
  }
}

class _OfficerJoinedOrgCard extends StatefulWidget {
  final Organization org;
  final bool isCurrentOrganization;
  final VoidCallback? onCommunity;
  final Future<String> Function(String orgId) fetchPosition;

  const _OfficerJoinedOrgCard({
    required this.org,
    required this.isCurrentOrganization,
    required this.onCommunity,
    required this.fetchPosition,
  });

  @override
  State<_OfficerJoinedOrgCard> createState() => _OfficerJoinedOrgCardState();
}

class _OfficerJoinedOrgCardState extends State<_OfficerJoinedOrgCard> {
  String _position = 'Member';

  @override
  void initState() {
    super.initState();
    _loadPosition();
  }

  Future<void> _loadPosition() async {
    final position = await widget.fetchPosition(widget.org.id);
    if (!mounted) return;
    setState(() => _position = position);
  }

  @override
  Widget build(BuildContext context) {
    final updates = _unreadOrganizationUpdatesCount(widget.org.id);

    return Material(
      color: _OfficerColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: _OfficerDecor.cardRadius,
        side: BorderSide(
          color: widget.isCurrentOrganization
              ? _OfficerColors.currentBorder
              : _OfficerColors.border,
          width: widget.isCurrentOrganization ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        onTap: widget.onCommunity,
        borderRadius: _OfficerDecor.cardRadius,
        hoverColor: _OfficerColors.hover,
        focusColor: _OfficerColors.focus,
        splashColor: _OfficerColors.splash,
        highlightColor: _OfficerColors.pressed,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _OfficerOrgLogo(asset: widget.org.logoAsset, size: 62),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.org.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _OfficerColors.ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (widget.isCurrentOrganization) ...[
                          const SizedBox(width: 8),
                          const _Pill(
                            label: 'CURRENT',
                            background: _OfficerColors.mint,
                            foreground: _OfficerColors.primaryStrong,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.isCurrentOrganization
                          ? '${_position == 'Member' ? 'Officer' : _position} • Your officer organization'
                          : (_position == 'Member'
                              ? (widget.org.shortDesc.isEmpty
                                  ? 'Your member community'
                                  : widget.org.shortDesc)
                              : _position),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _OfficerText.meta,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.campaign_rounded,
                          size: 16,
                          color: _OfficerColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            updates == 0
                                ? 'No new updates'
                                : '$updates new update${updates == 1 ? '' : 's'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _OfficerColors.primaryStrong,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
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

class _OfficerOrgLogo extends StatelessWidget {
  final String asset;
  final double size;

  const _OfficerOrgLogo({
    required this.asset,
    required this.size,
  });

  Widget _fallback() => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _OfficerColors.mint,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(
          Icons.groups_rounded,
          color: _OfficerColors.primary,
          size: 30,
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (asset.trim().isEmpty) return _fallback();
    if (asset.startsWith('http://') || asset.startsWith('https://')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.network(
          asset,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      ),
    );
  }
}

int _unreadOrganizationUpdatesCount(String orgId) => AppState
    .instance.notifications
    .where((n) =>
        n.orgId == orgId &&
        !n.read &&
        !_isWorkflowOrganizationNotification(n) &&
        !_isStudentPersonalNotification(n))
    .length;

bool _isStudentPersonalNotification(app_models.Notification n) {
  final title = n.title.trim().toLowerCase();
  final message = n.message.trim().toLowerCase();
  return title.contains('interview scheduled') ||
      title == 'application update' ||
      title.contains('congratulations') ||
      message.contains('your interview') ||
      message.contains('your application') ||
      message.contains('officially a member');
}

bool _isWorkflowOrganizationNotification(app_models.Notification n) {
  final title = n.title.trim().toLowerCase();
  final message = n.message.trim().toLowerCase();
  const workflowWords = [
    'proposal approved',
    'proposal forwarded',
    'proposal revision',
    'proposal sent back',
    'admin / cso',
    'final posting',
    'creative submitted',
    'revision requested',
    'forwarded to admin',
    'approved and published',
    'has been approved and published',
    'final pictures',
  ];
  return workflowWords.any(
        (word) => title.contains(word) || message.contains(word),
      ) ||
      title == 'new event';
}
