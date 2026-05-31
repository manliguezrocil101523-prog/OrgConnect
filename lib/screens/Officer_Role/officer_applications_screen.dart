import 'package:flutter/material.dart' hide Notification;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../core/app_state.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

// =============================================================================
// DESIGN SYSTEM — Officer Applications Screen
// PRIMARY: #4F46E5  SECONDARY: #06B6D4  BG: #F8FAFC
// All logic, filtering, dialogs, and Supabase calls are 100% preserved.
// =============================================================================

class OfficerApplicationsScreen extends StatelessWidget {
  final String? filter;
  const OfficerApplicationsScreen({super.key, this.filter});

  static const _primary = Color(0xFF4F46E5);
  static const _secondary = Color(0xFF06B6D4);
  static const _background = Color(0xFFF8FAFC);
  static const _success = Color(0xFF22C55E);

  // ── Status config ─────────────────────────────────────────────────────
  static _SC _sc(ApplicationStatus s) {
    switch (s) {
      case ApplicationStatus.pending:
        return const _SC(
            'Pending', Color(0xFFFFFBEB), Color(0xFF92400E), Color(0xFFFDE68A));
      case ApplicationStatus.for_approval:
        return const _SC('Approval', Color(0xFFEFF6FF), Color(0xFF1E40AF),
            Color(0xFFBFDBFE));
      case ApplicationStatus.accepted:
        return const _SC('Accepted', Color(0xFFECFDF5), Color(0xFF065F46),
            Color(0xFFA7F3D0));
      case ApplicationStatus.interview_scheduled:
        return const _SC('Interview', Color(0xFFEEF2FF), Color(0xFF3730A3),
            Color(0xFFC7D2FE));
      case ApplicationStatus.declined:
        return const _SC('Declined', Color(0xFFFFF1F2), Color(0xFF9F1239),
            Color(0xFFFFCDD3));
    }
  }

  String _filterTitle() {
    switch (filter) {
      case 'pending':
        return 'Pending';
      case 'forApproval':
        return 'For Approval';
      case 'interviewed':
        return 'Interviewees';
      case 'approved':
        return 'Approved';
      case 'declined':
        return 'Declined';
      default:
        return 'Applications';
    }
  }

  String _statusText(ApplicationStatus s) {
    switch (s) {
      case ApplicationStatus.pending:
        return 'Pending Review';
      case ApplicationStatus.for_approval:
        return 'For Approval';
      case ApplicationStatus.accepted:
        return 'Accepted';
      case ApplicationStatus.interview_scheduled:
        return 'Interview Scheduled';
      case ApplicationStatus.declined:
        return 'Declined';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Header ──────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: MediaQuery.of(context).size.height * 0.18,
            backgroundColor: _primary,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            centerTitle: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _AppHeroHeader(
                primary: _primary,
                secondary: _secondary,
                title: _filterTitle(),
              ),
            ),
          ),

