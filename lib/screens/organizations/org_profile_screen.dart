import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_state.dart';
import '../../widgets/app_header.dart';
import 'org_form_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

abstract class _C {
  static const green = Color(0xFF0F8A61);
  static const bright = Color(0xFF20B77D);
  static const dark = Color(0xFF075A42);
  static const mint = Color(0xFFEAF6EF);
  static const bg = Color(0xFFF7F8F7);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF111827);
  static const body = Color(0xFF374151);
  static const muted = Color(0xFF6B7280);
  static const line = Color(0xFFE5E7EB);
}

// ---------------------------------------------------------------------------
// Layout constants
// ---------------------------------------------------------------------------

/// Content never gets wider than this, so tablets / web / landscape stay tidy.
const double _kMaxContentWidth = 720;
const double _kTabBarHeight = 58;

/// The floating tab bar overlaps the bottom of the hero by half its height.
const double _kTabOverlap = _kTabBarHeight / 2;

/// Hero height below the status bar (includes the area hidden by the tab bar).
const double _kHeroBodyHeight = 140;
const double _kCompactBodyHeight = 56 + _kTabOverlap;

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------

const List<String> _months = [
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
  'Dec',
];

String _formatDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

String _mediaName(OrgMediaItem item) {
  final title = item.title.trim();
  if (title.isNotEmpty) return title;
  final caption = item.caption.trim();
  if (caption.isNotEmpty) return caption;
  return 'Activity moment';
}

/// Opens a link in the external app/browser and tells the user if it fails.
Future<void> _openExternal(BuildContext context, Uri? uri) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  var ok = false;
  if (uri != null) {
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
  }
  if (!ok) {
    messenger?.showSnackBar(
      const SnackBar(content: Text("Couldn't open this link.")),
    );
  }
}

/// Videos open externally, pictures open in the full-screen viewer.
void _openMedia(
    BuildContext context, List<OrgMediaItem> all, OrgMediaItem item) {
  if (item.type == 'video') {
    _openExternal(context, Uri.tryParse(item.content.trim()));
    return;
  }
  final images = all
      .where((m) => m.type == 'image' && m.content.trim().startsWith('http'))
      .toList();
  final index = images.indexOf(item);
  if (index < 0) return;
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _MediaViewer(items: images, initialIndex: index),
    ),
  );
}

/// Lets horizontal lists be dragged with a mouse / trackpad too (web, desktop).
class _DragScrollBehavior extends MaterialScrollBehavior {
  const _DragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };

  @override
  Widget buildScrollbar(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;
}

class _Pad extends StatelessWidget {
  final Widget child;
  const _Pad({required this.child});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18), child: child);
}

/// Vertical scrolling tab body.
/// - owns its own controller (no shared PrimaryScrollController clashes)
/// - keeps its state alive, so scroll position and typed form data survive
///   switching tabs
/// - centers content to a readable max width on large screens
class _TabScroll extends StatefulWidget {
  final List<Widget> children;
  final EdgeInsets padding;
  final bool thumbVisibility;
  const _TabScroll({
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(18, 18, 18, 40),
    this.thumbVisibility = false,
  });

  @override
  State<_TabScroll> createState() => _TabScrollState();
}

