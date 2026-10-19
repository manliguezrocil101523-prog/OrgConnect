import 'dart:convert';

import 'package:flutter/material.dart' hide Notification;

import '../../../core/analytics_service.dart';
import '../../../core/app_state.dart';
import 'home_data.dart';
import 'home_tokens.dart';
import 'home_events_section.dart';
import 'home_recommended_section.dart';
import 'home_search_page.dart';

/// New student Home tab. Navigation is handed in by the dashboard shell, so
/// this file never touches the shell's private screens.
class NewHomeTab extends StatefulWidget {
  final void Function(int index)
      onSwitchTab; // 0 Home, 1 Orgs, 2 Events, 3 Profile
  final VoidCallback onOpenApplications;
  final VoidCallback onOpenJoinedOrgs;
  final VoidCallback onOpenNotifications;

  const NewHomeTab({
    super.key,
    required this.onSwitchTab,
    required this.onOpenApplications,
    required this.onOpenJoinedOrgs,
    required this.onOpenNotifications,
  });

  @override
  State<NewHomeTab> createState() => _NewHomeTabState();
}

class _NewHomeTabState extends State<NewHomeTab> {
  @override
  void initState() {
    super.initState();
    AppState.instance.fetchEvents();
    AnalyticsService.instance
        .logUsage('open_student_dashboard', route: 'student/home');
  }

  void _openSearch({bool openFilters = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HomeSearchPage(openFiltersOnStart: openFilters),
      ),
    );
  }

  Future<void> _refresh() async {
    try {
      await Future.wait<void>([
        AppState.instance.fetchEvents(),
        AppState.instance.fetchOrganizations(),
        AppState.instance.fetchApplications(),
        AppState.instance.fetchNotifications(),
      ]);
    } catch (e) {
      debugPrint('Home refresh failed: $e');
    }
  }

  ImageProvider? _avatar() {
    final url = AppState.instance.currentStudent?.avatarUrl ?? '';
    if (url.isEmpty) return null;
    if (url.startsWith('data:')) {
      try {
        return MemoryImage(base64Decode(url.substring(url.indexOf(',') + 1)));
      } catch (_) {
        return null;
      }
    }
    return NetworkImage(url);
  }

  String _greeting() {
    final h = DateTime.now().hour;
    final part =
        h < 12 ? 'Good morning' : (h < 18 ? 'Good afternoon' : 'Good evening');
    final name = (AppState.instance.currentStudent?.name ?? '').trim();
    if (name.isEmpty) return '$part! 👋';
    return '$part, ${name.split(RegExp(r'\s+')).first}! 👋';
  }

  @override
  Widget build(BuildContext context) {
    return HomeLayout.capText(
      context,
      AnimatedBuilder(
        animation: AppState.instance,
        builder: (context, _) {
          final l = HomeLayout.of(context);
          return RefreshIndicator(
            color: HC.primary,
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              padding: EdgeInsets.zero,
              children: [
                _Hero(
                  layout: l,
                  greeting: _greeting(),
                  avatar: _avatar(),
                  hasUnread: HomeData.unreadNotificationCount() > 0,
                  onBell: widget.onOpenNotifications,
                  onAvatar: () => widget.onSwitchTab(3),
                  onSearch: () => _openSearch(),
                  onFilter: () => _openSearch(openFilters: true),
                ),
                _Centered(
                  layout: l,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(l.hPad, 18, l.hPad, 0),
                    child: _QuickActions(
                      applicationBadge: HomeData.inProgressApplicationCount(),
                      onDiscover: () => widget.onSwitchTab(1),
                      onEvents: () => widget.onSwitchTab(2),
                      onApplications: widget.onOpenApplications,
                      onJoined: widget.onOpenJoinedOrgs,
                    ),
                  ),
                ),
                _Centered(
                  layout: l,
                  child: HomeRecommendedSection(
                    onViewAll: () => widget.onSwitchTab(1),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  final HomeLayout layout;
  final Widget child;
  const _Centered({required this.layout, required this.child});

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: layout.contentWidth),
          child: child,
        ),
      );
}

// ─── Hero ────────────────────────────────────────────────────────────────────
class _Hero extends StatelessWidget {
  final HomeLayout layout;
  final String greeting;
  final ImageProvider? avatar;
  final bool hasUnread;
  final VoidCallback onBell;
  final VoidCallback onAvatar;
  final VoidCallback onSearch;
  final VoidCallback onFilter;

  const _Hero({
    required this.layout,
    required this.greeting,
    required this.avatar,
    required this.hasUnread,
    required this.onBell,
    required this.onAvatar,
    required this.onFilter,
    required this.onSearch,
  });

  static const double _searchHeight = 56;
  static const double _overlap = _searchHeight / 2;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final narrow = layout.isNarrow;

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: _overlap),
          child: Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              gradient: HC.heroGradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: Stack(
              children: [
                Positioned(right: -50, top: -70, child: _orb(180)),
                Positioned(right: 40, bottom: -80, child: _orb(130)),
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: layout.contentWidth),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                          layout.hPad, top + 10, layout.hPad, _overlap + 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _Logo(size: narrow ? 38 : 44),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'OrgConnect',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: narrow ? 20 : 23,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              _BellButton(hasUnread: hasUnread, onTap: onBell),
                              const SizedBox(width: 6),
                              _AvatarButton(image: avatar, onTap: onAvatar),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            greeting,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: narrow ? 22 : 26,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Your campus. Your organizations. Your journey.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .88),
                              fontSize: narrow ? 12 : 13,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: layout.contentWidth),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: layout.hPad),
                child: _SearchBar(
                    height: _searchHeight, onTap: onSearch, onFilter: onFilter),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _orb(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: .07),
        ),
      );
}

