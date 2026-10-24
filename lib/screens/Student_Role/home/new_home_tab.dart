import 'dart:convert';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart' hide Notification;

import '../../../core/analytics_service.dart';
import '../../../core/app_state.dart';
import 'home_data.dart';
import 'home_tokens.dart';
import 'home_recommended_section.dart';
import 'home_events_section.dart';
import 'home_search_page.dart';
import 'all_upcoming_events_page.dart';

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
  /// Preserves quick-action subtree identity when the hero changes layout.
  final GlobalKey _quickActionsKey = GlobalKey();

  /// Preserves the events section subtree when the hero changes layout.
  final GlobalKey _eventsSectionKey = GlobalKey();

  /// Preserves the recommendations subtree when the hero changes layout.
  final GlobalKey _recommendedSectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    AppState.instance.fetchOrganizations();
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

  /// Builds the Home tab using its actual available width instead of assuming
  /// the full window width, which matters when a desktop NavigationRail exists.
  @override
  Widget build(BuildContext context) {
    return HomeLayout.capText(
      context,
      LayoutBuilder(
        builder: (context, constraints) {
          final windowWidth = MediaQuery.sizeOf(context).width;
          final measuredWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : windowWidth;

          // Construct the layout once here. All Home-specific decisions below
          // use these normalized measurements.
          final layout = HomeLayout.fromWidth(measuredWidth);
          final textScale = HomeLayout.textScaleOf(context);

          // An unbounded-height parent cannot safely host an Expanded pinned
          // layout, so the hero scrolls in that case as a safe fallback.
          final heroPinned = measuredWidth < HomeBreakpoints.desktopMin &&
              constraints.maxHeight.isFinite &&
              constraints.maxHeight >= 640 &&
              textScale <= 1.15;

          return HomeLayoutScope(
            width: layout.width,
            child: AnimatedBuilder(
              animation: AppState.instance,
              builder: (context, _) {
                final hero = _Hero(
                  layout: layout,
                  greeting: _greeting(),
                  avatar: _avatar(),
                  hasUnread: HomeData.unreadNotificationCount() > 0,
                  onBell: widget.onOpenNotifications,
                  onAvatar: () => widget.onSwitchTab(3),
                  onSearch: () => _openSearch(),
                  onFilter: () => _openSearch(openFilters: true),
                );

                final quickActions = _Centered(
                  key: _quickActionsKey,
                  layout: layout,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      layout.homeHPad,
                      layout.cardGap / 2,
                      layout.homeHPad,
                      0,
                    ),
                    child: _QuickActions(
                      layout: layout,
                      applicationBadge: HomeData.inProgressApplicationCount(),
                      onDiscover: () => widget.onSwitchTab(1),
                      onEvents: () => widget.onSwitchTab(2),
                      onApplications: widget.onOpenApplications,
                      onJoined: widget.onOpenJoinedOrgs,
                    ),
                  ),
                );

                final events = _Centered(
                  key: _eventsSectionKey,
                  layout: layout,
                  child: HomeEventsSection(
                    onViewAll: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AllUpcomingEventsPage(),
                      ),
                    ),
                  ),
                );

                final recommendations = _Centered(
                  key: _recommendedSectionKey,
                  layout: layout,
                  child: HomeRecommendedSection(
                    onViewAll: () => widget.onSwitchTab(1),
                  ),
                );
                final scrollingSections = <Widget>[
                  quickActions,
                  SizedBox(height: layout.sectionGap),
                  events,
                  SizedBox(height: layout.sectionGap),
                  recommendations, // recommendations (temporarily off)
                ];

                if (heroPinned) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      hero,
                      SizedBox(height: layout.cardGap),
                      Expanded(
                        child: _buildScrollableArea(
                          context,
                          layout: layout,
                          children: scrollingSections,
                        ),
                      ),
                    ],
                  );
                }

                // Desktop, short windows, landscape phones, and enlarged text
                // use one scrollable area so the hero cannot squeeze content.
                return _buildScrollableArea(
                  context,
                  layout: layout,
                  children: [
                    hero,
                    SizedBox(height: layout.cardGap),
                    ...scrollingSections,
                  ],
                );
              },
            ),
          );
        },
      ),
      maxScale: 1.5,
    );
  }

  /// Builds the pull-to-refresh list and enables mouse and touch dragging.
  Widget _buildScrollableArea(
    BuildContext context, {
    required HomeLayout layout,
    required List<Widget> children,
  }) {
    final behavior = ScrollConfiguration.of(context).copyWith(
      dragDevices: {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      },
    );

    return ScrollConfiguration(
      behavior: behavior,
      child: RefreshIndicator(
        color: HC.primary,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.only(bottom: layout.sectionGap),
          children: children,
        ),
      ),
    );
  }
}

