import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_state.dart';
import '../../widgets/app_header.dart';

class OfficerMembersScreen extends StatefulWidget {
  final String? organizationId;
  final bool showOnlyActive;
  final bool readOnly;
  final bool adviserView;
  final String title;

  const OfficerMembersScreen({
    super.key,
    this.organizationId,
    this.showOnlyActive = false,
    this.readOnly = false,
    this.adviserView = false,
    this.title = 'Organization Members',
  });

  @override
  State<OfficerMembersScreen> createState() => _OfficerMembersScreenState();
}

class _OfficerMembersScreenState extends State<OfficerMembersScreen> {
  void _snack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  static const _p = Color(0xFF16A34A); // primary
  static const _bg = Colors.white; // background
  static const _ok = Color(0xFF22C55E); // success
  static const _officerPositions = <String>[
    'President',
    'Vice President',
    'Officer',
    'Secretary',
    'Assistant Secretary',
    'Treasurer',
  ];

  final Set<String> _activeProfileIds = <String>{};
  final Map<String, int> _chatMessageCounts = <String, int>{};
  final Map<String, int> _commentCounts = <String, int>{};
  final Map<String, int> _attendancePresentCounts = <String, int>{};
  final Map<String, int> _attendanceTotalCounts = <String, int>{};
  final Map<String, Map<String, dynamic>> _impactByStudentId =
      <String, Map<String, dynamic>>{};
  bool _activeStatusLoaded = false;
  bool _canManageMembers = false;
  bool _canManageAttendance = false;
  bool _canManageMinutes = false;
  bool _canManageFinance = false;
  bool _canViewFinance = false;
  bool _managerRoleLoaded = false;
  RealtimeChannel? _attendanceChannel;
  final ScrollController _membersScrollController = ScrollController();

