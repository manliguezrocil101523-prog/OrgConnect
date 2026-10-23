import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart' hide Notification;
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../core/app_state.dart';
import '../analytics/event_comments_sheet.dart';
import '/screens/notifications/notification_screen.dart';
import '/screens/Student_Role/student_dashboard_events.dart';
import '/screens/profile/profile_screen.dart';
import '../community/org_community_chat_screen.dart';
import '/screens/organizations/org_list_screen.dart';
import '../../widgets/app_header.dart';
import 'home/new_home_tab.dart';

// =============================================================================
// Shared tokens + helpers
// =============================================================================

abstract final class _C {
  static const Color primary = Color(0xFF16A34A);
  static const Color teal = Color(0xFF0F766E);
  static const Color green = Color(0xFF0F8A61);
  static const Color ink = Color(0xFF173B30);
  static const Color ink2 = Color(0xFF24463C);
  static const Color muted = Color(0xFF6B8178);
  static const Color body = Color(0xFF4E665E);
  static const Color chat = Color(0xFF496A5D);
  static const Color border = Color(0xFFCBE8DC);
  static const Color softGreen = Color(0xFFE4F7EF);
  static const Color pageBg = Color(0xFFFFFFFF);
  static const Color tileBg = Color(0xFFF7FCF9);
  static const Color tileBorder = Color(0xFFDCEFE6);
  static const Color red = Color(0xFFDC2626);
  static const Color redDark = Color(0xFFB91C1C);
  static const Color amber = Color(0xFFD97706);
  static const Color blue = Color(0xFF2563EB);
  static const Color navInactive = Color(0xFF94A3B8);
  static const Color toast = Color(0xFF1E293B);
  static const Color shadow = Color(0x090F8A61);
}

const double _kMaxContent = 640;

/// 1.0 for 360dp and wider; shrinks linearly (floor 0.88) on narrow phones.
double _scaleOf(double width) =>
    width >= 360 ? 1.0 : math.max(0.88, width / 360);

double _sc(BuildContext c) => _scaleOf(MediaQuery.sizeOf(c).width);

/// Extra horizontal padding that centers content on wide screens while the
/// scroll view itself still spans edge to edge.
double _side(BuildContext c) =>
    math.max(0.0, (MediaQuery.sizeOf(c).width - _kMaxContent) / 2);

String _mdy(DateTime d) => '${d.month}/${d.day}/${d.year}';

/// "Role: Name" -> (role, name). A bare "Name" gets the role 'Officer'.
(String, String) _parseOfficer(String raw) {
  final colon = raw.indexOf(':');
  final role = colon < 0 ? 'Officer' : raw.substring(0, colon).trim();
  final name = (colon < 0 ? raw : raw.substring(colon + 1)).trim();
  return (role, name);
}

T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T) test) {
  for (final e in items) {
    if (test(e)) return e;
  }
  return null;
}

bool _sameItems(List<Object?> a, List<Object?> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

BoxDecoration _cardDeco({
  double radius = 20,
  Color? color = Colors.white,
  Color shadow = _C.shadow,
  double blur = 15,
  double dy = 6,
}) =>
    BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _C.border),
      boxShadow: [
        BoxShadow(color: shadow, blurRadius: blur, offset: Offset(0, dy))
      ],
    );

Future<T> _guard<T>(Future<T> Function() run, T fallback, String label) async {
  try {
    return await run();
  } catch (e) {
    debugPrint('Error loading $label: $e');
    return fallback;
  }
}

// ── Notification filters ─────────────────────────────────────────────────────

bool _isPersonalNotification(Notification n) {
  final title = n.title.trim().toLowerCase();
  final message = n.message.trim().toLowerCase();
  return title.contains('interview scheduled') ||
      title == 'application update' ||
      title.contains('congratulations') ||
      message.contains('your interview') ||
      message.contains('your application');
}

bool _isWorkflowNotification(Notification n) {
  final title = n.title.trim().toLowerCase();
  final message = n.message.trim().toLowerCase();
  const words = [
    'proposal',
    'admin / cso',
    'final posting',
    'creative submitted',
    'revision requested',
    'forwarded to admin',
    'approved and published',
    'final pictures',
  ];
  return words.any((w) => title.contains(w) || message.contains(w)) ||
      title == 'new event';
}

Notification _notificationFromRow(Map<String, dynamic> row) => Notification(
      id: row['id']?.toString() ?? '',
      title: row['title']?.toString() ?? '',
      message: row['message']?.toString() ?? '',
      date: DateTime.tryParse(
              (row['date'] ?? row['created_at'])?.toString() ?? '') ??
          DateTime.now(),
      read: row['read'] == true,
      orgId: row['org_id']?.toString(),
      studentId: row['student_id']?.toString(),
    );

// =============================================================================
// _Select — rebuilds ONLY when the selected snapshot changes.
// AppState notifies on ~17 realtime tables (chat, usage logs, ...); listening
// to it directly would rebuild constantly. Selectors must return values with
// proper == (see _Snap), never the live in-place-mutated AppState lists.
// =============================================================================

class _Snap<E> {
  const _Snap(this.items);
  final List<E> items;

  @override
  bool operator ==(Object other) =>
      other is _Snap<E> && _sameItems(items, other.items);

  @override
  int get hashCode => items.length.hashCode;
}

class _Select<T> extends StatefulWidget {
  const _Select({required this.selector, required this.builder});
  final T Function() selector;
  final Widget Function(BuildContext context, T value) builder;

  @override
  State<_Select<T>> createState() => _SelectState<T>();
}

class _SelectState<T> extends State<_Select<T>> {
  late T _value;
  bool _queued = false;

