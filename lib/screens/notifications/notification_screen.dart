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

class _NotificationScreenState extends State<NotificationScreen>
    with SingleTickerProviderStateMixin {
  static const Color _primary = Color(0xFF16A34A);
  static const Color _background = Color(0xFFF1F5F9);

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    AppState.instance.addListener(_onAppStateChanged);

    // Force fresh fetch every time this screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await AppState.instance.loadStudentProfile();
      await AppState.instance.fetchApplications();
      await AppState.instance.fetchNotifications();
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    AppState.instance.removeListener(_onAppStateChanged);
    super.dispose();
  }

  void _onAppStateChanged() => setState(() {});

  void _markAsRead(String id) => AppState.instance.markNotificationRead(id);

  Future<void> _handleRefresh() async {
    await AppState.instance.fetchNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final currentStudent = AppState.instance.currentStudent;
    final allNotifications = AppState.instance.notifications;

    final notifications = currentStudent == null
        ? []
        : allNotifications.where((n) {
            final title = n.title.toLowerCase();
            final message = n.message.toLowerCase();
            final isInterview = title.contains('interview') ||
                message.contains('scheduled interview');
            final isMember = title.contains('congratulations') ||
                message.contains('officially a member');
            return (n.studentId == currentStudent.id ||
                    n.studentId == currentStudent.studentId) &&
                (isInterview || isMember);
          }).toList();

    // Keep one student-facing workflow card per organization and category.
    // fetchNotifications() already performs this normalization, but this
    // second guard prevents duplicates from cached state or a realtime update
    // from rendering more than one card.
    final interviewSeen = <String>{};
    final interviewNotifications = notifications.where((n) {
      if (!n.title.toLowerCase().contains('interview')) return false;
      final key = n.orgId ?? n.title.toLowerCase();
      return interviewSeen.add(key);
    }).toList();
    final membershipSeen = <String>{};
    final otherNotifications = notifications.where((n) {
      final title = n.title.toLowerCase();
      final message = n.message.toLowerCase();
      final membership = title.contains('congratulations') ||
          message.contains('officially a member');
      if (!membership) return false;
      final key = n.orgId ?? n.title.toLowerCase();
      return membershipSeen.add(key);
    }).toList();

    final unreadCount = notifications.where((n) => !n.read).length;

    return Scaffold(
      backgroundColor: _background,
      body: Column(
        children: [
          AppHeader(
            title: 'Notifications',
            subtitle: 'Interview and membership updates',
            status: unreadCount > 0 ? '$unreadCount UNREAD' : 'ALL CAUGHT UP',
            icon: Icons.notifications_rounded,
            onBack: widget.showBackButton
                ? () => Navigator.of(context).maybePop()
                : null,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              color: _primary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  notifications.isEmpty
                      ? SliverFillRemaining(
                          child: _EmptyState(),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              Center(
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 540),
                                  child: FadeTransition(
                                    opacity: _fadeAnim,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (interviewNotifications
                                            .isNotEmpty) ...[
                                          const _SectionLabel(
                                              text: 'Interview Notifications'),
                                          const SizedBox(height: 12),
                                          ...interviewNotifications
                                              .asMap()
                                              .entries
                                              .map((e) => _InterviewCard(
                                                    notification: e.value,
                                                    index: e.key,
                                                    onTap: () =>
                                                        _markAsRead(e.value.id),
                                                  )),
                                          const SizedBox(height: 24),
                                        ],
                                        if (otherNotifications.isNotEmpty) ...[
                                          const _SectionLabel(
                                              text: 'Other Notifications'),
                                          const SizedBox(height: 12),
                                          ...otherNotifications
                                              .asMap()
                                              .entries
                                              .map((e) => _GeneralCard(
                                                    notification: e.value,
                                                    index: e.key,
                                                    onTap: () =>
                                                        _markAsRead(e.value.id),
                                                  )),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ]),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    ); // closes Scaffold
  }
}

// =============================================================================
// _NotificationHeroHeader
// =============================================================================
// =============================================================================
// _InterviewCard
// =============================================================================
class _InterviewCard extends StatelessWidget {
  final Notification notification;
  final int index;
  final VoidCallback onTap;

  static const Color _amber = Color(0xFFF59E0B);

  const _InterviewCard({
    required this.notification,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.read;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + index * 60),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - value)),
          child: child,
        ),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isUnread
                ? Border.all(color: _amber.withValues(alpha: 0.40), width: 1.5)
                : Border.all(color: const Color(0xFFE2E8F0), width: 1),
            boxShadow: [
              BoxShadow(
                color: isUnread
                    ? _amber.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.schedule_rounded,
                    color: _amber,
                    size: 22,
                  ),
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
                                fontWeight: isUnread
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 14,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: _amber,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        notification.message,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTimestamp(notification.date),
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (isUnread) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _amber.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'New',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _amber,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
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
    );
  }
}

// =============================================================================
// _GeneralCard
// =============================================================================
class _GeneralCard extends StatelessWidget {
  final Notification notification;
  final int index;
  final VoidCallback onTap;

  static const Color _teal = Color(0xFF0F766E);

  const _GeneralCard({
    required this.notification,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.read;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + index * 60),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - value)),
          child: child,
        ),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isUnread
                ? Border.all(color: _teal.withValues(alpha: 0.35), width: 1.5)
                : Border.all(color: const Color(0xFFE2E8F0), width: 1),
            boxShadow: [
              BoxShadow(
                color: isUnread
                    ? _teal.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isUnread
                        ? _teal.withValues(alpha: 0.12)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.calendar_today_rounded,
                    color: isUnread ? _teal : const Color(0xFF94A3B8),
                    size: 20,
                  ),
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
                                fontWeight: isUnread
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 14,
                                color: isUnread
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          if (isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: _teal,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        notification.message,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTimestamp(notification.date),
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (isUnread) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _teal.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'New',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _teal,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
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
    );
  }
}

// =============================================================================
// _EmptyState
// =============================================================================
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
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
            child: const Icon(
              Icons.notifications_off_rounded,
              size: 36,
              color: Color(0xFF16A34A),
            ),
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
          Text(
            "You're all caught up!\nCheck back later for updates.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: const Color(0xFF64748B),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _SectionLabel
// =============================================================================
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
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
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
            color: Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}

// ─── Shared timestamp helper ───────────────────────────────────────────────
String _formatTimestamp(DateTime timestamp) {
  final diff = DateTime.now().difference(timestamp);
  if (diff.inDays > 0) {
    return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
  }
  if (diff.inHours > 0) {
    return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
  }
  if (diff.inMinutes > 0) {
    return '${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''} ago';
  }
  return 'Just now';
}
