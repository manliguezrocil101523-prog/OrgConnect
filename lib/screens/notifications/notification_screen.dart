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
    // Force a fresh fetch every time this screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  @override
  void dispose() {
    _app.removeListener(_onAppStateChanged);
    super.dispose();
  }

  // Guard: the listener can fire after the screen is gone.
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

  @override
  Widget build(BuildContext context) {
    final student = _app.currentStudent;
    final interviews = <Notification>[];
    final members = <Notification>[];

    if (student != null) {
      // One student-facing card per organization and category
      // (guards against duplicates from cached or realtime state).
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

    Widget card(Notification n, int i, Color color, IconData icon) =>
        _NotificationCard(
          key: ValueKey(n.id),
          notification: n,
          index: i,
          color: color,
          icon: icon,
          onTap: () => _open(n),
        );

    final isEmpty = interviews.isEmpty && members.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          _Header(
            onBack: widget.showBackButton
                ? () => Navigator.of(context).maybePop()
                : null,
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  color: _primary,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      if (isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: _EmptyState(),
                        )
                      else
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            20,
                            16,
                            32 + MediaQuery.paddingOf(context).bottom,
                          ),
                          sliver: SliverList.list(
                            children: [
                              if (interviews.isNotEmpty) ...[
                                const _SectionLabel('Interview Notifications'),
                                for (var i = 0; i < interviews.length; i++)
                                  card(interviews[i], i, _amber,
                                      Icons.schedule_rounded),
                              ],
                              if (members.isNotEmpty) ...[
                                if (interviews.isNotEmpty)
                                  const SizedBox(height: 12),
                                const _SectionLabel('Other Notifications'),
                                for (var i = 0; i < members.length; i++)
                                  card(members[i], i, _teal,
                                      Icons.celebration_rounded),
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
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback? onBack;
  const _Header({this.onBack});

  static const double contentHeight = 72; // 👈 base height

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      height: contentHeight + topInset, // 👈 CHANGE 1: 72 + topInset
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        gradient: AppHeader.brandGradient,
      ),
      child: Stack(
        children: [
          Positioned(right: -45, top: -70, child: _orb(170)),
          Positioned(right: 45, bottom: -70, child: _orb(125)),

          // 👈 CHANGE 2: Positioned.fill + topInset-only padding,
          // so the Row is centered inside the 72px content area
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                onBack == null ? 20 : 8,
                topInset,
                20,
                0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (onBack != null)
                    IconButton(
                      onPressed: onBack,
                      tooltip: 'Back',
                      icon: const Icon(Icons.chevron_left_rounded,
                          color: Colors.white, size: 32),
                    ),
                  const Expanded(
                    child: Text(
                      'Notifications',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
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

  Widget _orb(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: .07),
        ),
      );
}

// =============================================================================
// _NotificationCard — shared by interview and membership notifications
// =============================================================================
class _NotificationCard extends StatelessWidget {
  final Notification notification;
  final int index;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _NotificationCard({
    super.key,
    required this.notification,
    required this.index,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unread = !notification.read;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + index.clamp(0, 8) * 60),
      curve: Curves.easeOut,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child:
            Transform.translate(offset: Offset(0, 16 * (1 - v)), child: child),
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
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: unread
                          ? color.withValues(alpha: 0.12)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon,
                        size: 22,
                        color: unread ? color : const Color(0xFF94A3B8)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: TextStyle(
                                  fontSize: 14,
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
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(left: 8),
                                decoration: BoxDecoration(
                                    color: color, shape: BoxShape.circle),
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _prettyMessage(notification.message),
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: Color(0xFF64748B),
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
                                const Icon(Icons.access_time_rounded,
                                    size: 12, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 4),
                                Text(
                                  _timeAgo(notification.date),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                            if (unread)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
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
    );
  }
}

// =============================================================================
// _EmptyState
// =============================================================================
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_off_rounded,
                  size: 36, color: Color(0xFF16A34A)),
            ),
            const SizedBox(height: 20),
            const Text(
              'No notifications yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "You're all caught up!\nCheck back later for updates.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// _SectionLabel
// =============================================================================
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

// ─── Helpers ────────────────────────────────────────────────────────────────
String _timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  String unit(int n, String s) => '$n $s${n > 1 ? 's' : ''} ago';
  if (d.inDays > 0) return unit(d.inDays, 'day');
  if (d.inHours > 0) return unit(d.inHours, 'hour');
  if (d.inMinutes > 0) return unit(d.inMinutes, 'minute');
  return 'Just now';
}

/// Display-only: turns "2026-10-24 22:13:00.000" inside a message into
/// "Oct 24, 2026 at 10:13 PM". The stored message is never modified.
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
    'Dec'
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
