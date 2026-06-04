import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_state.dart';
import '/screens/notifications/notification_screen.dart';
import '/screens/Student_Role/student_dashboard_events.dart';
import '/screens/profile/profile_screen.dart';
import '/screens/organizations/org_list_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:photo_view/photo_view.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  // ─── Color tokens — MUST match ProfileScreen exactly ─────────────────────
  static const Color _primary = Color(0xFF4F46E5);
  static const Color _secondary = Color(0xFF06B6D4);
  static const Color _background = Color(0xFFF8FAFC);

  // Per-action accent colors — all within the permitted palette
  static const Color _profileAccent = Color(0xFF4F46E5);
  static const Color _orgAccent = Color(0xFF06B6D4);
  static const Color _notifAccent = Color(0xFF22C55E);
  static const Color _eventsAccent = Color(0xFF6C63FF);

  // ─── Double-tap-to-exit state tracker ────────────────────────────────────
  DateTime? _lastBackPressed;
  int _selectedIndex = 0;

  // ─── AppState listener so badge refreshes when notifications change ───────
  @override
  void initState() {
    super.initState();
    AppState.instance.addListener(_onAppStateChanged);
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onAppStateChanged);
    super.dispose();
  }

  void _onAppStateChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Unread count for the notification badge
    final unreadCount = AppState.instance.notifications
        .where((n) =>
            (n.studentId == AppState.instance.currentStudent?.id ||
                n.studentId == AppState.instance.currentStudent?.studentId) &&
            !n.read)
        .length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        final now = DateTime.now();

        if (_lastBackPressed == null ||
            now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
          _lastBackPressed = now;

          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Tap again to exit',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.height - 140,
                left: 40,
                right: 40,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).clearSnackBars();
          SystemChannels.platform.invokeMethod('SystemNavigator.pop');
        }
      },
      child: Scaffold(
        backgroundColor: _background,
        body: IndexedStack(
          index: _selectedIndex,
          children: const [
            _HomeTab(),
            OrgListScreen(),
            NotificationScreen(),
            ProfileScreen(),
            StudentDashboard(),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(unreadCount),
      ),
    );
  }

  Widget _buildBottomNav(int unreadCount) {
    final screenWidth = MediaQuery.of(context).size.width;
    final iconSize = (screenWidth * 0.065).clamp(22.0, 30.0);
    final fontSize = (screenWidth * 0.028).clamp(10.0, 13.0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: (screenWidth * 0.18).clamp(56.0, 72.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                index: 0,
                selectedIndex: _selectedIndex,
                iconSize: iconSize,
                fontSize: fontSize,
                primaryColor: _primary,
                onTap: () => setState(() => _selectedIndex = 0),
              ),
              _NavItem(
                icon: Icons.groups_rounded,
                label: 'Orgs',
                index: 1,
                selectedIndex: _selectedIndex,
                iconSize: iconSize,
                fontSize: fontSize,
                primaryColor: _orgAccent,
                onTap: () => setState(() => _selectedIndex = 1),
              ),
              _NavItem(
                icon: Icons.calendar_month_rounded,
                label: 'Events',
                index: 4,
                selectedIndex: _selectedIndex,
                iconSize: iconSize,
                fontSize: fontSize,
                primaryColor: _eventsAccent,
                onTap: () => setState(() => _selectedIndex = 4),
              ),
              _NavBadgeItem(
                icon: Icons.notifications_rounded,
                label: 'Notifs',
                index: 2,
                selectedIndex: _selectedIndex,
                iconSize: iconSize,
                fontSize: fontSize,
                primaryColor: _notifAccent,
                badgeCount: unreadCount,
                onTap: () => setState(() => _selectedIndex = 2),
              ),
              _NavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                index: 3,
                selectedIndex: _selectedIndex,
                iconSize: iconSize,
                fontSize: fontSize,
                primaryColor: _profileAccent,
                onTap: () => setState(() => _selectedIndex = 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _CalendarCard
// Embeds the StudentDashboard (student_dashboard_events.dart) calendar widget
// directly into the dashboard page as a card.
// =============================================================================

// =============================================================================
// _HeroHeader  (UNCHANGED)
// =============================================================================
class _HeroHeader extends StatelessWidget {
  final Color primary;
  final Color secondary;

  const _HeroHeader({
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final avatarSize = (size.width * 0.18).clamp(60.0, 84.0);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Decorative orb — top right
          Positioned(
            top: -30,
            right: -20,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          // Decorative orb — bottom left
          Positioned(
            bottom: 10,
            left: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar ring
                  Container(
                    width: avatarSize + 10,
                    height: avatarSize + 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: _buildAvatar(avatarSize),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Name + subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ListenableBuilder(
                          listenable: AppState.instance,
                          builder: (context, _) {
                            final fullName =
                                AppState.instance.currentStudent?.name ?? '';
                            final firstName = fullName.trim().split(' ').first;
                            final greeting = firstName.isNotEmpty
                                ? 'Welcome Back, $firstName 👋'
                                : 'Welcome Back 👋';
                            return Text(
                              greeting,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.1,
                                height: 1.15,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Manage your applications\n& organizations',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.1,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // paste here ↓
  Widget _buildAvatar(double avatarSize) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final student = AppState.instance.currentStudent;
        final avatarUrl = student?.avatarUrl ?? '';

        ImageProvider? bgImage;
        Widget? fallbackChild;

        if (avatarUrl.startsWith('data:')) {
          try {
            final base64Str = avatarUrl.substring(avatarUrl.indexOf(',') + 1);
            bgImage = MemoryImage(base64Decode(base64Str));
          } catch (_) {}
        } else if (avatarUrl.isNotEmpty) {
          bgImage = CachedNetworkImageProvider(avatarUrl);
        }

        fallbackChild = bgImage == null
            ? Icon(
                Icons.person_rounded,
                size: avatarSize * 0.50,
                color: const Color(0xFF4F46E5),
              )
            : null;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: CircleAvatar(
            key: ValueKey(avatarUrl),
            radius: avatarSize / 2,
            backgroundColor: const Color(0xFFE0E7FF),
            backgroundImage: bgImage,
            child: fallbackChild,
          ),
        );
      },
    );
  }
} // ← this is the original closing brace of _HeroHeader

// =============================================================================
// _HeroBottomStrip — scrolls away with the page (NOT inside SliverAppBar)
// =============================================================================
class _HeroBottomStrip extends StatelessWidget {
  final Color primary;
  final Color secondary;

  const _HeroBottomStrip({
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: const [
          _HeroStatChip(
            label: 'Applications',
            icon: Icons.assignment_rounded,
          ),
          _VerticalDividerChip(),
          _HeroStatChip(
            label: 'Orgs Joined',
            icon: Icons.groups_rounded,
          ),
          _VerticalDividerChip(),
          _HeroStatChip(
            label: 'Notifications',
            icon: Icons.notifications_rounded,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _HeroStatChip  (UNCHANGED)
// =============================================================================
class _HeroStatChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _HeroStatChip({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.20),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// _VerticalDividerChip  (UNCHANGED)
// =============================================================================
class _VerticalDividerChip extends StatelessWidget {
  const _VerticalDividerChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: Colors.white.withOpacity(0.20),
    );
  }
}

// =============================================================================
// _HomeTab — shown when index == 0 (the hero header + welcome content)
// =============================================================================
class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  static const Color _primary = Color(0xFF4F46E5);
  static const Color _secondary = Color(0xFF06B6D4);

  @override
  void initState() {
    super.initState();
    AppState.instance.fetchEvents();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final events = AppState.instance.eventsForCurrentStudent();
        events.sort((a, b) => b.date.compareTo(a.date));

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Hero header (identity only) ──────────────────────────
            SliverAppBar(
              expandedHeight: size.height * 0.32,
              pinned: false, // ← MUST be false
              stretch: true,
              backgroundColor: _primary,
              elevation: 0,
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.blurBackground],
                background: _HeroHeader(
                  primary: _primary,
                  secondary: _secondary,
                ),
              ),
            ),

            // ── Bottom strip — separate, scrolls away cleanly ────────
            SliverToBoxAdapter(
              child: _HeroBottomStrip(
                primary: _primary,
                secondary: _secondary,
              ),
            ),

            // ── Section label ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 4,
                      height: 22,
                      decoration: BoxDecoration(
                        color: _secondary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Latest Events',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F0D2E),
                                  letterSpacing: -0.4)),
                          Text('From your organizations',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF6B6B8E),
                                  fontWeight: FontWeight.w400)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Events feed or empty state ─────────────────────────
            if (events.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_primary, _secondary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.event_note_rounded,
                              color: Colors.white, size: 32),
                        ),
                        const SizedBox(height: 16),
                        const Text('No events yet',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F0D2E))),
                        const SizedBox(height: 6),
                        const Text(
                            'Events from your organizations\nwill appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFF6B6B8E),
                                height: 1.55)),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _EventFeedCard(event: events[i]),
                    childCount: events.length,
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        );
      },
    );
  }
}