  @override
  void dispose() {
    final channel = _attendanceChannel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }
    _membersScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final orgId =
        widget.organizationId ?? AppState.instance.currentOfficerOrgId;
    if (orgId != null && orgId.isNotEmpty) {
      _attendanceChannel = Supabase.instance.client.channel(
          'member-attendance-$orgId-${Supabase.instance.client.auth.currentUser?.id ?? 'local'}')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'organization_member_attendance',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'org_id',
              value: orgId),
          callback: (_) => _loadEngagementData(),
        )
        ..subscribe();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await AppState.instance.fetchMembers(
          organizationId:
              widget.organizationId ?? AppState.instance.currentOfficerOrgId);
      await _loadManagerPermission();
      await _loadEngagementData();
    });
  }

  Future<void> _loadManagerPermission() async {
    try {
      final orgId =
          widget.organizationId ?? AppState.instance.currentOfficerOrgId;
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (orgId == null || orgId.isEmpty || userId == null) {
        if (mounted) setState(() => _managerRoleLoaded = true);
        return;
      }
      final row = await Supabase.instance.client
          .from('members')
          .select('position')
          .eq('org_id', orgId)
          .eq('profile_id', userId)
          .maybeSingle();
      final position = row?['position']?.toString().toLowerCase().trim() ?? '';
      if (mounted) {
        setState(() {
          _canManageMembers = widget.adviserView ||
              position == 'president' ||
              position == 'vice president';
          _canManageAttendance =
              {'secretary', 'assistant secretary'}.contains(position);
          _canManageMinutes =
              {'secretary', 'assistant secretary'}.contains(position);
          _canManageFinance = position == 'treasurer';
          _canViewFinance =
              {'treasurer', 'president', 'vice president'}.contains(position);
          _managerRoleLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Could not determine officer management permission: $e');
      if (mounted) setState(() => _managerRoleLoaded = true);
    }
  }

  Future<void> _loadEngagementData() async {
    try {
      final orgId =
          widget.organizationId ?? AppState.instance.currentOfficerOrgId;
      if (orgId == null || orgId.isEmpty) {
        if (mounted) setState(() => _activeStatusLoaded = true);
        return;
      }

      final client = Supabase.instance.client;
      final cutoff = DateTime.now().subtract(const Duration(days: 30));

      // Supabase `members` is the source of truth. Officers are members too,
      // so Active Members & Impact must read the membership table directly
      // instead of relying on the cached AppState member list or profile role.
      final membershipRows =
          await client.from('members').select('profile_id').eq('org_id', orgId);
      final memberProfileIds = (membershipRows as List)
          .map((row) => row['profile_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      // Keep active-account checking as a secondary guard, but never let a profile
      // lookup failure make a real member disappear from the engagement calculation.
      final activeAccounts = <String>{...memberProfileIds};
      try {
        final profileRows = await client
            .from('profiles')
            .select('id,active,role')
            .inFilter('id', memberProfileIds.toList());
        final returnedIds = <String>{};
        for (final row in profileRows as List) {
          final id = row['id']?.toString() ?? '';
          if (id.isEmpty) continue;
          returnedIds.add(id);
          if (row['active'] != true ||
              !{'student', 'officer'}
                  .contains(row['role']?.toString().toLowerCase())) {
            activeAccounts.remove(id);
          }
        }
        // If Supabase did not return some member profiles (for example because of a
        // temporary policy/cache issue), keep those member IDs rather than clearing
        // the list and incorrectly showing "No members yet".
        if (returnedIds.isEmpty && memberProfileIds.isNotEmpty) {
          activeAccounts
            ..clear()
            ..addAll(memberProfileIds);
        }
      } catch (e) {
        debugPrint(
            'Could not load member profile status; using membership records: $e');
      }

      List<dynamic> chatRows = <dynamic>[];
      try {
        chatRows = await client
            .from('org_chat_messages')
            .select('sender_id,created_at')
            .eq('org_id', orgId)
            .gte('created_at', cutoff.toIso8601String());
      } catch (e) {
        debugPrint('Could not load organization chat engagement: $e');
      }

      _chatMessageCounts.clear();
      for (final row in chatRows) {
        final senderId = row['sender_id']?.toString() ?? '';
        if (senderId.isEmpty || !activeAccounts.contains(senderId)) continue;
        _chatMessageCounts[senderId] = (_chatMessageCounts[senderId] ?? 0) + 1;
      }

      List<Map<String, dynamic>> eventRows = <Map<String, dynamic>>[];
      try {
        eventRows = List<Map<String, dynamic>>.from(
          await client.from('events').select('id').eq('org_id', orgId),
        );
      } catch (e) {
        debugPrint('Could not load organization events for engagement: $e');
      }

      _commentCounts.clear();
      final eventIds = eventRows
          .map((row) => row['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      if (eventIds.isNotEmpty) {
        try {
          final commentRows = await client
              .from('event_comments')
              .select('user_id,created_at')
              .inFilter('event_id', eventIds)
              .gte('created_at', cutoff.toIso8601String());
          for (final row in commentRows as List) {
            final userId = row['user_id']?.toString() ?? '';
            if (userId.isEmpty || !activeAccounts.contains(userId)) continue;
            _commentCounts[userId] = (_commentCounts[userId] ?? 0) + 1;
          }
        } catch (e) {
          debugPrint('Could not load event-comment engagement: $e');
        }
      }

      // Attendance is a separate member-activity signal; it is not part of
      // the student-reported organization-impact score.
      _attendancePresentCounts.clear();
      _attendanceTotalCounts.clear();
      try {
        final attendanceRows = await client
            .from('organization_member_attendance')
            .select('profile_id,status,marked_at')
            .eq('org_id', orgId)
            .gte('marked_at', cutoff.toIso8601String());
        for (final row in attendanceRows as List) {
          final profileId = row['profile_id']?.toString() ?? '';
          if (profileId.isEmpty || !memberProfileIds.contains(profileId)) {
            continue;
          }
          _attendanceTotalCounts[profileId] =
              (_attendanceTotalCounts[profileId] ?? 0) + 1;
          if (row['status']?.toString().toLowerCase() == 'present') {
            _attendancePresentCounts[profileId] =
                (_attendancePresentCounts[profileId] ?? 0) + 1;
          }
        }
      } catch (e) {
        debugPrint('Could not load organization attendance: $e');
      }

      _impactByStudentId.clear();
      try {
        final impactRows = await client
            .from('student_impact')
            .select(
                'student_id,academic_growth,social_growth,leadership_growth,confidence_growth,updated_at')
            .eq('org_id', orgId);
        for (final row in impactRows as List) {
          final studentId = row['student_id']?.toString() ?? '';
          if (studentId.isNotEmpty) {
            _impactByStudentId[studentId] =
                Map<String, dynamic>.from(row as Map);
          }
        }
      } catch (e) {
        debugPrint('Could not load organization impact data: $e');
      }

      // Active means a member participated in the last 30 days through chat,
      // event comments, or recorded attendance. This is distinct from impact.
      _activeProfileIds
        ..clear()
        ..addAll(_chatMessageCounts.keys)
        ..addAll(_commentCounts.keys)
        ..addAll(_attendancePresentCounts.keys
            .where((id) => (_attendancePresentCounts[id] ?? 0) > 0));
    } catch (e) {
      debugPrint('Error loading member engagement data: $e');
    }
    if (mounted) setState(() => _activeStatusLoaded = true);
  }

  double _impactAverage(Map<String, dynamic> impact) {
    final values = <double>[
      _asDouble(impact['academic_growth']),
      _asDouble(impact['social_growth']),
      _asDouble(impact['leadership_growth']),
      _asDouble(impact['confidence_growth']),
    ];
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _asDouble(dynamic value) =>
      double.tryParse(value?.toString() ?? '') ?? 0;

  // Position → accent color
  static Color _posColor(String pos) {
    switch (pos.toLowerCase()) {
      case 'president':
        return const Color(0xFF16A34A);
      case 'vice president':
        return const Color(0xFF0F766E);
      case 'secretary':
      case 'assistant secretary':
        return const Color(0xFF0D9488);
      case 'treasurer':
        return const Color(0xFFB45309);
      case 'officer':
        return const Color(0xFF22C55E);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgId =
        widget.organizationId ?? AppState.instance.currentOfficerOrgId;
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _membersHeader(context),
          Expanded(
            child: Scrollbar(
              controller: _membersScrollController,
              thumbVisibility: true,
              trackVisibility: true,
              child: AnimatedBuilder(
                animation: AppState.instance,
                builder: (ctx, _) {
                  final allOrgMembers = orgId != null
                      ? AppState.instance.members
                          .where((m) => m.orgId == orgId)
                          .toList()
                      : AppState.instance.members.toList();
                  var members = List<Member>.from(allOrgMembers);
                  if (widget.showOnlyActive && _activeStatusLoaded) {
                    members = members
                        .where((m) =>
                            m.profileId != null &&
                            _activeProfileIds.contains(m.profileId))
                        .toList();
                  }
                  if (members.isEmpty && !widget.adviserView) {
                    return ListView(
                      controller: _membersScrollController,
                      physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics()),
                      children: const [
                        SizedBox(height: 180),
                        _Empty(
                            icon: Icons.groups_rounded,
                            label: 'No members yet',
                            sub: 'Add your first member to get started.')
                      ],
                    );
                  }
                  return ListView(
                    controller: _membersScrollController,
                    physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 540),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _Label(widget.showOnlyActive
                                    ? '${members.length} Active Member${members.length == 1 ? '' : 's'}'
                                    : '${members.length} Member${members.length == 1 ? '' : 's'}'),
                                if (widget.showOnlyActive) ...[
                                  const SizedBox(height: 10),
                                  const _EngagementInfoCard(),
                                  const SizedBox(height: 10),
                                ],
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: .72),
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(
                                          color: const Color(0xFFDCEFE2))),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        const Padding(
                                            padding: EdgeInsets.fromLTRB(
                                                4, 2, 4, 10),
                                            child: Row(children: [
                                              Icon(Icons.fact_check_outlined,
                                                  size: 18, color: _p),
                                              SizedBox(width: 8),
                                              Text('Attendance',
                                                  style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color:
                                                          Color(0xFF14532D))),
                                              Spacer(),
                                              Text('Records & reports',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: Color(0xFF718579)))
                                            ])),
                                        _attendanceActionCard(
                                          title: 'View Attendance',
                                          subtitle:
                                              'Review attendance by event, date, and session',
                                          icon: Icons.fact_check_rounded,
                                          primary: false,
                                          onTap: () =>
                                              _viewAttendance(ctx, members),
                                        ),
                                        if (!widget.readOnly &&
                                            _canManageAttendance) ...[
                                          const SizedBox(height: 10),
                                          _attendanceActionCard(
                                            title: 'Record & Send Attendance',
                                            subtitle:
                                                'Take the roll call and send it to your adviser',
                                            icon: Icons.event_available_rounded,
                                            primary: true,
                                            onTap: () =>
                                                _manageAttendance(ctx, members),
                                          ),
                                        ],
                                        if (!widget.readOnly &&
                                            _canManageMinutes) ...[
                                          const SizedBox(height: 10),
                                          _attendanceActionCard(
                                            title: 'Meeting Minutes',
                                            subtitle:
                                                'Write what was discussed and send it to your adviser',
                                            icon: Icons.notes_rounded,
                                            primary: false,
                                            onTap: () => _openMeetingMinutes(
                                                ctx, orgId ?? ''),
                                          ),
                                          const SizedBox(height: 10),
                                          _attendanceActionCard(
                                            title: 'View Meeting Minutes',
                                            subtitle:
                                                'Review minutes previously created by your secretary team',
                                            icon: Icons.library_books_rounded,
                                            primary: false,
                                            onTap: () => _viewMeetingMinutes(
                                                ctx, orgId ?? ''),
                                          ),
                                        ],
                                        if (!widget.readOnly &&
                                            _canManageFinance) ...[
                                          const SizedBox(height: 10),
                                          _attendanceActionCard(
                                            title: 'Treasurer Financial Report',
                                            subtitle:
                                                'Record event income and expenses for your adviser',
                                            icon: Icons
                                                .account_balance_wallet_rounded,
                                            primary: true,
                                            onTap: () => _openTreasurerFinance(
                                                ctx, orgId ?? ''),
                                          ),
                                        ] else if (!widget.readOnly &&
                                            _canViewFinance) ...[
                                          const SizedBox(height: 10),
                                          _attendanceActionCard(
                                            title: 'View Financial Report',
                                            subtitle:
                                                'Review the organization budget, income, expenses, and balance',
                                            icon: Icons
                                                .account_balance_wallet_rounded,
                                            primary: false,
                                            onTap: () => _viewFinanceReport(
                                                ctx, orgId ?? ''),
                                          ),
                                        ],
                                      ]),
                                ),
                                const SizedBox(height: 18),
                                if (members.isNotEmpty)
                                  Row(children: [
                                    const Expanded(
                                        child: Text('Organization members',
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF14532D)))),
                                    Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                            color: const Color(0xFFDCFCE7),
                                            borderRadius:
                                                BorderRadius.circular(20)),
                                        child: Text('${members.length}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF166534))))
                                  ]),
                                if (members.isNotEmpty)
                                  const SizedBox(height: 10),
                                ...members.asMap().entries.map((e) =>
                                    _MemberCard(
                                      member: e.value,
                                      readOnly:
                                          widget.readOnly || !_canManageMembers,
                                      index: e.key,
                                      accentColor: _posColor(e.value.position),
                                      chatCount: _chatMessageCounts[
                                              e.value.profileId] ??
                                          0,
                                      commentCount:
                                          _commentCounts[e.value.profileId] ??
                                              0,
                                      attendancePresent:
                                          _attendancePresentCounts[
                                                  e.value.profileId] ??
                                              0,
                                      attendanceTotal: _attendanceTotalCounts[
                                              e.value.profileId] ??
                                          0,
                                      onEdit: widget.readOnly ||
                                              !_canManageMembers
                                          ? () {}
                                          : () =>
                                              _dialog(ctx, existing: e.value),
                                      onDelete:
                                          widget.readOnly || !_canManageMembers
                                              ? () {}
                                              : () {
                                                  AppState.instance
                                                      .removeMember(e.value.id);
                                                  _snack(
                                                      'Removed ${e.value.name}',
                                                      Colors.redAccent);
                                                },
                                    )),
                                const SizedBox(height: 18),
                                if (widget.adviserView) ...[
                                  _ImpactSection(
                                      members: allOrgMembers,
                                      impactByStudentId: _impactByStudentId,
                                      averageFor: _impactAverage,
                                      adviserView: true),
                                  const SizedBox(height: 14),
                                  _MemberActivitySection(
                                      members: allOrgMembers,
                                      activeProfileIds: _activeProfileIds,
                                      chatMessageCounts: _chatMessageCounts,
                                      commentCounts: _commentCounts,
                                      attendancePresent:
                                          _attendancePresentCounts,
                                      attendanceTotal: _attendanceTotalCounts),
                                ],
                              ]),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton:
          widget.readOnly || !_managerRoleLoaded || !_canManageMembers
              ? null
              : _GradFab(
                  icon: Icons.person_add_rounded,
                  label: 'Add Member',
                  onTap: () => _dialog(context)),
    );
  }

  Widget _orb(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: opacity),
          shape: BoxShape.circle,
        ),
      );

  Widget _membersHeader(BuildContext context) {
    return AppHeader(
      title: widget.title,
      subtitle: 'Members and impact',
      status: widget.showOnlyActive ? 'ACTIVE MEMBERS' : 'ORGANIZATION MEMBERS',
      icon: Icons.groups_rounded,
      onBack: () => Navigator.pop(context),
    );
  }

  Widget _attendanceFullHeader(
          BuildContext context, String title, IconData icon) =>
      SizedBox(
        height: 160,
        width: double.infinity,
        child: Container(
          decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFF16A34A), Color(0xFF0F766E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight)),
          child: SafeArea(
              child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
            child: Row(children: [
              IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20)),
              const SizedBox(width: 8),
              Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .18),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: .30),
                          width: 1.5)),
                  child: Icon(icon, color: Colors.white, size: 26)),
              const SizedBox(width: 14),
              Expanded(
                  child: Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900))),
            ]),
          )),
        ),
      );

  String _attendanceDateLabel(dynamic raw) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) return 'Date not set';
    final parsed = DateTime.tryParse(value)?.toLocal();
    if (parsed == null) return value;
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
    return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
  }

  String _attendanceTimeLabel(dynamic raw) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) return 'Time not specified';
    final parsed = DateTime.tryParse(value)?.toLocal();
    if (parsed == null) return value;
    // Date-only event values should not be displayed as midnight.
    if (parsed.hour == 0 && parsed.minute == 0) return 'Time not specified';
    final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${parsed.hour >= 12 ? 'PM' : 'AM'}';
  }

  Widget _attendanceSessionPicker(
      {required String session, required ValueChanged<String> onChanged}) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: const Color(0xFFEAF7EF),
          borderRadius: BorderRadius.circular(15)),
      child: Row(children: [
        for (final option in const [
          ('morning', 'Morning', Icons.wb_twilight_rounded),
          ('afternoon', 'Afternoon', Icons.wb_sunny_rounded)
        ])
          Expanded(
              child: Padding(
            padding: const EdgeInsets.all(2),
            child: Material(
              color: session == option.$1 ? _p : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onChanged(option.$1),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(option.$3,
                            size: 17,
                            color: session == option.$1 ? Colors.white : _p),
                        const SizedBox(width: 6),
                        Flexible(
                            child: Text(option.$2,
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: session == option.$1
                                        ? Colors.white
                                        : _p))),
                      ]),
                ),
              ),
            ),
          )),
      ]),
    );
  }

  Future<List<Map<String, dynamic>>> _loadAttendanceActivities(
      String orgId) async {
    final db = Supabase.instance.client;
    final eventRows = List<Map<String, dynamic>>.from(
      await db
          .from('events')
          .select('id,title,date')
          .eq('org_id', orgId)
          .order('date', ascending: false)
          .limit(100),
    );
    final customRows = List<Map<String, dynamic>>.from(
      await db
          .from('organization_attendance_sessions')
          .select('id,title,activity_type,session_date,session_time')
          .eq('org_id', orgId)
          .order('session_date', ascending: false)
          .limit(100),
    );
    final activities = <Map<String, dynamic>>[...eventRows];
    for (final row in customRows) {
      final date = row['session_date']?.toString() ?? '';
      final time = row['session_time']?.toString();
      final dateTime = time == null || time.isEmpty
          ? date
          : '${date}T${time.length >= 8 ? time.substring(0, 8) : time}';
      activities.add({
        'id': row['id']?.toString(),
        'title': row['title']?.toString() ?? 'Untitled activity',
        'date': dateTime,
        'activity_type': row['activity_type']?.toString() ?? 'event',
      });
    }
    activities.sort((a, b) =>
        (b['date']?.toString() ?? '').compareTo(a['date']?.toString() ?? ''));
    return activities;
  }

  Future<Map<String, dynamic>?> _pickOrCreateAttendanceActivity(
      BuildContext context, String orgId) async {
    final existing = await _loadAttendanceActivities(orgId);
    if (!context.mounted) return null;
    if (existing.isEmpty) return _createAttendanceActivity(context, orgId);
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (pickerContext) => AlertDialog(
        backgroundColor: const Color(0xFFF7FFF9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Record attendance',
            style: TextStyle(
                fontWeight: FontWeight.w900, color: Color(0xFF14532D))),
        content: SizedBox(
          width: 520,
          child: ListView(shrinkWrap: true, children: [
            const Text(
                'Continue an existing event to record another session, or create a new attendance record.',
                style: TextStyle(height: 1.4, color: Color(0xFF64786D))),
            const SizedBox(height: 12),
            for (final item in existing.take(12))
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFFD5F0DE))),
                child: ListTile(
                  leading: CircleAvatar(
                      backgroundColor: const Color(0xFFEAF7EF),
                      child: Icon(
                          item['activity_type']?.toString() == 'meeting'
                              ? Icons.groups_rounded
                              : Icons.event_rounded,
                          color: _p)),
                  title: Text(item['title']?.toString() ?? 'Untitled activity',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                      '${(item['activity_type']?.toString() ?? 'event').toUpperCase()}  •  ${_attendanceDateLabel(item['date'])}'),
                  trailing: const Icon(Icons.chevron_right_rounded, color: _p),
                  onTap: () => Navigator.pop(pickerContext, item),
                ),
              ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(pickerContext),
              child: const Text('Cancel')),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: _p, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(
                  pickerContext, <String, dynamic>{'_create_new': true});
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create new'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _createAttendanceActivity(
      BuildContext context, String orgId) async {
    final titleController = TextEditingController();
    String type = 'event';
    DateTime date = DateTime.now();
    TimeOfDay? time;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      useSafeArea: false,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Scaffold(
          backgroundColor: const Color(0xFFF0FDF4),
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(160),
            child: _attendanceFullHeader(dialogContext, 'Record Attendance',
                Icons.event_available_rounded),
          ),
          body: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
                  children: [
                    Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [Color(0xFFE1F7E8), Color(0xFFE5F5F4)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: const Color(0xFFD1EBDD))),
                        child: const Row(children: [
                          CircleAvatar(
                              radius: 25,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.fact_check_rounded,
                                  color: _p, size: 27)),
                          SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text('Create attendance record',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF14532D))),
                                SizedBox(height: 4),
                                Text('Set up your activity details below',
                                    style: TextStyle(
                                        fontSize: 12, color: Color(0xFF64786D)))
                              ]))
                        ])),
                    const SizedBox(height: 10),
                    const Text(
                        'Enter the event or meeting details first, then mark each organization member present or absent.',
                        style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: Color(0xFF64786D))),
                    const SizedBox(height: 18),
                    TextField(
                      controller: titleController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Event or meeting name',
                        hintText: 'e.g. Monthly Organization Meeting',
                        prefixIcon:
                            const Icon(Icons.edit_calendar_rounded, color: _p),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration: InputDecoration(
                          labelText: 'Activity type',
                          prefixIcon:
                              const Icon(Icons.category_outlined, color: _p),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16))),
                      items: const [
                        DropdownMenuItem(value: 'event', child: Text('Event')),
                        DropdownMenuItem(
                            value: 'meeting', child: Text('Meeting'))
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => type = v);
                      },
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 16),
                          alignment: Alignment.centerLeft,
                          backgroundColor: Colors.white,
                          foregroundColor: _p),
                      onPressed: () async {
                        final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate: date,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100));
                        if (picked != null && dialogContext.mounted) {
                          setDialogState(() => date = picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: Text(
                          'Date: ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 16),
                          alignment: Alignment.centerLeft,
                          backgroundColor: Colors.white,
                          foregroundColor: _p),
                      onPressed: () async {
                        final initial = time ?? TimeOfDay.now();
                        int hour = initial.hourOfPeriod == 0
                            ? 12
                            : initial.hourOfPeriod;
                        int minute = initial.minute;
                        String period =
                            initial.period == DayPeriod.am ? 'AM' : 'PM';
                        final picked = await showModalBottomSheet<TimeOfDay>(
                          context: dialogContext,
                          backgroundColor: const Color(0xFFF7FFF9),
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(24))),
                          builder: (sheetContext) => StatefulBuilder(
                              builder: (sheetContext, setTimeState) => SafeArea(
                                    child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            18, 20, 18, 20),
                                        child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              const Text('Select time',
                                                  style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color:
                                                          Color(0xFF173B2B))),
                                              const SizedBox(height: 16),
                                              Row(children: [
                                                Expanded(
                                                    child: DropdownButtonFormField<
                                                            int>(
                                                        initialValue: hour,
                                                        decoration:
                                                            const InputDecoration(
                                                                labelText:
                                                                    'Hour',
                                                                border:
                                                                    OutlineInputBorder()),
                                                        items: List.generate(
                                                          12,
                                                          (i) => DropdownMenuItem(
                                                              value: i + 1,
                                                              child: Text((i +
                                                                      1)
                                                                  .toString()
                                                                  .padLeft(
                                                                      2, '0'))),
                                                        ),
                                                        onChanged: (v) {
                                                          if (v != null) {
                                                            setTimeState(
                                                                () => hour = v);
                                                          }
                                                        })),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                    child: DropdownButtonFormField<
                                                            int>(
                                                        initialValue: minute,
                                                        decoration:
                                                            const InputDecoration(
                                                                labelText:
                                                                    'Minute',
                                                                border:
                                                                    OutlineInputBorder()),
                                                        items: List.generate(
                                                          60,
                                                          (i) => DropdownMenuItem(
                                                              value: i,
                                                              child: Text(i
                                                                  .toString()
                                                                  .padLeft(
                                                                      2, '0'))),
                                                        ),
                                                        onChanged: (v) {
                                                          if (v != null) {
                                                            setTimeState(() =>
                                                                minute = v);
                                                          }
                                                        })),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                    child: DropdownButtonFormField<
                                                            String>(
                                                        initialValue: period,
                                                        decoration:
                                                            const InputDecoration(
                                                                labelText:
                                                                    'AM/PM',
                                                                border:
                                                                    OutlineInputBorder()),
                                                        items: const [
                                                          DropdownMenuItem(
                                                              value: 'AM',
                                                              child:
                                                                  Text('AM')),
                                                          DropdownMenuItem(
                                                              value: 'PM',
                                                              child: Text('PM'))
                                                        ],
                                                        onChanged: (v) {
                                                          if (v != null) {
                                                            setTimeState(() =>
                                                                period = v);
                                                          }
                                                        })),
                                              ]),
                                              const SizedBox(height: 16),
                                              FilledButton(
                                                  style: FilledButton.styleFrom(
                                                      backgroundColor: _p,
                                                      foregroundColor:
                                                          Colors.white,
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 13)),
                                                  onPressed: () {
                                                    var h = hour % 12;
                                                    if (period == 'PM') h += 12;
                                                    Navigator.pop(
                                                        sheetContext,
                                                        TimeOfDay(
                                                            hour: h,
                                                            minute: minute));
                                                  },
                                                  child: const Text(
                                                      'Confirm time')),
                                            ])),
                                  )),
                        );
                        if (picked != null && dialogContext.mounted) {
                          setDialogState(() => time = picked);
                        }
                      },
                      icon: const Icon(Icons.schedule_rounded),
                      label: Text(time == null
                          ? 'Select time'
                          : 'Time: ${time!.format(dialogContext)}'),
                    ),
                    const SizedBox(height: 16),
                    Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: const Color(0xFFEAF7EF),
                            borderRadius: BorderRadius.circular(14)),
                        child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  color: _p, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                  child: Text(
                                      'Morning and afternoon attendance are saved separately. This record is saved to your organization in Supabase.',
                                      style: TextStyle(
                                          fontSize: 12,
                                          height: 1.35,
                                          color: Color(0xFF496657))))
                            ])),
                  ],
                ),
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                  child: Row(children: [
                    Expanded(
                        child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15)),
                            child: const Text('Cancel'))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: _p,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15)),
                      icon: const Icon(Icons.arrow_forward_rounded),
                      onPressed: () async {
                        final title = titleController.text.trim();
                        if (title.isEmpty) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Enter an event or meeting name first.')));
                          return;
                        }
                        try {
                          final db = Supabase.instance.client;
                          final currentUser = db.auth.currentUser?.id;
                          if (currentUser == null) {
                            throw Exception(
                                'You are not signed in to Supabase. Please sign in again.');
                          }
                          final row = await db
                              .from('organization_attendance_sessions')
                              .insert({
                                'org_id': orgId,
                                'title': title,
                                'activity_type': type,
                                'session_date':
                                    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                                'session_time': time == null
                                    ? null
                                    : '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}:00',
                                'created_by': currentUser,
                              })
                              .select(
                                  'id,title,activity_type,session_date,session_time')
                              .single();
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext, {
                            'id': row['id'].toString(),
                            'title': row['title'],
                            'activity_type': row['activity_type'],
                            'date': time == null
                                ? row['session_date'].toString()
                                : '${row['session_date']}T${row['session_time']}'
                          });
                        } catch (e) {
                          if (!dialogContext.mounted) return;
                          ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(
                              content: Text(
                                  'Could not save attendance activity to Supabase: $e')));
                        }
                      },
                      label: const Text('Continue to Member Roll Call'),
                    )),
                  ]))),
        ),
      ),
    );
    titleController.dispose();
    return result;
  }

  Future<void> _openMeetingMinutes(BuildContext context, String orgId) async {
    if (orgId.isEmpty) return;
    final titleCtrl = TextEditingController();
    final minutesCtrl = TextEditingController();
    DateTime meetingDate = DateTime.now();
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
                title: const Text('Meeting Minutes'),
                content: SizedBox(
                    width: 420,
                    child: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: titleCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Meeting title')),
                      const SizedBox(height: 10),
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.calendar_month_rounded),
                          title: const Text('Meeting date'),
                          subtitle: Text(
                              '${meetingDate.year}-${meetingDate.month.toString().padLeft(2, '0')}-${meetingDate.day.toString().padLeft(2, '0')}'),
                          onTap: () async {
                            final d = await showDatePicker(
                                context: ctx,
                                initialDate: meetingDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100));
                            if (d != null) {
                              setDialogState(() => meetingDate = d);
                            }
                          }),
                      const SizedBox(height: 8),
                      TextField(
                          controller: minutesCtrl,
                          minLines: 5,
                          maxLines: 9,
                          decoration: const InputDecoration(
                              alignLabelWithHint: true,
                              labelText: 'Discussion / minutes',
                              hintText:
                                  'Write the topics discussed, decisions made, and action items...',
                              border: OutlineInputBorder())),
                      const SizedBox(height: 8),
                      const Text(
                          'Submitting saves the minutes in Supabase for the adviser to review.',
                          style:
                              TextStyle(fontSize: 12, color: Colors.black54)),
                    ]))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Send to Adviser'))
                ],
              )),
    );
    if (save != true) {
      titleCtrl.dispose();
      minutesCtrl.dispose();
      return;
    }
    if (titleCtrl.text.trim().isEmpty || minutesCtrl.text.trim().isEmpty) {
      _snack('Enter a meeting title and the meeting minutes.', Colors.orange);
      titleCtrl.dispose();
      minutesCtrl.dispose();
      return;
    }
    try {
      await Supabase.instance.client
          .from('organization_meeting_minutes')
          .insert({
        'org_id': orgId,
        'title': titleCtrl.text.trim(),
        'meeting_date':
            '${meetingDate.year}-${meetingDate.month.toString().padLeft(2, '0')}-${meetingDate.day.toString().padLeft(2, '0')}',
        'minutes': minutesCtrl.text.trim(),
        'submitted_by': Supabase.instance.client.auth.currentUser?.id,
      });
      _snack('Meeting minutes sent to adviser.', _ok);
    } catch (e) {
      _snack('Could not submit meeting minutes: $e', Colors.red);
    } finally {
      titleCtrl.dispose();
      minutesCtrl.dispose();
    }
  }

  Future<void> _viewMeetingMinutes(BuildContext context, String orgId) async {
    if (orgId.isEmpty) return;
    try {
      final rows = await Supabase.instance.client
          .from('organization_meeting_minutes')
          .select('title,meeting_date,minutes,submitted_at')
          .eq('org_id', orgId)
          .order('meeting_date', ascending: false);
      if (!context.mounted) return;
      final records = List<Map<String, dynamic>>.from(rows as List);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Row(children: [
            Icon(Icons.library_books_rounded, color: _p),
            SizedBox(width: 8),
            Expanded(child: Text('Meeting Minutes'))
          ]),
          content: SizedBox(
              width: 480,
              child: records.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No meeting minutes have been saved yet.'))
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: records.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final item = records[i];
                        return Container(
                            decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(16),
                                border:
                                    Border.all(color: const Color(0xFFD1FAE5))),
                            child: ExpansionTile(
                                leading: const CircleAvatar(
                                    backgroundColor: Color(0xFFDCFCE7),
                                    child: Icon(Icons.description_rounded,
                                        color: Color(0xFF128058))),
                                title: Text(
                                    item['title']?.toString() ?? 'Meeting',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800)),
                                subtitle: Text(
                                    item['meeting_date']?.toString() ?? ''),
                                children: [
                                  Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 0, 16, 16),
                                      child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: SelectableText(
                                              item['minutes']?.toString() ?? '',
                                              style: const TextStyle(
                                                  height: 1.5))))
                                ]));
                      })),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'))
          ],
        ),
      );
    } catch (e) {
      _snack('Could not load meeting minutes: $e', Colors.red);
    }
  }

  bool _showAllFinanceTransactions = false;

  Future<void> _viewFinanceReport(BuildContext context, String orgId) async {
    if (orgId.isEmpty) return;
    try {
      final db = Supabase.instance.client;
      final results = await Future.wait<dynamic>([
        db
            .from('organizations')
            .select('name,allocated_budget')
            .eq('id', orgId)
            .maybeSingle(),
        db
            .from('org_financial_transactions')
            .select('*')
            .eq('org_id', orgId)
            .order('transaction_date', ascending: false),
      ]);
      final org = results[0] as Map<String, dynamic>?;
      final rows = List<Map<String, dynamic>>.from(results[1] as List);
      double total(String type) =>
          rows.where((r) => r['type']?.toString().toLowerCase() == type).fold(
              0.0, (sum, r) => sum + ((r['amount'] as num?)?.toDouble() ?? 0));
      String money(double n) => '₱${n.toStringAsFixed(2)}';
      final allocated = (org?['allocated_budget'] as num?)?.toDouble() ?? 0;
      final income = total('income');
      final expenses = total('expense');
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => Dialog(
          insetPadding: const EdgeInsets.all(12),
          clipBehavior: Clip.antiAlias,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 900,
              maxHeight: MediaQuery.of(dialogContext).size.height * 0.92,
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  height: 142,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF16A34A), Color(0xFF0F766E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Close financial report',
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                                color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .18),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: .30),
                                  width: 1.5),
                            ),
                            child: const Icon(
                                Icons.account_balance_wallet_rounded,
                                color: Colors.white,
                                size: 26),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Treasurer Financial Report',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900)),
                                const SizedBox(height: 4),
                                Text(
                                    org?['name']?.toString() ??
                                        'Organization finances',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 560
                              ? 4
                              : (constraints.maxWidth >= 360 ? 2 : 1);
                          final gap = 10.0;
                          final cardWidth =
                              (constraints.maxWidth - gap * (columns - 1)) /
                                  columns;
                          Widget metric(String label, String value,
                                  IconData icon, Color color) =>
                              Container(
                                width: cardWidth,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                    color: color.withValues(alpha: .08),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: color.withValues(alpha: .22))),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(icon, color: color, size: 21),
                                      const SizedBox(height: 10),
                                      Text(label,
                                          style: const TextStyle(
                                              color: Color(0xFF48665A),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 4),
                                      Text(value,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              color: color,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900)),
                                    ]),
                              );
                          return Wrap(spacing: gap, runSpacing: gap, children: [
                            metric('Allocated budget', money(allocated),
                                Icons.savings_rounded, const Color(0xFF0F766E)),
                            metric(
                                'Total income',
                                money(income),
                                Icons.trending_up_rounded,
                                const Color(0xFF15803D)),
                            metric(
                                'Total expenses',
                                money(expenses),
                                Icons.trending_down_rounded,
                                const Color(0xFFB45309)),
                            metric(
                                'Available balance',
                                money(allocated + income - expenses),
                                Icons.account_balance_wallet_rounded,
                                const Color(0xFF166534)),
                          ]);
                        }),
                        const SizedBox(height: 22),
                        Row(children: [
                          const Expanded(
                              child: Text('Transaction details',
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF14532D)))),
                          Text(
                              '${rows.length} record${rows.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w700)),
                        ]),
                        const SizedBox(height: 10),
                        if (rows.isEmpty)
                          Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: const Color(0xFFD1FAE5))),
                              child: const Column(children: [
                                Icon(Icons.receipt_long_rounded,
                                    size: 34, color: Color(0xFF16A34A)),
                                SizedBox(height: 8),
                                Text('No financial transactions recorded yet.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Color(0xFF48665A),
                                        fontWeight: FontWeight.w600))
                              ]))
                        else
                          ...(_showAllFinanceTransactions
                                  ? rows
                                  : rows.take(5).toList())
                              .map((r) {
                            final rawKind = (r['type'] ?? 'transaction')
                                .toString()
                                .toLowerCase();
                            final isReimb = rawKind == 'expense' &&
                                (r['category']?.toString().toLowerCase() ==
                                        'reimbursement' ||
                                    r['description']
                                            ?.toString()
                                            .toLowerCase()
                                            .startsWith('reimbursement') ==
                                        true);
                            final kind = isReimb ? 'reimbursement' : rawKind;
                            final color = kind == 'income'
                                ? const Color(0xFF15803D)
                                : (kind == 'reimbursement'
                                    ? const Color(0xFF7C3AED)
                                    : const Color(0xFFB45309));
                            final eventName =
                                r['event_name']?.toString().trim() ?? '';
                            final description =
                                r['description']?.toString().trim() ?? '';
                            final heading = eventName.isNotEmpty
                                ? eventName
                                : (description.isNotEmpty
                                    ? description
                                    : 'Transaction');
                            return Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFFAFFFB),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: const Color(0xFFDCEFE2))),
                              child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                            color: color.withValues(alpha: .10),
                                            borderRadius:
                                                BorderRadius.circular(13)),
                                        child: Icon(Icons.receipt_long_rounded,
                                            color: color)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Text(heading,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF173D2D),
                                                  fontSize: 14)),
                                          const SizedBox(height: 5),
                                          Wrap(
                                              spacing: 7,
                                              runSpacing: 5,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              children: [
                                                Text(
                                                    r['transaction_date']
                                                            ?.toString() ??
                                                        'Date not set',
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        color:
                                                            Color(0xFF64748B))),
                                                Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 3),
                                                    decoration: BoxDecoration(
                                                        color: color.withValues(
                                                            alpha: .10),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20)),
                                                    child: Text(
                                                        kind.toUpperCase(),
                                                        style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w900,
                                                            color: color))),
                                              ]),
                                          if (description.isNotEmpty &&
                                              description != heading) ...[
                                            const SizedBox(height: 6),
                                            Text(description,
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    height: 1.35,
                                                    color: Color(0xFF48665A))),
                                          ],
                                          if (r['category']
                                                  ?.toString()
                                                  .trim()
                                                  .isNotEmpty ==
                                              true) ...[
                                            const SizedBox(height: 4),
                                            Text('Category: ${r['category']}',
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Color(0xFF64748B))),
                                          ],
                                        ])),
                                    const SizedBox(width: 10),
                                    Flexible(
                                        child: Text(
                                            money((r['amount'] as num?)
                                                    ?.toDouble() ??
                                                0),
                                            textAlign: TextAlign.end,
                                            style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                color: color,
                                                fontSize: 14))),
                                  ]),
                            );
                          }),
                        if (rows.length > 5)
                          Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () {
                                  setState(() => _showAllFinanceTransactions =
                                      !_showAllFinanceTransactions);
                                  Navigator.pop(dialogContext);
                                  _viewFinanceReport(context, orgId);
                                },
                                icon: Icon(_showAllFinanceTransactions
                                    ? Icons.expand_less_rounded
                                    : Icons.expand_more_rounded),
                                label: Text(_showAllFinanceTransactions
                                    ? 'View latest 5'
                                    : 'View all ${rows.length} records'),
                              )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      _snack('Could not load financial report: $e', Colors.red);
    }
  }

  Future<void> _openTreasurerFinance(BuildContext context, String orgId) async {
    if (orgId.isEmpty) return;
    final amountCtrl = TextEditingController();
    final eventCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();
    String type = 'expense';
    DateTime date = DateTime.now();
    final save = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (ctx, setDialogState) => AlertDialog(
                  titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  title: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 15),
                      decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFF128058), Color(0xFF16A34A)]),
                          borderRadius: BorderRadius.circular(16)),
                      child: const Row(children: [
                        Icon(Icons.account_balance_wallet_rounded,
                            color: Colors.white),
                        SizedBox(width: 10),
                        Expanded(
                            child: Text('Treasurer Financial Report',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17)))
                      ])),
                  content: SizedBox(
                      width: 420,
                      child: SingleChildScrollView(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        DropdownButtonFormField<String>(
                            initialValue: type,
                            decoration: const InputDecoration(
                                labelText: 'Transaction type'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'expense',
                                  child: Text(
                                      'Expense / Paid from organization funds')),
                              DropdownMenuItem(
                                  value: 'income',
                                  child: Text('Income / Money received')),
                              DropdownMenuItem(
                                  value: 'reimbursement',
                                  child: Text(
                                      'Reimbursement (paid with personal money)'))
                            ],
                            onChanged: (v) {
                              if (v != null) setDialogState(() => type = v);
                            }),
                        TextField(
                            controller: eventCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Event name')),
                        TextField(
                            controller: amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration:
                                const InputDecoration(labelText: 'Amount (₱)')),
                        TextField(
                            controller: categoryCtrl,
                            decoration: InputDecoration(
                                labelText: type == 'reimbursement'
                                    ? 'Expense category (e.g. supplies, transport)'
                                    : 'Category (e.g. supplies, tickets)')),
                        if (type == 'reimbursement')
                          const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                  'Use this when a member paid an event expense using personal money. Submitting records it for the adviser to review.',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.black54))),
                        TextField(
                            controller: descCtrl,
                            maxLines: 2,
                            decoration: const InputDecoration(
                                labelText: 'Details / receipt notes')),
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.calendar_month_rounded),
                            title: const Text('Transaction date'),
                            subtitle: Text(
                                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'),
                            onTap: () async {
                              final d = await showDatePicker(
                                  context: ctx,
                                  initialDate: date,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100));
                              if (d != null) setDialogState(() => date = d);
                            }),
                        const Text(
                            'The adviser and admin can review these transactions in the organization financial report.',
                            style:
                                TextStyle(fontSize: 12, color: Colors.black54)),
                      ]))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Submit report'))
                  ],
                )));
    if (save != true) {
      amountCtrl.dispose();
      eventCtrl.dispose();
      descCtrl.dispose();
      categoryCtrl.dispose();
      return;
    }
    final amount = double.tryParse(amountCtrl.text.trim().replaceAll(',', ''));
    if (amount == null || amount <= 0 || eventCtrl.text.trim().isEmpty) {
      _snack('Enter a valid amount and event name.', Colors.orange);
      amountCtrl.dispose();
      eventCtrl.dispose();
      descCtrl.dispose();
      categoryCtrl.dispose();
      return;
    }
    try {
      final isReimbursement = type == 'reimbursement';
      final userCategory = categoryCtrl.text.trim();
      final userDetails = descCtrl.text.trim();
      final reimbursementText =
          [userCategory, userDetails].where((s) => s.isNotEmpty).join(' - ');
      await Supabase.instance.client.from('org_financial_transactions').insert({
        'org_id': orgId,
        'type': isReimbursement ? 'expense' : type,
        'amount': amount,
        'category': isReimbursement ? 'reimbursement' : userCategory,
        'description': isReimbursement
            ? 'Reimbursement: ${reimbursementText.isNotEmpty ? reimbursementText : eventCtrl.text.trim()}'
            : userDetails,
        'event_name': eventCtrl.text.trim(),
        'transaction_date':
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'created_by': Supabase.instance.client.auth.currentUser?.id,
      });
      _snack(
          type == 'reimbursement'
              ? 'Reimbursement submitted for adviser review.'
              : 'Financial transaction submitted.',
          _ok);
    } catch (e) {
      _snack('Could not submit financial transaction: $e', Colors.red);
    } finally {
      amountCtrl.dispose();
      eventCtrl.dispose();
      descCtrl.dispose();
      categoryCtrl.dispose();
    }
  }

  Future<void> _viewAttendance(
      BuildContext context, List<Member> members) async {
    final orgId =
        widget.organizationId ?? AppState.instance.currentOfficerOrgId;
    if (orgId == null || orgId.isEmpty) return;
    try {
      final db = Supabase.instance.client;
      final events = await _loadAttendanceActivities(orgId);
      if (!context.mounted) return;
      if (events.isEmpty) {
        _snack(
            'There are no attendance records yet. The Secretary can create an event or meeting from Record Attendance.',
            Colors.orange);
        return;
      }
      // Start on the activity/session that was most recently recorded, rather than
      // blindly showing the activity with the newest scheduled date (which may be empty).
      final latestAttendance = List<Map<String, dynamic>>.from(
        await db
            .from('organization_member_attendance')
            .select('event_id,session,marked_at')
            .eq('org_id', orgId)
            .order('marked_at', ascending: false)
            .limit(1),
      );
      final latestEventId = latestAttendance.isEmpty
          ? null
          : latestAttendance.first['event_id']?.toString();
      final selectedActivity =
          events.where((e) => e['id']?.toString() == latestEventId).toList();
      String selectedEvent = selectedActivity.isNotEmpty
          ? selectedActivity.first['id'].toString()
          : (events.first['id']?.toString() ?? '');
      final selectedRow =
          latestAttendance.isNotEmpty && latestEventId == selectedEvent
              ? latestAttendance.first
              : null;
      bool isMeeting = events
              .firstWhere((e) => e['id']?.toString() == selectedEvent,
                  orElse: () => events.first)['activity_type']
              ?.toString()
              .toLowerCase() ==
          'meeting';
      // The database only permits 'morning' or 'afternoon' in the session column.
      // Meetings use the single stored 'morning' slot internally; the UI hides the session picker.
      String session = isMeeting
          ? 'morning'
          : ((selectedRow?['session']?.toString() == 'afternoon')
              ? 'afternoon'
              : 'morning');
      List<Map<String, dynamic>> records = List<Map<String, dynamic>>.from(
          await db
              .from('organization_member_attendance')
              .select('profile_id,status,marked_at,session')
              .eq('org_id', orgId)
              .eq('event_id', selectedEvent)
              .eq('session', session));
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        useSafeArea: false,
        barrierDismissible: false,
        builder: (dialogContext) =>
            StatefulBuilder(builder: (dialogContext, setDialogState) {
          final byProfile = <String, Map<String, dynamic>>{
            for (final row in records)
              if (row['profile_id'] != null) row['profile_id'].toString(): row
          };
          final presentCount = records
              .where((r) => r['status']?.toString().toLowerCase() == 'present')
              .length;
          final absentCount = records
              .where((r) => r['status']?.toString().toLowerCase() == 'absent')
              .length;
          final event = events.firstWhere(
              (e) => e['id']?.toString() == selectedEvent,
              orElse: () => events.first);
          return Scaffold(
            backgroundColor: const Color(0xFFF0FDF4),
            appBar: PreferredSize(
                preferredSize: const Size.fromHeight(160),
                child: _attendanceFullHeader(dialogContext, 'View Attendance',
                    Icons.fact_check_rounded)),
            body: SizedBox(
                width: double.infinity,
                height: MediaQuery.of(dialogContext).size.height - 180,
                child: Scrollbar(
                    thumbVisibility: true,
                    interactive: true,
                    child: SingleChildScrollView(
                        primary: true,
                        child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(children: [
                                    const Expanded(
                                        child: Text('LATEST ACTIVITY',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 1.0,
                                                color: _p))),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.history_rounded,
                                          size: 17),
                                      label:
                                          Text('View All (${events.length})'),
                                      onPressed: () async {
                                        final chosen = await showDialog<
                                            Map<String, dynamic>>(
                                          context: dialogContext,
                                          builder: (pickerContext) =>
                                              AlertDialog(
                                            title: const Text(
                                                'All Attendance Activities'),
                                            content: SizedBox(
                                              width: 420,
                                              height:
                                                  MediaQuery.of(pickerContext)
                                                          .size
                                                          .height *
                                                      .55,
                                              child: ListView.separated(
                                                itemCount: events.length,
                                                separatorBuilder: (_, __) =>
                                                    const Divider(height: 1),
                                                itemBuilder:
                                                    (pickerContext, index) {
                                                  final item = events[index];
                                                  final itemId =
                                                      item['id']?.toString() ??
                                                          '';
                                                  return ListTile(
                                                    leading: Icon(
                                                      item['activity_type']
                                                                  ?.toString()
                                                                  .toLowerCase() ==
                                                              'meeting'
                                                          ? Icons.groups_rounded
                                                          : Icons.event_rounded,
                                                      color: _p,
                                                    ),
                                                    title: Text(
                                                        item['title']
                                                                ?.toString() ??
                                                            'Activity',
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis),
                                                    subtitle: Text(
                                                        '${_attendanceDateLabel(item['date'])} • ${(item['activity_type']?.toString() ?? 'event').toUpperCase()}'),
                                                    trailing: itemId ==
                                                            selectedEvent
                                                        ? const Icon(
                                                            Icons
                                                                .check_circle_rounded,
                                                            color: _p)
                                                        : const Icon(Icons
                                                            .chevron_right_rounded),
                                                    onTap: () => Navigator.pop(
                                                        pickerContext, item),
                                                  );
                                                },
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          pickerContext),
                                                  child: const Text('Cancel'))
                                            ],
                                          ),
                                        );
                                        if (chosen == null ||
                                            !dialogContext.mounted) {
                                          return;
                                        }
                                        final nextId =
                                            chosen['id']?.toString() ?? '';
                                        final nextIsMeeting =
                                            chosen['activity_type']
                                                    ?.toString()
                                                    .toLowerCase() ==
                                                'meeting';
                                        final nextSession = nextIsMeeting
                                            ? 'morning'
                                            : 'morning';
                                        try {
                                          final rows = await db
                                              .from(
                                                  'organization_member_attendance')
                                              .select(
                                                  'profile_id,status,marked_at,session')
                                              .eq('org_id', orgId)
                                              .eq('event_id', nextId)
                                              .eq('session', nextSession);
                                          if (!dialogContext.mounted) return;
                                          selectedEvent = nextId;
                                          isMeeting = nextIsMeeting;
                                          session = nextSession;
                                          records =
                                              List<Map<String, dynamic>>.from(
                                                  rows as List);
                                          setDialogState(() {});
                                        } catch (e) {
                                          _snack(
                                              'Could not load this activity: $e',
                                              Colors.red);
                                        }
                                      },
                                    ),
                                  ]),
                                  const SizedBox(height: 8),
                                  Container(
                                      padding: const EdgeInsets.all(13),
                                      decoration: BoxDecoration(
                                          color: const Color(0xFFF0FDF4),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                              color: const Color(0xFFD5F0DE))),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(children: [
                                              Expanded(
                                                  child: Text(
                                                      event['title']
                                                              ?.toString() ??
                                                          'Event',
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          color: Color(
                                                              0xFF14532D)))),
                                              const SizedBox(width: 8),
                                              Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 9,
                                                      vertical: 5),
                                                  decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFFDDF5E5),
                                                      borderRadius: BorderRadius
                                                          .circular(20)),
                                                  child: Text(
                                                      (event['activity_type']
                                                                  ?.toString() ??
                                                              'event')
                                                          .toUpperCase(),
                                                      style: const TextStyle(
                                                          fontSize: 9,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          color: Color(
                                                              0xFF166534))))
                                            ]),
                                            const SizedBox(height: 9),
                                            Row(children: [
                                              const Icon(
                                                  Icons.calendar_month_rounded,
                                                  size: 17,
                                                  color: _p),
                                              const SizedBox(width: 7),
                                              Expanded(
                                                  child: Text(
                                                      _attendanceDateLabel(
                                                          event['date']),
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700)))
                                            ]),
                                            const SizedBox(height: 4),
                                            Row(children: [
                                              const Icon(Icons.schedule_rounded,
                                                  size: 17, color: _p),
                                              const SizedBox(width: 7),
                                              Expanded(
                                                  child: Text(
                                                      _attendanceTimeLabel(
                                                          event['date']),
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700)))
                                            ]),
                                          ])),
                                  const SizedBox(height: 12),
                                  if (!isMeeting)
                                    _attendanceSessionPicker(
                                        session: session,
                                        onChanged: (value) async {
                                          try {
                                            final rows = await db
                                                .from(
                                                    'organization_member_attendance')
                                                .select(
                                                    'profile_id,status,marked_at,session')
                                                .eq('org_id', orgId)
                                                .eq('event_id', selectedEvent)
                                                .eq('session', value);
                                            if (!dialogContext.mounted) return;
                                            session = value;
                                            records =
                                                List<Map<String, dynamic>>.from(
                                                    rows as List);
                                            setDialogState(() {});
                                          } catch (e) {
                                            _snack(
                                                'Could not load this session: $e',
                                                Colors.red);
                                          }
                                        }),
                                  const SizedBox(height: 10),
                                  Text(
                                      '$presentCount present  •  $absentCount absent  •  ${members.length - records.length < 0 ? 0 : members.length - records.length} not recorded',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: _p,
                                          fontSize: 12)),
                                  const SizedBox(height: 8),
                                  ConstrainedBox(
                                      constraints: BoxConstraints(
                                          maxHeight:
                                              MediaQuery.of(dialogContext)
                                                      .size
                                                      .height *
                                                  .52),
                                      child: Scrollbar(
                                          thumbVisibility: true,
                                          interactive: true,
                                          child: ListView.separated(
                                              shrinkWrap: true,
                                              itemCount: members.length,
                                              separatorBuilder: (_, __) =>
                                                  const Divider(height: 1),
                                              itemBuilder: (_, index) {
                                                final member = members[index];
                                                final row =
                                                    member.profileId == null
                                                        ? null
                                                        : byProfile[
                                                            member.profileId!];
                                                final status = row?['status']
                                                    ?.toString()
                                                    .toLowerCase();
                                                final isPresent =
                                                    status == 'present';
                                                return ListTile(
                                                  dense: true,
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  leading: CircleAvatar(
                                                      radius: 17,
                                                      backgroundColor: status ==
                                                              null
                                                          ? Colors.grey.shade100
                                                          : isPresent
                                                              ? const Color(
                                                                  0xFFDCFCE7)
                                                              : const Color(
                                                                  0xFFFFE4E6),
                                                      child: Icon(
                                                          status == null
                                                              ? Icons
                                                                  .hourglass_empty_rounded
                                                              : isPresent
                                                                  ? Icons
                                                                      .check_rounded
                                                                  : Icons
                                                                      .close_rounded,
                                                          size: 18,
                                                          color: status == null
                                                              ? Colors.grey
                                                              : isPresent
                                                                  ? _p
                                                                  : Colors
                                                                      .redAccent)),
                                                  title: Text(member.name,
                                                      softWrap: true,
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700)),
                                                  subtitle: Text(
                                                      member.position,
                                                      maxLines: 1,
                                                      overflow: TextOverflow
                                                          .ellipsis),
                                                  trailing: Text(
                                                      status == null
                                                          ? 'Not recorded'
                                                          : isPresent
                                                              ? 'Present'
                                                              : 'Absent',
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: status == null
                                                              ? Colors.grey
                                                              : isPresent
                                                                  ? _p
                                                                  : Colors
                                                                      .redAccent)),
                                                );
                                              }))),
                                ]))))),
          );
        }),
      );
    } catch (e) {
      if (!mounted) return;
      _snack('Could not load attendance: $e', Colors.red);
    }
  }

  Future<void> _manageAttendance(
      BuildContext context, List<Member> members) async {
    final orgId =
        widget.organizationId ?? AppState.instance.currentOfficerOrgId;
    if (orgId == null || orgId.isEmpty) return;
    try {
      final db = Supabase.instance.client;
      if (!context.mounted) return;
      // Reuse an existing activity when recording another session later in the day.
      final choice = await _pickOrCreateAttendanceActivity(context, orgId);
      if (choice == null || !context.mounted) return;
      final activity = choice['_create_new'] == true
          ? await _createAttendanceActivity(context, orgId)
          : choice;
      if (activity == null || !context.mounted) return;
      final events = <Map<String, dynamic>>[activity];
      String selectedEvent = activity['id']?.toString() ?? '';
      final isMeeting =
          activity['activity_type']?.toString().toLowerCase() == 'meeting';
      // The database only permits 'morning' or 'afternoon' in the session column.
      // Meetings use the single stored 'morning' slot internally; the UI hides the session picker.
      String session = 'morning';
      final selected = <String>{};
      Future<void> loadSelected() async {
        final rows = await db
            .from('organization_member_attendance')
            .select('profile_id,status')
            .eq('event_id', selectedEvent)
            .eq('org_id', orgId)
            .eq('session', session);
        selected.clear();
        for (final row in rows as List) {
          if (row['status']?.toString().toLowerCase() == 'present') {
            final id = row['profile_id']?.toString() ?? '';
            if (id.isNotEmpty) selected.add(id);
          }
        }
      }

      await loadSelected();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        useSafeArea: false,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
            builder: (dialogContext, setDialogState) => Scaffold(
                  backgroundColor: const Color(0xFFF0FDF4),
                  appBar: PreferredSize(
                      preferredSize: const Size.fromHeight(160),
                      child: _attendanceFullHeader(dialogContext,
                          'Record Attendance', Icons.event_available_rounded)),
                  body: SizedBox(
                      width: double.infinity,
                      height: MediaQuery.of(dialogContext).size.height - 260,
                      child: Scrollbar(
                          thumbVisibility: true,
                          interactive: true,
                          child: SingleChildScrollView(
                              primary: true,
                              child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(18, 16, 18, 24),
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                              color: const Color(0xFFEAF7EF),
                                              borderRadius:
                                                  BorderRadius.circular(14)),
                                          child: Row(children: [
                                            const Icon(
                                                Icons.edit_calendar_rounded,
                                                color: _p),
                                            const SizedBox(width: 8),
                                            Expanded(
                                                child: Text(
                                                    'Attendance for: ${events.first['title'] ?? 'Event or meeting'}',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: Color(
                                                            0xFF173B2B)))),
                                          ]),
                                        ),
                                        const SizedBox(height: 12),
                                        Builder(builder: (_) {
                                          final event = events.firstWhere(
                                              (e) =>
                                                  e['id']?.toString() ==
                                                  selectedEvent,
                                              orElse: () => events.first);
                                          return Container(
                                              padding: const EdgeInsets.all(13),
                                              decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFF0FDF4),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  border: Border.all(
                                                      color: const Color(
                                                          0xFFD5F0DE))),
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(children: [
                                                      Expanded(
                                                          child: Text(
                                                              event['title']
                                                                      ?.toString() ??
                                                                  'Event',
                                                              maxLines: 2,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: const TextStyle(
                                                                  fontSize: 16,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w900,
                                                                  color: Color(
                                                                      0xFF14532D)))),
                                                      const SizedBox(width: 8),
                                                      Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal: 9,
                                                                  vertical: 5),
                                                          decoration: BoxDecoration(
                                                              color: const Color(
                                                                  0xFFDDF5E5),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          20)),
                                                          child: Text(
                                                              (event['activity_type']
                                                                          ?.toString() ??
                                                                      'event')
                                                                  .toUpperCase(),
                                                              style: const TextStyle(
                                                                  fontSize: 9,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w900,
                                                                  color: Color(
                                                                      0xFF166534))))
                                                    ]),
                                                    const SizedBox(height: 9),
                                                    Row(children: [
                                                      const Icon(
                                                          Icons
                                                              .calendar_month_rounded,
                                                          size: 17,
                                                          color: _p),
                                                      const SizedBox(width: 7),
                                                      Expanded(
                                                          child: Text(
                                                              _attendanceDateLabel(
                                                                  event[
                                                                      'date']),
                                                              style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700)))
                                                    ]),
                                                    const SizedBox(height: 4),
                                                    Row(children: [
                                                      const Icon(
                                                          Icons
                                                              .schedule_rounded,
                                                          size: 17,
                                                          color: _p),
                                                      const SizedBox(width: 7),
                                                      Expanded(
                                                          child: Text(
                                                              _attendanceTimeLabel(
                                                                  event[
                                                                      'date']),
                                                              style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700)))
                                                    ]),
                                                  ]));
                                        }),
                                        const SizedBox(height: 12),
                                        if (!isMeeting)
                                          _attendanceSessionPicker(
                                              session: session,
                                              onChanged: (value) async {
                                                try {
                                                  session = value;
                                                  await loadSelected();
                                                  if (!dialogContext.mounted) {
                                                    return;
                                                  }
                                                  setDialogState(() {});
                                                } catch (e) {
                                                  _snack(
                                                      'Could not load this session: $e',
                                                      Colors.red);
                                                }
                                              }),
                                        const SizedBox(height: 8),
                                        Text(
                                            isMeeting
                                                ? 'Check the members who attended this meeting.'
                                                : 'Check the members who are present for the ${session == 'morning' ? 'morning' : 'afternoon'} session.',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.blueGrey)),
                                        const SizedBox(height: 6),
                                        Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 9),
                                            decoration: BoxDecoration(
                                                color: const Color(0xFFF7FAF8),
                                                borderRadius:
                                                    BorderRadius.circular(12)),
                                            child: Row(children: [
                                              const Icon(Icons.groups_2_rounded,
                                                  size: 17, color: _p),
                                              const SizedBox(width: 7),
                                              Expanded(
                                                  child: Text(
                                                      '${members.length} members',
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: Color(
                                                              0xFF315342)))),
                                              Text('${selected.length} present',
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: _p))
                                            ])),
                                        ConstrainedBox(
                                            constraints: BoxConstraints(
                                                maxHeight:
                                                    MediaQuery.of(dialogContext)
                                                            .size
                                                            .height *
                                                        .52),
                                            child: Scrollbar(
                                                thumbVisibility: true,
                                                interactive: true,
                                                child: ListView.separated(
                                                    shrinkWrap: true,
                                                    itemCount: members.length,
                                                    separatorBuilder: (_, __) =>
                                                        const Divider(
                                                            height: 1),
                                                    itemBuilder: (_, index) {
                                                      final member =
                                                          members[index];
                                                      final id =
                                                          member.profileId;
                                                      if (id == null ||
                                                          id.isEmpty) {
                                                        return const SizedBox
                                                            .shrink();
                                                      }
                                                      final present =
                                                          selected.contains(id);
                                                      return CheckboxListTile(
                                                          value: present,
                                                          activeColor: _p,
                                                          contentPadding:
                                                              EdgeInsets.zero,
                                                          controlAffinity:
                                                              ListTileControlAffinity
                                                                  .leading,
                                                          title: Text(
                                                              member.name,
                                                              softWrap: true,
                                                              style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800)),
                                                          subtitle: Text(
                                                              member.position,
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis),
                                                          onChanged: (value) =>
                                                              setDialogState(() =>
                                                                  value == true
                                                                      ? selected
                                                                          .add(
                                                                              id)
                                                                      : selected
                                                                          .remove(id)));
                                                    }))),
                                      ]))))),
                  bottomNavigationBar: SafeArea(
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                  backgroundColor: _p,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 15)),
                              icon: const Icon(Icons.send_rounded, size: 18),
                              onPressed: () async {
                                try {
                                  final now =
                                      DateTime.now().toUtc().toIso8601String();
                                  final me = db.auth.currentUser?.id;
                                  final seen = <String>{};
                                  final payload = <Map<String, dynamic>>[];
                                  for (final member in members) {
                                    final id = member.profileId;
                                    if (id == null ||
                                        id.isEmpty ||
                                        !seen.add(id)) {
                                      continue;
                                    }
                                    payload.add({
                                      'org_id': orgId,
                                      'event_id': selectedEvent,
                                      'profile_id': id,
                                      'session': session,
                                      'status': selected.contains(id)
                                          ? 'present'
                                          : 'absent',
                                      'marked_by': me,
                                      'marked_at': now,
                                      'submitted_at': now,
                                      'submitted_by': me,
                                      'submission_status': 'submitted',
                                    });
                                  }
                                  if (payload.isEmpty) {
                                    _snack(
                                        'No members with linked accounts to record.',
                                        Colors.orange);
                                    return;
                                  }
                                  await db
                                      .from('organization_member_attendance')
                                      .upsert(payload,
                                          onConflict:
                                              'event_id,profile_id,session');
                                  if (!dialogContext.mounted) return;
                                  Navigator.pop(dialogContext);
                                  await _loadEngagementData();
                                  if (!mounted) return;
                                  _snack(
                                      isMeeting
                                          ? 'Meeting attendance saved and sent to the adviser.'
                                          : '${session == 'morning' ? 'Morning' : 'Afternoon'} attendance saved and sent to the adviser.',
                                      _ok);
                                } catch (e) {
                                  if (!mounted) return;
                                  _snack('Could not save attendance: $e',
                                      Colors.red);
                                }
                              },
                              label: const Text('Save & Send')))),
                )),
      );
    } catch (e) {
      if (!mounted) return;
      _snack('Could not load attendance: $e', Colors.red);
    }
  }

  // Clear, touch-friendly attendance actions for both desktop and mobile layouts.
  Widget _attendanceActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool primary,
    required VoidCallback onTap,
  }) =>
      Material(
        color: primary ? _p : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: primary ? _p : const Color(0xFFB7E4C7), width: 1.2),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF14532D)
                        .withValues(alpha: primary ? .10 : .04),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Row(children: [
              Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: primary
                          ? Colors.white.withValues(alpha: .16)
                          : const Color(0xFFEAF7EF),
                      borderRadius: BorderRadius.circular(14)),
                  child:
                      Icon(icon, color: primary ? Colors.white : _p, size: 23)),
              const SizedBox(width: 13),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: TextStyle(
                            color: primary
                                ? Colors.white
                                : const Color(0xFF166534),
                            fontSize: 15,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                            color: primary
                                ? Colors.white.withValues(alpha: .86)
                                : const Color(0xFF64786D),
                            fontSize: 11.5,
                            height: 1.3,
                            fontWeight: FontWeight.w500)),
                  ])),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 15, color: primary ? Colors.white : _p),
            ]),
          ),
        ),
      );

  // ── Member dialog ────────────────────────────────────────────────────────
  void _dialog(BuildContext context, {Member? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    // AFTER
    const validPositions = [
      'Member',
      'Officer',
      'President',
      'Vice President',
      'Secretary',
      'Assistant Secretary',
      'Treasurer'
    ];

    String position =
        (existing != null && validPositions.contains(existing.position))
            ? existing.position
            : 'Member';

    // Hardcoded officer org — resolved once at dialog open, never from user input
    final String? officerOrgId = AppState.instance.currentOfficerOrgId;
    final String officerOrgName = officerOrgId != null
        ? AppState.instance.organizations
            .firstWhere(
              (o) => o.id == officerOrgId,
              orElse: () => AppState.instance.organizations.first,
            )
            .name
        : (existing?.orgName ?? '');

    // Guard: bail out if no officer org context is available
    if (officerOrgId == null) {
      _snack('No organization context. Please re-login.', Colors.red);
      return;
    }

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
          builder: (ctx, ss) => Dialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DialogHeader(
                            existing == null
                                ? Icons.person_add_rounded
                                : Icons.edit_rounded,
                            existing == null ? 'Add Member' : 'Edit Member'),
                        const SizedBox(height: 20),
                        _Field(
                            ctrl: nameCtrl,
                            label: 'Full Name',
                            hint: 'Enter member name',
                            icon: Icons.person_rounded),
                        const SizedBox(height: 14),
                        // Designation choices shared by adviser and organization leadership
                        _FieldLabel('Position'),
                        DropdownButtonFormField<String>(
                          initialValue: position,
                          decoration: _fieldDeco(Icons.badge_rounded),
                          items: [
                            'President',
                            'Vice President',
                            'Secretary',
                            'Assistant Secretary',
                            'Treasurer',
                            'Officer',
                            'Member',
                          ]
                              .map((v) =>
                                  DropdownMenuItem(value: v, child: Text(v)))
                              .toList(),
                          onChanged: (v) => ss(() => position = v ?? 'Member'),
                        ),
                        const SizedBox(height: 14),
                        // Read-only org display — not editable by officer
                        _FieldLabel('Organization'),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.groups_rounded,
                                color: Color(0xFF16A34A), size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                officerOrgName,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF64748B)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.lock_rounded,
                                color: Color(0xFFCBD5E1), size: 14),
                          ]),
                        ),
                        const SizedBox(height: 22),
                        Row(children: [
                          Expanded(
                              child:
                                  _CancelBtn(onTap: () => Navigator.pop(ctx))),
                          const SizedBox(width: 12),
                          Expanded(child: _SaveBtn(onTap: () async {
                            final name = nameCtrl.text.trim();
                            final navigator = Navigator.of(ctx);
                            final messenger = ScaffoldMessenger.of(ctx);
                            if (name.isEmpty) return;
                            if (existing == null) {
                              // ADD: org identifiers sourced from officer session only
                              await AppState.instance.addMember(
                                name: name,
                                position: position,
                                orgName: officerOrgName,
                                orgId: officerOrgId,
                              );
                              await AppState.instance
                                  .fetchMembers(organizationId: officerOrgId);
                              _showSnack(messenger, 'Added $name', _ok);
                            } else {
                              // UPDATE: preserve id, override org identifiers.
                              final updated = existing.copyWith(
                                name: name,
                                position: position,
                                orgName: officerOrgName,
                                orgId: officerOrgId,
                              );
                              final saved =
                                  await AppState.instance.updateMember(updated);
                              if (!saved) {
                                _showSnack(
                                    messenger,
                                    'Could not save position: ${AppState.instance.lastMemberUpdateError ?? 'Unknown database error'}',
                                    Colors.redAccent);
                                return;
                              }
                              // Keep account-level access synchronized with the
                              // membership position. The dashboard reads the exact
                              // position from members, while profiles.role controls
                              // student/officer routing.
                              if (existing.profileId != null &&
                                  existing.profileId!.isNotEmpty) {
                                final officerPosition =
                                    _officerPositions.contains(position) ||
                                        position == 'Officer';
                                try {
                                  await Supabase.instance.client
                                      .from('profiles')
                                      .update({
                                    'role':
                                        officerPosition ? 'officer' : 'student',
                                    'assigned_org_id':
                                        officerPosition ? officerOrgId : null,
                                  }).eq('id', existing.profileId!);
                                } catch (e) {
                                  debugPrint(
                                      'Could not synchronize officer account role: $e');
                                }
                              }
                              await AppState.instance
                                  .fetchMembers(organizationId: officerOrgId);
                              if (!mounted) return;
                              _showSnack(
                                  messenger, 'Updated $name to $position', _ok);
                            }
                            if (!mounted) return;
                            navigator.pop();
                          })),
                        ]),
                      ],
                    )),
              )),
    );
  }

  void _showSnack(ScaffoldMessengerState messenger, String msg, Color bg) =>
      messenger.showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
}