          // ── Body ────────────────────────────────────────────────────────
          AnimatedBuilder(
            animation: AppState.instance,
            builder: (context, _) {
              final orgId = AppState.instance.currentOfficerOrgId;
              if (orgId == null) {
                return const SliverFillRemaining(
                  child: Center(child: Text('No organization selected.')),
                );
              }

              final allApps = AppState.instance.applications
                  .where((a) => a.orgId == orgId)
                  .toList();

              final memberNames = AppState.instance.members
                  .where((m) => m.orgId == orgId)
                  .map((m) => m.name)
                  .toSet();

              // UNTOUCHED: original grouping logic
              final pending = allApps
                  .where((a) => a.status == ApplicationStatus.pending)
                  .toList();
              final forApproval = allApps
                  .where((a) => a.status == ApplicationStatus.for_approval)
                  .toList();
              final accepted = allApps
                  .where((a) => a.status == ApplicationStatus.accepted)
                  .toList();
              final scheduled = allApps
                  .where(
                      (a) => a.status == ApplicationStatus.interview_scheduled)
                  .toList();
              final declined = allApps
                  .where((a) => a.status == ApplicationStatus.declined)
                  .toList();
              final interviewed =
                  accepted.where((a) => !memberNames.contains(a.name)).toList();
              final approved =
                  accepted.where((a) => memberNames.contains(a.name)).toList();

              try {
                print(
                    'OfficerApps: org=$orgId pending=${pending.length} forApproval=${forApproval.length} accepted=${accepted.length} scheduled=${scheduled.length} declined=${declined.length}');
              } catch (_) {}

              // Filtered view
              List<Application>? filtered;
              if (filter == 'pending')
                filtered = pending;
              else if (filter == 'forApproval')
                filtered = forApproval;
              else if (filter == 'interviewed')
                filtered = interviewed;
              else if (filter == 'approved')
                filtered = approved;
              else if (filter == 'declined') filtered = declined;

              if (filtered != null) {
                if (filtered.isEmpty) {
                  return SliverFillRemaining(
                    child: _EmptyState(label: _filterTitle()),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _AppCard(
                        app: filtered![i],
                        index: i,
                        onView: () => _showDetails(context, filtered![i]),
                        onAccept: _canAccept(filtered![i])
                            ? () => _accept(context, filtered![i])
                            : null,
                        onDecline: _canDecline(filtered![i])
                            ? () => _decline(context, filtered![i])
                            : null,
                        onSchedule: _canSchedule(filtered![i], memberNames)
                            ? () => _scheduleInterview(context, filtered![i])
                            : null,
                        onAssign: _canAssign(filtered![i], memberNames)
                            ? () => _assignPosition(context, filtered![i])
                            : null,
                        onDelete: filtered![i].status ==
                                ApplicationStatus.declined
                            ? () => _deleteApplication(context, filtered![i])
                            : null,
                      ),
                      childCount: filtered.length,
                    ),
                  ),
                );
              }

              // All view — grouped by section
              if (allApps.isEmpty) {
                return const SliverFillRemaining(
                  child: _EmptyState(label: 'Applications'),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 540),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (pending.isNotEmpty)
                              ..._section(context, 'Pending Applications',
                                  pending, memberNames),
                            if (scheduled.isNotEmpty)
                              ..._section(context, 'Scheduled Interviews',
                                  scheduled, memberNames),
                            if (interviewed.isNotEmpty)
                              ..._section(context, 'Interviewees', interviewed,
                                  memberNames),
                            if (approved.isNotEmpty)
                              ..._section(
                                  context, 'Approved', approved, memberNames),
                            if (declined.isNotEmpty) ...[
                              _DeclinedHeader(
                                onClearAll: () =>
                                    _clearDeclined(context, declined),
                              ),
                              const SizedBox(height: 12),
                              ..._buildCards(context, declined, memberNames),
                              const SizedBox(height: 24),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Section helper ────────────────────────────────────────────────────
  List<Widget> _section(BuildContext context, String title,
      List<Application> apps, Set<String> memberNames) {
    return [
      _SectionLabel(text: title),
      const SizedBox(height: 12),
      ..._buildCards(context, apps, memberNames),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _buildCards(
      BuildContext context, List<Application> apps, Set<String> memberNames) {
    return apps
        .asMap()
        .entries
        .map((e) => _AppCard(
              app: e.value,
              index: e.key,
              onView: () => _showDetails(context, e.value),
              onAccept:
                  _canAccept(e.value) ? () => _accept(context, e.value) : null,
              onDecline: _canDecline(e.value)
                  ? () => _decline(context, e.value)
                  : null,
              onSchedule: _canSchedule(e.value, memberNames)
                  ? () => _scheduleInterview(context, e.value)
                  : null,
              onAssign: _canAssign(e.value, memberNames)
                  ? () => _assignPosition(context, e.value)
                  : null,
              onDelete: e.value.status == ApplicationStatus.declined
                  ? () => _deleteApplication(context, e.value)
                  : null,
            ))
        .toList();
  }

  // ── Action guards — UNTOUCHED logic ───────────────────────────────────
  bool _canAccept(Application a) =>
      a.status == ApplicationStatus.pending ||
      a.status == ApplicationStatus.for_approval;

  bool _canDecline(Application a) =>
      a.status == ApplicationStatus.pending ||
      a.status == ApplicationStatus.for_approval;

  bool _canSchedule(Application a, Set<String> memberNames) =>
      a.status == ApplicationStatus.accepted && !memberNames.contains(a.name);

  bool _canAssign(Application a, Set<String> memberNames) =>
      a.status == ApplicationStatus.accepted && !memberNames.contains(a.name);

  // ── Actions — all original logic preserved ────────────────────────────
  void _accept(BuildContext context, Application a) {
    final orgId = AppState.instance.currentOfficerOrgId;
    final org = orgId != null
        ? AppState.instance.organizations.firstWhere(
            (o) => o.id == orgId,
            orElse: () => a.orgId != null
                ? AppState.instance.organizations.firstWhere(
                    (o) => o.id == a.orgId,
                    orElse: () => AppState.instance.organizations.first)
                : AppState.instance.organizations.first,
          )
        : null;

    // Guard: if no org context, bail out safely
    if (orgId == null || org == null) {
      _snack(context, 'No organization context found. Please re-login.',
          Colors.red);
      return;
    }

    if (a.status == ApplicationStatus.for_approval) {
      AppState.instance.approveApplication(
        a.id,
        defaultPosition: 'Member',
      );

      _snack(context, '${a.name} approved and added to the organization.',
          _success);
    } else {
      AppState.instance.setApplicationStatus(a.id, ApplicationStatus.accepted);
      _snack(context, 'Moved to Interviewees. You can schedule an interview.');
    }
  }

  void _decline(BuildContext context, Application a) {
    AppState.instance.setApplicationStatus(a.id, ApplicationStatus.declined);
    _snack(context, 'Application declined.', Colors.redAccent);
  }

  void _clearDeclined(BuildContext context, List<Application> declined) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Delete all declined',
        message:
            'Permanently delete all declined applications? This cannot be undone.',
        confirmLabel: 'Delete',
        confirmColor: Colors.red,
      ),
    );
    if (ok != true) return;
    final ids = declined.map((a) => a.id).toList();
    AppState.instance.removeApplications(ids);
    try {
      for (final id in ids) {
        await supabase.Supabase.instance.client
            .from('applications')
            .delete()
            .eq('id', id);
      }
    } catch (e) {
      print('Error deleting declined: $e');
    }
    if (context.mounted)
      _snack(context, 'Deleted ${ids.length} declined application(s).',
          Colors.red);
  }

  void _showDetails(BuildContext context, Application a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // ── Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  // Profile picture
                  // Profile picture
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [_primary, _secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: a.profilePicUrl.isNotEmpty
                          ? Image.network(
                              a.profilePicUrl,
                              fit: BoxFit.cover,
                              width: 48,
                              height: 48,
                              loadingBuilder: (_, child, progress) =>
                                  progress == null
                                      ? child
                                      : const Center(
                                          child: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white),
                                          ),
                                        ),
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.person_rounded,
                                  color: Colors.white,
                                  size: 22),
                            )
                          : const Icon(Icons.person_rounded,
                              color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${a.name}'s Application",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          a.orgName,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _sc(a.status).bg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _sc(a.status).ring),
                    ),
                    child: Text(
                      _statusText(a.status),
                      style: TextStyle(
                        color: _sc(a.status).fg,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),

              // ── Scrollable content
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  children: [
                    _sectionHeader('Personal Information'),
                    const SizedBox(height: 10),
                    _infoCard([
                      _detailRow('Student ID', a.studentId),
                      _detailRow('Full Name', a.name),
                      _detailRow('Course', a.course),
                      _detailRow('Year & Section', a.yearSection),
                    ]),

                    const SizedBox(height: 16),
                    _sectionHeader('Contact Information'),
                    const SizedBox(height: 10),
                    _infoCard([
                      _detailRow('Contact No.', a.contact),
                      _detailRow('Email', a.email),
                      _detailRow('Facebook', a.facebook),
                    ]),

                    const SizedBox(height: 16),
                    _sectionHeader('Application Details'),
                    const SizedBox(height: 10),
                    _infoCard([
                      _detailRow('Reason for Joining', a.reason),
                      _detailRow('Skills / Talents', a.skills),
                      _detailRow('Previous Experience', a.experience),
                      _detailRow('Emergency Contact', a.emergencyContact),
                    ]),

                    const SizedBox(height: 16),
                    _sectionHeader('Status & Dates'),
                    const SizedBox(height: 10),
                    _infoCard([
                      _detailRow('Status', _statusText(a.status)),
                      _detailRow('Submitted',
                          a.createdAt.toLocal().toString().split('.')[0]),
                      if (a.interviewAt != null)
                        _detailRow('Interview',
                            a.interviewAt!.toLocal().toString().split('.')[0]),
                    ]),

                    // ── Attachments
                    if (a.attachments.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _sectionHeader('Attachments'),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: a.attachments.asMap().entries.map((entry) {
                            final url = entry.value;
                            final ext = url.contains('.')
                                ? url
                                    .split('.')
                                    .last
                                    .split('?')
                                    .first
                                    .toLowerCase()
                                : '';
                            const imgExts = [
                              'jpg',
                              'jpeg',
                              'png',
                              'gif',
                              'webp',
                              'heic'
                            ];
                            const vidExts = [
                              'mp4',
                              'mov',
                              'avi',
                              'mkv',
                              'm4v',
                              'webm'
                            ];

                            if (imgExts.contains(ext)) {
                              return _AttachmentImage(
                                  url: url, context: context);
                            } else if (vidExts.contains(ext)) {
                              return _AttachmentVideo(
                                  url: url, context: context);
                            } else {
                              // Fallback: unknown type, show link chip
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF64748B)
                                        .withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: const Color(0xFF64748B)
                                            .withOpacity(0.25)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                          Icons.insert_drive_file_rounded,
                                          size: 14,
                                          color: Color(0xFF64748B)),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          url,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
                                              fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                          }).toList(),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: const Text('Close',
                          style: TextStyle(color: Color(0xFF64748B))),
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

// ── Detail view helpers (add these right after _showDetails)
  Widget _sectionHeader(String title) => Row(children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_primary, _secondary],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: Color(0xFF94A3B8),
          ),
        ),
      ]);

  Widget _infoCard(List<Widget> rows) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows.asMap().entries.map((e) {
            final isLast = e.key == rows.length - 1;
            return Column(
              children: [
                e.value,
                if (!isLast) const Divider(height: 1, color: Color(0xFFF1F5F9)),
              ],
            );
          }).toList(),
        ),
      );

  void _scheduleInterview(BuildContext context, Application a) {
    DateTime selDate = DateTime.now().add(const Duration(days: 3));
    TimeOfDay selTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _dialogHeader(Icons.schedule_rounded, 'Schedule Interview'),
                const SizedBox(height: 16),
                Text('Schedule for ${a.name}',
                    style: const TextStyle(color: Color(0xFF64748B))),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                      child: _DateTimeChip(
                    label: selDate.toLocal().toString().split(' ')[0],
                    icon: Icons.calendar_today_rounded,
                    onTap: () async {
                      final p = await showDatePicker(
                        context: ctx,
                        initialDate: selDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        builder: (_, child) => Theme(
                          data: Theme.of(ctx).copyWith(
                            colorScheme:
                                const ColorScheme.light(primary: _primary),
                          ),
                          child: child!,
                        ),
                      );
                      if (p != null) setState(() => selDate = p);
                    },
                  )),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _DateTimeChip(
                    label: selTime.format(ctx),
                    icon: Icons.access_time_rounded,
                    onTap: () async {
                      final p = await showTimePicker(
                          context: ctx, initialTime: selTime);
                      if (p != null) setState(() => selTime = p);
                    },
                  )),
                ]),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                      child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(color: Color(0xFF64748B))),
                  )),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _GradientButton(
                    label: 'Schedule',
                    onTap: () async {
                      final dt = DateTime(selDate.year, selDate.month,
                          selDate.day, selTime.hour, selTime.minute);
                      try {
                        final ok =
                            await AppState.instance.scheduleInterview(a.id, dt);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted)
                          _snack(
                            context,
                            ok
                                ? 'Interview scheduled for ${a.name}.'
                                : 'Failed to schedule.',
                            ok ? _success : Colors.red,
                          );
                      } catch (e) {
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted)
                          _snack(
                            context,
                            'Failed to schedule interview. Please try again.',
                            Colors.red,
                          );
                        print('Schedule interview error: $e');
                      }
                    },
                  )),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _assignPosition(BuildContext context, Application a) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _dialogHeader(Icons.person_add_rounded, 'Assign Position'),
              const SizedBox(height: 16),
              Text('Assign a position to ${a.name}',
                  style: const TextStyle(color: Color(0xFF64748B))),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'e.g., Member, Officer, Coordinator',
                  hintStyle: const TextStyle(color: Color(0xFFCBD5E1)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  prefixIcon: const Icon(Icons.badge_rounded,
                      color: _primary, size: 18),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: _primary, width: 1.5)),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                    child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(color: Color(0xFF64748B))),
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: _GradientButton(
                  label: 'Assign & Accept',
                  onTap: () {
                    if (ctrl.text.trim().isEmpty) return;
                    AppState.instance.approveApplication(a.id,
                        defaultPosition: ctrl.text.trim());
                    Navigator.pop(context);
                    _snack(context,
                        '${a.name} assigned as ${ctrl.text.trim()}.', _success);
                  },
                )),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteApplication(BuildContext context, Application a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Delete Application',
        message:
            'Permanently delete ${a.name}\'s application? This cannot be undone.',
        confirmLabel: 'Delete',
        confirmColor: Colors.red,
      ),
    );
    if (ok != true) return;
    AppState.instance.applications.removeWhere((x) => x.id == a.id);
    try {
      await supabase.Supabase.instance.client
          .from('applications')
          .delete()
          .eq('id', a.id);
    } catch (e) {
      print('Error deleting: $e');
    }
    if (context.mounted)
      _snack(context, "${a.name}'s application deleted.", Colors.red);
  }

  // ── Small helpers ─────────────────────────────────────────────────────
  void _snack(BuildContext context, String msg, [Color? bg]) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Widget _detailRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value.isEmpty ? '—' : value,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _dialogHeader(IconData icon, String title) => Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [_primary, _secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Text(title,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A))),
      ]);
}