// =============================================================================
// _NavItem — a single bottom nav tab button
// =============================================================================
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int selectedIndex;
  final double iconSize;
  final double fontSize;
  final Color primaryColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.selectedIndex,
    required this.iconSize,
    required this.fontSize,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = index == selectedIndex;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:
              isSelected ? primaryColor.withOpacity(0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: isSelected ? primaryColor : const Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? primaryColor : const Color(0xFFCBD5E1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// _NavBadgeItem — nav tab with unread count badge (for Notifications)
// =============================================================================
class _NavBadgeItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int selectedIndex;
  final double iconSize;
  final double fontSize;
  final Color primaryColor;
  final int badgeCount;
  final VoidCallback onTap;

  const _NavBadgeItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.selectedIndex,
    required this.iconSize,
    required this.fontSize,
    required this.primaryColor,
    required this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = index == selectedIndex;
    final showBadge = badgeCount > 0;
    final badgeLabel = badgeCount > 9 ? '9+' : '$badgeCount';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:
              isSelected ? primaryColor.withOpacity(0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: iconSize,
                  color: isSelected ? primaryColor : const Color(0xFFCBD5E1),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? primaryColor : const Color(0xFFCBD5E1),
                  ),
                ),
              ],
            ),
            if (showBadge)
              Positioned(
                top: -6,
                right: -10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    badgeLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
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

// =============================================================================
// _EventFeedCard — rich card shown in the student home feed
// =============================================================================
// =============================================================================
// _EventFeedCard — rich card with multi-image carousel
// =============================================================================
class _EventFeedCard extends StatefulWidget {
  final Event event;
  const _EventFeedCard({required this.event});

  @override
  State<_EventFeedCard> createState() => _EventFeedCardState();
}

class _EventFeedCardState extends State<_EventFeedCard> {
  int _currentImageIndex = 0;

  // Build the final list of image URLs to show
  List<String> get _imageUrls {
    if (widget.event.imageUrls.isNotEmpty) return widget.event.imageUrls;
    if (widget.event.imageUrl != null && widget.event.imageUrl!.isNotEmpty) {
      return [widget.event.imageUrl!];
    }
    return [];
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
            imageProvider: CachedNetworkImageProvider(url),
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
          // ── Image / Carousel ─────────────────────────────────────
          if (hasImages)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                children: [
                  // ── Carousel or single image ──────────────────────
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
                          child: CachedNetworkImage(
                            imageUrl: url,
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              height: 200,
                              color: const Color(0xFFEEF2FF),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF4F46E5),
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              height: 200,
                              color: const Color(0xFFEEF2FF),
                              child: const Icon(Icons.broken_image_rounded,
                                  color: Color(0xFF4F46E5), size: 36),
                            ),
                          ),
                        );
                      }).toList(),
                    )
                  else
                    // Single image — no carousel needed
                    GestureDetector(
                      onTap: () => _openZoom(context, urls.first),
                      child: CachedNetworkImage(
                        imageUrl: urls.first,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          height: 200,
                          color: const Color(0xFFEEF2FF),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF4F46E5),
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          height: 200,
                          color: const Color(0xFFEEF2FF),
                          child: const Icon(Icons.broken_image_rounded,
                              color: Color(0xFF4F46E5), size: 36),
                        ),
                      ),
                    ),

                  // ── Dot indicators (only for multiple images) ─────
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

                  // ── Image counter badge (top-right) ───────────────
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

          // ── Content ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Org name + status pill
                Row(
                  children: [
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
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
                  ],
                ),

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

                // Date row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
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
              ],
            ),
          ),
        ],
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