// ── Member card ─────────────────────────────────────────────────────────────
class _MemberCard extends StatelessWidget {
  final Member member;
  final bool readOnly;
  final int index;
  final Color accentColor;
  final int chatCount;
  final int commentCount;
  final int attendancePresent;
  final int attendanceTotal;
  final VoidCallback onEdit, onDelete;
  const _MemberCard({
    required this.member,
    this.readOnly = false,
    required this.index,
    required this.accentColor,
    this.chatCount = 0,
    this.commentCount = 0,
    this.attendancePresent = 0,
    this.attendanceTotal = 0,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final initial = member.name.isNotEmpty ? member.name[0].toUpperCase() : '?';
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 240 + index * 50),
      curve: Curves.easeOut,
      builder: (_, v, child) => Opacity(
          opacity: v,
          child: Transform.translate(
              offset: Offset(0, 12 * (1 - v)), child: child)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE4F0E8)),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF16A34A).withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 6))
          ],
        ),
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              // Avatar
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle),
                child: Center(
                    child: Text(initial,
                        style: TextStyle(
                            color: accentColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w800))),
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    // Keep the complete member/officer name visible. The card
                    // grows vertically for long names instead of truncating.
                    Text(member.name,
                        softWrap: true,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A))),
                    const SizedBox(height: 2),
                    Text(member.orgName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(member.position,
                              style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: accentColor)),
                        ),
                        if (chatCount > 0)
                          _tinyMetric(
                              Icons.chat_bubble_rounded, '$chatCount chat'),
                        if (commentCount > 0)
                          _tinyMetric(Icons.forum_rounded,
                              '$commentCount comment${commentCount == 1 ? '' : 's'}'),
                        _tinyMetric(
                            Icons.event_available_rounded,
                            attendanceTotal == 0
                                ? 'Attendance —'
                                : 'Attendance ${((attendancePresent / attendanceTotal) * 100).round()}%'),
                      ],
                    ),
                  ])),
              if (!readOnly)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  _IconBtn(
                      icon: Icons.edit_rounded,
                      color: const Color(0xFF16A34A),
                      onTap: onEdit,
                      tip: 'Edit'),
                  const SizedBox(width: 4),
                  _IconBtn(
                      icon: Icons.delete_rounded,
                      color: const Color(0xFFEF4444),
                      onTap: onDelete,
                      tip: 'Remove'),
                ]),
            ])),
      ),
    );
  }
}