// =============================================================================
// _AppHeroHeader
// =============================================================================
class _AppHeroHeader extends StatelessWidget {
  final Color primary, secondary;
  final String title;
  const _AppHeroHeader(
      {required this.primary, required this.secondary, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [primary, secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
      ),
      child: Stack(children: [
        Positioned(top: -30, right: -20, child: _orb(160, 0.07)),
        Positioned(bottom: 10, left: -40, child: _orb(120, 0.05)),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 52, left: 24, right: 24),
            child: Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withOpacity(0.30), width: 1.5),
                ),
                child: const Icon(Icons.assignment_rounded,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text('Review and manage applications',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.72),
                            fontSize: 12.5)),
                  ]),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _orb(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            shape: BoxShape.circle, color: Colors.white.withOpacity(opacity)),
      );
}

// =============================================================================
// _AppCard — application card with status pill + action buttons
// =============================================================================
class _AppCard extends StatelessWidget {
  final Application app;
  final int index;
  final VoidCallback onView;
  final VoidCallback? onAccept, onDecline, onSchedule, onAssign, onDelete;

  const _AppCard({
    required this.app,
    required this.index,
    required this.onView,
    this.onAccept,
    this.onDecline,
    this.onSchedule,
    this.onAssign,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cfg = OfficerApplicationsScreen._sc(app.status);
    final initial = app.name.isNotEmpty ? app.name[0].toUpperCase() : '?';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 250 + index * 40),
      curve: Curves.easeOut,
      builder: (_, v, child) => Opacity(
          opacity: v,
          child: Transform.translate(
              offset: Offset(0, 12 * (1 - v)), child: child)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF4F46E5).withOpacity(0.05),
                blurRadius: 16,
                offset: const Offset(0, 5)),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: IntrinsicHeight(
          child: Row(children: [
            // Status bar
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: cfg.fg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: avatar + name + status pill
                      Row(children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: cfg.bg,
                            shape: BoxShape.circle,
                            border: Border.all(color: cfg.ring),
                          ),
                          child: Center(
                              child: Text(initial,
                                  style: TextStyle(
                                      color: cfg.fg,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(app.name,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A))),
                                Text(app.orgName,
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF94A3B8))),
                              ]),
                        ),
                        // Status pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                              color: cfg.bg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: cfg.ring)),
                          child: Text(cfg.label,
                              style: TextStyle(
                                  color: cfg.fg,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ]),

                      const SizedBox(height: 10),
                      Divider(height: 1, color: Colors.grey.shade100),
                      const SizedBox(height: 10),

                      // Details
                      _info(Icons.badge_rounded, 'ID: ${app.studentId}'),
                      const SizedBox(height: 3),
                      _info(Icons.phone_rounded, app.contact),
                      const SizedBox(height: 3),
                      _info(Icons.email_rounded, app.email),
                      if (app.reason.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        _info(Icons.notes_rounded, app.reason, maxLines: 2),
                      ],

                      const SizedBox(height: 10),

                      // Action buttons row
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          _Chip(
                              icon: Icons.visibility_rounded,
                              label: 'View',
                              color: const Color(0xFF4F46E5),
                              onTap: onView),
                          if (onAccept != null) ...[
                            const SizedBox(width: 6),
                            _Chip(
                                icon: Icons.check_circle_rounded,
                                label: 'Accept',
                                color: const Color(0xFF22C55E),
                                onTap: onAccept!)
                          ],
                          if (onDecline != null) ...[
                            const SizedBox(width: 6),
                            _Chip(
                                icon: Icons.cancel_rounded,
                                label: 'Decline',
                                color: const Color(0xFFEF4444),
                                onTap: onDecline!)
                          ],
                          if (onSchedule != null) ...[
                            const SizedBox(width: 6),
                            _Chip(
                                icon: Icons.schedule_rounded,
                                label: 'Schedule',
                                color: const Color(0xFFF59E0B),
                                onTap: onSchedule!)
                          ],
                          if (onAssign != null) ...[
                            const SizedBox(width: 6),
                            _Chip(
                                icon: Icons.person_add_rounded,
                                label: 'Assign',
                                color: const Color(0xFF8B5CF6),
                                onTap: onAssign!)
                          ],
                          if (onDelete != null) ...[
                            const SizedBox(width: 6),
                            _Chip(
                                icon: Icons.delete_forever_rounded,
                                label: 'Delete',
                                color: const Color(0xFFEF4444),
                                onTap: onDelete!)
                          ],
                        ]),
                      ),
                    ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _info(IconData icon, String text, {int maxLines = 1}) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 6),
          Expanded(
              child: Text(text,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
        ],
      );
}