class _TabScrollState extends State<_TabScroll>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _controller = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = widget.padding;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: Scrollbar(
        controller: _controller,
        thumbVisibility: widget.thumbVisibility,
        interactive: true,
        child: SingleChildScrollView(
          controller: _controller,
          physics: const BouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
              p.left, p.top, p.right, p.bottom + bottomInset),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: widget.children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class OrgDetailScreen extends StatefulWidget {
  final String orgId;
  final int initialTab; // 0 Dashboard, 1 About, 2 Apply
  const OrgDetailScreen({super.key, required this.orgId, this.initialTab = 0});

  @override
  State<OrgDetailScreen> createState() => _OrgDetailScreenState();
}

class _OrgDetailScreenState extends State<OrgDetailScreen>
    with SingleTickerProviderStateMixin {
  static const int _applyTab = 2;

  late final TabController _tabs;
  bool get _loggedIn => Supabase.instance.client.auth.currentUser != null;
  List<Map<String, dynamic>> _orgPeople = <Map<String, dynamic>>[];
  int _lastNonApplyTab = 0;
  OverlayEntry? _loginRequiredEntry;
  Timer? _loginMessageTimer;
  bool _redirectingGuest = false;
  final GlobalKey _tabBarKey = GlobalKey();
  StreamSubscription<AuthState>? _authSub;
  int _shownTab = 0;

  @override
  void initState() {
    super.initState();
    final requested = widget.initialTab < 0
        ? 0
        : (widget.initialTab > 2 ? 2 : widget.initialTab);
    final start = (requested == _applyTab && !_loggedIn) ? 0 : requested;
    _tabs = TabController(length: 3, vsync: this, initialIndex: start);
    _shownTab = start;
    _lastNonApplyTab = start == _applyTab ? 0 : start;
    _tabs.addListener(_handleTabChange);
    _loadOrganizationPeople();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (!mounted) return;
      if (!_loggedIn && _tabs.index == _applyTab) {
        _tabs.animateTo(_lastNonApplyTab);
      }
      setState(() {});
    });
  }

  Future<void> _loadOrganizationPeople() async {
    try {
      final rows = await Supabase.instance.client
          .from('profiles')
          .select('id,name,role,avatar_url,assigned_org_id,org_id')
          .or('assigned_org_id.eq.${widget.orgId},org_id.eq.${widget.orgId}')
          .order('name');
      if (!mounted) return;
      setState(() {
        _orgPeople = List<Map<String, dynamic>>.from(rows);
      });
    } catch (_) {
      // The About tab still shows names and clean square placeholders when
      // profile photos are unavailable.
    }
  }

  /// Tracks the last tab the user was really on, and stops guests from
  /// reaching the Apply page by swiping (taps are handled in TabBar.onTap).
  void _handleTabChange() {
    if (_tabs.index != _shownTab) {
      _shownTab = _tabs.index;
      FocusManager.instance.primaryFocus?.unfocus();
    }
    if (_tabs.index != _applyTab) {
      _lastNonApplyTab = _tabs.index;
      return;
    }
    if (_loggedIn || _tabs.indexIsChanging || _redirectingGuest) return;
    _redirectingGuest = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _redirectingGuest = false;
      if (!mounted) return;
      if (_tabs.index == _applyTab) _tabs.animateTo(_lastNonApplyTab);
      _showLoginRequiredMessage();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _hideLoginRequiredMessage();
    _tabs.removeListener(_handleTabChange);
    _tabs.dispose();
    super.dispose();
  }

  void _hideLoginRequiredMessage() {
    _loginMessageTimer?.cancel();
    _loginMessageTimer = null;
    final entry = _loginRequiredEntry;
    _loginRequiredEntry = null;
    if (entry != null) {
      entry.remove();
      entry.dispose();
    }
  }

  void _showLoginRequiredMessage() {
    if (!mounted || _loginRequiredEntry != null) return;
    final overlay = Overlay.maybeOf(context);
    final anchor = _tabBarKey.currentContext?.findRenderObject();
    if (overlay == null || anchor is! RenderBox || !anchor.hasSize) return;

    final overlayObject = overlay.context.findRenderObject();
    final overlayBox = overlayObject is RenderBox ? overlayObject : null;
    final topLeft = anchor.localToGlobal(Offset.zero, ancestor: overlayBox);
    final overlaySize = overlayBox?.size ?? MediaQuery.sizeOf(context);

    // Right-align the bubble under the Apply tab; it can never leave the screen.
    final rightEdge = topLeft.dx + anchor.size.width;
    final right = math.max(8.0, overlaySize.width - rightEdge + 6);
    final top = topLeft.dy + anchor.size.height + 8;
    final maxWidth = math.min(285.0, overlaySize.width - 16);

    _loginRequiredEntry = OverlayEntry(
      builder: (overlayContext) => Positioned(
        right: right,
        top: top,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(
                offset: Offset(0, (1 - t) * -6), child: child),
          ),
          child: Material(
            color: Colors.transparent,
            child: Semantics(
              liveRegion: true,
              child: GestureDetector(
                onTap: _hideLoginRequiredMessage,
                child: Container(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF374151)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 18,
                        offset: Offset(0, 7),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_outline_rounded,
                          color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Flexible(
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(
                              text: 'Login required',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            TextSpan(
                              text:
                                  '\nTap Login on the “Discover campus life” card to apply.',
                            ),
                          ]),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_loginRequiredEntry!);
    _loginMessageTimer?.cancel();
    _loginMessageTimer =
        Timer(const Duration(seconds: 3), _hideLoginRequiredMessage);
  }

  Widget _buildTabBar(bool loggedIn) {
    return Container(
      key: _tabBarKey,
      width: double.infinity,
      height: _kTabBarHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: Color(0x10000000), blurRadius: 18, offset: Offset(0, 6))
        ],
      ),
      child: TabBar(
        controller: _tabs,
        labelColor: _C.green,
        unselectedLabelColor: _C.muted,
        indicatorColor: _C.green,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll<Color?>(Colors.transparent),
        dividerColor: Colors.transparent,
        labelPadding: EdgeInsets.zero,
        onTap: (index) {
          if (!loggedIn && index == _applyTab) {
            // Guests cannot open the application tab. Keep the current page
            // selected and show a brief message beside Apply instead.
            _tabs.index = _lastNonApplyTab;
            _showLoginRequiredMessage();
          }
        },
        labelStyle:
            const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5),
        tabs: [
          const Tab(
              height: _kTabBarHeight,
              icon: Icon(Icons.dashboard_rounded, size: 18),
              text: 'Dashboard'),
          const Tab(
              height: _kTabBarHeight,
              icon: Icon(Icons.info_outline_rounded, size: 18),
              text: 'About'),
          Tab(
              height: _kTabBarHeight,
              icon: Icon(
                  loggedIn
                      ? Icons.volunteer_activism_rounded
                      : Icons.lock_outline_rounded,
                  size: 18),
              text: 'Apply'),
        ],
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, Organization org, Widget tabBar, bool compact) {
    final pad = MediaQuery.paddingOf(context);
    final heroHeight =
        pad.top + (compact ? _kCompactBodyHeight : _kHeroBodyHeight);
    return SizedBox(
      height: heroHeight + _kTabOverlap,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: heroHeight,
            child: _Hero(
              org: org,
              compact: compact,
              onBack: () => Navigator.of(context).maybePop(),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _kTabBarHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12 + pad.left),
              child: Center(
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: _kMaxContentWidth - 24),
                  child: tabBar,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) => _buildScreen(context),
    );
  }

  Widget _buildScreen(BuildContext context) {
    final matches =
        AppState.instance.organizations.where((o) => o.id == widget.orgId);
    if (matches.isEmpty) {
      if (AppState.instance.isLoadingOrganizations) {
        return Scaffold(
          backgroundColor: _C.bg,
          appBar: AppBar(
            backgroundColor: _C.bg,
            foregroundColor: _C.ink,
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
          body: const Center(
            child: CircularProgressIndicator(color: _C.green),
          ),
        );
      }
      return Scaffold(
        backgroundColor: _C.bg,
        appBar: AppBar(
          backgroundColor: _C.bg,
          foregroundColor: _C.ink,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: _SoftEmpty(
              icon: Icons.search_off_rounded,
              title: 'Organization not found',
              subtitle: 'It may have been removed or is no longer available.',
            ),
          ),
        ),
      );
    }
    final org = matches.first;
    final loggedIn = _loggedIn;

    // Collapse the header when the keyboard is open (Apply form) or the screen
    // is very short (phone in landscape) so the content keeps its room.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final shortScreen = MediaQuery.sizeOf(context).height < 480;
    final compact = keyboardOpen || shortScreen;

    return Scaffold(
      backgroundColor: _C.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fixed organization header: it stays visible while the tab content scrolls.
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.2,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child:
                  _buildHeader(context, org, _buildTabBar(loggedIn), compact),
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              bottom: false,
              child: TabBarView(
                controller: _tabs,
                children: [
                  _OrgDashboard(org: org),
                  _AboutTab(org: org, people: _orgPeople),
                  if (loggedIn)
                    _ApplyTab(org: org)
                  else
                    const _GuestApplyPlaceholder(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestApplyPlaceholder extends StatelessWidget {
  const _GuestApplyPlaceholder();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(18),
        child: Align(
          alignment: Alignment.topCenter,
          child: _SoftEmpty(
            icon: Icons.lock_outline_rounded,
            title: 'Login required',
            subtitle: 'Tap Login on the “Discover campus life” card to apply.',
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Hero extends StatelessWidget {
  final Organization org;
  final bool compact;
  final VoidCallback onBack;
  const _Hero({required this.org, required this.compact, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Container(
      decoration: const BoxDecoration(
        gradient: AppHeader.brandGradient,
      ),
      child: Stack(children: [
        Positioned(
            right: -45,
            top: -70,
            child: _orb(170, Colors.white.withValues(alpha: .07))),
        Positioned(
            right: 45,
            bottom: -70,
            child: _orb(125, Colors.white.withValues(alpha: .07))),
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(left: pad.left, right: pad.right),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
                child: SizedBox.expand(
                  child: Stack(children: [
                    Positioned.fill(
                      child: Padding(
                        padding:
                            EdgeInsets.fromLTRB(64, pad.top, 20, _kTabOverlap),
                        child: Center(
                            child: compact ? _compactTitle() : _fullTitle()),
                      ),
                    ),
                    Positioned(
                      top: pad.top + (compact ? 4 : 6),
                      left: 8,
                      child: IconButton(
                        tooltip: 'Back',
                        style: IconButton.styleFrom(
                          overlayColor: Colors.transparent,
                        ),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 20),
                        onPressed: onBack,
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _fullTitle() => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Logo(asset: org.logoAsset, size: 54),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(org.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          height: 1.08,
                          fontWeight: FontWeight.w900)),
                ),
                if (org.category.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Align(
                      alignment: Alignment.centerLeft,
                      child: _Pill(org.category)),
                ],
              ],
            ),
          ),
        ],
      );

  Widget _compactTitle() => Row(
        children: [
          _Logo(asset: org.logoAsset, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(org.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      );

  Widget _orb(double size, Color color) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color));
}

class _Logo extends StatelessWidget {
  final String asset;
  final double size;
  const _Logo({required this.asset, required this.size});

  @override
  Widget build(BuildContext context) {
    Widget image;
    final path = asset.trim();
    if (path.startsWith('http')) {
      image = CachedNetworkImage(
          imageUrl: path,
          fit: BoxFit.contain,
          placeholder: (_, __) => const _FallbackLogo(),
          errorWidget: (_, __, ___) => const _FallbackLogo());
    } else if (path.isEmpty) {
      image = const _FallbackLogo();
    } else {
      image = Image.asset(path,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const _FallbackLogo());
    }
    return Container(
        width: size + 18,
        height: size + 18,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: .16),
            border: Border.all(color: Colors.white.withValues(alpha: .26))),
        child: ClipOval(child: image));
  }
}

class _FallbackLogo extends StatelessWidget {
  const _FallbackLogo();
  @override
  Widget build(BuildContext context) => Container(
      color: _C.mint,
      child: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.groups_rounded, color: _C.green, size: 38))));
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill(this.text);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: .22))),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w800)),
      );
}