Widget _tinyMetric(IconData icon, String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF16A34A).withValues(alpha: .08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: const Color(0xFF16A34A)),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF166534))),
      ]),
    );

class _EngagementInfoCard extends StatelessWidget {
  const _EngagementInfoCard();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFF5FFF9), Color(0xFFDDF4E8)]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFB9E4CF)),
        ),
        child:
            const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.verified_user_rounded, color: Color(0xFF16A34A), size: 21),
          SizedBox(width: 10),
          Expanded(
              child: Text(
            'Active means the member participated in the last 30 days through community chat, event comments, or recorded attendance.',
            style: TextStyle(
                color: Color(0xFF4D6F62),
                fontSize: 11.5,
                height: 1.4,
                fontWeight: FontWeight.w600),
          )),
        ]),
      );
}

class _ImpactSection extends StatelessWidget {
  final List<Member> members;
  final Map<String, Map<String, dynamic>> impactByStudentId;
  final double Function(Map<String, dynamic>) averageFor;
  final bool adviserView;
  const _ImpactSection(
      {required this.members,
      required this.impactByStudentId,
      required this.averageFor,
      this.adviserView = false});

  double _rating(dynamic value) {
    final n = double.tryParse(value?.toString() ?? '') ?? 0;
    return n > 5 ? (n / 20).clamp(1, 5) : n.clamp(1, 5);
  }

