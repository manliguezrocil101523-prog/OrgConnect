import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Roles supported by the app
enum UserRole { student, officer, admin, adviser }

/// Application status lifecycle
enum ApplicationStatus {
  pending,
  interviewed,
  forApproval,
  approved,
  accepted,
  interviewScheduled,
  declined
}

/// In-app notifications
class Notification {
  final String id;
  final String title;
  final String message;
  final DateTime date;
  bool read;
  final String? orgId;
  final String? studentId;

  Notification({
    required this.id,
    required this.title,
    required this.message,
    required this.date,
    this.read = false,
    this.orgId,
    this.studentId,
  });

  Notification copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? date,
    bool? read,
    String? orgId,
    String? studentId,
  }) {
    return Notification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      date: date ?? this.date,
      read: read ?? this.read,
      orgId: orgId ?? this.orgId,
      studentId: studentId ?? this.studentId,
    );
  }
}

/// Student profile (in-memory for demo)
class StudentProfile {
  final String id;
  final String name;
  final String email;
  final String studentId;
  final String contact;
  final String facebook;
  final String avatarUrl;
  final List<String> joinedOrgIds;

  const StudentProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.studentId,
    required this.contact,
    required this.facebook,
    required this.avatarUrl,
    this.joinedOrgIds = const [],
  });

  StudentProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? studentId,
    String? contact,
    String? facebook,
    String? avatarUrl,
    List<String>? joinedOrgIds,
  }) =>
      StudentProfile(
        id: id ?? this.id,
        name: name ?? this.name,
        email: email ?? this.email,
        studentId: studentId ?? this.studentId,
        contact: contact ?? this.contact,
        facebook: facebook ?? this.facebook,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        joinedOrgIds: joinedOrgIds ?? this.joinedOrgIds,
      );
}

/// Student application to an organization
class Application {
  final String id;
  final String? userId;
  final String orgName;
  final String? orgId;
  final String studentId;
  final String name;
  final String contact;
  final String email;
  final String reason;
  final String skills;
  final DateTime createdAt;
  ApplicationStatus status;
  final DateTime? interviewAt;
  final List<String> attachments;
  final String course;
  final String yearSection;
  final String facebook;
  final String experience;
  final String emergencyContact;
  final String profilePicUrl;
  final String declineReason;

  Application({
    required this.id,
    this.userId,
    required this.orgName,
    required this.studentId,
    required this.name,
    required this.contact,
    required this.email,
    required this.reason,
    required this.skills,
    required this.createdAt,
    this.interviewAt,
    this.status = ApplicationStatus.pending,
    this.attachments = const [],
    this.orgId,
    this.course = '',
    this.yearSection = '',
    this.facebook = '',
    this.experience = '',
    this.emergencyContact = '',
    this.profilePicUrl = '',
    this.declineReason = '',
  });

  Application copyWith({
    String? id,
    String? userId,
    String? orgName,
    String? studentId,
    String? name,
    String? contact,
    String? email,
    String? reason,
    String? skills,
    DateTime? createdAt,
    DateTime? interviewAt,
    ApplicationStatus? status,
    List<String>? attachments,
    String? orgId,
    String? declineReason,
  }) {
    return Application(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      orgName: orgName ?? this.orgName,
      studentId: studentId ?? this.studentId,
      name: name ?? this.name,
      contact: contact ?? this.contact,
      email: email ?? this.email,
      reason: reason ?? this.reason,
      skills: skills ?? this.skills,
      createdAt: createdAt ?? this.createdAt,
      interviewAt: interviewAt ?? this.interviewAt,
      status: status ?? this.status,
      attachments: attachments ?? this.attachments,
      orgId: orgId ?? this.orgId,
      course: course,
      yearSection: yearSection,
      facebook: facebook,
      experience: experience,
      emergencyContact: emergencyContact,
      profilePicUrl: profilePicUrl,
      declineReason: declineReason ?? this.declineReason,
    );
  }
}

/// Organization member
class Member {
  final String id;
  final String name;
  final String position;
  final String orgName;
  final String? orgId;
  final String? profileId;

  Member({
    required this.id,
    required this.name,
    required this.position,
    required this.orgName,
    this.orgId,
    this.profileId,
  });

  Member copyWith({
    String? id,
    String? name,
    String? position,
    String? orgName,
    String? orgId,
    String? profileId,
  }) =>
      Member(
        id: id ?? this.id,
        name: name ?? this.name,
        position: position ?? this.position,
        orgName: orgName ?? this.orgName,
        orgId: orgId ?? this.orgId,
        profileId: profileId ?? this.profileId,
      );
}

/// Organization event
/// Organization event
class Event {
  final String id;
  final String title;
  final DateTime date;
  final String description;
  final String orgName;
  final String? orgId;
  final String? imageUrl;
  final List<String> imageUrls;
  final DateTime createdAt;
  final String venue; // NEW (events.venue)
  final String? startTime; // NEW (events.start_time, text)
  final String? endTime; // NEW (events.end_time, text)

  Event({
    required this.id,
    required this.title,
    required this.date,
    required this.description,
    required this.orgName,
    this.orgId,
    this.imageUrl,
    this.imageUrls = const [],
    DateTime? createdAt,
    this.venue = '',
    this.startTime,
    this.endTime,
  }) : createdAt = createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  /// "08:00 – 16:00", just the start, or '' when no time was saved.
  String get timeLabel {
    final s = startTime?.trim() ?? '';
    final e = endTime?.trim() ?? '';
    if (s.isEmpty) return '';
    return e.isEmpty ? s : '$s – $e';
  }

  Event copyWith({
    String? id,
    String? title,
    DateTime? date,
    String? description,
    String? orgName,
    String? orgId,
    String? imageUrl,
    List<String>? imageUrls,
    DateTime? createdAt,
    String? venue,
    String? startTime,
    String? endTime,
  }) =>
      Event(
        id: id ?? this.id,
        title: title ?? this.title,
        date: date ?? this.date,
        description: description ?? this.description,
        orgName: orgName ?? this.orgName,
        orgId: orgId ?? this.orgId,
        imageUrl: imageUrl ?? this.imageUrl,
        imageUrls: imageUrls ?? this.imageUrls,
        createdAt: createdAt ?? this.createdAt,
        venue: venue ?? this.venue,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
      );
}

/// User for Admin management
class User {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final bool active;
  final String? studentId;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
    this.studentId,
  });

  User copyWith(
          {String? id,
          String? name,
          String? email,
          UserRole? role,
          bool? active,
          String? studentId}) =>
      User(
        id: id ?? this.id,
        name: name ?? this.name,
        email: email ?? this.email,
        role: role ?? this.role,
        active: active ?? this.active,
        studentId: studentId ?? this.studentId,
      );
}

/// Represents one item in the Activities & Events media list
class OrgMediaItem {
  final String type; // 'text' | 'image' | 'video'
  final String content; // text string OR public URL
  final String caption; // legacy caption / fallback title
  final String title; // activity name, e.g. 'Attending Mass'
  final String description; // optional short activity description

  const OrgMediaItem({
    required this.type,
    required this.content,
    this.caption = '',
    this.title = '',
    this.description = '',
  });

  factory OrgMediaItem.fromJson(dynamic raw) {
    // Backward compat: old plain strings become text items
    if (raw is String) {
      return OrgMediaItem(type: 'text', content: raw);
    }
    if (raw is Map) {
      final legacyCaption = raw['caption']?.toString() ?? '';
      final rawTitle = raw['title']?.toString().trim().isNotEmpty == true
          ? raw['title']?.toString()
          : (raw['name']?.toString().trim().isNotEmpty == true
              ? raw['name']?.toString()
              : (raw['activity_name']?.toString().trim().isNotEmpty == true
                  ? raw['activity_name']?.toString()
                  : legacyCaption));
      return OrgMediaItem(
        type: raw['type']?.toString() ?? 'text',
        content: raw['content']?.toString() ?? '',
        caption: legacyCaption,
        title: rawTitle ?? '',
        description:
            raw['description']?.toString() ?? raw['details']?.toString() ?? '',
      );
    }
    return const OrgMediaItem(type: 'text', content: '');
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'content': content,
        'caption': caption,
        'title': title,
        'description': description,
      };
}

class OrgOfficerProfile {
  final String name;
  final String role;
  final String avatarUrl;

  const OrgOfficerProfile({
    required this.name,
    required this.role,
    this.avatarUrl = '',
  });

  factory OrgOfficerProfile.fromJson(dynamic raw) {
    if (raw is Map) {
      return OrgOfficerProfile(
        name: raw['name']?.toString() ?? '',
        role: raw['role']?.toString() ?? 'Officer',
        avatarUrl: raw['avatar_url']?.toString() ?? '',
      );
    }
    return const OrgOfficerProfile(name: '', role: 'Officer');
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'role': role,
        'avatar_url': avatarUrl,
      };
}