// =============================================================================
// Small shared widgets
// =============================================================================
class _SC {
  final String label;
  final Color bg, fg, ring;
  const _SC(this.label, this.bg, this.fg, this.ring);
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Chip(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: color, size: 13),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}

class _DateTimeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _DateTimeChip(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: const Color(0xFF4F46E5), size: 14),
              const SizedBox(width: 6),
              Flexible(
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4F46E5)))),
            ]),
          ),
        ),
      );
}

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GradientButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF4F46E5).withOpacity(0.28),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                  child: Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14))),
            ),
          ),
        ),
      );
}

class _ConfirmDialog extends StatelessWidget {
  final String title, message, confirmLabel;
  final Color confirmColor;
  const _ConfirmDialog(
      {required this.title,
      required this.message,
      required this.confirmLabel,
      required this.confirmColor});

  @override
  Widget build(BuildContext context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A))),
                const SizedBox(height: 10),
                Text(message,
                    style: const TextStyle(
                        fontSize: 13.5, color: Color(0xFF64748B), height: 1.5)),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                      child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: const Text('Cancel',
                        style: TextStyle(color: Color(0xFF64748B))),
                  )),
                  const SizedBox(width: 12),
                  Expanded(
                      child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: confirmColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0),
                    child: Text(confirmLabel,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  )),
                ]),
              ]),
        ),
      );
}