  @override
  Widget build(BuildContext context) {
    final rows = members
        .where((m) =>
            m.profileId != null && impactByStudentId.containsKey(m.profileId))
        .toList();
    final impacts = rows.map((m) => impactByStudentId[m.profileId!]!).toList();
    final avgScore = impacts.isEmpty
        ? 0.0
        : impacts
                .map((impact) => averageFor(impact))
                .map((v) => v > 5 ? v / 20 : v)
                .reduce((a, b) => a + b) /
            impacts.length;
    // A 1/5 response means no perceived impact (0%); 5/5 means full impact (100%).
    final percent = impacts.isEmpty
        ? 0
        : (((avgScore - 1) / 4) * 100).round().clamp(0, 100);
    final level = impacts.isEmpty
        ? 'Awaiting responses'
        : percent >= 75
            ? 'High impact'
            : percent >= 50
                ? 'Moderate impact'
                : 'Low impact';
    final high = impacts.where((i) {
      final a = averageFor(i);
      final p = (((((a > 5 ? a / 20 : a) - 1) / 4) * 100));
      return p >= 75;
    }).length;
    final moderate = impacts.where((i) {
      final a = averageFor(i);
      final p = (((((a > 5 ? a / 20 : a) - 1) / 4) * 100));
      return p >= 50 && p < 75;
    }).length;
    final low = impacts.length - high - moderate;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFFEAF9F0),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFB7E2C9))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.insights_rounded,
              color: Color(0xFF15803D), size: 22),
          const SizedBox(width: 10),
          const Expanded(
              child: Text('Organization Impact',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF12352A)))),
          if (impacts.isNotEmpty)
            Text('$percent%',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF166534)))
        ]),
        const SizedBox(height: 6),
        Text(
            impacts.isEmpty
                ? 'No member impact responses have been submitted yet.'
                : '$level • Overall result from ${impacts.length} submitted member response${impacts.length == 1 ? '' : 's'}.',
            style: const TextStyle(
                color: Color(0xFF3F6255),
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w700)),
        if (impacts.isNotEmpty) ...[
          const SizedBox(height: 10),
          ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                  value: percent / 100,
                  minHeight: 10,
                  backgroundColor: Colors.white,
                  color: const Color(0xFF16A34A))),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _summaryPill('High impact', high),
            _summaryPill('Moderate impact', moderate),
            _summaryPill('Low impact', low)
          ]),
          const SizedBox(height: 7),
          const Text(
              'Impact bands: High 75–100%, Moderate 50–74%, Low below 50%. These are suggested reporting bands based on the 1–5 self-reported scale.',
              style: TextStyle(
                  color: Color(0xFF48665A), fontSize: 10.5, height: 1.35)),
        ],
        const SizedBox(height: 14),
        if (impacts.isEmpty)
          const Text(
              'Members rate Academic, Social, Leadership, and Confidence from 1 to 5. Their combined answers are converted to an overall percentage.',
              style: TextStyle(
                  color: Color(0xFF48665A), fontSize: 11.5, height: 1.4))
        else
          ...rows.map((member) {
            final impact = impactByStudentId[member.profileId!]!;
            final avg = averageFor(impact);
            final normalized = avg > 5 ? avg / 20 : avg;
            final memberPercent =
                ((((normalized - 1) / 4) * 100).round()).clamp(0, 100);
            final memberLevel = memberPercent >= 75
                ? 'High'
                : memberPercent >= 50
                    ? 'Moderate'
                    : 'Low';
            return Container(
                margin: const EdgeInsets.only(bottom: 9),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD1FAE5))),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(member.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF12352A)))),
                        Text('$memberPercent% • $memberLevel',
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF166534),
                                fontSize: 11))
                      ]),
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        _impactChip(
                            'Academic', _rating(impact['academic_growth'])),
                        _impactChip('Social', _rating(impact['social_growth'])),
                        _impactChip(
                            'Leadership', _rating(impact['leadership_growth'])),
                        _impactChip(
                            'Confidence', _rating(impact['confidence_growth']))
                      ]),
                    ]));
          }),
      ]),
    );
  }

  Widget _summaryPill(String label, int count) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Text('$label: $count',
          style: const TextStyle(
              color: Color(0xFF166534),
              fontSize: 10.5,
              fontWeight: FontWeight.w800)));

  Widget _impactChip(String label, double value) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(30)),
      child: Text('$label ${value.round()}/5',
          style: const TextStyle(
              fontSize: 9.5,
              color: Color(0xFF166534),
              fontWeight: FontWeight.w900)));
}