/// Organization metadata
class Organization {
  final String id;
  final String name;
  final String logoAsset;
  final String shortDesc;
  final String acronym;
  final String category;
  final String about;
  final String mission;
  final String vision;
  final String goals;
  final String missionVision;
  final String adviser;
  final String contactEmail;
  final String contactPhone;
  final String socialLink;
  final List<String> officers;
  final List<OrgOfficerProfile> officerProfiles;
  final List<OrgMediaItem> activitiesHighlights;
  final String officerPassword;

  Organization({
    required this.id,
    required this.name,
    required this.logoAsset,
    required this.shortDesc,
    this.acronym = '',
    this.category = '',
    this.about = '',
    this.mission = '',
    this.vision = '',
    this.goals = '',
    this.missionVision = '',
    this.adviser = '',
    this.contactEmail = '',
    this.contactPhone = '',
    this.socialLink = '',
    this.officers = const [],
    this.officerProfiles = const <OrgOfficerProfile>[],
    this.activitiesHighlights = const <OrgMediaItem>[],
    this.officerPassword = 'officer123',
  });

  Organization copyWith({
    String? id,
    String? name,
    String? logoAsset,
    String? shortDesc,
    String? acronym,
    String? category,
    String? about,
    String? mission,
    String? vision,
    String? goals,
    String? missionVision,
    String? adviser,
    String? contactEmail,
    String? contactPhone,
    String? socialLink,
    List<String>? officers,
    List<OrgOfficerProfile>? officerProfiles,
    List<OrgMediaItem>? activitiesHighlights,
    String? officerPassword,
  }) =>
      Organization(
        id: id ?? this.id,
        name: name ?? this.name,
        logoAsset: logoAsset ?? this.logoAsset,
        shortDesc: shortDesc ?? this.shortDesc,
        acronym: acronym ?? this.acronym,
        category: category ?? this.category,
        about: about ?? this.about,
        mission: mission ?? this.mission,
        vision: vision ?? this.vision,
        goals: goals ?? this.goals,
        missionVision: missionVision ?? this.missionVision,
        adviser: adviser ?? this.adviser,
        contactEmail: contactEmail ?? this.contactEmail,
        contactPhone: contactPhone ?? this.contactPhone,
        socialLink: socialLink ?? this.socialLink,
        officers: officers ?? this.officers,
        officerProfiles: officerProfiles ?? this.officerProfiles,
        activitiesHighlights: activitiesHighlights ?? this.activitiesHighlights,
        officerPassword: officerPassword ?? this.officerPassword,
      );
}

/// Simple singleton app state using ChangeNotifier.
class AppState extends ChangeNotifier {
  AppState._internal() {
    loadStudentProfile();
    fetchOrganizations();
    fetchEvents();
    fetchNotifications();
    fetchMembers();
    fetchApplications();
    _subscribeToRealtime();
  }

  static final AppState instance = AppState._internal();

  List<Organization> organizations = [];
  bool isLoadingOrganizations = false;

  UserRole? selectedRole;
  StudentProfile? currentStudent;
  SharedPreferences? _prefs;
  String? currentOfficerOrgId;

  // ── Theme ────────────────────────────────────────────────────────────────
  bool isDark = false; // default = light mode

  void toggleTheme() async {
    isDark = !isDark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('admin_is_dark', isDark);
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    isDark = prefs.getBool('admin_is_dark') ?? false; // false = light default
    notifyListeners();
  }

  final List<Application> applications = <Application>[];
  final List<Member> members = <Member>[];
  final List<Event> events = <Event>[];
  final List<User> users = <User>[
    User(
        id: _genId(),
        name: 'Admin User',
        email: 'admin@example.com',
        role: UserRole.admin,
        active: true),
    User(
        id: _genId(),
        name: 'Officer User',
        email: 'officer@example.com',
        role: UserRole.officer,
        active: true),
    User(
        id: _genId(),
        name: 'Adviser User',
        email: 'adviser@example.com',
        role: UserRole.adviser,
        active: true),
    User(
        id: _genId(),
        name: 'Student User',
        email: 'student@example.com',
        role: UserRole.student,
        active: true,
        studentId: '123456789'),
  ];
  final List<Notification> notifications = <Notification>[];

// ── Organizations ─────────────────────────────────────────────────────────

  Future<void> fetchOrganizations() async {
    isLoadingOrganizations = true;
    notifyListeners();
    try {
      final response = await supabase.Supabase.instance.client
          .from('organizations')
          .select('*')
          .order('created_at', ascending: true);

      organizations.clear();
      for (var item in response) {
        List<String> officers = [];
        List<OrgOfficerProfile> officerProfiles = [];
        List<OrgMediaItem> activitiesHighlights = [];
        try {
          final rawOfficers = item['officers'];
          if (rawOfficers != null) {
            if (rawOfficers is List) {
              officers = List<String>.from(rawOfficers);
            }
          }
        } catch (_) {}
        try {
          final rawOfficerProfiles = item['officer_profiles'];
          if (rawOfficerProfiles is List) {
            officerProfiles = rawOfficerProfiles
                .map((e) => OrgOfficerProfile.fromJson(e))
                .where((p) => p.name.trim().isNotEmpty)
                .toList();
          }
        } catch (_) {}
        try {
          final rawActivities = item['activities_highlights'];
          if (rawActivities != null && rawActivities is List) {
            activitiesHighlights =
                rawActivities.map((e) => OrgMediaItem.fromJson(e)).toList();
          }
        } catch (_) {}

        organizations.add(Organization(
          id: item['id'],
          name: item['name'] ?? '',
          logoAsset: item['logo_asset'] ?? '',
          shortDesc: item['short_desc'] ?? '',
          acronym: item['acronym'] ?? '',
          category: item['category'] ?? '',
          about: item['about'] ?? '',
          mission: item['mission'] ?? '',
          vision: item['vision'] ?? '',
          goals: item['goals'] ?? '',
          missionVision: item['mission_vision'] ?? '',
          adviser: item['adviser'] ?? '',
          contactEmail: item['contact_email'] ?? '',
          contactPhone: item['contact_phone'] ?? '',
          socialLink: item['social_link'] ?? '',
          officers: officers,
          officerProfiles: officerProfiles,
          activitiesHighlights: activitiesHighlights,
          officerPassword: item['officer_password'] ?? 'officer123',
        ));
      }
    } catch (e) {
      debugPrint('Error fetching organizations from Supabase: $e');
    } finally {
      isLoadingOrganizations = false;
      notifyListeners();
    }
  }

// ── Real-time subscriptions ───────────────────────────────────────────────
  void _subscribeToRealtime() {
    final client = supabase.Supabase.instance.client;

    // Central realtime fan-out. Screens that listen to AppState therefore
    // update immediately when another user changes shared data. Individual
    // chat screens still maintain their own message channel for low latency.
    void subscribe(String table, Future<void> Function() refresh) {
      client
          .channel('app-realtime-$table')
          .onPostgresChanges(
            event: supabase.PostgresChangeEvent.all,
            schema: 'public',
            table: table,
            callback: (_) => refresh(),
          )
          .subscribe();
    }

    subscribe('applications', fetchApplications);
    subscribe('notifications', fetchNotifications);
    subscribe('events', fetchEvents);
    subscribe('members', () async {
      await fetchMembers();
      await _syncCurrentStudentMemberships();
      await fetchNotifications();
      notifyListeners();
    });
    subscribe('organizations', fetchOrganizations);
    subscribe('profiles', () async {
      await loadStudentProfile();
      await fetchMembers();
      notifyListeners();
    });
    subscribe('event_comments', () async {
      notifyListeners();
    });
    subscribe('event_comment_reactions', () async {
      notifyListeners();
    });
    subscribe('event_comment_replies', () async {
      notifyListeners();
    });
    subscribe('organization_attendance_sessions', () async {
      notifyListeners();
    });
    subscribe('organization_member_attendance', () async {
      notifyListeners();
    });
    subscribe('event_requests', () async {
      // Event request screens query their own scoped rows; notify the shared
      // state so open dashboards rebuild without a manual refresh.
      notifyListeners();
    });
    subscribe('event_views', () async {
      notifyListeners();
    });
    subscribe('student_impact', () async {
      notifyListeners();
    });
    subscribe('org_financial_transactions', () async {
      notifyListeners();
    });
    subscribe('usage_logs', () async {
      notifyListeners();
    });
    subscribe('application_assets', () async {
      notifyListeners();
    });
    // Tables used by screens that query Supabase directly. Notify all open
    // AppState listeners on changes so shared widgets and dashboards rebuild;
    // screens with private query state should also reload in their own channel.
    subscribe('org_chat_messages', () async {
      notifyListeners();
    });
  }

  // ── Status helper ─────────────────────────────────────────────────────────