  @override
  void initState() {
    super.initState();
    _value = widget.selector();
    AppState.instance.addListener(_onChange);
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (_queued) return;
    _queued = true;
    Future.microtask(() {
      _queued = false;
      if (!mounted) return;
      final next = widget.selector();
      if (next != _value) setState(() => _value = next);
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _value);
}

class _SmartImage extends StatelessWidget {
  const _SmartImage({
    required this.source,
    required this.width,
    required this.height,
    this.radius = 17,
    this.bg = _C.softGreen,
    this.icon = Icons.groups_rounded,
    this.iconSize = 28,
    this.borderColor,
    this.borderWidth = 1.0,
  });

  final String source;
  final double width;
  final double height;
  final double radius;
  final Color bg;
  final IconData icon;
  final double iconSize;
  final Color? borderColor;
  final double borderWidth;

  static final Map<String, Uint8List> _cache = <String, Uint8List>{};

  static Uint8List? _decode(String value) {
    final hit = _cache.remove(value);
    if (hit != null) {
      _cache[value] = hit; // refresh LRU position
      return hit;
    }
    try {
      final comma = value.indexOf(',');
      if (comma < 0) return null;
      final bytes = base64Decode(value.substring(comma + 1));
      _cache[value] = bytes;
      if (_cache.length > 30) _cache.remove(_cache.keys.first);
      return bytes;
    } catch (_) {
      return null;
    }
  }

  BoxDecoration _deco(Color? fill) => BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: borderWidth),
      );

  @override
  Widget build(BuildContext context) {
    final iconOnly = ColoredBox(
      color: bg,
      child: Center(child: Icon(icon, color: _C.green, size: iconSize)),
    );
    final value = source.trim();
    if (value.isEmpty) {
      return Container(
          width: width, height: height, decoration: _deco(bg), child: iconOnly);
    }

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final logicalW = width.isFinite ? width : MediaQuery.sizeOf(context).width;
    final cacheW = math.max(1, (logicalW * dpr).round());
    Widget errorBuilder(BuildContext _, Object __, StackTrace? ___) => iconOnly;

    final Widget image;
    if (value.startsWith('data:')) {
      final bytes = _decode(value);
      if (bytes == null) {
        return Container(
            width: width,
            height: height,
            decoration: _deco(bg),
            child: iconOnly);
      }
      image = Image.memory(bytes,
          fit: BoxFit.cover,
          cacheWidth: cacheW,
          gaplessPlayback: true,
          errorBuilder: errorBuilder);
    } else if (value.startsWith('http://') || value.startsWith('https://')) {
      image = Image.network(value,
          fit: BoxFit.cover,
          cacheWidth: cacheW,
          gaplessPlayback: true,
          errorBuilder: errorBuilder);
    } else {
      image = Image.asset(value,
          fit: BoxFit.cover,
          cacheWidth: cacheW,
          gaplessPlayback: true,
          errorBuilder: errorBuilder);
    }

    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: _deco(null),
      child: image,
    );
  }
}