class _MemberActivitySection extends StatelessWidget {
  final List<Member> members;
  final Set<String> activeProfileIds;
  final Map<String, int> chatMessageCounts;
  final Map<String, int> commentCounts;
  final Map<String, int> attendancePresent;
  final Map<String, int> attendanceTotal;
  const _MemberActivitySection(
      {required this.members,
      required this.activeProfileIds,
      required this.chatMessageCounts,
      required this.commentCounts,
      required this.attendancePresent,
      required this.attendanceTotal});

  @override
  Widget build(BuildContext context) {
    final totalMembers = members.where((m) => m.profileId != null).length;
    final active = members
        .where((m) =>
            m.profileId != null && activeProfileIds.contains(m.profileId))
        .length;
    final chatParticipants = members
        .where((m) =>
            m.profileId != null &&
            ((chatMessageCounts[m.profileId] ?? 0) > 0 ||
                (commentCounts[m.profileId] ?? 0) > 0))
        .length;
    final totalAttendance =
        attendanceTotal.values.fold<int>(0, (a, b) => a + b);
    final presentAttendance =
        attendancePresent.values.fold<int>(0, (a, b) => a + b);
    final attendanceRate = totalAttendance == 0
        ? 0
        : (presentAttendance / totalAttendance * 100).round();
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFDCEFE2))),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Row(children: [
            Icon(Icons.groups_rounded, color: Color(0xFF0F766E), size: 22),
            SizedBox(width: 10),
            Expanded(
                child: Text('Member Activity',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF12352A))))
          ]),
          const SizedBox(height: 5),
          const Text(
              'A separate participation measure based on attendance and engagement in the organization community during the last 30 days.',
              style: TextStyle(
                  color: Color(0xFF48665A), fontSize: 11.5, height: 1.4)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _activityMetric('Active members',
                    '$active/$totalMembers', Icons.verified_user_rounded)),
            const SizedBox(width: 8),
            Expanded(
                child: _activityMetric('Chat / comments', '$chatParticipants',
                    Icons.forum_rounded)),
            const SizedBox(width: 8),
            Expanded(
                child: _activityMetric(
                    'Attendance',
                    totalAttendance == 0 ? '—' : '$attendanceRate%',
                    Icons.fact_check_rounded))
          ]),
          const SizedBox(height: 12),
          if (members.isEmpty)
            const Text('No members found for this organization.',
                style: TextStyle(color: Color(0xFF48665A), fontSize: 11.5))
          else
            ...members.where((m) => m.profileId != null).map((m) {
              final id = m.profileId!;
              final present = attendancePresent[id] ?? 0;
              final total = attendanceTotal[id] ?? 0;
              final messages = chatMessageCounts[id] ?? 0;
              final comments = commentCounts[id] ?? 0;
              final isActive = activeProfileIds.contains(id);
              return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Expanded(
                        child: Text(m.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF234638)))),
                    Expanded(
                        child: Text(
                            '${isActive ? 'Active' : 'No recent activity'}  •  Chat $messages  •  Comments $comments  •  Attendance ${total == 0 ? '—' : '$present/$total'}',
                            textAlign: TextAlign.end,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 9.5,
                                color: Color(0xFF48665A),
                                fontWeight: FontWeight.w700)))
                  ]));
            }),
        ]));
  }

  Widget _activityMetric(String label, String value, IconData icon) =>
      Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(14)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: const Color(0xFF15803D), size: 18),
            const SizedBox(height: 5),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: Color(0xFF14532D))),
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                    color: Color(0xFF48665A)))
          ]));
}