// ---------------------------------------------------------------------------
// Dashboard tab
// ---------------------------------------------------------------------------

class _OrgDashboard extends StatelessWidget {
  final Organization org;
  const _OrgDashboard({required this.org});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final events = AppState.instance.events.where((e) {
      final eventDay = DateTime(e.date.year, e.date.month, e.date.day);
      return !eventDay.isBefore(today) &&
          (e.orgId == org.id ||
              (e.orgId == null &&
                  e.orgName.toLowerCase() == org.name.toLowerCase()));
    }).toList();
    events.sort((a, b) => a.date.compareTo(b.date));
    final media = org.activitiesHighlights
        .where((m) => m.type == 'image' || m.type == 'video')
        .toList();

    // Room for the text under the picture grows with the user's font size.
    final textScale =
        math.min(1.6, math.max(1.0, MediaQuery.textScalerOf(context).scale(1)));
    final tileHeight = 128 + 108 * textScale;

    return _TabScroll(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 40),
      children: [
        const _Pad(
          child: _SectionIntro(
              icon: Icons.dashboard_rounded,
              title: 'Inside the organization',
              subtitle:
                  'See what they do, what is coming up, and moments from campus life.'),
        ),
        if (events.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Pad(
            child: _TitleRow(
                title: 'Upcoming events',
                icon: Icons.event_available_rounded,
                count: events.length),
          ),
          const SizedBox(height: 10),
          for (final event in events)
            _Pad(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _EventVisualCard(event: event, expanded: true),
              ),
            ),
        ] else ...[
          const SizedBox(height: 14),
          const _Pad(
            child: _SoftEmpty(
                icon: Icons.event_note_rounded,
                title: 'No upcoming events yet',
                subtitle:
                    'New activities from this organization will appear here.'),
          ),
        ],
        const SizedBox(height: 20),
        _Pad(
          child: _TitleRow(
              title: 'Highlights & activities',
              icon: Icons.photo_library_rounded,
              count: media.length),
        ),
        const SizedBox(height: 10),
        if (media.isEmpty)
          const _Pad(
            child: _SoftEmpty(
              icon: Icons.photo_library_outlined,
              title: 'No highlights posted yet',
              subtitle:
                  "Photos from this organization's activities will appear here.",
            ),
          )
        else
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.6,
            child: SizedBox(
              height: tileHeight + 16,
              child: ScrollConfiguration(
                behavior: const _DragScrollBehavior(),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 2, 18, 14),
                  itemCount: media.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (ctx, i) => _MediaTile(
                    item: media[i],
                    onTap: () => _openMedia(ctx, media, media[i]),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _EventVisualCard extends StatelessWidget {
  final Event event;
  final bool expanded;
  const _EventVisualCard({required this.event, this.expanded = false});

  @override
  Widget build(BuildContext context) {
    final primary = (event.imageUrl ?? '').trim();
    final image = primary.isNotEmpty
        ? primary
        : (event.imageUrls.isNotEmpty ? event.imageUrls.first.trim() : '');
    final date = event.date;

    final picture = Stack(children: [
      Positioned.fill(
        child: image.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: image,
                fit: BoxFit.cover,
                memCacheWidth: 900,
                fadeInDuration: const Duration(milliseconds: 200),
                placeholder: (_, __) => _eventArt(showIcon: false),
                errorWidget: (_, __, ___) => _eventArt())
            : _eventArt(),
      ),
      Positioned(top: 12, left: 12, child: _dateBadge(date)),
    ]);

    return Container(
        width: expanded ? double.infinity : 255,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _C.line),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x10000000),
                  blurRadius: 15,
                  offset: Offset(0, 7))
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          expanded
              ? AspectRatio(aspectRatio: 2, child: picture)
              : SizedBox(height: 128, width: double.infinity, child: picture),
          Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: _C.ink,
                            fontWeight: FontWeight.w900,
                            fontSize: expanded ? 18 : 15,
                            height: 1.15)),
                    const SizedBox(height: 7),
                    Row(children: [
                      const Icon(Icons.calendar_month_rounded,
                          size: 14, color: _C.green),
                      const SizedBox(width: 5),
                      Expanded(
                          child: Text(_formatDate(date),
                              style: TextStyle(
                                  color: _C.muted,
                                  fontSize: expanded ? 12.5 : 11.5,
                                  fontWeight: FontWeight.w700)))
                    ]),
                  ])),
        ]));
  }

  Widget _dateBadge(DateTime d) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .95),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
                color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_months[d.month - 1].toUpperCase(),
              style: const TextStyle(
                  color: _C.green,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8)),
          const SizedBox(height: 1),
          Text('${d.day}',
              style: const TextStyle(
                  color: _C.ink,
                  fontSize: 17,
                  height: 1.0,
                  fontWeight: FontWeight.w900)),
        ]),
      );

  Widget _eventArt({bool showIcon = true}) => Container(
      decoration: const BoxDecoration(
          gradient:
              LinearGradient(colors: [Color(0xFFF1F5F4), Color(0xFFE5E9E8)])),
      child: Center(
          child: showIcon
              ? const Icon(Icons.auto_awesome_rounded,
                  color: _C.muted, size: 34)
              : null));
}