// =============================================================================
// StudentDashboardScreen — shell with lazy, kept-alive tabs + bottom nav
// =============================================================================

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  DateTime? _lastBackPressed;
  int _selectedIndex = 0;
  final Set<int> _visited = <int>{0};
  final List<Widget?> _tabs = List<Widget?>.filled(4, null);

  void _select(int i) => setState(() {
        _selectedIndex = i;
        _visited.add(i);
      });

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  /// Built the first time it is selected, then kept alive.
  Widget _tab(int i) => _tabs[i] ??= RepaintBoundary(
        child: switch (i) {
          0 => NewHomeTab(
              onSwitchTab: _select,
              onOpenApplications: () => _push(const _MyApplicationsScreen()),
              onOpenJoinedOrgs: () => _push(const _JoinedOrganizationsScreen()),
              onOpenNotifications: () =>
                  _push(const NotificationScreen(showBackButton: true)),
            ),
          1 => const OrgListScreen(),
          2 => const StudentDashboard(),
          _ => const ProfileScreen(),
        },
      );

  void _onBack(bool didPop, Object? result) {
    if (didPop) return;
    if (_selectedIndex != 0) {
      _select(0);
      return;
    }
    final now = DateTime.now();
    final messenger = ScaffoldMessenger.of(context);
    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;
      final height = MediaQuery.sizeOf(context).height;
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: const Text(
            'Tap again to exit',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _C.toast,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: EdgeInsets.only(
              bottom: math.max(0.0, height - 140), left: 40, right: 40),
        ),
      );
    } else {
      messenger.clearSnackBars();
      SystemChannels.platform.invokeMethod('SystemNavigator.pop');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onBack,
      child: Scaffold(
        backgroundColor: _C.pageBg,
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            for (var i = 0; i < 4; i++)
              _visited.contains(i) ? _tab(i) : const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar:
            _BottomNav(selected: _selectedIndex, onSelect: _select),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.selected, required this.onSelect});
  final int selected;
  final ValueChanged<int> onSelect;

  static const List<(IconData, String)> _items = [
    (Icons.home_rounded, 'Home'),
    (Icons.groups_rounded, 'Orgs'),
    (Icons.calendar_month_rounded, 'Events'),
    (Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final iconSize = (width * 0.065).clamp(22.0, 30.0);
    final fontSize = (width * 0.028).clamp(10.0, 13.0);
    final minHeight = (width * 0.18).clamp(56.0, 72.0);

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < _items.length; i++)
                    Expanded(
                      child: _NavItem(
                        icon: _items[i].$1,
                        label: _items[i].$2,
                        selected: i == selected,
                        iconSize: iconSize,
                        fontSize: fontSize,
                        onTap: () => onSelect(i),
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

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.iconSize,
    required this.fontSize,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final double iconSize;
  final double fontSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? _C.green : _C.navInactive;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: iconSize, color: color),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: color,
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

// =============================================================================
// My Applications
// =============================================================================

class _AppRow {
  const _AppRow(this.app, this.org);
  final Application app;
  final Organization? org;

  @override
  bool operator ==(Object other) =>
      other is _AppRow &&
      identical(other.app, app) &&
      identical(other.org, org);

  @override
  int get hashCode => Object.hash(app, org);
}

/// Finds the organization record for an application (by id, name or acronym,
/// plus the legacy El Teatro name match).
Organization? _matchOrg(Application a, List<Organization> orgs) {
  final n = a.orgName.trim().toLowerCase();
  for (final o in orgs) {
    final name = o.name.trim().toLowerCase();
    final acronym = o.acronym.trim().toLowerCase();
    if ((a.orgId != null && o.id == a.orgId) ||
        name == n ||
        acronym == n ||
        (n.contains('el teatro') && name.contains('el teatro'))) {
      return o;
    }
  }
  return null;
}

_Snap<_AppRow> _selectApplications() {
  final app = AppState.instance;
  final authUserId = supabase.Supabase.instance.client.auth.currentUser?.id;
  // SECURITY: match ONLY on the authenticated user id.
  final mine = app.applications
      .where((a) => authUserId != null && a.userId == authUserId)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return _Snap<_AppRow>(
      [for (final a in mine) _AppRow(a, _matchOrg(a, app.organizations))]);
}

enum _AppFilter { all, pending, reviewed }

/// Reviewed = a final result was given. Everything else is still pending.
/// To move a status between tabs, edit this list only.
bool _isReviewed(ApplicationStatus s) =>
    s == ApplicationStatus.approved ||
    s == ApplicationStatus.accepted ||
    s == ApplicationStatus.declined ||
    s == ApplicationStatus.interviewed;

class _MyApplicationsScreen extends StatefulWidget {
  const _MyApplicationsScreen();

  @override
  State<_MyApplicationsScreen> createState() => _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends State<_MyApplicationsScreen> {
  bool _refreshing = true;
  bool _failed = false;
  _AppFilter _filter = _AppFilter.all;
  @override
  void initState() {
    super.initState();
    // Cached AppState data renders immediately; refresh happens after the
    // first frame so AppState notifications never land mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  Future<void> _refresh() async {
    if (!_refreshing || _failed) {
      setState(() {
        _refreshing = true;
        _failed = false;
      });
    }
    try {
      final app = AppState.instance;
      if (app.currentStudent == null) await app.loadStudentProfile();
      await Future.wait<void>([
        app.fetchApplications(),
        if (app.organizations.isEmpty) app.fetchOrganizations(),
      ]).timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('Could not refresh My Applications: $e');
      _failed = true;
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Select<_Snap<_AppRow>>(
      selector: _selectApplications,
      builder: (context, snap) {
        final rows = snap.items;
        final s = _sc(context);
        final side = _side(context);
        final bottom = MediaQuery.paddingOf(context).bottom;

        final pendingRows =
            rows.where((r) => !_isReviewed(r.app.status)).toList();
        final reviewedRows =
            rows.where((r) => _isReviewed(r.app.status)).toList();
        final filtered = switch (_filter) {
          _AppFilter.all => rows,
          _AppFilter.pending => pendingRows,
          _AppFilter.reviewed => reviewedRows,
        };

        final Widget body;
        if (rows.isEmpty && _refreshing) {
          body =
              const Center(child: CircularProgressIndicator(color: _C.green));
        } else if (rows.isEmpty && _failed) {
          body = const _QuickEmpty(
            icon: Icons.wifi_off_rounded,
            title: 'Could not load applications',
            subtitle: 'Check your connection and pull down to try again.',
          );
        } else if (rows.isEmpty) {
          body = const _QuickEmpty(
            icon: Icons.assignment_outlined,
            title: 'No applications yet',
            subtitle:
                'Organizations you apply to will appear here with their current status.',
          );
        } else if (filtered.isEmpty) {
          body = _QuickEmpty(
            icon: Icons.inbox_outlined,
            title: _filter == _AppFilter.pending
                ? 'No pending applications'
                : 'No reviewed applications',
            subtitle: _filter == _AppFilter.pending
                ? 'Applications waiting for a result will show up here.'
                : 'Applications with a final result will show up here.',
          );
        } else {
          body = ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
                18 * s + side, 18, 18 * s + side, 36 + bottom),
            // +1 for the "That's all for now" footer.
            itemCount: filtered.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              if (i == filtered.length) return const _ListFooter();
              return _ApplicationCard(
                  key: ValueKey(filtered[i].app.id), row: filtered[i]);
            },
          );
        }

        return Scaffold(
          backgroundColor: _C.pageBg,
          body: Column(children: [
            _StudentHeader(
              title: 'My Applications',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            _ApplicationsTop(
              subtitle: 'Track your organization applications',
              showControls: rows.isNotEmpty,
              activeCount: pendingRows.length,
              allCount: rows.length,
              pendingCount: pendingRows.length,
              reviewedCount: reviewedRows.length,
              filter: _filter,
              onFilter: (f) => setState(() => _filter = f),
            ),
            // Thin bar: old data stays visible while fresh data loads.
            // Fixed 2dp strip: always reserved, so the layout never shifts.
            // Idle = static divider line, refreshing = animated bar.
            // Static divider. Background refresh is silent (the cached list
            // stays visible); pull-to-refresh shows its own indicator.
            const Divider(height: 1, thickness: 1, color: _C.softGreen),
            Expanded(
              child: SafeArea(
                top: false,
                bottom: false,
                child: RefreshIndicator(
                  color: _C.green,
                  onRefresh: _refresh,
                  child: filtered.isEmpty
                      ? ListView(
                          // Must stay scrollable or pull-to-refresh is dead
                          // on Android when the empty state fits the screen.
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.sizeOf(context).height * 0.5,
                              child: body,
                            ),
                          ],
                        )
                      : body,
                ),
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _StudentHeader extends StatelessWidget {
  const _StudentHeader({
    required this.title,
    required this.onBack,
  });

  final String title;
  final VoidCallback onBack;

  static const double _barHeight = 72;

  Widget _orb(double size) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: .07),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final top = mq.padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        height: _barHeight + top,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          gradient: AppHeader.brandGradient,
        ),
        child: Stack(
          children: [
            Positioned(right: -30, top: -50, child: _orb(120)),
            Positioned(right: 45, bottom: -50, child: _orb(90)),

            // Title: vertically centered in the bar
            Positioned(
              left: 60,
              right: 16,
              top: top,
              height: _barHeight,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),

            // Back button: same center line as the title
            Positioned(
              left: 8,
              top: top,
              height: _barHeight,
              child: Center(
                child: IconButton(
                  tooltip: 'Back',
                  onPressed: onBack,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 44, minHeight: 44),
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Title, summary card and filter chips shown below the header.
class _ApplicationsTop extends StatelessWidget {
  const _ApplicationsTop({
    required this.subtitle,
    required this.showControls,
    required this.activeCount,
    required this.allCount,
    required this.pendingCount,
    required this.reviewedCount,
    required this.filter,
    required this.onFilter,
  });

  final String subtitle;
  final bool showControls;
  final int activeCount;
  final int allCount;
  final int pendingCount;
  final int reviewedCount;
  final _AppFilter filter;
  final ValueChanged<_AppFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    final s = _sc(context);
    final side = _side(context);
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.fromLTRB(18 * s + side, 18, 18 * s + side, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your applications',
              style: TextStyle(
                  color: _C.ink, fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(color: _C.muted, fontSize: 13)),
            if (showControls) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: _cardDeco(radius: 18),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                          color: _C.softGreen,
                          borderRadius: BorderRadius.circular(13)),
                      child: const Icon(Icons.assignment_rounded,
                          color: _C.green, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '$activeCount active application${activeCount == 1 ? '' : 's'}',
                        style: const TextStyle(
                            color: _C.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: _C.softGreen,
                          borderRadius: BorderRadius.circular(12)),
                      child: Text('$activeCount',
                          style: const TextStyle(
                              color: _C.green,
                              fontSize: 13,
                              fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChipButton(
                      label: 'All ($allCount)',
                      selected: filter == _AppFilter.all,
                      onTap: () => onFilter(_AppFilter.all),
                    ),
                    const SizedBox(width: 8),
                    _FilterChipButton(
                      label: 'Pending ($pendingCount)',
                      selected: filter == _AppFilter.pending,
                      onTap: () => onFilter(_AppFilter.pending),
                    ),
                    const SizedBox(width: 8),
                    _FilterChipButton(
                      label: 'Reviewed ($reviewedCount)',
                      selected: filter == _AppFilter.reviewed,
                      onTap: () => onFilter(_AppFilter.reviewed),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _C.green : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? _C.green : _C.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : _C.body,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _ListFooter extends StatelessWidget {
  const _ListFooter();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Icon(Icons.eco_rounded, size: 18, color: _C.green),
          SizedBox(height: 6),
          Text("That's all for now.",
              style: TextStyle(
                  color: _C.muted, fontSize: 12, fontWeight: FontWeight.w700)),
          SizedBox(height: 2),
          Text('Check back for updates on your applications.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _C.muted, fontSize: 11.5)),
        ],
      ),
    );
  }
}

Color _statusColor(ApplicationStatus status) {
  switch (status) {
    case ApplicationStatus.approved:
    case ApplicationStatus.accepted:
      return _C.green;
    case ApplicationStatus.declined:
      return _C.red;
    case ApplicationStatus.interviewed:
    case ApplicationStatus.interviewScheduled:
      return _C.amber;
    default:
      return _C.blue;
  }
}

String _statusLabel(ApplicationStatus status) {
  if (status == ApplicationStatus.approved ||
      status == ApplicationStatus.accepted) {
    return 'Approved';
  }
  // Enum names are camelCase: forApproval -> "For Approval".
  final spaced =
      status.name.replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m[0]}').trim();
  return spaced[0].toUpperCase() + spaced.substring(1);
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({super.key, required this.row});
  final _AppRow row;

  @override
  Widget build(BuildContext context) {
    final application = row.app;
    final org = row.org;
    final s = _sc(context);
    final color = _statusColor(application.status);
    final rawName = application.orgName.trim();

    // The organization was renamed from SCAP to Student Catholic Action.
    // Prefer the current organization record so old rows cannot revert it.
    final displayName = org?.name.trim().isNotEmpty == true
        ? org!.name
        : (rawName.toLowerCase() == 'scap'
            ? 'Student Catholic Action'
            : rawName);

    return Container(
      padding: EdgeInsets.all(16 * s),
      decoration: _cardDeco(),
      child: Row(
        children: [
          if (org != null)
            _SmartImage(source: org.logoAsset, width: 46 * s, height: 46 * s)
          else
            Container(
              width: 46 * s,
              height: 46 * s,
              decoration: BoxDecoration(
                  color: _C.softGreen, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.groups_rounded, color: _C.green),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName,
                    style: const TextStyle(
                        color: _C.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('Applied ${_mdy(application.createdAt)}',
                    style: const TextStyle(color: _C.muted, fontSize: 11.5)),
                if (application.status == ApplicationStatus.declined &&
                    application.declineReason.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Reason: ${application.declineReason}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _C.redDark, fontSize: 11.5, height: 1.35)),
                ],
              ],
            ),
          ),
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(12)),
              child: Text(_statusLabel(application.status),
                  style: TextStyle(
                      color: color,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Joined Organizations
// =============================================================================

/// Joined = profile.joinedOrgIds
///        + orgs of member rows owned by this profile
///        + orgs of approved/accepted applications owned by this student.
/// Name matching is a fallback ONLY for legacy member rows with no profileId,
/// so two students with the same name can never see each other's orgs.
_Snap<Organization> _selectJoinedOrgs() {
  final app = AppState.instance;
  final student = app.currentStudent;
  final authId = supabase.Supabase.instance.client.auth.currentUser?.id;
  final ids = <String>{...?student?.joinedOrgIds};
  final names = <String>{};

  void add(String? id, String name) {
    final trimmedId = id?.trim();
    if (trimmedId != null && trimmedId.isNotEmpty) ids.add(trimmedId);
    final n = name.trim().toLowerCase();
    if (n.isNotEmpty) names.add(n);
  }

  if (student != null) {
    final myName = student.name.trim().toLowerCase();
    for (final m in app.members) {
      final pid = m.profileId ?? '';
      final isMine = pid.isNotEmpty
          ? pid == student.id
          : (myName.isNotEmpty && m.name.trim().toLowerCase() == myName);
      if (isMine) add(m.orgId, m.orgName);
    }
  }

  final myStudentId = student?.studentId.trim() ?? '';
  for (final a in app.applications) {
    if (a.status != ApplicationStatus.approved &&
        a.status != ApplicationStatus.accepted) {
      continue;
    }
    final uid = a.userId ?? '';
    final byUser = uid.isNotEmpty && (uid == authId || uid == student?.id);
    final byStudentId =
        myStudentId.isNotEmpty && a.studentId.trim() == myStudentId;
    if (byUser || byStudentId) add(a.orgId, a.orgName);
  }

  return _Snap<Organization>([
    for (final o in app.organizations)
      if (ids.contains(o.id) || names.contains(o.name.trim().toLowerCase())) o,
  ]);
}

class _JoinedOrganizationsScreen extends StatefulWidget {
  const _JoinedOrganizationsScreen();

  @override
  State<_JoinedOrganizationsScreen> createState() =>
      _JoinedOrganizationsScreenState();
}

class _JoinedOrganizationsScreenState
    extends State<_JoinedOrganizationsScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  /// Cached data is shown immediately; this refreshes in the background.
  Future<void> _load() async {
    try {
      final app = AppState.instance;
      if (app.currentStudent == null) await app.loadStudentProfile();
      await Future.wait<void>([app.fetchOrganizations(), app.fetchMembers()]);
    } catch (e) {
      debugPrint('Error loading Joined Orgs: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Select<_Snap<Organization>>(
      selector: _selectJoinedOrgs,
      builder: (context, snap) {
        final joined = snap.items;
        final s = _sc(context);
        final side = _side(context);
        final bottom = MediaQuery.paddingOf(context).bottom;

        final Widget body;
        if (joined.isEmpty && _loading) {
          body =
              const Center(child: CircularProgressIndicator(color: _C.green));
        } else if (joined.isEmpty) {
          body = const _QuickEmpty(
            icon: Icons.groups_outlined,
            title: 'No organizations joined yet',
            subtitle:
                'When an application is accepted, your organization will appear here.',
          );
        } else {
          body = ListView.separated(
            padding: EdgeInsets.fromLTRB(
                18 * s + side, 18, 18 * s + side, 36 + bottom),
            itemCount: joined.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) =>
                _JoinedOrgCard(key: ValueKey(joined[i].id), org: joined[i]),
          );
        }

        return Scaffold(
          backgroundColor: _C.pageBg,
          body: Column(children: [
            _StudentHeader(
              title: 'Joined Organizations',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            _JoinedTop(
              subtitle: 'Your organization communities',
              status: joined.isEmpty
                  ? 'NO ORGANIZATIONS YET'
                  : '${joined.length} JOINED',
            ),
            Expanded(
              child: SafeArea(top: false, bottom: false, child: body),
            ),
          ]),
        );
      },
    );
  }
}

// Subtitle + status shown BELOW the header on the Joined Organizations screen.
class _JoinedTop extends StatelessWidget {
  const _JoinedTop({required this.subtitle, required this.status});
  final String subtitle;
  final String status;

  @override
  Widget build(BuildContext context) {
    final s = _sc(context);
    final side = _side(context);
    return SizedBox(
      width: double.infinity,
      child: Padding(
          padding: EdgeInsets.fromLTRB(18 * s + side, 18, 18 * s + side, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subtitle,
                style: const TextStyle(
                  color: _C.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _C.softGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: _C.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      status,
                      style: const TextStyle(
                        color: _C.green,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )),
    );
  }
}

class _JoinedOrgCard extends StatelessWidget {
  const _JoinedOrgCard({super.key, required this.org});
  final Organization org;

  @override
  Widget build(BuildContext context) {
    final s = _sc(context);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => _MemberOrganizationSpace(org: org))),
        child: Container(
          padding: EdgeInsets.all(14 * s),
          decoration: _cardDeco(radius: 22, color: null),
          child: Row(
            children: [
              _SmartImage(source: org.logoAsset, width: 62 * s, height: 62 * s),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(org.name,
                        style: const TextStyle(
                            color: _C.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      org.shortDesc.isEmpty
                          ? 'Your member community'
                          : org.shortDesc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _C.muted, fontSize: 11.5, height: 1.35),
                    ),
                    const SizedBox(height: 7),
                    const Row(
                      children: [
                        Icon(Icons.campaign_rounded, size: 14, color: _C.green),
                        SizedBox(width: 4),
                        Text('No new updates',
                            style: TextStyle(
                                color: _C.green,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _C.muted),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Member Organization Space
// =============================================================================

class _OrgView {
  const _OrgView(this.org, this.events, this.memberCount);
  final Organization org;
  final List<Event> events;
  final int memberCount;

  @override
  bool operator ==(Object other) =>
      other is _OrgView &&
      identical(other.org, org) &&
      other.memberCount == memberCount &&
      _sameItems(other.events, events);

  @override
  int get hashCode => Object.hash(org, memberCount, events.length);
}

_OrgView _orgViewFor(Organization base) {
  final app = AppState.instance;
  // Use the freshest org record (realtime may have updated it).
  final org =
      app.organizations.firstWhere((o) => o.id == base.id, orElse: () => base);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final events = app.events
      .where((e) =>
          (e.orgId == org.id || e.orgName == org.name) &&
          !DateTime(e.date.year, e.date.month, e.date.day).isBefore(today))
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  // Unique lowercase member names for this org + officer names not yet counted.
  final names = <String>{};
  for (final m in app.members) {
    if (m.orgId != org.id && m.orgName != org.name) continue;
    final n = m.name.trim().toLowerCase();
    if (n.isNotEmpty) names.add(n);
  }
  for (final raw in org.officers) {
    final n = _parseOfficer(raw).$2.toLowerCase();
    if (n.isNotEmpty) names.add(n);
  }
  return _OrgView(org, events.take(8).toList(), names.length);
}

class _MemberOrganizationSpace extends StatefulWidget {
  const _MemberOrganizationSpace({required this.org});
  final Organization org;

  @override
  State<_MemberOrganizationSpace> createState() =>
      _MemberOrganizationSpaceState();
}

class _MemberOrganizationSpaceState extends State<_MemberOrganizationSpace> {
  List<Notification> _announcements = <Notification>[];
  List<Map<String, dynamic>> _people = <Map<String, dynamic>>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<List<Notification>> _queryAnnouncements(String orgId) async {
    final rows = await supabase.Supabase.instance.client
        .from('notifications')
        .select('id,title,message,date,read,org_id,student_id,created_at')
        .eq('org_id', orgId)
        .order('created_at', ascending: false)
        .limit(50);
    // Read org rows directly so adviser announcements show even if an old row
    // was mistakenly addressed to a student; personal types stay in
    // Notifications.
    return [
      for (final r in (rows as List))
        _notificationFromRow(Map<String, dynamic>.from(r as Map)),
    ]
        .where(
            (n) => !_isPersonalNotification(n) && !_isWorkflowNotification(n))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<List<Map<String, dynamic>>> _queryPeople(String orgId) async {
    final rows = await supabase.Supabase.instance.client
        .from('profiles')
        .select('id,name,role,avatar_url,assigned_org_id,org_id')
        .or('assigned_org_id.eq.$orgId,org_id.eq.$orgId')
        // PostgREST "in" is case-sensitive, so cover both spellings.
        .inFilter(
            'role', ['officer', 'Officer', 'adviser', 'Adviser']).order('name');
    return [
      for (final r in (rows as List)) Map<String, dynamic>.from(r as Map),
    ];
  }

  /// On open: only this org's two direct queries + a member refresh scoped to
  /// this org. Pull-to-refresh (full: true) also refreshes the shared state.
  /// Each request is guarded so one failure never wipes the others.
  Future<void> _load({bool full = false}) async {
    final app = AppState.instance;
    final id = widget.org.id;

    final announcementsF = _guard<List<Notification>>(
        () => _queryAnnouncements(id), _announcements, 'org notifications');
    final peopleF = _guard<List<Map<String, dynamic>>>(
        () => _queryPeople(id), _people, 'org people');
    final sharedF = Future.wait<void>([
      _guard<void>(() => app.fetchMembers(organizationId: id), null, 'members'),
      if (full) ...[
        _guard<void>(app.fetchOrganizations, null, 'organizations'),
        _guard<void>(app.fetchEvents, null, 'events'),
        _guard<void>(app.fetchNotifications, null, 'notifications'),
      ],
    ]);

    final announcements = await announcementsF;
    final people = await peopleF;
    await sharedF;
    if (!mounted) return;
    setState(() {
      _announcements = announcements;
      _people = people;
      _loading = false;
    });

    // Opening the space counts as seeing the announcements that are SHOWN.
    // NOTE: org-wide announcements share one `read` column, so one student
    // opening this marks them read for everyone. The real fix needs a
    // per-user read table.
    final unread = announcements.take(10).where((n) => !n.read).toList();
    if (unread.isEmpty) return;
    try {
      await Future.wait<void>(
          unread.map((n) => app.markNotificationRead(n.id)));
    } catch (e) {
      debugPrint('Error marking announcements read: $e');
    }
    if (!mounted) return;
    final readIds = {for (final n in unread) n.id};
    setState(() {
      _announcements = [
        for (final n in _announcements)
          readIds.contains(n.id) ? n.copyWith(read: true) : n,
      ];
    });
  }

  Widget _announcementsBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_announcements.isEmpty) {
      return const Text(
        'No organization announcements have been posted yet. Meeting notices, reminders, deadlines, and other member updates will appear here.',
        style: TextStyle(color: _C.muted, height: 1.45),
      );
    }
    return Column(children: [
      for (final n in _announcements.take(10)) _AnnouncementTile(n: n),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return _Select<_OrgView>(
      selector: () => _orgViewFor(widget.org),
      builder: (context, v) {
        final org = v.org;
        final s = _sc(context);
        final side = _side(context);
        final bottom = MediaQuery.paddingOf(context).bottom;

        return Scaffold(
          backgroundColor: _C.pageBg,
          body: Column(children: [
            _StudentOrgHeader(org: org),
            Expanded(
              child: SafeArea(
                top: false,
                bottom: false,
                child: RefreshIndicator(
                  onRefresh: () => _load(full: true),
                  color: _C.green,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                        16 * s + side, 16, 16 * s + side, 28 + bottom),
                    children: [
                      _CommunitySection(
                        title: 'Organization announcements',
                        icon: Icons.campaign_rounded,
                        child: _announcementsBody(),
                      ),
                      const SizedBox(height: 14),
                      _CommunitySection(
                        title: 'Upcoming events',
                        icon: Icons.event_rounded,
                        child: v.events.isEmpty
                            ? const Text('No upcoming events posted yet.',
                                style: TextStyle(color: _C.muted))
                            : Column(children: [
                                for (final e in v.events)
                                  _UpcomingEventCard(
                                      key: ValueKey(e.id), event: e),
                              ]),
                      ),
                      const SizedBox(height: 14),
                      _CommunitySection(
                        title: 'Adviser and Officers',
                        icon: Icons.badge_rounded,
                        child: _OfficersSection(org: org, people: _people),
                      ),
                      const SizedBox(height: 14),
                      _CommunitySection(
                        title: 'Members',
                        icon: Icons.groups_rounded,
                        child: _MemberCount(count: v.memberCount),
                      ),
                      const SizedBox(height: 14),
                      _CommunitySection(
                        title: 'Community Chat',
                        icon: Icons.forum_rounded,
                        child: _ChatCard(org: org),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  const _AnnouncementTile({required this.n});
  final Notification n;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _C.tileBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.tileBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: _C.softGreen, borderRadius: BorderRadius.circular(13)),
            child: const Icon(Icons.campaign_rounded, color: _C.green),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n.title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(n.message,
                    style: const TextStyle(color: _C.body, height: 1.35)),
                const SizedBox(height: 6),
                Text(_mdy(n.date),
                    style: const TextStyle(
                        color: _C.green,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingEventCard extends StatelessWidget {
  const _UpcomingEventCard({super.key, required this.event});
  final Event event;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final image = (e.imageUrl != null && e.imageUrl!.isNotEmpty)
        ? e.imageUrl!
        : (e.imageUrls.isNotEmpty ? e.imageUrls.first : '');

    return LayoutBuilder(builder: (context, c) {
      // ~175dp on a 360dp phone; grows with the card, within sane bounds.
      final imageHeight = math.min(260.0, math.max(150.0, c.maxWidth / 1.7));
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        decoration: _cardDeco(blur: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (image.isNotEmpty)
              SizedBox(
                height: imageHeight,
                width: double.infinity,
                child: Stack(children: [
                  Positioned.fill(
                    child: _SmartImage(
                      source: image,
                      width: double.infinity,
                      height: imageHeight,
                      radius: 0,
                      bg: const Color(0xFFDDF4E8),
                      icon: Icons.event_rounded,
                      iconSize: 40,
                    ),
                  ),
                  const Positioned(left: 12, top: 12, child: _UpcomingBadge()),
                ]),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.title,
                      style: const TextStyle(
                          color: _C.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                        color: _C.softGreen,
                        borderRadius: BorderRadius.circular(11)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_month_rounded,
                            size: 14, color: _C.green),
                        const SizedBox(width: 6),
                        Text(_mdy(e.date),
                            style: const TextStyle(
                                color: _C.green,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  if (e.description.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Text(e.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _C.muted, fontSize: 12, height: 1.4)),
                  ],
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () => showEventComments(context,
                          eventId: e.id, eventTitle: e.title),
                      icon: const Icon(Icons.forum_outlined, size: 15),
                      label: EventCommentCountLabel(
                        eventId: e.id,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _C.softGreen,
                        foregroundColor: _C.green,
                        elevation: 0,
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _UpcomingBadge extends StatelessWidget {
  const _UpcomingBadge();

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .92),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available_rounded, size: 14, color: _C.green),
            SizedBox(width: 5),
            Text('Upcoming',
                style: TextStyle(
                    color: _C.green,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

Map<String, dynamic>? _liveProfileByName(
        List<Map<String, dynamic>> people, String lowerName) =>
    _firstWhereOrNull(
        people, (p) => p['name']?.toString().trim().toLowerCase() == lowerName);

String _roleOf(Map<String, dynamic> p) =>
    p['role']?.toString().toLowerCase() ?? '';

class _OfficersSection extends StatelessWidget {
  const _OfficersSection({required this.org, required this.people});
  final Organization org;
  final List<Map<String, dynamic>> people;

  /// Officer tile data: the org's own officer list when present (enriched with
  /// live avatars / saved profiles), otherwise the live officer profiles.
  List<Map<String, dynamic>> _officerTiles(List<Map<String, dynamic>> live) {
    if (org.officers.isEmpty) return live;
    return [
      for (final raw in org.officers)
        () {
          final (role, name) = _parseOfficer(raw);
          final key = name.toLowerCase();
          final liveAvatar = _liveProfileByName(people, key)?['avatar_url']
                  ?.toString()
                  .trim() ??
              '';
          final saved = _firstWhereOrNull(
              org.officerProfiles, (p) => p.name.trim().toLowerCase() == key);
          final savedAvatar = saved?.avatarUrl.trim() ?? '';
          return <String, dynamic>{
            'name': name,
            'role': saved?.role ?? role,
            'avatar_url': liveAvatar.isNotEmpty ? liveAvatar : savedAvatar,
          };
        }(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final advisers = people.where((p) => _roleOf(p) == 'adviser').toList();
    final officers = people.where((p) => _roleOf(p) == 'officer').toList();
    final tiles = _officerTiles(officers);
    const labelStyle = TextStyle(fontWeight: FontWeight.w900, color: _C.ink2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (advisers.isNotEmpty || org.adviser.trim().isNotEmpty) ...[
          const Text('Adviser', style: labelStyle),
          const SizedBox(height: 10),
          _OrganizationPersonTile(
            person: advisers.isNotEmpty
                ? advisers.first
                : {
                    'name': org.adviser.trim(),
                    'role': 'Adviser',
                    'avatar_url': '',
                  },
            fallbackIcon: Icons.school_rounded,
            wide: true,
          ),
          const SizedBox(height: 16),
        ],
        const Text('Officers', style: labelStyle),
        const SizedBox(height: 10),
        if (tiles.isEmpty)
          const Text(
              'No officer profiles have been posted for this organization yet.',
              style: TextStyle(color: _C.muted))
        else
          LayoutBuilder(builder: (context, c) {
            // Tiles are at least 132dp wide, at least 2 per row, and stretch
            // to fill the row so no space is wasted on any screen width.
            const minWidth = 132.0;
            const gap = 10.0;
            final cols =
                math.max(2, ((c.maxWidth + gap) / (minWidth + gap)).floor());
            final tileWidth = (c.maxWidth - (cols - 1) * gap) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: 12,
              children: [
                for (final p in tiles)
                  SizedBox(
                    width: tileWidth,
                    child: _OrganizationPersonTile(
                        person: p, fallbackIcon: Icons.badge_rounded),
                  ),
              ],
            );
          }),
      ],
    );
  }
}

class _OrganizationPersonTile extends StatelessWidget {
  const _OrganizationPersonTile({
    required this.person,
    required this.fallbackIcon,
    this.wide = false,
  });

  final Map<String, dynamic> person;
  final IconData fallbackIcon;
  final bool wide;

  static String _roleLabel(String role) =>
      role.isEmpty ? role : role[0].toUpperCase() + role.substring(1);

  @override
  Widget build(BuildContext context) {
    final name = (person['name']?.toString().trim().isNotEmpty ?? false)
        ? person['name'].toString().trim()
        : 'Organization member';
    final role = person['role']?.toString().trim() ?? '';
    final avatarUrl = person['avatar_url']?.toString().trim() ?? '';
    final size = wide ? 82.0 : 86.0;

    final image = _SmartImage(
      source: avatarUrl,
      width: size,
      height: size,
      radius: 18,
      borderColor: _C.border,
      icon: fallbackIcon,
      iconSize: 30,
    );

    if (wide) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FFFB), Color(0xFFE7F8F0)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _C.border),
        ),
        child: Row(
          children: [
            image,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _C.ink2,
                          fontSize: 14,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(role.isEmpty ? 'Adviser' : _roleLabel(role),
                      style: const TextStyle(
                          color: _C.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 7),
                  const Text('Organization adviser',
                      style: TextStyle(color: _C.muted, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8EEE4)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x070F8A61), blurRadius: 12, offset: Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          image,
          const SizedBox(height: 8),
          Text(name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: _C.ink2,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  height: 1.2)),
          if (role.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(_roleLabel(role),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _C.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

class _MemberCount extends StatelessWidget {
  const _MemberCount({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
              color: _C.softGreen, borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.groups_rounded, color: _C.green),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Organization members',
                  style:
                      TextStyle(color: _C.ink2, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text('$count ${count == 1 ? 'member' : 'members'}',
                  style: const TextStyle(
                      color: _C.green,
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatCard extends StatelessWidget {
  const _ChatCard({required this.org});
  final Organization org;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
            'Open your organization community. Messages are shared with members, officers, and the adviser in the same organization.',
            style: TextStyle(color: _C.chat, fontSize: 12, height: 1.4)),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) =>
                  OrgCommunityChatScreen(orgId: org.id, orgName: org.name))),
          icon: const Icon(Icons.forum_rounded),
          label: const Text('Open Community Chat'),
          style: FilledButton.styleFrom(
              backgroundColor: _C.green, foregroundColor: Colors.white),
        ),
      ],
    );
  }
}

class _StudentOrgHeader extends StatelessWidget {
  const _StudentOrgHeader({required this.org});
  final Organization org;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final s = _sc(context);

    // 150dp is a MINIMUM (it includes the status-bar inset); it grows with
    // large text instead of overflowing.
    return ConstrainedBox(
      constraints:
          const BoxConstraints(minWidth: double.infinity, minHeight: 150),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_C.teal, _C.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(76, 12, 20, 0),
              child: Row(children: [
                _SmartImage(
                    source: org.logoAsset, width: 60 * s, height: 60 * s),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Member Space',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              height: 1.1)),
                      const SizedBox(height: 4),
                      Text('Stay connected with ${org.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ]),
            ),
          ),
          Positioned(
            left: pad.left + 8,
            top: pad.top + 4,
            child: IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white),
            ),
          ),
        ]),
      ),
    );
  }
}

// =============================================================================
// Small shared widgets
// =============================================================================

class _CommunitySection extends StatelessWidget {
  const _CommunitySection(
      {required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      decoration: _cardDeco(shadow: const Color(0x080F8A61), blur: 12, dy: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: _C.softGreen, borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, color: _C.green, size: 18),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      color: _C.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w900)),
            ),
          ]),
          const SizedBox(height: 11),
          child,
        ],
      ),
    );
  }
}

class _QuickEmpty extends StatelessWidget {
  const _QuickEmpty(
      {required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    // Scrollable so large text sizes can never cause a RenderFlex overflow.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient:
                    const LinearGradient(colors: [_C.green, Color(0xFF20B77D)]),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _C.ink, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _C.muted, fontSize: 12.5, height: 1.45)),
          ],
        ),
      ),
    );
  }
}