/// Centers content and constrains its outer width without adding extra padding.
class _Centered extends StatelessWidget {
  final HomeLayout layout;
  final Widget child;

  const _Centered({
    super.key,
    required this.layout,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: layout.homeContentWidth,
        ),
        child: SizedBox(
          width: double.infinity,
          child: child,
        ),
      ),
    );
  }
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

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    final textScale = HomeLayout.textScaleOf(context);

    final safeTextScale = textScale.isFinite ? textScale : 1.0;
    final searchScale =
        safeTextScale < 1.0 ? 1.0 : (safeTextScale > 1.3 ? 1.3 : safeTextScale);

    final searchHeight = 56.0 * searchScale;
    final searchOverlap = searchHeight / 2;
    final isDesktop = layout.size == HomeSize.desktop;

    final double logoSize;
    final double titleSize;
    final double greetingSize;
    final double taglineSize;

    switch (layout.size) {
      case HomeSize.smallMobile:
        logoSize = 38;
        titleSize = 20;
        greetingSize = 22;
        taglineSize = 12;
      case HomeSize.mobile:
        logoSize = 44;
        titleSize = 23;
        greetingSize = 26;
        taglineSize = 13;
      case HomeSize.tablet:
        logoSize = 48;
        titleSize = 24;
        greetingSize = 28;
        taglineSize = 14;
      case HomeSize.desktop:
        logoSize = 52;
        titleSize = 26;
        greetingSize = 32;
        taglineSize = 15;
    }

    final searchMaxWidth = isDesktop && layout.homeInnerWidth > 840
        ? 840.0
        : layout.homeInnerWidth;

    return Stack(
      // The search shadow must remain visible beyond the hero's background.
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: searchOverlap),
          child: Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: HC.heroGradient,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(isDesktop ? 36 : 30),
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -50,
                  top: -70,
                  child: _orb(180),
                ),
                Positioned(
                  right: 40,
                  bottom: -80,
                  child: _orb(130),
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: layout.homeContentWidth,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          layout.homeHPad,
                          safeTop + (isDesktop ? 16 : 10),
                          layout.homeHPad,
                          searchOverlap + (isDesktop ? 28 : 18),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _Logo(size: logoSize),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'OrgConnect',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: titleSize,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ),
                                _BellButton(
                                  hasUnread: hasUnread,
                                  onTap: onBell,
                                ),
                                const SizedBox(width: 6),
                                _AvatarButton(
                                  image: avatar,
                                  onTap: onAvatar,
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Text(
                              greeting,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: greetingSize,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Your campus. Your organizations. Your journey.',
                              softWrap: true,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .88),
                                fontSize: taglineSize,
                                fontWeight: FontWeight.w500,
                                height: 1.35,
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
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: layout.homeContentWidth,
              ),
              child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: layout.homeHPad,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: searchMaxWidth,
                      child: _SearchBar(
                        height: searchHeight,
                        onTap: onSearch,
                        onFilter: onFilter,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _orb(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: .07),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  final double size;

  const _Logo({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.12),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/icon/app_logo_green.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.groups_rounded, color: HC.primary),
        ),
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  final bool hasUnread;
  final VoidCallback onTap;

  const _BellButton({
    required this.hasUnread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
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
              const Icon(
                Icons.notifications_none_rounded,
                color: Colors.white,
                size: 27,
              ),
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
}

class _AvatarButton extends StatelessWidget {
  final ImageProvider? image;
  final VoidCallback onTap;

  const _AvatarButton({
    required this.image,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open profile',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                radius: 19,
                backgroundColor: HC.mint,
                backgroundImage: image,
                child: image == null
                    ? const Icon(
                        Icons.person_rounded,
                        color: HC.primary,
                        size: 22,
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
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
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x260F8A61),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
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
                const Icon(
                  Icons.search_rounded,
                  color: Colors.black,
                  size: 23,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Search organizations, events, or keywords…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: HC.muted,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 1,
                  height: 24,
                  color: HC.line,
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onFilter,
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.tune_rounded,
                      color: Colors.black,
                      size: 22,
                    ),
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

// ─── Quick actions ───────────────────────────────────────────────────────────

class _QA {
  final IconData icon;
  final List<String> lines;
  final VoidCallback onTap;
  final int badge;

  const _QA(
    this.icon,
    this.lines,
    this.onTap, {
    this.badge = 0,
  });
}

class _QuickActions extends StatelessWidget {
  final HomeLayout layout;
  final int applicationBadge;
  final VoidCallback onDiscover;
  final VoidCallback onEvents;
  final VoidCallback onApplications;
  final VoidCallback onJoined;

  const _QuickActions({
    required this.layout,
    required this.applicationBadge,
    required this.onDiscover,
    required this.onEvents,
    required this.onApplications,
    required this.onJoined,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Keep the horizontal gap at 12 so a 552 px inner width (600 px
        // viewport) still meets the specified 128 px four-column threshold.
        const horizontalGap = 12.0;

        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : layout.homeInnerWidth;

        final cardWidth4 = (maxWidth - horizontalGap * 3) / 4;
        final rawTextScale = HomeLayout.textScaleOf(context);
        final textScale =
            rawTextScale.isFinite && rawTextScale > 1.0 ? rawTextScale : 1.0;

        final fourAcross = cardWidth4 >= 128.0 * textScale;

        final items = <_QA>[
          _QA(
            Icons.explore_rounded,
            const ['Discover', 'Organizations'],
            onDiscover,
          ),
          _QA(
            Icons.event_note_rounded,
            const ['Upcoming', 'Events'],
            onEvents,
          ),
          _QA(
            Icons.assignment_rounded,
            const ['My', 'Applications'],
            onApplications,
            badge: applicationBadge,
          ),
          _QA(
            Icons.groups_rounded,
            const ['Joined', 'Orgs'],
            onJoined,
          ),
        ];

        // Tablet and desktop cards stay roomy even in a single row.
        final roomy = !fourAcross ||
            layout.size == HomeSize.tablet ||
            layout.size == HomeSize.desktop;

        Widget buildCard(_QA item) {
          return _QuickCard(
            layout: layout,
            a: item,
            roomy: roomy,
          );
        }

        Widget buildRow(List<_QA> rowItems) {
          final children = <Widget>[];

          for (var i = 0; i < rowItems.length; i++) {
            if (i > 0) {
              children.add(const SizedBox(width: horizontalGap));
            }
            children.add(
              Expanded(child: buildCard(rowItems[i])),
            );
          }

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          );
        }

        if (fourAcross) {
          return buildRow(items);
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildRow(items.sublist(0, 2)),
            SizedBox(height: layout.cardGap),
            buildRow(items.sublist(2, 4)),
          ],
        );
      },
    );
  }
}

class _QuickCard extends StatelessWidget {
  final HomeLayout layout;
  final _QA a;
  final bool roomy;

  const _QuickCard({
    required this.layout,
    required this.a,
    required this.roomy,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = layout.size == HomeSize.desktop;
    final iconBox = isDesktop ? 44.0 : (roomy ? 42.0 : 36.0);
    final iconSize = isDesktop ? 28.0 : (roomy ? 25.0 : 22.0);
    final arrowSize = isDesktop ? 18.0 : (roomy ? 16.0 : 14.0);
    final cardPadding = isDesktop ? 18.0 : (roomy ? 14.0 : 10.0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HC.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F8A61),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: a.onTap,
          child: Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: iconBox,
                      height: iconBox,
                      child: Center(
                        child: Icon(
                          a.icon,
                          color: HC.primary,
                          size: iconSize,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (a.badge > 0) ...[
                      _Badge(count: a.badge),
                      const SizedBox(width: 4),
                    ],
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: arrowSize,
                      color: Colors.black,
                    ),
                  ],
                ),
                SizedBox(height: layout.cardGap),
                for (final line in a.lines)
                  Text(
                    line,
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: HC.ink,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
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

class _Badge extends StatelessWidget {
  final int count;

  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minWidth: 20,
        minHeight: 20,
      ),
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
