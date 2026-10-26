import 'package:flutter/material.dart' hide Notification;
import '../../core/app_state.dart';
import '../../widgets/app_header.dart';

class NotificationScreen extends StatefulWidget {
  /// Set to false when this screen is used as a bottom-nav tab.
  final bool showBackButton;

  const NotificationScreen({super.key, this.showBackButton = true});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  static const _primary = Color(0xFF16A34A);
  static const _amber = Color(0xFFF59E0B);
  static const _teal = Color(0xFF0F766E);

  final _app = AppState.instance;

  @override
  void initState() {
    super.initState();
    _app.addListener(_onAppStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  @override
  void dispose() {
    _app.removeListener(_onAppStateChanged);
    super.dispose();
  }

  void _onAppStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAll() async {
    try {
      await _app.loadStudentProfile();
      await _app.fetchApplications();
      await _app.fetchNotifications();
    } catch (e) {
      debugPrint('NotificationScreen load failed: $e');
    }
  }

  Future<void> _refresh() async {
    try {
      await _app.fetchNotifications();
    } catch (e) {
      debugPrint('NotificationScreen refresh failed: $e');
    }
  }

  void _open(Notification n) {
    if (!n.read) _app.markNotificationRead(n.id);
  }

  ({List<Notification> interviews, List<Notification> members})
      _filterNotifications() {
    final student = _app.currentStudent;
    final interviews = <Notification>[];
    final members = <Notification>[];

    if (student != null) {
      final seen = <String>{};
      for (final n in _app.notifications) {
        if (n.studentId != student.id && n.studentId != student.studentId) {
          continue;
        }
        final title = n.title.toLowerCase();
        final isInterview = title.contains('interview');
        final isMember = title.contains('congratulations') ||
            n.message.toLowerCase().contains('officially a member');
        if (!isInterview && !isMember) continue;
        if (!seen.add('$isInterview${n.orgId ?? title}')) continue;
        (isInterview ? interviews : members).add(n);
      }
    }

    return (interviews: interviews, members: members);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final insets = MediaQuery.paddingOf(context);
    final dims = _Dims.fromWidth(width);
    final filtered = _filterNotifications();
    final interviews = filtered.interviews;
    final members = filtered.members;
    final isEmpty = interviews.isEmpty && members.isEmpty;

    Widget card(Notification n, int i, Color color, IconData icon) =>
        _NotificationCard(
          key: ValueKey(n.id),
          notification: n,
          index: i,
          color: color,
          icon: icon,
          dims: dims,
          onTap: () => _open(n),
        );

    return MediaQuery.withClampedTextScaling(
      minScaleFactor: 1.0,
      maxScaleFactor: 1.3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: Column(
          children: [
            _Header(
              dims: dims,
              insets: insets,
              onBack: widget.showBackButton
                  ? () => Navigator.of(context).maybePop()
                  : null,
            ),
            Expanded(
              child: SafeArea(
                top: false,
                left: false,
                right: false,
                bottom: true,
                child: LayoutBuilder(
                  builder: (context, viewport) => Center(
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(maxWidth: dims.contentMaxWidth),
                      child: RefreshIndicator(
                        onRefresh: _refresh,
                        color: _primary,
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            if (isEmpty)
                              SliverToBoxAdapter(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: viewport.maxHeight,
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      dims.horizontalPadding + insets.left,
                                      0,
                                      dims.horizontalPadding + insets.right,
                                      0,
                                    ),
                                    child: _EmptyState(dims: dims),
                                  ),
                                ),
                              )
                            else
                              SliverPadding(
                                padding: EdgeInsets.fromLTRB(
                                  dims.horizontalPadding + insets.left,
                                  20,
                                  dims.horizontalPadding + insets.right,
                                  32,
                                ),
                                sliver: SliverList.list(
                                  children: [
                                    if (interviews.isNotEmpty) ...[
                                      const _SectionLabel(
                                        'Interview Notifications',
                                      ),
                                      for (var i = 0;
                                          i < interviews.length;
                                          i++)
                                        card(
                                          interviews[i],
                                          i,
                                          _amber,
                                          Icons.schedule_rounded,
                                        ),
                                    ],
                                    if (members.isNotEmpty) ...[
                                      if (interviews.isNotEmpty)
                                        const SizedBox(height: 12),
                                      const _SectionLabel(
                                        'Other Notifications',
                                      ),
                                      for (var i = 0; i < members.length; i++)
                                        card(
                                          members[i],
                                          i,
                                          _teal,
                                          Icons.celebration_rounded,
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dims {
  final double screenWidth;
  final double horizontalPadding;
  final double cardPadding;
  final double iconBoxSize;
  final double titleFontSize;
  final double bodyFontSize;
  final double timeFontSize;
  final double headerHeight;
  final double headerTitleFontSize;
  final double contentMaxWidth;

  const _Dims({
    required this.screenWidth,
    required this.horizontalPadding,
    required this.cardPadding,
    required this.iconBoxSize,
    required this.titleFontSize,
    required this.bodyFontSize,
    required this.timeFontSize,
    required this.headerHeight,
    required this.headerTitleFontSize,
    required this.contentMaxWidth,
  });

  factory _Dims.fromWidth(double width) {
    final compact = width < 360;
    final wide = width >= 600;

    return _Dims(
      screenWidth: width,
      horizontalPadding: compact
          ? 12
          : wide
              ? 24
              : 16,
      cardPadding: compact
          ? 12
          : wide
              ? 24
              : 16,
      iconBoxSize: compact
          ? 40
          : wide
              ? 48
              : 44,
      titleFontSize: compact
          ? 13
          : wide
              ? 16
              : 14,
      bodyFontSize: compact
          ? 12
          : wide
              ? 14
              : 13,
      timeFontSize: compact
          ? 11
          : wide
              ? 12
              : 11.5,
      headerHeight: compact
          ? 60
          : wide
              ? 76
              : 68,
      headerTitleFontSize: compact
          ? 19
          : wide
              ? 24
              : 22,
      contentMaxWidth: wide ? 680 : 600,
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback? onBack;
  final _Dims dims;
  final EdgeInsets insets;

  const _Header({
    required this.dims,
    required this.insets,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final orbSize = (dims.screenWidth * 0.32).clamp(96.0, 184.0).toDouble();

    return Container(
      width: double.infinity,
      height: dims.headerHeight + insets.top,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(gradient: AppHeader.brandGradient),
      child: Stack(
        children: [
          Positioned(
            right: -orbSize * 0.28,
            top: -orbSize * 0.42,
            child: _orb(orbSize),
          ),
          Positioned(
            right: orbSize * 0.28,
            bottom: -orbSize * 0.50,
            child: _orb(orbSize * 0.72),
          ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: insets.top),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: dims.contentMaxWidth),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      dims.horizontalPadding + insets.left,
                      0,
                      dims.horizontalPadding + insets.right,
                      0,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (onBack != null) ...[
                          SizedBox(
                            width: 48,
                            height: 48,
                            child: IconButton(
                              onPressed: onBack,
                              tooltip: 'Back',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(
                                width: 48,
                                height: 48,
                              ),
                              icon: const Icon(
                                Icons.chevron_left_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            'Notifications',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: dims.headerTitleFontSize,
                              fontWeight: FontWeight.w700,
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
        ],
      ),
    );
  }

  Widget _orb(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.07),
        ),
      );
}

class _NotificationCard extends StatelessWidget {
  final Notification notification;
  final int index;
  final Color color;
  final IconData icon;
  final _Dims dims;
  final VoidCallback onTap;

  const _NotificationCard({
    super.key,
    required this.notification,
    required this.index,
    required this.color,
    required this.icon,
    required this.dims,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unread = !notification.read;
    final delay = (index.clamp(0, 8) * 0.06).toDouble();

    return Semantics(
      container: true,
      button: true,
      label:
          '${notification.title}, ${unread ? 'unread' : 'read'}, ${_prettyMessage(notification.message)}, ${_timeAgo(notification.date)}',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Interval(delay, 1.0, curve: Curves.easeOut),
        builder: (_, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - value)),
            child: child,
          ),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: unread
                  ? color.withValues(alpha: 0.40)
                  : const Color(0xFFE2E8F0),
              width: unread ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: unread
                    ? color.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.all(dims.cardPadding),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: dims.iconBoxSize,
                      height: dims.iconBoxSize,
                      decoration: BoxDecoration(
                        color: unread
                            ? color.withValues(alpha: 0.12)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        size: dims.iconBoxSize * 0.5,
                        color: unread ? color : const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  notification.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: dims.titleFontSize,
                                    fontWeight: unread
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: unread
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              if (unread)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 8,
                                    top: 5,
                                  ),
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _prettyMessage(notification.message),
                            style: TextStyle(
                              fontSize: dims.bodyFontSize,
                              height: 1.4,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.access_time_rounded,
                                    size: 12,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _timeAgo(notification.date),
                                    style: TextStyle(
                                      fontSize: dims.timeFontSize,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                              if (unread)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'New',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: color,
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
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final _Dims dims;

  const _EmptyState({required this.dims});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(dims.cardPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: dims.iconBoxSize + 24,
              height: dims.iconBoxSize + 24,
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_off_rounded,
                size: dims.iconBoxSize * 0.8,
                color: const Color(0xFF16A34A),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: dims.titleFontSize + 3,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "You're all caught up!\nCheck back later for updates.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: dims.bodyFontSize,
                height: 1.5,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF16A34A), Color(0xFF0F766E)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
                color: Color(0xFF94A3B8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  String unit(int n, String s) => '$n $s${n > 1 ? 's' : ''} ago';
  if (d.inDays > 0) return unit(d.inDays, 'day');
  if (d.inHours > 0) return unit(d.inHours, 'hour');
  if (d.inMinutes > 0) return unit(d.inMinutes, 'minute');
  return 'Just now';
}

/// Formats dates for display without modifying the stored notification.
String _prettyMessage(String message) {
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
    'Dec',
  ];

  return message.replaceAllMapped(
    RegExp(r'\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}(:\d{2}(\.\d+)?)?'),
    (m) {
      final d = DateTime.tryParse(m[0]!);
      if (d == null) return m[0]!;
      final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
      final min = d.minute.toString().padLeft(2, '0');
      return '${months[d.month - 1]} ${d.day}, ${d.year} at $h:$min '
          '${d.hour < 12 ? 'AM' : 'PM'}';
    },
  );
}