// Shared small widgets

class _GradFab extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _GradFab(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF16A34A), Color(0xFF0F766E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF16A34A).withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6))
          ],
        ),
        child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icon, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(label,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                    ])))),
      );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tip;
  const _IconBtn(
      {required this.icon,
      required this.color,
      required this.onTap,
      required this.tip});

  @override
  Widget build(BuildContext context) => Tooltip(
      message: tip,
      child: Material(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(icon, color: color, size: 17)))));
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: const LinearGradient(
                    colors: [Color(0xFF16A34A), Color(0xFF0F766E)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter))),
        const SizedBox(width: 10),
        Text(text.toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
                color: Color(0xFF94A3B8))),
      ]);
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  const _Empty({required this.icon, required this.label, required this.sub});

  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF16A34A), Color(0xFF0F766E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.28),
                      blurRadius: 20,
                      offset: const Offset(0, 8))
                ]),
            child: Icon(icon, size: 36, color: Colors.white)),
        const SizedBox(height: 18),
        Text(label,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A))),
        const SizedBox(height: 6),
        Text(sub,
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B))),
      ]));
}

// ── Dialog helpers ───────────────────────────────────────────────────────────

class _DialogHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _DialogHeader(this.icon, this.title);

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                gradient: const LinearGradient(
                    colors: [Color(0xFF16A34A), Color(0xFF0F766E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight)),
            child: Icon(icon, color: Colors.white, size: 18)),
        const SizedBox(width: 12),
        Text(title,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A))),
      ]);
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 7),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151))),
      );
}

InputDecoration _fieldDeco(IconData icon, {String? hint}) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13.5),
      filled: true,
      fillColor: const Color(0xFFF0FDF4),
      prefixIcon: Icon(icon, color: const Color(0xFF16A34A), size: 18),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF16A34A), width: 1.5)),
    );

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final IconData icon;
  const _Field(
      {required this.ctrl,
      required this.label,
      required this.hint,
      required this.icon});

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _FieldLabel(label),
        TextField(
            controller: ctrl,
            maxLines: 1,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0F172A)),
            decoration: _fieldDeco(icon, hint: hint)),
      ]);
}

class _CancelBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _CancelBtn({required this.onTap});
  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
        child: const Text('Cancel',
            style: TextStyle(
                color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
      );
}

class _SaveBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _SaveBtn({required this.onTap});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF16A34A), Color(0xFF0F766E)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF16A34A).withValues(alpha: 0.28),
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
                child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                        child: Text('Save',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14)))))),
      );
}