class _DeclinedHeader extends StatelessWidget {
  final VoidCallback onClearAll;
  const _DeclinedHeader({required this.onClearAll});

  @override
  Widget build(BuildContext context) => Row(children: [
        const Expanded(child: _SectionLabel(text: 'Declined')),
        TextButton.icon(
          onPressed: onClearAll,
          icon: const Icon(Icons.delete_forever_rounded,
              color: Colors.redAccent, size: 16),
          label: const Text('Clear All',
              style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
      ]);
}

class _EmptyState extends StatelessWidget {
  final String label;
  const _EmptyState({required this.label});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF4F46E5).withOpacity(0.28),
                    blurRadius: 20,
                    offset: const Offset(0, 8))
              ],
            ),
            child: const Icon(Icons.assignment_rounded,
                size: 32, color: Colors.white),
          ),
          const SizedBox(height: 18),
          Text('No $label yet',
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A))),
          const SizedBox(height: 6),
          const Text('Applications will appear here.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        ]),
      );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(text.toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
                color: Color(0xFF94A3B8))),
      ]);
}

// =============================================================================
// _AttachmentImage — tappable image thumbnail
// =============================================================================
class _AttachmentImage extends StatelessWidget {
  final String url;
  final BuildContext context;
  const _AttachmentImage({required this.url, required this.context});