class _MediaTile extends StatelessWidget {
  final OrgMediaItem item;
  final VoidCallback? onTap;
  const _MediaTile({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isVideo = item.type == 'video';
    final url = item.content.trim();
    final description = item.description.trim();
    final name = _mediaName(item);
    final canOpen = isVideo || url.startsWith('http');

    return Semantics(
      button: canOpen,
      label: '${isVideo ? 'Video' : 'Photo'}: $name',
      child: Container(
        width: 190,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _C.line),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 5)),
          ],
        ),
        child: Stack(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              height: 128,
              width: double.infinity,
              child: Stack(children: [
                Positioned.fill(
                  child: isVideo
                      ? _videoFallback()
                      : url.startsWith('http')
                          ? CachedNetworkImage(
                              imageUrl: url,
                              fit: BoxFit.cover,
                              memCacheWidth: 500,
                              fadeInDuration: const Duration(milliseconds: 200),
                              placeholder: (_, __) => _mediaFallback(),
                              errorWidget: (_, __, ___) => _mediaFallback(),
                            )
                          : _mediaFallback(),
                ),
                if (isVideo)
                  const Positioned(
                    right: 9,
                    top: 9,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(0xAA0F8A61),
                      child:
                          Icon(Icons.play_arrow_rounded, color: Colors.white),
                    ),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isVideo ? 'VIDEO' : 'PICTURES',
                    style: const TextStyle(
                      color: _C.green,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .7,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.ink,
                      fontSize: 13.5,
                      height: 1.2,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _C.muted,
                        fontSize: 10.5,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ]),
          // Ripple layer on top of the content so the tap feedback is visible.
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(onTap: canOpen ? onTap : null),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _videoFallback() => Container(
        decoration: const BoxDecoration(
            gradient:
                LinearGradient(colors: [Color(0xFF1F2937), Color(0xFF111827)])),
        child: const Center(
            child: Icon(Icons.play_circle_fill_rounded,
                color: Colors.white, size: 48)),
      );

  Widget _mediaFallback() => Container(
        decoration: const BoxDecoration(
          gradient:
              LinearGradient(colors: [Color(0xFFF1F5F4), Color(0xFFE5E9E8)]),
        ),
        child: const Center(
          child: Icon(Icons.photo_rounded, color: _C.muted, size: 32),
        ),
      );
}

// ---------------------------------------------------------------------------
// Full-screen picture viewer (swipe between pictures, pinch / double-tap zoom)
// ---------------------------------------------------------------------------

class _MediaViewer extends StatefulWidget {
  final List<OrgMediaItem> items;
  final int initialIndex;
  const _MediaViewer({required this.items, required this.initialIndex});

  @override
  State<_MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<_MediaViewer> {
  late final PageController _page =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  bool _zoomed = false;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final item = items[_index];
    final description = item.description.trim();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(
          child: PageView.builder(
            controller: _page,
            physics: _zoomed
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            itemCount: items.length,
            onPageChanged: (i) => setState(() {
              _index = i;
              _zoomed = false;
            }),
            itemBuilder: (_, i) => _ZoomableImage(
              key: ValueKey('${i}_${items[i].content}'),
              url: items[i].content.trim(),
              onZoomChanged: (z) {
                if (z != _zoomed) setState(() => _zoomed = z);
              },
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 14, 0),
              child: Row(children: [
                IconButton(
                  tooltip: 'Close',
                  style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: .45)),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const Spacer(),
                if (items.length > 1)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .45),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${_index + 1} / ${items.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                  ),
              ]),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xCC000000)],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_mediaName(item),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800)),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(description,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12.5,
                                height: 1.35)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _ZoomableImage extends StatefulWidget {
  final String url;
  final ValueChanged<bool> onZoomChanged;
  const _ZoomableImage(
      {super.key, required this.url, required this.onZoomChanged});

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  final TransformationController _tc = TransformationController();
  Offset _doubleTapAt = Offset.zero;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _tc.addListener(_onTransformChanged);
  }

  void _onTransformChanged() {
    final zoomed = _tc.value.getMaxScaleOnAxis() > 1.02;
    if (zoomed != _zoomed) {
      _zoomed = zoomed;
      widget.onZoomChanged(zoomed);
    }
  }

  void _toggleZoom() {
    if (_zoomed) {
      _tc.value = Matrix4.identity();
      return;
    }
    const scale = 2.5;
    final m = Matrix4.translationValues(
        -_doubleTapAt.dx * (scale - 1), -_doubleTapAt.dy * (scale - 1), 0);
    m.multiply(Matrix4.diagonal3Values(scale, scale, 1));
    _tc.value = m;
  }

  @override
  void dispose() {
    _tc.removeListener(_onTransformChanged);
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _tc,
        minScale: 1,
        maxScale: 4,
        child: CachedNetworkImage(
          imageUrl: widget.url,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.contain,
          placeholder: (_, __) => const Center(
              child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white70))),
          errorWidget: (_, __, ___) => const Center(
              child: Icon(Icons.broken_image_outlined,
                  color: Colors.white54, size: 48)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// About tab
// ---------------------------------------------------------------------------

class _AboutTab extends StatelessWidget {
  final Organization org;
  final List<Map<String, dynamic>> people;
  const _AboutTab({required this.org, required this.people});

  @override
  Widget build(BuildContext context) {
    final hasMissionBlock = org.mission.isNotEmpty ||
        org.vision.isNotEmpty ||
        org.goals.isNotEmpty ||
        org.missionVision.isNotEmpty;
    final hasPeople = org.adviser.isNotEmpty || org.officers.isNotEmpty;
    final mission = org.mission.isNotEmpty ? org.mission : org.missionVision;

    return _TabScroll(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 40),
      children: [
        const _Pad(
          child: _SectionIntro(
              icon: Icons.info_outline_rounded,
              title: 'Get to know the organization',
              subtitle: 'The people, purpose, and ways to stay connected.'),
        ),
        const SizedBox(height: 14),
        if (org.about.isNotEmpty)
          _Pad(
            child: _StoryCard(
                icon: Icons.info_rounded,
                title: 'Who they are',
                body: org.about),
          ),
        if (hasMissionBlock) ...[
          const SizedBox(height: 12),
          _Pad(
            child: _MissionVisionCard(
              label: 'MISSION',
              text: mission.isNotEmpty
                  ? mission
                  : 'No mission has been added yet.',
              placeholder: mission.isEmpty,
              icon: Icons.flag_rounded,
            ),
          ),
          const SizedBox(height: 12),
          _Pad(
            child: _MissionVisionCard(
              label: 'VISION',
              text: org.vision.isNotEmpty
                  ? org.vision
                  : 'No vision has been added yet.',
              placeholder: org.vision.isEmpty,
              icon: Icons.visibility_rounded,
            ),
          ),
          const SizedBox(height: 12),
          _Pad(
            child: _MissionVisionCard(
              label: 'GOALS',
              text: org.goals.isNotEmpty
                  ? org.goals
                  : 'No goals have been added yet.',
              placeholder: org.goals.isEmpty,
              icon: Icons.track_changes_rounded,
            ),
          ),
        ],
        if (hasPeople) ...[
          const SizedBox(height: 18),
          const _Pad(child: _PeopleSectionLabel(title: 'Adviser & officers')),
          const SizedBox(height: 10),
          _AboutPeopleGallery(org: org, people: people),
        ],
        if (org.socialLink.isNotEmpty) ...[
          const SizedBox(height: 10),
          _Pad(child: _ConnectCard(org: org)),
        ],
        if (org.about.isEmpty &&
            !hasMissionBlock &&
            !hasPeople &&
            org.socialLink.isEmpty)
          const _Pad(
            child: _SoftEmpty(
                icon: Icons.info_outline_rounded,
                title: 'More details coming soon',
                subtitle:
                    'This organization has not added its full profile yet.'),
          ),
      ],
    );
  }
}

