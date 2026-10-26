import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
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

  String _avatarUrl = '';
  String _userName = '';
  String _position = 'Officer';

  @override
  void initState() {
    super.initState();
    unawaited(_loadOfficerHome());
  }

  @override
  void dispose() {
    _exitTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadOfficerHome() async {
    await Future.wait([
      _loadPublishedEvents(),
      _loadOfficerProfile(),
    ]);
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
          OfficerEventsScreen(
            orgId: widget.orgId,
            orgName: widget.orgName,
            logoAsset: _currentOrganizationLogo(),
            embedded: true,
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
          _OfficerBottomNav(
            selectedIndex: _selectedIndex,
            onSelected: _selectTab,
          ),
        ],
      );
    }

    final extended = layout.isDesktop;
    final railWidth =
        extended ? _OfficerRail.extendedWidth : _OfficerRail.compactWidth;
    return Row(
      children: [
        _OfficerRail(
          selectedIndex: _selectedIndex,
          onSelected: _selectTab,
          extended: extended,
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
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

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
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: _OfficerColors.surface,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                indicatorColor: _OfficerColors.mint,
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  final selected = states.contains(WidgetState.selected);
                  return TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected
                        ? _OfficerColors.primaryStrong
                        : _OfficerColors.mutedText,
                  );
                }),
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  final selected = states.contains(WidgetState.selected);
                  return IconThemeData(
                    size: 24,
                    color: selected
                        ? _OfficerColors.primary
                        : _OfficerColors.mutedText,
                  );
                }),
              ),
              child: NavigationBar(
                height: 68,
                selectedIndex: selectedIndex,
                onDestinationSelected: onSelected,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: [
                  for (final item in _kNavItems)
                    NavigationDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.selectedIcon),
                      label: item.label,
                    ),
                ],
              ),
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
  });

  static const double compactWidth = 88;
  static const double extendedWidth = 232;

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool extended;

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
                      indicatorColor: _OfficerColors.mint,
                      selectedIconTheme: const IconThemeData(
                        color: _OfficerColors.primary,
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
                        for (final item in _kNavItems)
                          NavigationRailDestination(
                            icon: Icon(item.icon),
                            selectedIcon: Icon(item.selectedIcon),
                            label: Text(
                              item.label,
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
        backgroundColor: _OfficerColors.headerChip,
        foregroundColor: _OfficerColors.onHeader,
        disabledBackgroundColor: _OfficerColors.headerChip,
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
              fadeInDuration: const Duration(milliseconds: 250),
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
  _EventFilter _filter = _EventFilter.upcoming;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _setFilter(_EventFilter filter) {
    if (filter == _filter) return;
    setState(() => _filter = filter);
  }

  void _retry() => unawaited(widget.onRefresh());

  Widget _buildEventsArea({
    required HomeLayout layout,
    required List<_OfficerEvent> shown,
    required bool hasLoaded,
    required DateTime now,
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
    if (shown.isEmpty) {
      return switch (_filter) {
        _EventFilter.upcoming => const _StateCard(
            icon: Icons.event_available_rounded,
            title: 'No upcoming events',
            message:
                'Nothing is scheduled right now. Request an event or check the Past tab.',
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
    return _EventGrid(
      events: shown,
      today: now,
      columns: columns,
      width: layout.homeInnerWidth,
      gap: layout.cardGap,
      onOpen: (event) => _OfficerEventDetailsSheet.show(context, event),
    );
  }

  @override
  Widget build(BuildContext context) {
    final layout = HomeLayout.of(context);
    final now = DateTime.now();
    final buckets = _EventBuckets.from(widget.events, now);
    final shown = buckets.forFilter(_filter);
    final hasLoaded = widget.lastUpdated != null;
    final error = widget.error;
    final updated = widget.lastUpdated;
    final next = buckets.upcoming.isEmpty ? null : buckets.upcoming.first;
    final nextDays = next?.daysFrom(now);

    final displayName = _firstNameOf(widget.userName);
    final cleanPosition =
        widget.position.trim().isEmpty ? 'Officer' : widget.position.trim();

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatsRow(
          posted: hasLoaded ? widget.events.length : null,
          upcoming: hasLoaded ? buckets.upcoming.length : null,
          past: hasLoaded ? buckets.past.length : null,
          filter: _filter,
          compact: layout.isSmallMobile,
          gap: layout.cardGap,
          onSelect: _setFilter,
        ),
        if (hasLoaded && error != null) ...[
          const SizedBox(height: 16),
          _StaleBanner(message: error, onRetry: _retry),
        ],
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
        _QuickActions(
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
              onTap: () => _OfficerNav.community(
                context,
                widget.orgId,
                widget.orgName,
              ),
            ),
          ],
        ),
        SizedBox(height: layout.sectionGap),
        const _SectionTitle('Posted events'),
        if (updated != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Updated ${DateFormat('h:mm a').format(updated)}',
              style: _OfficerText.caption,
            ),
          ),
        const SizedBox(height: 12),
        _FilterBar(filter: _filter, onChanged: _setFilter),
        const SizedBox(height: 16),
        _buildEventsArea(
          layout: layout,
          shown: shown,
          hasLoaded: hasLoaded,
          now: now,
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
                  subtitle: 'Your organization’s posted events at a glance',
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
    return Semantics(
      button: true,
      onTap: onTap,
      label: 'Next event: ${event.title}, $relative. Open details.',
      excludeSemantics: true,
      child: _SurfaceCard(
        onTap: onTap,
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
                          background: _OfficerColors.mint,
                          foreground: _OfficerColors.primaryStrong,
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
    );
  }
}

class _QuickActionData {
  const _QuickActionData({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
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
    final columns = HomeLayout.gridColumns(
      width,
      minItemWidth: 136,
      gap: gap,
      maxColumns: actions.length,
    );
    final itemWidth = HomeLayout.gridItemWidth(width, columns, gap: gap);
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (final action in actions)
          SizedBox(
            width: itemWidth,
            child: _QuickActionTile(data: action, stacked: itemWidth < 150),
          ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.data, required this.stacked});

  final _QuickActionData data;
  final bool stacked;

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
                      _IconCircle(icon: data.icon, size: 36),
                      const SizedBox(height: 8),
                      label,
                    ],
                  )
                : Row(
                    children: [
                      _IconCircle(icon: data.icon, size: 36),
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
  const _FilterBar({required this.filter, required this.onChanged});

  final _EventFilter filter;
  final ValueChanged<_EventFilter> onChanged;

  static const Map<_EventFilter, String> _labels = <_EventFilter, String>{
    _EventFilter.upcoming: 'Upcoming',
    _EventFilter.past: 'Past',
    _EventFilter.all: 'All',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in _labels.entries)
          ChoiceChip(
            label: Text(entry.value),
            selected: filter == entry.key,
            onSelected: (_) => onChanged(entry.key),
            showCheckmark: false,
            selectedColor: _OfficerColors.primaryStrong,
            backgroundColor: _OfficerColors.surface,
            side: BorderSide(
              color: filter == entry.key
                  ? _OfficerColors.primaryStrong
                  : _OfficerColors.border,
            ),
            labelStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: filter == entry.key
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

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _EventImage(
                    url: event.images.isEmpty ? '' : event.images.first,
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
              Positioned(
                left: 12,
                top: 12,
                child: _DateBadge(
                  date: event.date,
                  past: isPast,
                  onImage: true,
                ),
              ),
              Positioned.fill(
                child: Semantics(
                  button: true,
                  label: 'Open details for ${event.title}',
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap: onTap,
                      hoverColor: _OfficerColors.hover,
                      focusColor: _OfficerColors.focus,
                      splashColor: _OfficerColors.splash,
                      highlightColor: _OfficerColors.pressed,
                    ),
                  ),
                ),
              ),
            ],
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

class _OfficerEventDetailsSheet extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final days = event.daysFrom(DateTime.now());

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
                          background: _OfficerColors.mint,
                          foreground: _OfficerColors.primaryStrong,
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
                for (final url in event.images)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _EventImage(url: url, memCacheWidth: 1200),
                    ),
                  ),
              ],
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
                leading: _HeaderLogo(asset: _logo()),
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

class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

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
                _IconCircle(icon: icon, size: 44),
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
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: _OfficerColors.primary,
                          ),
                        )
                      : ScrollConfiguration(
                          behavior: const _OfficerScrollBehavior(),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final side =
                                  _joinedSidePadding(constraints.maxWidth);
                              if (joined.isEmpty) {
                                return ListView(
                                  padding:
                                      EdgeInsets.fromLTRB(side, 18, side, 36),
                                  children: const [
                                    SizedBox(height: 64),
                                    Center(
                                      child: _IconCircle(
                                        icon: Icons.groups_outlined,
                                        size: 64,
                                        neutral: true,
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'No organizations joined yet',
                                      textAlign: TextAlign.center,
                                      style: _OfficerText.cardTitle,
                                    ),
                                  ],
                                );
                              }
                              return ListView.separated(
                                padding:
                                    EdgeInsets.fromLTRB(side, 18, side, 36),
                                itemCount: joined.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (_, i) {
                                  final org = joined[i];
                                  final isCurrent =
                                      org.id == widget.currentOrgId;
                                  return _OfficerJoinedOrgCard(
                                    org: org,
                                    isCurrentOrganization: isCurrent,
                                    onCommunity: isCurrent
                                        ? null
                                        : () => _openCommunity(context, org),
                                    fetchPosition: _fetchPosition,
                                  );
                                },
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
    final updates = AppState.instance.notifications
        .where((n) =>
            n.orgId == widget.org.id &&
            !n.read &&
            !_isWorkflowOrganizationNotification(n) &&
            !_isStudentPersonalNotification(n))
        .length;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _OfficerColors.surface,
        borderRadius: _OfficerDecor.cardRadius,
        border: Border.all(
          color: widget.isCurrentOrganization
              ? _OfficerColors.currentBorder
              : _OfficerColors.border,
          width: widget.isCurrentOrganization ? 1.4 : 1,
        ),
        boxShadow: _OfficerDecor.softShadow,
      ),
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