  /// Converts a Supabase status string back to the [ApplicationStatus] enum.
  /// Falls back to [ApplicationStatus.pending] for any unrecognised value.
  ApplicationStatus _parseStatus(String? status) {
    final normalized = (status ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'interviewed':
        return ApplicationStatus.interviewed;
      case 'forapproval':
        return ApplicationStatus.forApproval;
      case 'approved':
        return ApplicationStatus.approved;
      case 'accepted':
        return ApplicationStatus.accepted;
      case 'interviewscheduled':
        return ApplicationStatus.interviewScheduled;
      case 'declined':
        return ApplicationStatus.declined;
      case 'pending':
      default:
        return ApplicationStatus.pending;
    }
  }

  // ── Applications ──────────────────────────────────────────────────────────

  /// Fetches all rows from the Supabase `applications` table and populates
  /// the local [applications] list. Called once on startup.
  Future<void> fetchApplications() async {
    try {
      final client = supabase.Supabase.instance.client;
      final byId = <String, Map<String, dynamic>>{};

      // Officers still need their organization's applicant queue, but an
      // officer is also a member/student and must be able to see their own
      // applications to other organizations. Fetch both scopes and merge by
      // application id so one screen never hides a valid application.
      if (currentOfficerOrgId != null &&
          currentOfficerOrgId!.trim().isNotEmpty) {
        final officerRows = await client
            .from('applications')
            .select('*')
            .eq('org_id', currentOfficerOrgId!);
        for (final row in (officerRows as List)) {
          final map = Map<String, dynamic>.from(row);
          final id = map['id']?.toString() ?? '';
          if (id.isNotEmpty) byId[id] = map;
        }
      } else {
        final rows = await client.from('applications').select('*');
        for (final row in (rows as List)) {
          final map = Map<String, dynamic>.from(row);
          final id = map['id']?.toString() ?? '';
          if (id.isNotEmpty) byId[id] = map;
        }
      }

      final authUserId = client.auth.currentUser?.id;
      if (authUserId != null && authUserId.isNotEmpty) {
        try {
          final ownRows = await client
              .from('applications')
              .select('*')
              .eq('user_id', authUserId);
          for (final row in (ownRows as List)) {
            final map = Map<String, dynamic>.from(row);
            final id = map['id']?.toString() ?? '';
            if (id.isNotEmpty) byId[id] = map;
          }
        } catch (e) {
          debugPrint('Could not load applications by auth user: $e');
        }
      }

      final schoolStudentId = currentStudent?.studentId.trim() ?? '';
      if (schoolStudentId.isNotEmpty) {
        try {
          final ownRows = await client
              .from('applications')
              .select('*')
              .eq('student_id', schoolStudentId);
          for (final row in (ownRows as List)) {
            final map = Map<String, dynamic>.from(row);
            final id = map['id']?.toString() ?? '';
            if (id.isNotEmpty) byId[id] = map;
          }
        } catch (e) {
          debugPrint('Could not load applications by student id: $e');
        }
      }

      // Some older application rows were created before user_id/student_id
      // was consistently populated. The student's email is also stored on
      // every application, so use it as a third ownership key. This makes
      // older approved applications (for example El Teatro) appear together
      // with newer applications (for example Student Catholic Action).
      final studentEmail = currentStudent?.email.trim() ?? '';
      if (studentEmail.isNotEmpty) {
        try {
          final ownRows = await client
              .from('applications')
              .select('*')
              .ilike('email', studentEmail);
          for (final row in (ownRows as List)) {
            final map = Map<String, dynamic>.from(row);
            final id = map['id']?.toString() ?? '';
            if (id.isNotEmpty) byId[id] = map;
          }
        } catch (e) {
          debugPrint('Could not load applications by email: $e');
        }
      }

      // Final compatibility fallback: if the RLS policy allows the signed-in
      // user to read the application table, inspect all visible rows and keep
      // only rows that belong to this student. This recovers older El Teatro
      // records whose ownership column was left blank during migration.
      if (byId.isEmpty && currentStudent != null) {
        try {
          final visibleRows = await client.from('applications').select('*');
          final normalizedName = currentStudent!.name.trim().toLowerCase();
          final normalizedEmail = currentStudent!.email.trim().toLowerCase();
          final normalizedStudentId =
              currentStudent!.studentId.trim().toLowerCase();
          for (final row in (visibleRows as List)) {
            final map = Map<String, dynamic>.from(row);
            final rowName = map['name']?.toString().trim().toLowerCase() ?? '';
            final rowEmail =
                map['email']?.toString().trim().toLowerCase() ?? '';
            final rowStudentId =
                map['student_id']?.toString().trim().toLowerCase() ?? '';
            if ((normalizedEmail.isNotEmpty && rowEmail == normalizedEmail) ||
                (normalizedStudentId.isNotEmpty &&
                    rowStudentId == normalizedStudentId) ||
                (normalizedName.isNotEmpty && rowName == normalizedName)) {
              final id = map['id']?.toString() ?? '';
              if (id.isNotEmpty) byId[id] = map;
            }
          }
        } catch (e) {
          debugPrint(
              'Could not use visible application compatibility fallback: $e');
        }
      }

      // My Applications must reflect real application records only.
      // Do not reconstruct/synthesize applications from memberships. A member
      // record is not an application record, and using it here can make a
      // deleted/old application reappear after the user is preparing to apply
      // again.

      applications
        ..clear()
        ..addAll(byId.values.map(_applicationFromRow).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

      await _syncCurrentStudentMemberships();
      // Rebuild notifications after applications are available so older
      // approval messages can be upgraded with the actual applicant name.
      await fetchNotifications();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching applications from Supabase: $e');
    }
  }

  Future<Application> submitApplication({
    required String orgName,
    required String studentId,
    required String name,
    required String course, // NEW
    required String yearSection,
    required String contact,
    required String email,
    required String facebook,
    required String reason,
    required String skills,
    required String experience, // NEW
    required String emergencyContact, // NEW
    String? orgId,
    String profilePicUrl = '',
    List<String> attachments = const [],
  }) async {
    final currentUser = supabase.Supabase.instance.client.auth.currentUser;

    // Guard: user must be logged in
    if (currentUser == null) {
      throw Exception('User not logged in');
    }

    final found = orgId == null || orgId.isEmpty
        ? _findOrgByName(orgName)
        : _findOrgById(orgId);
    final app = Application(
      id: _genId(),
      orgName: orgName,
      orgId: found?.id,
      studentId: studentId,
      name: name,
      contact: contact,
      email: email,
      reason: reason,
      skills: skills,
      attachments: attachments,
      createdAt: DateTime.now(),
      course: course,
      yearSection: yearSection,
      facebook: facebook,
      experience: experience,
      emergencyContact: emergencyContact,
      profilePicUrl: profilePicUrl,
    );
    applications.add(app);

    try {
      await supabase.Supabase.instance.client.from('applications').insert({
        'id': app.id,
        'org_name': app.orgName,
        'org_id': app.orgId,
        'student_id': app.studentId,
        'user_id': currentUser.id, // ✅ auth UUID, satisfies RLS
        'name': app.name,
        'contact': app.contact,
        'email': app.email,
        'reason': app.reason,
        'skills': app.skills,
        // Store attachments as a real JSONB array. Passing jsonEncode(...) here
        // stores the entire list as a JSON string, which made the Officer UI
        // receive "[]" instead of an attachment array.
        'attachments': app.attachments,
        'created_at': app.createdAt.toIso8601String(),
        'status': app.status.toString().split('.').last,
        'course': app.course,
        'year_section': app.yearSection,
        'facebook': app.facebook,
        'experience': app.experience,
        'emergency_contact': app.emergencyContact,
        'profile_pic_url': app.profilePicUrl,
        'decline_reason': app.declineReason,
      });
      debugPrint(
          'SUCCESS: Application inserted with user_id: ${currentUser.id}');
    } catch (e) {
      debugPrint('Error persisting application to Supabase: $e');
      // Do not report a successful submission when the database rejected it.
      applications.removeWhere((a) => a.id == app.id);
      notifyListeners();
      rethrow;
    }

    notifyListeners();
    return app;
  }

  Future<bool> declineApplication(String applicationId, String reason) async {
    final idx = applications.indexWhere((a) => a.id == applicationId);
    if (idx == -1) return false;
    final app = applications[idx];
    applications[idx] =
        app.copyWith(status: ApplicationStatus.declined, declineReason: reason);
    final client = supabase.Supabase.instance.client;
    try {
      await client.from('applications').update({
        'status': 'declined',
        'decline_reason': reason,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', applicationId);
      await client.from('notifications').insert({
        'id': _genId(),
        'title': 'Application update',
        'message':
            'We are sorry, your application to ${app.orgName} was not approved. Reason: $reason',
        'student_id': app.userId ?? app.studentId,
        'org_id': app.orgId
      });
    } catch (e) {
      debugPrint('Error declining application: $e');
    }
    notifyListeners();
    return true;
  }

  bool setApplicationStatus(String applicationId, ApplicationStatus status) {
    final idx = applications.indexWhere((a) => a.id == applicationId);
    if (idx == -1) return false;
    applications[idx] = applications[idx].copyWith(status: status);

    // ✅ ADD THIS — save to Supabase
    supabase.Supabase.instance.client
        .from('applications')
        .update({'status': status.toString().split('.').last})
        .eq('id', applicationId)
        .then((_) {}, onError: (Object e, StackTrace stack) {
          debugPrint('Error updating status: $e');
        });

    notifyListeners();
    return true;
  }

  Future<bool> approveApplication(String applicationId,
      {String defaultPosition = 'Member'}) async {
    final idx = applications.indexWhere((a) => a.id == applicationId);
    if (idx == -1) return false;

    final app = applications[idx];
    final client = supabase.Supabase.instance.client;
    final orgId = app.orgId ?? _findOrgByName(app.orgName)?.id;

    // Resolve the student's actual profiles.id. The members table links to
    // profiles through profile_id, so do not assume applications.user_id and
    // profiles.id are identical in older records.
    String? profileId;
    try {
      if (app.userId != null && app.userId!.trim().isNotEmpty) {
        final profile = await client
            .from('profiles')
            .select('id')
            .eq('id', app.userId!.trim())
            .maybeSingle();
        profileId = profile?['id']?.toString();
      }
      if ((profileId == null || profileId.isEmpty) &&
          app.studentId.trim().isNotEmpty) {
        final profile = await client
            .from('profiles')
            .select('id')
            .eq('student_id', app.studentId.trim())
            .maybeSingle();
        profileId = profile?['id']?.toString();
      }
      if ((profileId == null || profileId.isEmpty) &&
          app.email.trim().isNotEmpty) {
        final profile = await client
            .from('profiles')
            .select('id')
            .eq('email', app.email.trim())
            .maybeSingle();
        profileId = profile?['id']?.toString();
      }
    } catch (e) {
      debugPrint('Error resolving profile for membership: $e');
    }
    if ((profileId == null || profileId.isEmpty) &&
        currentStudent?.studentId == app.studentId) {
      profileId = currentStudent?.id;
    }
    profileId ??= app.userId;

    try {
      // Read the authoritative database status first. Some older records can
      // still be `interviewed` in Supabase while the officer screen already
      // shows `For Approval` locally. In that case, repair the persisted
      // workflow state before performing the final approval. This keeps the
      // application eligible without requiring the student to submit a
      // duplicate application.
      final remote = await client
          .from('applications')
          .select('status, interview_at')
          .eq('id', applicationId)
          .maybeSingle();

      final remoteStatus = remote?['status']?.toString();
      final remoteInterviewAt = remote?['interview_at'];

      if (remoteStatus == 'interviewed' && remoteInterviewAt != null) {
        await client
            .from('applications')
            .update({'status': 'for_approval'}).eq('id', applicationId);
      }

      await client
          .from('applications')
          .update({'status': 'approved'}).eq('id', applicationId);
    } catch (e) {
      debugPrint('Error updating application status: $e');
      return false;
    }

    // The application status change is the authoritative approval action.
    // Update the local state immediately, then perform membership/cache and
    // notification synchronization independently so a secondary sync issue
    // cannot incorrectly show "Failed to approve" after the application was
    // already approved in Supabase.
    applications[idx] = app.copyWith(status: ApplicationStatus.approved);
    notifyListeners();

    try {
      await addMember(
        name: app.name,
        position: defaultPosition,
        orgName: app.orgName,
        orgId: orgId,
        profileId: profileId,
      );
    } catch (e) {
      debugPrint('Membership sync after approval failed: $e');
    }

    if (profileId != null && profileId.isNotEmpty && orgId != null) {
      try {
        await _setProfileJoinedOrg(orgId, profileId: profileId);
      } catch (e) {
        debugPrint('Joined-organization sync after approval failed: $e');
      }
    }

    try {
      // The notification is created only after the application itself has
      // successfully changed to approved.
      await addNotification(Notification(
        id: _genId(),
        title: 'Congratulations!',
        message:
            'Congratulations, ${app.name}! You are officially a member of ${app.orgName}.',
        date: DateTime.now(),
        studentId: app.studentId,
        orgId: orgId,
      ));
    } catch (e) {
      debugPrint('Approval notification sync failed: $e');
    }

    try {
      await fetchMembers();
      await _syncCurrentStudentMemberships();
      await fetchNotifications();
    } catch (e) {
      debugPrint('Post-approval refresh failed: $e');
    }
    notifyListeners();
    return true;
  }

  Future<bool> scheduleInterview(
      String applicationId, DateTime interviewAt) async {
    final idx = applications.indexWhere((a) => a.id == applicationId);
    if (idx == -1) return false;
    final app = applications[idx];

    applications[idx] = app.copyWith(
      status: ApplicationStatus.interviewed,
      interviewAt: interviewAt,
    );

    final orgId = app.orgId ?? _findOrgByName(app.orgName)?.id;

    // Fetch the correct profile UUID for this student from Supabase
    await addNotification(Notification(
      id: _genId(),
      title: 'Interview Scheduled',
      message:
          'Your interview for ${app.orgName} has been scheduled on ${interviewAt.toLocal().toString()}.',
      date: DateTime.now(),
      orgId: orgId,
      studentId: app.userId,
    ));
    try {
      await supabase.Supabase.instance.client.from('applications').update({
        'status': 'interviewed',
        'interview_at': interviewAt.toIso8601String(),
      }).eq('id', app.id);
    } catch (e) {
      debugPrint('Error saving interview schedule to Supabase: $e');
    }

    notifyListeners();
    return true;
  }

  // ── Members ───────────────────────────────────────────────────────────────

  Future<Member> addMember({
    required String name,
    required String position,
    required String orgName,
    String? orgId,
    String? profileId,
  }) async {
    final client = supabase.Supabase.instance.client;
    final resolvedOrgId = orgId ?? _findOrgByName(orgName)?.id;

    // Do not create duplicate membership rows for the same student/org.
    if (profileId != null && profileId.isNotEmpty && resolvedOrgId != null) {
      try {
        final existing = await client
            .from('members')
            .select('id,name,position,org_name,org_id,profile_id')
            .eq('profile_id', profileId)
            .eq('org_id', resolvedOrgId)
            .maybeSingle();
        if (existing != null) {
          final member = Member(
            id: existing['id']?.toString() ?? _genId(),
            name: existing['name']?.toString() ?? name,
            position: _sanitizePosition(existing['position']?.toString()),
            orgName: existing['org_name']?.toString() ?? orgName,
            orgId: existing['org_id']?.toString() ?? resolvedOrgId,
            profileId: existing['profile_id']?.toString() ?? profileId,
          );
          final localIdx = members.indexWhere((m) => m.id == member.id);
          if (localIdx == -1) {
            members.add(member);
          } else {
            members[localIdx] = member;
          }
          notifyListeners();
          return member;
        }

        // Backfill an older member row that has the same name/org but no
        // profile_id yet. This prevents duplicate memberships when migrating
        // records created by older app versions.
        final oldRows = await client
            .from('members')
            .select('id,name,position,org_name,org_id,profile_id')
            .eq('org_id', resolvedOrgId);
        for (final row in (oldRows as List)) {
          final rowProfileId = row['profile_id']?.toString();
          final rowName = row['name']?.toString().trim().toLowerCase();
          if ((rowProfileId == null || rowProfileId.isEmpty) &&
              rowName == name.trim().toLowerCase()) {
            final rowId = row['id']?.toString();
            if (rowId != null && rowId.isNotEmpty) {
              final updated = await client
                  .from('members')
                  .update({'profile_id': profileId})
                  .eq('id', rowId)
                  .select()
                  .single();
              final member = Member(
                id: rowId,
                name: updated['name']?.toString() ?? name,
                position: _sanitizePosition(updated['position']?.toString()),
                orgName: updated['org_name']?.toString() ?? orgName,
                orgId: updated['org_id']?.toString() ?? resolvedOrgId,
                profileId: profileId,
              );
              final localIdx = members.indexWhere((m) => m.id == member.id);
              if (localIdx == -1) {
                members.add(member);
              } else {
                members[localIdx] = member;
              }
              notifyListeners();
              return member;
            }
          }
        }
      } catch (e) {
        debugPrint('Error checking existing membership: $e');
      }
    }

    final newId = _genId();
    try {
      final response = await client
          .from('members')
          .insert({
            'id': newId,
            'name': name,
            'position': position,
            'org_name': orgName,
            'org_id': resolvedOrgId,
            'profile_id': profileId,
          })
          .select()
          .single();

      final member = Member(
        id: response['id']?.toString() ?? newId,
        name: response['name']?.toString() ?? name,
        position: _sanitizePosition(response['position']?.toString()),
        orgName: response['org_name']?.toString() ?? orgName,
        orgId: response['org_id']?.toString() ?? resolvedOrgId,
        profileId: response['profile_id']?.toString() ?? profileId,
      );

      final localIdx = members.indexWhere((m) => m.id == member.id);
      if (localIdx == -1) {
        members.add(member);
      } else {
        members[localIdx] = member;
      }
      notifyListeners();
      return member;
    } catch (e) {
      debugPrint('Error saving member to Supabase: $e');
      // Return a local representation so the officer UI remains responsive,
      // but do not pretend that the server record was created.
      final member = Member(
        id: newId,
        name: name,
        position: _sanitizePosition(position),
        orgName: orgName,
        orgId: resolvedOrgId,
        profileId: profileId,
      );
      members.add(member);
      notifyListeners();
      return member;
    }
  }

  String? lastMemberUpdateError;

  Future<bool> updateMember(Member member) async {
    final client = supabase.Supabase.instance.client;
    lastMemberUpdateError = null;
    try {
      // Only change editable membership fields. Keeping org_id/profile_id
      // untouched avoids needless foreign-key/RLS failures on a position edit.
      final response = await client
          .from('members')
          .update({
            'name': member.name,
            'position': member.position,
            'org_name': member.orgName,
          })
          .eq('id', member.id)
          .select('id,name,position,org_name,org_id,profile_id')
          .maybeSingle();

      if (response == null) {
        lastMemberUpdateError =
            'No membership row was updated. Check the selected organization and database permissions.';
        debugPrint('Member update returned no row for id ${member.id}.');
        return false;
      }

      final saved = Member(
        id: response['id']?.toString() ?? member.id,
        name: response['name']?.toString() ?? member.name,
        position: _sanitizePosition(response['position']?.toString()),
        orgName: response['org_name']?.toString() ?? member.orgName,
        orgId: response['org_id']?.toString() ?? member.orgId,
        profileId: response['profile_id']?.toString() ?? member.profileId,
      );
      final idx = members.indexWhere((m) => m.id == saved.id);
      if (idx == -1) {
        members.add(saved);
      } else {
        members[idx] = saved;
      }
      notifyListeners();
      return true;
    } catch (e) {
      lastMemberUpdateError = e.toString();
      debugPrint('Error updating member in Supabase: $e');
      return false;
    }
  }

  Future<bool> removeMember(String id) async {
    try {
      await supabase.Supabase.instance.client
          .from('members')
          .delete()
          .eq('id', id);
    } catch (e) {
      debugPrint('Error deleting member from Supabase: $e');
    }

    final before = members.length;
    members.removeWhere((m) => m.id == id);
    final removed = members.length < before;
    if (removed) notifyListeners();
    return removed;
  }

  static const _validPositions = [
    'Member',
    'Officer',
    'President',
    'Vice President',
    'Secretary',
    'Assistant Secretary',
    'Treasurer'
  ];

  String _sanitizePosition(String? raw) {
    if (raw == null) return 'Member';
    // Try exact match first
    if (_validPositions.contains(raw)) return raw;
    // Try case-insensitive match
    final lower = raw.toLowerCase();
    for (final p in _validPositions) {
      if (p.toLowerCase() == lower) return p;
    }
    // No match — default to Member
    return 'Member';
  }

  Future<void> fetchMembers({String? organizationId}) async {
    final client = supabase.Supabase.instance.client;
    final requestedOrgId =
        (organizationId != null && organizationId.trim().isNotEmpty)
            ? organizationId.trim()
            : currentOfficerOrgId;
    try {
      // Use the exact organization membership key. The database can contain
      // valid members even when their profile role is still "student".
      final List<dynamic> response;
      if (requestedOrgId != null && requestedOrgId.isNotEmpty) {
        response = await client
            .from('members')
            .select('id,name,position,org_name,org_id,profile_id')
            .eq('org_id', requestedOrgId)
            .order('created_at', ascending: true);
      } else {
        response = await client
            .from('members')
            .select('id,name,position,org_name,org_id,profile_id')
            .order('created_at', ascending: true);
      }

      final loaded = <Member>[];
      for (final raw in response) {
        final item = Map<String, dynamic>.from(raw as Map);
        loaded.add(Member(
          id: item['id']?.toString() ?? '',
          name: item['name']?.toString() ?? 'Unnamed member',
          position: _sanitizePosition(item['position']?.toString()),
          orgName: item['org_name']?.toString() ?? '',
          orgId: item['org_id']?.toString(),
          profileId: item['profile_id']?.toString(),
        ));
      }

      // Replace only the requested organization's cache, preserving any other
      // organization members that may already be in memory.
      if (requestedOrgId != null && requestedOrgId.isNotEmpty) {
        members.removeWhere((m) => m.orgId == requestedOrgId);
        members.addAll(loaded);
      } else {
        members
          ..clear()
          ..addAll(loaded);
      }
      notifyListeners();
    } catch (e) {
      // Preserve the last known cache if the read fails; do not silently clear it.
      debugPrint(
          'Error fetching members from Supabase for org $requestedOrgId: $e');
    }
  }

  // ── Events ────────────────────────────────────────────────────────────────

  Future<void> fetchEvents() async {
    try {
      final response = await supabase.Supabase.instance.client
          .from('events')
          .select('*')
          .order('date', ascending: true);

      events.clear();
      for (var item in response) {
        // Parse image_urls array
        List<String> imageUrls = [];
        try {
          final raw = item['image_urls'];
          if (raw != null && raw is List) {
            imageUrls = List<String>.from(raw);
          }
        } catch (_) {}

        // Fallback: if imageUrls empty but image_url exists, use it
        final singleUrl = item['image_url'] as String?;
        if (imageUrls.isEmpty && singleUrl != null && singleUrl.isNotEmpty) {
          imageUrls = [singleUrl];
        }

        final createdAt =
            DateTime.tryParse(item['created_at']?.toString() ?? '')
                    ?.toLocal() ??
                DateTime.parse(item['date']).toLocal();

        events.add(Event(
          id: item['id'],
          title: item['title'],
          date: DateTime.parse(item['date']).toLocal(),
          description: item['description'] ?? '',
          orgName: item['org_name'] ?? '',
          orgId: item['org_id'],
          imageUrl: singleUrl,
          imageUrls: imageUrls,
          createdAt: createdAt,
          venue: item['venue']?.toString() ?? '',
          startTime: (item['start_time']?.toString().trim().isEmpty ?? true)
              ? null
              : item['start_time'].toString().trim(),
          endTime: (item['end_time']?.toString().trim().isEmpty ?? true)
              ? null
              : item['end_time'].toString().trim(),
        ));
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching events from Supabase: $e');
    }
  }

  Future<Event> addEvent({
    required String title,
    required DateTime date,
    required String description,
    required String orgName,
    String? orgId,
    String? imageUrl,
    List<String> imageUrls = const [], // ← NEW
  }) async {
    String newId = _genId();

    // Use first image as imageUrl for backward compat
    final firstUrl = imageUrls.isNotEmpty ? imageUrls.first : imageUrl;

    try {
      final response = await supabase.Supabase.instance.client
          .from('events')
          .insert({
            'title': title,
            'date': date.toIso8601String(),
            'description': description,
            'org_name': orgName,
            'org_id': orgId,
            'image_url': firstUrl,
            'image_urls': imageUrls, // ← NEW
          })
          .select()
          .single();

      newId = response['id'];
    } catch (err) {
      debugPrint('Error saving event to Supabase: $err');
    }

    final e = Event(
      id: newId,
      title: title,
      date: date,
      description: description,
      orgName: orgName,
      orgId: orgId,
      imageUrl: firstUrl,
      imageUrls: imageUrls,
      createdAt: DateTime.now(),
    );

    events.add(e);
    notifyListeners();
    return e;
  }

  Future<bool> updateEvent(Event event) async {
    final idx = events.indexWhere((e) => e.id == event.id);
    if (idx == -1) return false;

    final firstUrl =
        event.imageUrls.isNotEmpty ? event.imageUrls.first : event.imageUrl;

    try {
      await supabase.Supabase.instance.client.from('events').update({
        'title': event.title,
        'date': event.date.toIso8601String(),
        'description': event.description,
        'org_name': event.orgName,
        'org_id': event.orgId,
        'image_url': firstUrl,
        'image_urls': event.imageUrls, // ← NEW
      }).eq('id', event.id);
    } catch (e) {
      debugPrint('Error updating event in Supabase: $e');
    }

    events[idx] = event;
    notifyListeners();
    return true;
  }

  Future<bool> removeEvent(String id) async {
    try {
      await supabase.Supabase.instance.client
          .from('events')
          .delete()
          .eq('id', id);
    } catch (e) {
      debugPrint('Error deleting event from Supabase: $e');
    }

    final before = events.length;
    events.removeWhere((e) => e.id == id);
    final removed = events.length < before;
    if (removed) notifyListeners();
    return removed;
  }

  Future<Event?> addEventForCurrentOfficer({
    required String title,
    required DateTime date,
    required String description,
  }) async {
    final orgId = currentOfficerOrgId;
    if (orgId == null) return null;
    final org = _findOrgById(orgId);
    if (org == null) return null;
    return await addEvent(
        title: title,
        date: date,
        description: description,
        orgName: org.name,
        orgId: org.id);
  }

  // ── Notifications ─────────────────────────────────────────────────────────

  Application _applicationFromRow(Map<String, dynamic> item) {
    List<String> attachments = [];
    try {
      final raw = item['attachments'];
      if (raw is List) {
        attachments = raw.map((e) => e.toString()).toList();
      } else if (raw is String && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          attachments = decoded.map((e) => e.toString()).toList();
        }
      }
    } catch (_) {}

    return Application(
      id: item['id']?.toString() ?? '',
      userId: item['user_id']?.toString(),
      orgName: item['org_name']?.toString() ?? '',
      orgId: item['org_id']?.toString(),
      studentId: item['student_id']?.toString() ?? '',
      name: item['name']?.toString() ?? '',
      contact: item['contact']?.toString() ?? '',
      email: item['email']?.toString() ?? '',
      reason: item['reason']?.toString() ?? '',
      skills: item['skills']?.toString() ?? '',
      attachments: attachments,
      status: _parseStatus(item['status']?.toString()),
      createdAt: DateTime.tryParse(item['created_at']?.toString() ?? '') ??
          DateTime.now(),
      interviewAt: item['interview_at'] == null
          ? null
          : DateTime.tryParse(item['interview_at'].toString()),
      course: item['course']?.toString() ?? '',
      yearSection: item['year_section']?.toString() ?? '',
      facebook: item['facebook']?.toString() ?? '',
      experience: item['experience']?.toString() ?? '',
      emergencyContact: item['emergency_contact']?.toString() ?? '',
      profilePicUrl: item['profile_pic_url']?.toString() ?? '',
      declineReason: item['decline_reason']?.toString() ?? '',
    );
  }

  bool _isStudentHiddenWorkflowNotification(String title, String message) {
    final t = title.trim().toLowerCase();
    final m = message.trim().toLowerCase();
    const hiddenPhrases = [
      'proposal approved by admin',
      'proposal forwarded to admin',
      'proposal revision requested',
      'proposal sent back to officers',
      'final posting sent to adviser',
      'final posting',
      'creative submitted',
      'revision requested',
      'forwarded to admin',
      'approved and published',
      'admin / cso',
      'final pictures, venue, purpose, and time details',
    ];
    return hiddenPhrases
            .any((phrase) => t.contains(phrase) || m.contains(phrase)) ||
        (t == 'new event' && m.contains('approved and published'));
  }

  Future<void> fetchNotifications() async {
    final client = supabase.Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    final student = currentStudent;
    try {
      String schoolStudentId = student?.studentId ?? '';
      if (userId != null && userId.isNotEmpty) {
        try {
          final profile = await client
              .from('profiles')
              .select('id,student_id')
              .eq('id', userId)
              .maybeSingle();
          final dbStudentId = profile?['student_id']?.toString() ?? '';
          if (dbStudentId.isNotEmpty) schoolStudentId = dbStudentId;
        } catch (_) {}
      }

      // Determine the organizations this student is actually a member of.
      final memberOrgIds = <String>{};
      final memberOrgNames = <String>{};
      final memberOrganizations = <String, String>{};
      if (student != null && student.id.isNotEmpty) {
        try {
          final rows = await client
              .from('members')
              .select('org_id,org_name,profile_id,name')
              .eq('profile_id', student.id);
          for (final row in (rows as List)) {
            final orgId = row['org_id']?.toString().trim();
            final orgName = row['org_name']?.toString().trim() ?? '';
            if (orgId != null && orgId.isNotEmpty) memberOrgIds.add(orgId);
            if (orgName.isNotEmpty) {
              memberOrgNames.add(orgName.toLowerCase());
              if (orgId != null && orgId.isNotEmpty) {
                memberOrganizations[orgId] = orgName;
              }
            }
          }
        } catch (_) {}

        // Compatibility fallback for legacy members that were created before
        // profile_id was populated. The student's exact name is the only
        // available legacy link in that table.
        if (memberOrgIds.isEmpty && student.name.trim().isNotEmpty) {
          try {
            final rows = await client
                .from('members')
                .select('org_id,org_name,profile_id,name')
                .eq('name', student.name.trim());
            for (final row in (rows as List)) {
              final orgId = row['org_id']?.toString().trim();
              final orgName = row['org_name']?.toString().trim() ?? '';
              if (orgId != null && orgId.isNotEmpty) memberOrgIds.add(orgId);
              if (orgName.isNotEmpty) {
                memberOrgNames.add(orgName.toLowerCase());
                if (orgId != null && orgId.isNotEmpty) {
                  memberOrganizations[orgId] = orgName;
                }
              }
            }
          } catch (_) {}
        }
      }
      // Do not use the cached joinedOrgIds list as a notification source.\n      // It may contain stale membership data from an older app version.\n
      // Only real application records can authorize student-specific
      // application/interview/approval notifications. This prevents stale
      // notifications from an organization that the student no longer has an
      // application for from reappearing in the UI.
      final applicationOrgIds = <String>{};
      final applicationOrgNames = <String>{};
      Future<void> collectStudentApplications(
          String column, String value) async {
        try {
          final rows = await client
              .from('applications')
              .select('org_id,org_name')
              .eq(column, value);
          for (final row in (rows as List)) {
            final id = row['org_id']?.toString().trim();
            final name = row['org_name']?.toString().trim().toLowerCase() ?? '';
            if (id != null && id.isNotEmpty) applicationOrgIds.add(id);
            if (name.isNotEmpty) applicationOrgNames.add(name);
          }
        } catch (_) {}
      }

      if (userId != null && userId.isNotEmpty) {
        await collectStudentApplications('user_id', userId);
      }
      if (schoolStudentId.isNotEmpty) {
        await collectStudentApplications('student_id', schoolStudentId);
      }

      List<dynamic> response = const [];
      try {
        response = await client
            .from('notifications')
            .select('*')
            .order('created_at', ascending: false);
      } catch (e) {
        // Do not stop the notification screen here. A student's approval
        // message can still be synthesized from approved applications or
        // members below even when the notifications table is blocked by RLS.
        debugPrint('Error loading notification rows: $e');
      }

      notifications.clear();
      final seenStudentOrgNotificationKinds = <String>{};
      for (final item in response) {
        try {
          final rawStudentId = item['student_id']?.toString();
          final orgId = item['org_id']?.toString();
          final isPersonal = rawStudentId != null && rawStudentId.isNotEmpty;
          final belongsToCurrentStudent = isPersonal &&
              (rawStudentId == userId || rawStudentId == schoolStudentId);
          final isOrgAnnouncement =
              !isPersonal && orgId != null && memberOrgIds.contains(orgId);

          // Personal messages belong only to their student. Notifications with
          // no student_id are organization-wide announcements and are shown to
          // members of that organization.
          if (!belongsToCurrentStudent && !isOrgAnnouncement) continue;

          final rawTitle = item['title']?.toString() ?? '';
          final rawMessage = item['message']?.toString() ?? '';

          // Students should not receive internal Admin / CSO and final-posting
          // workflow updates. Those steps are handled between officers and the
          // adviser; students only see adviser announcements and the normal
          // student-facing interview/membership notifications.
          if (student != null &&
              orgId != null &&
              _isStudentHiddenWorkflowNotification(rawTitle, rawMessage)) {
            continue;
          }

          var title = rawTitle;
          var message = rawMessage;

          // A student must see only one workflow notification per organization
          // and category. The database can contain legacy duplicates, so the
          // UI intentionally keeps the newest row because the query is ordered
          // newest-first. Interview notices are one category; the final
          // membership/congratulations notice is a separate category.
          if (belongsToCurrentStudent && orgId != null && orgId.isNotEmpty) {
            final lowerTitle = rawTitle.toLowerCase();
            final lowerMessage = rawMessage.toLowerCase();
            final kind = (lowerTitle.contains('interview') ||
                    lowerMessage.contains('scheduled interview'))
                ? 'interview'
                : (lowerTitle.contains('congratulations') ||
                        lowerMessage.contains('officially a member'))
                    ? 'membership'
                    : null;
            if (kind != null) {
              final dedupeKey = '${userId ?? schoolStudentId}|$orgId|$kind';
              if (!seenStudentOrgNotificationKinds.add(dedupeKey)) {
                continue;
              }
            }
          }

          // Student-specific notifications must belong to an organization for
          // which a real application currently exists. Membership history,
          // cached state, and old notification rows cannot resurrect an old
          // application in the Notifications screen.
          if (belongsToCurrentStudent &&
              orgId != null &&
              !applicationOrgIds.contains(orgId)) {
            final notificationOrgName =
                memberOrganizations[orgId]?.toLowerCase() ?? '';
            if (notificationOrgName.isEmpty ||
                !applicationOrgNames.contains(notificationOrgName)) {
              continue;
            }
          }

          notifications.add(Notification(
            id: item['id']?.toString() ?? _genId(),
            title: title,
            message: message,
            date: DateTime.tryParse(
                    (item['date'] ?? item['created_at'])?.toString() ?? '') ??
                DateTime.now(),
            read: item['read'] == true,
            orgId: orgId,
            studentId: (belongsToCurrentStudent || isOrgAnnouncement)
                ? userId
                : rawStudentId,
          ));
        } catch (parseErr) {
          debugPrint('Error parsing notification: $parseErr');
        }
      }

      // Notifications are strictly database-backed here. Do not create or
      // reconstruct notification rows from applications or memberships.
      // A notification appears only after an actual notification row exists.

      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    }
  }

  Future<void> addNotification(Notification notification) async {
    try {
      final client = supabase.Supabase.instance.client;
      final title = notification.title.toLowerCase();
      final message = notification.message.toLowerCase();
      final isInterview = title.contains('interview') ||
          message.contains('scheduled interview');
      final isMembership = title.contains('congratulations') ||
          message.contains('officially a member');

      // Workflow notifications are idempotent: repeated scheduling/approval
      // actions update the existing student+organization notification instead
      // of creating another card. The final membership notice is written only
      // by approveApplication(), after the application is actually approved.
      if (notification.studentId != null &&
          notification.studentId!.isNotEmpty &&
          notification.orgId != null &&
          notification.orgId!.isNotEmpty &&
          (isInterview || isMembership)) {
        final existing = await client
            .from('notifications')
            .select('id')
            .eq('student_id', notification.studentId!)
            .eq('org_id', notification.orgId!)
            .ilike('title', isInterview ? '%interview%' : '%congratulations%')
            .order('created_at', ascending: false)
            .limit(1);

        if ((existing as List).isNotEmpty) {
          final existingId = existing.first['id']?.toString();
          if (existingId != null && existingId.isNotEmpty) {
            await client.from('notifications').update({
              'title': notification.title,
              'message': notification.message,
              'date': notification.date.toIso8601String(),
              'read': notification.read,
              'org_id': notification.orgId,
              'student_id': notification.studentId,
            }).eq('id', existingId);

            notifications.removeWhere((n) => n.id == existingId);
            notifications.add(notification.copyWith(id: existingId));
            notifyListeners();
            return;
          }
        }
      }

      await client.from('notifications').insert({
        'id': notification.id,
        'title': notification.title,
        'message': notification.message,
        'date': notification.date.toIso8601String(),
        'read': notification.read,
        'org_id': notification.orgId,
        'student_id': notification.studentId,
      });
      notifications.add(notification);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding notification: $e');
    }
  }

  Future<bool> updateNotification(Notification notification) async {
    try {
      await supabase.Supabase.instance.client.from('notifications').update({
        'title': notification.title,
        'message': notification.message,
        'date': notification.date.toIso8601String(),
        'read': notification.read,
        'org_id': notification.orgId,
        'student_id': notification.studentId,
      }).eq('id', notification.id);

      final idx = notifications.indexWhere((n) => n.id == notification.id);
      if (idx == -1) return false;
      notifications[idx] = notification;
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> removeNotification(String id) async {
    try {
      await supabase.Supabase.instance.client
          .from('notifications')
          .delete()
          .eq('id', id);

      final before = notifications.length;
      notifications.removeWhere((n) => n.id == id);
      final removed = notifications.length < before;
      if (removed) notifyListeners();
      return removed;
    } catch (e) {
      return false;
    }
  }

  Future<void> markNotificationRead(String id) async {
    final idx = notifications.indexWhere((n) => n.id == id);
    if (idx != -1 && !notifications[idx].read) {
      notifications[idx] = notifications[idx].copyWith(read: true);
      await updateNotification(notifications[idx]);
      notifyListeners();
    }
  }

  void setRole(UserRole? role) {
    selectedRole = role;
    notifyListeners();
  }

  Future<void> setStudentProfile(StudentProfile profile) async {
    currentStudent = profile;
    notifyListeners();
    await _saveStudentProfile();
  }

  Future<void> updateStudentProfile(
      StudentProfile Function(StudentProfile) updater) async {
    final s = currentStudent;
    if (s == null) return;
    currentStudent = updater(s);
    notifyListeners();
    await _saveStudentProfile();
  }

  void setOfficerOrgContext(String orgId) {
    currentOfficerOrgId = orgId;
    notifyListeners();
  }

  void setCurrentOfficerOrgId(String orgId) {
    currentOfficerOrgId = orgId;
    notifyListeners();
  }

  void removeApplications(List<String> ids) {
    applications.removeWhere((a) => ids.contains(a.id));
    notifyListeners();
  }

  List<Event> eventsForCurrentStudent() {
    return events;
  }

  void setUserRole(String userId, UserRole role) {
    final idx = users.indexWhere((u) => u.id == userId);
    if (idx != -1) {
      users[idx] = users[idx].copyWith(role: role);
      notifyListeners();
    }
  }

  void toggleUserActive(String userId) {
    final idx = users.indexWhere((u) => u.id == userId);
    if (idx != -1) {
      final u = users[idx];
      users[idx] = u.copyWith(active: !u.active);
      notifyListeners();
    }
  }

  void setUserActive(String userId, bool active) {
    final idx = users.indexWhere((u) => u.id == userId);
    if (idx != -1) {
      users[idx] = users[idx].copyWith(active: active);
      notifyListeners();
    }
  }

  Future<void> removeOrganization(String orgId) async {
    try {
      await supabase.Supabase.instance.client
          .from('organizations')
          .delete()
          .eq('id', orgId);
      organizations.removeWhere((o) => o.id == orgId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting organization from Supabase: $e');
    }
  }

  Future<void> updateOrganization(Organization org) async {
    try {
      await supabase.Supabase.instance.client.from('organizations').update({
        'name': org.name,
        'logo_asset': org.logoAsset,
        'short_desc': org.shortDesc,
        'acronym': org.acronym,
        'category': org.category,
        'about': org.about,
        'mission': org.mission,
        'vision': org.vision,
        'goals': org.goals,
        'mission_vision': org.missionVision,
        'adviser': org.adviser,
        'contact_email': org.contactEmail,
        'contact_phone': org.contactPhone,
        'social_link': org.socialLink,
        'officers': org.officers,
        'officer_profiles': org.officerProfiles.map((e) => e.toJson()).toList(),
        'activities_highlights':
            org.activitiesHighlights.map((e) => e.toJson()).toList(),
        'officer_password': org.officerPassword,
      }).eq('id', org.id);
      final idx = organizations.indexWhere((o) => o.id == org.id);
      if (idx != -1) {
        organizations[idx] = org;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating organization in Supabase: $e');
    }
  }

  Future<void> addOrganization({
    required String name,
    required String logoAsset,
    required String shortDesc,
    String acronym = '',
    String category = '',
    String about = '',
    String mission = '',
    String vision = '',
    String goals = '',
    String missionVision = '',
    String adviser = '',
    String contactEmail = '',
    String contactPhone = '',
    String socialLink = '',
    String officerPassword = 'officer123',
  }) async {
    final existingNumbers =
        organizations.map((o) => int.tryParse(o.id) ?? 0).toList();
    final nextNumber = existingNumbers.isEmpty
        ? 1
        : (existingNumbers.reduce((a, b) => a > b ? a : b) + 1);
    final newId = nextNumber.toString().padLeft(3, '0');
    final newOrg = Organization(
      id: newId,
      name: name,
      logoAsset: logoAsset,
      shortDesc: shortDesc,
      acronym: acronym,
      category: category,
      about: about,
      mission: mission,
      vision: vision,
      goals: goals,
      missionVision: missionVision,
      adviser: adviser,
      contactEmail: contactEmail,
      contactPhone: contactPhone,
      socialLink: socialLink,
      officerPassword: officerPassword,
    );
    try {
      await supabase.Supabase.instance.client.from('organizations').insert({
        'id': newId,
        'name': name,
        'logo_asset': logoAsset,
        'short_desc': shortDesc,
        'acronym': acronym,
        'category': category,
        'about': about,
        'mission': mission,
        'vision': vision,
        'goals': goals,
        'mission_vision': missionVision,
        'adviser': adviser,
        'contact_email': contactEmail,
        'contact_phone': contactPhone,
        'social_link': socialLink,
        'officers': [],
        'officer_profiles': [],
        'activities_highlights': [],
        'officer_password': officerPassword,
      });
      organizations.add(newOrg);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding organization to Supabase: $e');
    }
  }

  static String _genId() => const Uuid().v4();

  Organization? _findOrgByName(String name) {
    try {
      return organizations.firstWhere((o) => o.name == name);
    } catch (_) {
      return null;
    }
  }

  Organization? _findOrgById(String id) {
    try {
      return organizations.firstWhere((o) => o.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<String> uploadAvatar(Uint8List bytes, String userId) async {
    // Use a unique filename every upload to bust CDN + Flutter image cache
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '$userId/$timestamp.jpg';

    await supabase.Supabase.instance.client.storage.from('avatar').uploadBinary(
          path,
          bytes,
          fileOptions: const supabase.FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    final publicUrl = supabase.Supabase.instance.client.storage
        .from('avatar')
        .getPublicUrl(path);

    return publicUrl;
  }

  Future<void> _setProfileJoinedOrg(String orgId, {String? profileId}) async {
    final student = currentStudent;
    final id = profileId ?? student?.id;
    if (id == null || id.isEmpty) return;

    final currentIds = <String>{...(student?.joinedOrgIds ?? const <String>[])};
    currentIds.add(orgId);
    final nextIds = currentIds.toList();

    if (student != null && student.id == id) {
      currentStudent = student.copyWith(joinedOrgIds: nextIds);
      await _saveStudentProfileLocalOnly();
    }

    try {
      await supabase.Supabase.instance.client
          .from('profiles')
          .update({'joined_org_ids': nextIds}).eq('id', id);
    } catch (e) {
      try {
        await supabase.Supabase.instance.client
            .from('profiles')
            .update({'joined_org_ids': jsonEncode(nextIds)}).eq('id', id);
      } catch (inner) {
        debugPrint('Error syncing joined_org_ids: $inner');
      }
    }
  }

  Future<void> _saveStudentProfileLocalOnly() async {
    _prefs ??= await SharedPreferences.getInstance();
    if (currentStudent == null) return;
    await _prefs!.setString(
      'student_profile',
      jsonEncode({
        'id': currentStudent!.id,
        'name': currentStudent!.name,
        'email': currentStudent!.email,
        'studentId': currentStudent!.studentId,
        'contact': currentStudent!.contact,
        'facebook': currentStudent!.facebook,
        'avatarUrl': currentStudent!.avatarUrl,
        'joinedOrgIds': currentStudent!.joinedOrgIds,
      }),
    );
  }

  Future<void> loadStudentProfile() async {
    _prefs ??= await SharedPreferences.getInstance();

    // 1. Load from SharedPreferences first (fast, offline fallback)
    final profileJson = _prefs!.getString('student_profile');
    if (profileJson != null) {
      try {
        final data = jsonDecode(profileJson) as Map<String, dynamic>;
        currentStudent = StudentProfile(
          id: data['id'] ?? '',
          name: data['name'] ?? '',
          email: data['email'] ?? '',
          studentId: data['studentId'] ?? '',
          contact: data['contact'] ?? '',
          facebook: data['facebook'] ?? '',
          avatarUrl: data['avatarUrl'] ?? '',
          joinedOrgIds: List<String>.from(data['joinedOrgIds'] ?? []),
        );
      } catch (_) {}
    }

    // 2. Always fetch fresh data from Supabase (gets latest avatar_url)
    try {
      final userId = supabase.Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final response = await supabase.Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();

        if (response != null) {
          currentStudent = StudentProfile(
            id: response['id'] ?? '',
            name: response['name'] ?? '',
            email: response['email'] ?? '',
            studentId: response['student_id'] ?? '',
            contact: response['contact'] ?? '',
            facebook: response['facebook'] ?? '',
            avatarUrl: response['avatar_url'] ?? '',
            joinedOrgIds: _parseJoinedOrgIds(response['joined_org_ids']),
          );

          // Update SharedPreferences with the latest data
          await _prefs!.setString(
              'student_profile',
              jsonEncode({
                'id': currentStudent!.id,
                'name': currentStudent!.name,
                'email': currentStudent!.email,
                'studentId': currentStudent!.studentId,
                'contact': currentStudent!.contact,
                'facebook': currentStudent!.facebook,
                'avatarUrl': currentStudent!.avatarUrl,
                'joinedOrgIds': currentStudent!.joinedOrgIds,
              }));

          // Applications can finish loading before the profile request.
          // Refresh them now that the real student id is known so legacy
          // applications (including older rows without user_id) are visible.
          await fetchApplications();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error fetching profile from Supabase: $e');
    }
  }

  List<String> _parseJoinedOrgIds(dynamic raw) {
    try {
      if (raw is List) {
        return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
      }
      if (raw is String && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList();
        }
        // PostgreSQL text[] can sometimes arrive in {id,id} form.
        final trimmed = raw.trim();
        if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
          return trimmed
              .substring(1, trimmed.length - 1)
              .split(',')
              .map((e) => e.trim().replaceAll('"', ''))
              .where((e) => e.isNotEmpty)
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<void> syncCurrentStudentMemberships() =>
      _syncCurrentStudentMemberships();

  Future<void> _syncCurrentStudentMemberships() async {
    final student = currentStudent;
    final client = supabase.Supabase.instance.client;
    final authUserId = client.auth.currentUser?.id;
    if (student == null || student.id.isEmpty) return;

    final joinedIds = <String>{};

    // Existing membership records.
    try {
      final rows = await client
          .from('members')
          .select('org_id,org_name,profile_id')
          .eq('profile_id', student.id);
      for (final row in (rows as List)) {
        final id = row['org_id']?.toString().trim();
        if (id != null && id.isNotEmpty) joinedIds.add(id);
      }
    } catch (e) {
      debugPrint('Error loading member rows: $e');
    }

    // Approved applications are a second source of truth. This is important
    // for older approved applications whose members/profile cache was never
    // updated.
    Future<void> collectApproved(String column, String value) async {
      try {
        final rows =
            await client.from('applications').select('*').eq(column, value);
        for (final row in (rows as List)) {
          final status = row['status']?.toString().trim().toLowerCase();
          if (status != 'approved' && status != 'accepted') continue;

          final orgId = row['org_id']?.toString().trim();
          final orgName = row['org_name']?.toString().trim() ?? '';
          if (orgId != null && orgId.isNotEmpty) {
            joinedIds.add(orgId);
          } else if (orgName.isNotEmpty) {
            final org = _findOrgByName(orgName);
            if (org != null) joinedIds.add(org.id);
          }
        }
      } catch (e) {
        debugPrint('Error loading approved applications by $column: $e');
      }
    }

    if (authUserId != null && authUserId.isNotEmpty) {
      await collectApproved('user_id', authUserId);
    }
    final studentId = student.studentId.trim();
    if (studentId.isNotEmpty) {
      await collectApproved('student_id', studentId);
    }

    // Save the cache to the local profile and Supabase. The UI does not rely
    // solely on this cache, but keeping it updated makes the dashboard count
    // and Joined Orgs entry point reflect membership immediately.
    final nextIds = joinedIds.toList()..sort();
    final existing = [...student.joinedOrgIds]..sort();
    final changed = nextIds.length != existing.length ||
        nextIds.asMap().entries.any((e) => e.value != existing[e.key]);

    if (!changed) return; // nothing to write -> no realtime echo

    currentStudent = student.copyWith(joinedOrgIds: nextIds);
    await _saveStudentProfileLocalOnly();

    try {
      await client
          .from('profiles')
          .update({'joined_org_ids': nextIds}).eq('id', student.id);
    } catch (e) {
      try {
        await client.from('profiles').update(
            {'joined_org_ids': jsonEncode(nextIds)}).eq('id', student.id);
      } catch (inner) {
        debugPrint('Error saving joined_org_ids: $inner');
      }
    }

    notifyListeners();
  }

  Future<void> _saveStudentProfile() async {
    _prefs ??= await SharedPreferences.getInstance();
    if (currentStudent != null) {
      final data = {
        'id': currentStudent!.id,
        'name': currentStudent!.name,
        'email': currentStudent!.email,
        'studentId': currentStudent!.studentId,
        'contact': currentStudent!.contact,
        'facebook': currentStudent!.facebook,
        'avatarUrl': currentStudent!.avatarUrl,
        'joinedOrgIds': currentStudent!.joinedOrgIds,
      };

      await _prefs!.setString('student_profile', jsonEncode(data));

      try {
        final profileData = {
          'id': currentStudent!.id,
          'name': currentStudent!.name,
          'email': currentStudent!.email,
          'student_id': currentStudent!.studentId,
          'contact': currentStudent!.contact,
          'facebook': currentStudent!.facebook,
          'avatar_url': currentStudent!.avatarUrl,
          'joined_org_ids': currentStudent!.joinedOrgIds,
        };

        await supabase.Supabase.instance.client
            .from('profiles')
            .upsert(profileData)
            .select();
      } catch (e) {
        debugPrint('Error saving profile to Supabase: $e');
      }
    } else {
      await _prefs!.remove('student_profile');
    }
  }

  Future<String?> uploadEventImage(Uint8List bytes, String eventId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '$eventId/$timestamp.jpg';

      await supabase.Supabase.instance.client.storage
          .from('event_images')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const supabase.FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      return supabase.Supabase.instance.client.storage
          .from('event_images')
          .getPublicUrl(path);
    } catch (e) {
      debugPrint('Error uploading event image: $e');
      return null;
    }
  }
}