class _SectionIntro extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _SectionIntro(
      {required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, color: _C.green, size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(
            header: true,
            child: Text(title,
                style: const TextStyle(
                    color: _C.ink, fontSize: 18, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 3),
          Text(subtitle,
              style: const TextStyle(
                  color: _C.muted, fontSize: 12.5, height: 1.35)),
        ])),
      ]);
}

class _TitleRow extends StatelessWidget {
  final String title;
  final IconData icon;
  final int count;
  const _TitleRow(
      {required this.title, required this.icon, required this.count});
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 18, color: _C.green),
        const SizedBox(width: 7),
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    color: _C.ink, fontWeight: FontWeight.w900, fontSize: 16))),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
                color: _C.mint, borderRadius: BorderRadius.circular(20)),
            child: Text('$count',
                style: const TextStyle(
                    color: _C.green,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900)))
      ]);
}

class _StoryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _StoryCard(
      {required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _C.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: _C.green, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _C.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
            child: Text(
              body,
              style: const TextStyle(
                color: _C.body,
                fontSize: 13.5,
                height: 1.58,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionVisionCard extends StatelessWidget {
  final String label;
  final String text;
  final IconData icon;

  /// True when [text] is only the "nothing added yet" message.
  final bool placeholder;
  const _MissionVisionCard(
      {required this.label,
      required this.text,
      required this.icon,
      this.placeholder = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _C.line),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 5))
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _C.green, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: _C.green,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .9)),
                  const SizedBox(height: 7),
                  Text(text,
                      style: TextStyle(
                          color: placeholder ? _C.muted : _C.ink,
                          fontSize: 13.5,
                          height: 1.55,
                          fontStyle:
                              placeholder ? FontStyle.italic : FontStyle.normal,
                          fontWeight:
                              placeholder ? FontWeight.w500 : FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _PeopleSectionLabel extends StatelessWidget {
  final String title;
  const _PeopleSectionLabel({required this.title});
  @override
  Widget build(BuildContext context) => Row(children: [
        const Icon(Icons.badge_rounded, color: _C.green, size: 19),
        const SizedBox(width: 7),
        Text(title,
            style: const TextStyle(
                color: _C.ink, fontSize: 16, fontWeight: FontWeight.w900)),
      ]);
}

class _AboutPeopleGallery extends StatelessWidget {
  final Organization org;
  final List<Map<String, dynamic>> people;
  const _AboutPeopleGallery({required this.org, required this.people});

  Map<String, dynamic>? _findByName(String name) {
    final target = name.trim().toLowerCase();
    if (target.isEmpty) return null;
    for (final p in people) {
      final n = p['name']?.toString().trim().toLowerCase() ?? '';
      if (n == target) return p;
    }
    return null;
  }

  String _officerName(String raw) {
    final text = raw.trim();
    final split = text.indexOf(':');
    return split == -1 ? text : text.substring(split + 1).trim();
  }

  String _officerRole(String raw) {
    final text = raw.trim();
    final split = text.indexOf(':');
    return split == -1 ? 'Officer' : text.substring(0, split).trim();
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? adviserProfile;
    for (final p in people) {
      if (p['role']?.toString().toLowerCase() == 'adviser') {
        adviserProfile = p;
        break;
      }
    }

    final officers = org.officers.map((raw) {
      final name = _officerName(raw);
      OrgOfficerProfile? savedProfile;
      for (final profile in org.officerProfiles) {
        if (profile.name.trim().toLowerCase() == name.trim().toLowerCase()) {
          savedProfile = profile;
          break;
        }
      }
      // The live profile is the source of truth for photos. The JSON
      // officer_profiles value is a fallback only: it can contain an older
      // URL if an officer updates their picture from their own profile.
      final liveProfile = _findByName(name);
      final liveAvatar = liveProfile?['avatar_url']?.toString().trim() ?? '';
      final savedAvatar = savedProfile?.avatarUrl.trim() ?? '';
      return <String, dynamic>{
        'name': name,
        'role': savedProfile?.role ?? _officerRole(raw),
        'avatar_url': liveAvatar.isNotEmpty ? liveAvatar : savedAvatar,
      };
    }).toList();

    if (adviserProfile == null && org.adviser.isEmpty && officers.isEmpty) {
      return const SizedBox.shrink();
    }

    final profileName = adviserProfile?['name']?.toString().trim() ?? '';
    final adviserName = profileName.isNotEmpty ? profileName : org.adviser;
    final adviserAvatar = adviserProfile?['avatar_url']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (adviserProfile != null || org.adviser.isNotEmpty) ...[
          const _Pad(
            child: Text('Adviser',
                style: TextStyle(
                    color: _C.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 8),
          Center(
            child: _SquarePersonCard(
              name: adviserName,
              role: 'Adviser',
              avatarUrl: adviserAvatar,
              width: 144,
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (officers.isNotEmpty) ...[
          const _Pad(
            child: Text('Officers',
                style: TextStyle(
                    color: _C.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) => ScrollConfiguration(
              behavior: const _DragScrollBehavior(),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 2, 18, 12),
                // Few officers are centered; many officers scroll sideways.
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      minWidth: math.max(0.0, constraints.maxWidth - 36)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < officers.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        _SquarePersonCard(
                          name: officers[i]['name'].toString(),
                          role: officers[i]['role'].toString(),
                          avatarUrl: officers[i]['avatar_url'].toString(),
                          width: 144,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SquarePersonCard extends StatelessWidget {
  final String name;
  final String role;
  final String avatarUrl;
  final double width;
  const _SquarePersonCard(
      {required this.name,
      required this.role,
      required this.avatarUrl,
      this.width = 156});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.line, width: 1.1),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: SizedBox(
              height: 122,
              child: avatarUrl.trim().isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: avatarUrl,
                      width: double.infinity,
                      height: 122,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      memCacheWidth: 400,
                      fadeInDuration: const Duration(milliseconds: 200),
                      placeholder: (_, __) => _squareFallback(),
                      errorWidget: (_, __, ___) => _squareFallback(),
                    )
                  : _squareFallback(),
            ),
          ),
          const SizedBox(height: 9),
          // Fixed-height name container ensures all cards match in height
          SizedBox(
            height: 38,
            child: Center(
              child: Text(
                name,
                softWrap: true,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _C.ink,
                  fontSize: 13.5,
                  height: 1.14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: _C.mint,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                role,
                softWrap: true,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _C.green,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _squareFallback() => Container(
        color: _C.mint,
        child: const Center(
            child: Icon(Icons.person_rounded, color: _C.green, size: 34)),
      );
}

class _ConnectCard extends StatelessWidget {
  final Organization org;
  const _ConnectCard({required this.org});

  String _facebookDisplayName(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    final uri = Uri.tryParse(value.contains('://') ? value : 'https://$value');
    final host = uri?.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    if ((host == 'facebook.com' ||
            host == 'm.facebook.com' ||
            host == 'web.facebook.com') &&
        uri != null) {
      final query = uri.queryParameters['q'];
      if (query != null && query.trim().isNotEmpty) return query.trim();
      final path = uri.pathSegments.where((part) => part.isNotEmpty).join(' ');
      if (path.isNotEmpty && path.toLowerCase() != 'search top') {
        return path.replaceAll(RegExp(r'[-_]'), ' ');
      }
    }
    return value;
  }

  /// A real link opens as is; a plain page name opens a Facebook search.
  Uri? _resolveUri(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    if (value.contains('://')) return Uri.tryParse(value);
    if (!value.contains(' ') && value.contains('.')) {
      return Uri.tryParse('https://$value');
    }
    return Uri.https('www.facebook.com', '/search/top', {'q': value});
  }

  @override
  Widget build(BuildContext context) {
    final facebookName = _facebookDisplayName(org.socialLink);
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _C.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openExternal(context, _resolveUri(org.socialLink)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('FACEBOOK PAGE',
                        style: TextStyle(
                            color: _C.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .9)),
                    const SizedBox(height: 7),
                    Text(
                      facebookName,
                      softWrap: true,
                      style: const TextStyle(
                          color: _C.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w700),
                    ),
                  ]),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.open_in_new_rounded, color: _C.green, size: 20),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Apply tab
// ---------------------------------------------------------------------------

class _ApplyTab extends StatelessWidget {
  final Organization org;
  const _ApplyTab({required this.org});

  @override
  Widget build(BuildContext context) {
    return _TabScroll(
      thumbVisibility: true,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 48),
      children: [
        // The scrollable area starts here, at "Ready to join?".
        const _SectionIntro(
          icon: Icons.volunteer_activism_rounded,
          title: 'Ready to join?',
          subtitle:
              'Send your application when you are ready to become part of this community.',
        ),
        const SizedBox(height: 16),
        _LazyOrgForm(
            title: org.name,
            logoAsset: org.logoAsset,
            orgId: org.id,
            category: org.category),
      ],
    );
  }
}

class _LazyOrgForm extends StatefulWidget {
  final String title;
  final String logoAsset;
  final String orgId;
  final String category;
  const _LazyOrgForm(
      {required this.title,
      required this.logoAsset,
      required this.orgId,
      required this.category});
  @override
  State<_LazyOrgForm> createState() => _LazyOrgFormState();
}

class _LazyOrgFormState extends State<_LazyOrgForm> {
  @override
  Widget build(BuildContext context) {
    return OrgFormContent(
      title: widget.title,
      logoAsset: widget.logoAsset,
      orgId: widget.orgId,
      category: widget.category,
      embedded: true,
    );
  }
}

class _SoftEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _SoftEmpty(
      {required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _C.line),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 5))
          ]),
      child: Column(children: [
        Icon(icon, color: _C.green, size: 36),
        const SizedBox(height: 12),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: _C.ink, fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text(subtitle,
            textAlign: TextAlign.center,
            style:
                const TextStyle(color: _C.muted, fontSize: 12.5, height: 1.4))
      ]));
}