  @override
  Widget build(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _FullScreenImage(url: url),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            url,
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return Container(
                height: 180,
                color: const Color(0xFFF1F5F9),
                child: const Center(child: CircularProgressIndicator()),
              );
            },
            errorBuilder: (_, __, ___) => Container(
              height: 80,
              color: const Color(0xFFF1F5F9),
              child: const Center(
                child: Icon(Icons.broken_image_rounded,
                    color: Color(0xFF94A3B8), size: 32),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _AttachmentVideo — thumbnail tile that opens Chewie player
// =============================================================================
class _AttachmentVideo extends StatelessWidget {
  final String url;
  final BuildContext context;
  const _AttachmentVideo({required this.url, required this.context});

  @override
  Widget build(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _VideoPlayerScreen(url: url),
          ),
        ),
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: Icon(Icons.play_circle_fill_rounded,
                color: Colors.white, size: 52),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _FullScreenImage — full screen image viewer
// =============================================================================
class _FullScreenImage extends StatelessWidget {
  final String url;
  const _FullScreenImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded,
                color: Colors.white, size: 48),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _VideoPlayerScreen — in-app video player using Chewie
// =============================================================================
class _VideoPlayerScreen extends StatefulWidget {
  final String url;
  const _VideoPlayerScreen({required this.url});

  @override
  State<_VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
  late VideoPlayerController _videoCtrl;
  ChewieController? _chewieCtrl;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _videoCtrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {
          _chewieCtrl = ChewieController(
            videoPlayerController: _videoCtrl,
            autoPlay: true,
            looping: false,
            aspectRatio: _videoCtrl.value.aspectRatio,
          );
        });
      }).catchError((_) {
        if (mounted) setState(() => _error = true);
      });
  }

  @override
  void dispose() {
    _chewieCtrl?.dispose();
    _videoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: _error
            ? const Text('Failed to load video.',
                style: TextStyle(color: Colors.white))
            : _chewieCtrl != null
                ? Chewie(controller: _chewieCtrl!)
                : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