class _Logo extends StatelessWidget {
  final double size;
  const _Logo({required this.size});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.12),
        decoration:
            const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: ClipOval(
          child: Image.asset(
            'assets/icon/app_logo.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.groups_rounded, color: HC.primary),
          ),
        ),
      );
}

class _BellButton extends StatelessWidget {
  final bool hasUnread;
  final VoidCallback onTap;
  const _BellButton({required this.hasUnread, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: hasUnread ? 'Notifications, unread' : 'Notifications',
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.notifications_none_rounded,
                    color: Colors.white, size: 27),
                if (hasUnread)
                  Positioned(
                    top: 9,
                    right: 11,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: HC.danger,
                        shape: BoxShape.circle,
                        border: Border.all(color: HC.dark, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}

class _AvatarButton extends StatelessWidget {
  final ImageProvider? image;
  final VoidCallback onTap;
  const _AvatarButton({required this.image, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Open profile',
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
            child: CircleAvatar(
              radius: 19,
              backgroundColor: HC.mint,
              backgroundImage: image,
              child: image == null
                  ? const Icon(Icons.person_rounded,
                      color: HC.primary, size: 22)
                  : null,
            ),
          ),
        ),
      );
}

// ─── Search bar (visual for now) ─────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final double height;
  final VoidCallback onTap;
  final VoidCallback onFilter;

  const _SearchBar({
    required this.height,
    required this.onTap,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
                color: Color(0x260F8A61), blurRadius: 18, offset: Offset(0, 6)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: HC.primary, size: 23),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Search organizations, events, or keywords…',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: HC.muted,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(width: 1, height: 24, color: HC.line),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onFilter,
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child:
                          Icon(Icons.tune_rounded, color: HC.primary, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

// ─── Quick actions ───────────────────────────────────────────────────────────
class _QA {
  final IconData icon;
  final List<String> lines;
  final VoidCallback onTap;
  final int badge;
  const _QA(this.icon, this.lines, this.onTap, {this.badge = 0});
}

class _QuickActions extends StatelessWidget {
  final int applicationBadge;
  final VoidCallback onDiscover;
  final VoidCallback onEvents;
  final VoidCallback onApplications;
  final VoidCallback onJoined;

  const _QuickActions({
    required this.applicationBadge,
    required this.onDiscover,
    required this.onEvents,
    required this.onApplications,
    required this.onJoined,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const gap = 8.0;
      // 4 across only when each card would be at least 80px wide.
      final fourAcross = (c.maxWidth - gap * 3) / 4 >= 80;

      final items = <_QA>[
        _QA(Icons.explore_rounded, const ['Discover', 'Organizations'],
            onDiscover),
        _QA(Icons.event_note_rounded, const ['Upcoming', 'Events'], onEvents),
        _QA(Icons.assignment_rounded, const ['My', 'Applications'],
            onApplications,
            badge: applicationBadge),
        _QA(Icons.groups_rounded, const ['Joined', 'Orgs'], onJoined),
      ];

      Widget card(_QA a) => _QuickCard(a: a, roomy: !fourAcross);

      if (fourAcross) {
        return Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              Expanded(child: card(items[i])),
            ],
          ],
        );
      }
      return Column(
        children: [
          Row(children: [
            Expanded(child: card(items[0])),
            const SizedBox(width: gap),
            Expanded(child: card(items[1])),
          ]),
          const SizedBox(height: gap),
          Row(children: [
            Expanded(child: card(items[2])),
            const SizedBox(width: gap),
            Expanded(child: card(items[3])),
          ]),
        ],
      );
    });
  }
}

class _QuickCard extends StatelessWidget {
  final _QA a;
  final bool roomy;
  const _QuickCard({required this.a, required this.roomy});

  @override
  Widget build(BuildContext context) {
    final iconBox = roomy ? 42.0 : 36.0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HC.line),
        boxShadow: const [
          BoxShadow(
              color: Color(0x120F8A61), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: a.onTap,
          child: Padding(
            padding: EdgeInsets.all(roomy ? 14 : 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: iconBox,
                      height: iconBox,
                      decoration: const BoxDecoration(
                          color: HC.mint, shape: BoxShape.circle),
                      child: Icon(a.icon,
                          color: HC.primary, size: roomy ? 22 : 19),
                    ),
                    const Spacer(),
                    if (a.badge > 0) _Badge(count: a.badge),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final line in a.lines)
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                line,
                                maxLines: 1,
                                style: const TextStyle(
                                  color: HC.ink,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (roomy)
                      const Icon(Icons.arrow_forward_rounded,
                          size: 16, color: HC.primary),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        padding: const EdgeInsets.symmetric(horizontal: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: HC.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          count > 9 ? '9+' : '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
      );
}

// ─── Temporary placeholder (removed in step 3) ───────────────────────────────
class _TemporaryNotice extends StatelessWidget {
  const _TemporaryNotice();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: HC.mint,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: HC.line),
        ),
        child: const Row(
          children: [
            Icon(Icons.construction_rounded, color: HC.primary),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Featured event, upcoming events and recommendations are '
                'added in the next steps.',
                style: TextStyle(color: HC.ink, fontSize: 12.5, height: 1.4),
              ),
            ),
          ],
        ),
      );
}
