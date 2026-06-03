import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Roles supported by the app
enum UserRole { student, officer, admin }

/// Application status lifecycle
enum ApplicationStatus {
  pending,
  for_approval,
  accepted,
  interview_scheduled,
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

  Member({
    required this.id,
    required this.name,
    required this.position,
    required this.orgName,
    this.orgId,
  });

  Member copyWith(
          {String? id,
          String? name,
          String? position,
          String? orgName,
          String? orgId}) =>
      Member(
        id: id ?? this.id,
        name: name ?? this.name,
        position: position ?? this.position,
        orgName: orgName ?? this.orgName,
        orgId: orgId ?? this.orgId,
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
  final String? imageUrl; // ← keep for backward compat
  final List<String> imageUrls; // ← NEW: multiple images

  Event({
    required this.id,
    required this.title,
    required this.date,
    required this.description,
    required this.orgName,
    this.orgId,
    this.imageUrl,
    this.imageUrls = const [], // ← NEW
  });

  Event copyWith({
    String? id,
    String? title,
    DateTime? date,
    String? description,
    String? orgName,
    String? orgId,
    String? imageUrl,
    List<String>? imageUrls, // ← NEW
  }) =>
      Event(
        id: id ?? this.id,
        title: title ?? this.title,
        date: date ?? this.date,
        description: description ?? this.description,
        orgName: orgName ?? this.orgName,
        orgId: orgId ?? this.orgId,
        imageUrl: imageUrl ?? this.imageUrl,
        imageUrls: imageUrls ?? this.imageUrls, // ← NEW
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
  final String caption;

  const OrgMediaItem({
    required this.type,
    required this.content,
    this.caption = '',
  });

  factory OrgMediaItem.fromJson(dynamic raw) {
    // Backward compat: old plain strings become text items
    if (raw is String) return OrgMediaItem(type: 'text', content: raw);
    if (raw is Map) {
      return OrgMediaItem(
        type: raw['type']?.toString() ?? 'text',
        content: raw['content']?.toString() ?? '',
        caption: raw['caption']?.toString() ?? '',
      );
    }
    return const OrgMediaItem(type: 'text', content: '');
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'content': content,
        'caption': caption,
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
  final String missionVision;
  final String adviser;
  final String contactEmail;
  final String contactPhone;
  final String socialLink;
  final List<String> officers;
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
    this.missionVision = '',
    this.adviser = '',
    this.contactEmail = '',
    this.contactPhone = '',
    this.socialLink = '',
    this.officers = const [],
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
    String? missionVision,
    String? adviser,
    String? contactEmail,
    String? contactPhone,
    String? socialLink,
    List<String>? officers,
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
        missionVision: missionVision ?? this.missionVision,
        adviser: adviser ?? this.adviser,
        contactEmail: contactEmail ?? this.contactEmail,
        contactPhone: contactPhone ?? this.contactPhone,
        socialLink: socialLink ?? this.socialLink,
        officers: officers ?? this.officers,
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
        name: 'Student User',
        email: 'student@example.com',
        role: UserRole.student,
        active: true,
        studentId: '123456789'),
  ];
  final List<Notification> notifications = <Notification>[];
  supabase.RealtimeChannel? _applicationsChannel;
  supabase.RealtimeChannel? _notificationsChannel;

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
          missionVision: item['mission_vision'] ?? '',
          adviser: item['adviser'] ?? '',
          contactEmail: item['contact_email'] ?? '',
          contactPhone: item['contact_phone'] ?? '',
          socialLink: item['social_link'] ?? '',
          officers: officers,
          activitiesHighlights: activitiesHighlights,
          officerPassword: item['officer_password'] ?? 'officer123',
        ));
      }
    } catch (e) {
      print('Error fetching organizations from Supabase: $e');
    } finally {
      isLoadingOrganizations = false;
      notifyListeners();
    }
  }

// ── Real-time subscriptions ───────────────────────────────────────────────
  void _subscribeToRealtime() {
    _applicationsChannel = supabase.Supabase.instance.client
        .channel('public:applications')
        .onPostgresChanges(
          event: supabase.PostgresChangeEvent.all,
          schema: 'public',
          table: 'applications',
          callback: (payload) => fetchApplications(),
        )
        .subscribe();

    _notificationsChannel = supabase.Supabase.instance.client
        .channel('public:notifications')
        .onPostgresChanges(
          event: supabase.PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          callback: (payload) => fetchNotifications(),
        )
        .subscribe();
  }
  // ── Status helper ─────────────────────────────────────────────────────────

  /// Converts a Supabase status string back to the [ApplicationStatus] enum.
  /// Falls back to [ApplicationStatus.pending] for any unrecognised value.
  ApplicationStatus _parseStatus(String? status) {
    switch (status) {
      case 'for_approval':
        return ApplicationStatus.for_approval;
      case 'accepted':
        return ApplicationStatus.accepted;
      case 'interview_scheduled':
        return ApplicationStatus.interview_scheduled;
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
      final query =
          supabase.Supabase.instance.client.from('applications').select('*');

      final response = currentOfficerOrgId != null
          ? await query.eq('org_id', currentOfficerOrgId!)
          : await query;

      applications.clear();
      for (var item in response) {
        // attachments is stored as jsonb; decode safely.
        List<String> attachments = [];
        try {
          final raw = item['attachments'];
          if (raw != null) {
            if (raw is List) {
              attachments = List<String>.from(raw);
            } else if (raw is String) {
              attachments = List<String>.from(jsonDecode(raw));
            }
          }
        } catch (_) {}

        applications.add(Application(
          id: item['id'],
          userId: item['user_id'],
          orgName: item['org_name'] ?? '',
          orgId: item['org_id'],
          studentId: item['student_id'] ?? '',
          name: item['name'] ?? '',
          contact: item['contact'] ?? '',
          email: item['email'] ?? '',
          reason: item['reason'] ?? '',
          skills: item['skills'] ?? '',
          attachments: attachments,
          status: _parseStatus(item['status']),
          createdAt: DateTime.parse(item['created_at']),
          interviewAt: item['interview_at'] != null
              ? DateTime.parse(item['interview_at'])
              : null,
          course: item['course'] ?? '',
          yearSection: item['year_section'] ?? '',
          facebook: item['facebook'] ?? '',
          experience: item['experience'] ?? '',
          emergencyContact: item['emergency_contact'] ?? '',
          profilePicUrl: item['profile_pic_url'] ?? '',
        ));
      }
      notifyListeners();
    } catch (e) {
      print('Error fetching applications from Supabase: $e');
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
    String profilePicUrl = '',
    List<String> attachments = const [],
  }) async {
    final currentUser = supabase.Supabase.instance.client.auth.currentUser;

    // Guard: user must be logged in
    if (currentUser == null) {
      throw Exception('User not logged in');
    }

    final found = _findOrgByName(orgName);
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
        'attachments': jsonEncode(app.attachments),
        'created_at': app.createdAt.toIso8601String(),
        'status': app.status.toString().split('.').last,
        'course': app.course,
        'year_section': app.yearSection,
        'facebook': app.facebook,
        'experience': app.experience,
        'emergency_contact': app.emergencyContact,
        'profile_pic_url': app.profilePicUrl,
      });
      print('SUCCESS: Application inserted with user_id: ${currentUser.id}');
    } catch (e) {
      print('Error persisting application to Supabase: $e');
    }

    notifyListeners();
    return app;
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
        .then((_) {})
        .catchError((e) => print('Error updating status: $e'));

    notifyListeners();
    return true;
  }

  Future<bool> approveApplication(String applicationId,
      {String defaultPosition = 'Member'}) async {
    final idx = applications.indexWhere((a) => a.id == applicationId);
    if (idx == -1) return false;
    final app = applications[idx];
    applications[idx] = app.copyWith(status: ApplicationStatus.accepted);

    // ✅ ADD THIS — save accepted status to Supabase
    try {
      await supabase.Supabase.instance.client
          .from('applications')
          .update({'status': 'accepted'}).eq('id', applicationId);
    } catch (e) {
      print('Error updating application status: $e');
    }

    await addMember(
      name: app.name,
      position: defaultPosition,
      orgName: app.orgName,
      orgId: app.orgId,
    );

    if (currentStudent != null && currentStudent!.studentId == app.studentId) {
      final joined = Set<String>.from(currentStudent!.joinedOrgIds);
      final orgId = app.orgId ?? _findOrgByName(app.orgName)?.id;
      if (orgId != null) {
        joined.add(orgId);
        currentStudent =
            currentStudent!.copyWith(joinedOrgIds: joined.toList());
      }
    }

    // Find the matching student profile id (UUID) from the application's studentId (school ID)
    // Fetch the correct profile UUID for this student from Supabase
    await addNotification(Notification(
      id: _genId(),
      title: 'Application Accepted',
      message:
          'Your application to ${app.orgName} has been accepted. You are now a member.',
      date: DateTime.now(),
      studentId: app.userId,
      orgId: app.orgId,
    ));
    notifyListeners();
    return true;
  }

  Future<bool> scheduleInterview(
      String applicationId, DateTime interviewAt) async {
    final idx = applications.indexWhere((a) => a.id == applicationId);
    if (idx == -1) return false;
    final app = applications[idx];

    applications[idx] = app.copyWith(
      status: ApplicationStatus.interview_scheduled, // ✅ correct
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
        'status': 'interview_scheduled',
        'interview_at': interviewAt.toIso8601String(),
      }).eq('id', app.id);
    } catch (e) {
      print('Error saving interview schedule to Supabase: $e');
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
  }) async {
    String newId = _genId(); // fallback only if Supabase fails
    try {
      final response = await supabase.Supabase.instance.client
          .from('members')
          .insert({
            'id': newId, // ← ADD THIS — members table needs id sent manually
            'name': name,
            'position': position,
            'org_name': orgName,
            'org_id': orgId,
          })
          .select()
          .single();
      newId = response['id'];
    } catch (e) {
      print('Error saving member to Supabase: $e');
    }
    final m = Member(
      id: newId,
      name: name,
      position: position,
      orgName: orgName,
      orgId: orgId,
    );
    members.add(m);
    notifyListeners();
    return m;
  }

  Future<bool> updateMember(Member member) async {
    final idx = members.indexWhere((m) => m.id == member.id);
    if (idx == -1) return false;

    try {
      await supabase.Supabase.instance.client.from('members').update({
        'name': member.name,
        'position': member.position,
        'org_name': member.orgName,
        'org_id': member.orgId,
      }).eq('id', member.id);
    } catch (e) {
      print('Error updating member in Supabase: $e');
    }

    members[idx] = member;
    notifyListeners();
    return true;
  }

  Future<bool> removeMember(String id) async {
    try {
      await supabase.Supabase.instance.client
          .from('members')
          .delete()
          .eq('id', id);
    } catch (e) {
      print('Error deleting member from Supabase: $e');
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
    'Secretary'
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

  Future<void> fetchMembers() async {
    try {
      final query =
          supabase.Supabase.instance.client.from('members').select('*');

      final response = currentOfficerOrgId != null
          ? await query.eq('org_id', currentOfficerOrgId!)
          : await query;

      members.clear();
      for (var item in response) {
        members.add(Member(
          id: item['id'],
          name: item['name'],
          // AFTER
          position: _sanitizePosition(item['position']),
          orgName: item['org_name'] ?? '',
          orgId: item['org_id'],
        ));
      }
      notifyListeners();
    } catch (e) {
      print('Error fetching members from Supabase: $e');
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

        events.add(Event(
          id: item['id'],
          title: item['title'],
          date: DateTime.parse(item['date']),
          description: item['description'] ?? '',
          orgName: item['org_name'] ?? '',
          orgId: item['org_id'],
          imageUrl: singleUrl,
          imageUrls: imageUrls,
        ));
      }
      notifyListeners();
    } catch (e) {
      print('Error fetching events from Supabase: $e');
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
      print('Error saving event to Supabase: $err');
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
      print('Error updating event in Supabase: $e');
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
      print('Error deleting event from Supabase: $e');
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

  Future<void> fetchNotifications() async {
    try {
      final response = await supabase.Supabase.instance.client
          .from('notifications')
          .select('*')
          .order('created_at', ascending: false);

      notifications.clear();
      for (var item in response) {
        try {
          notifications.add(Notification(
            id: item['id'],
            title: item['title'] ?? '',
            message: item['message'] ?? '',
            date: DateTime.parse(item['date'] ?? item['created_at']),
            read: item['read'] ?? false,
            orgId: item['org_id'],
            studentId: item['student_id'],
          ));
        } catch (parseErr) {
          print('Error parsing notification: $parseErr');
        }
      }
      notifyListeners();
    } catch (e) {
      print('Error fetching notifications: $e');
    }
  }

  Future<void> addNotification(Notification notification) async {
    try {
      await supabase.Supabase.instance.client.from('notifications').insert({
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
      print('Error adding notification: $e');
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
      print('Error deleting organization from Supabase: $e');
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
        'mission_vision': org.missionVision,
        'adviser': org.adviser,
        'contact_email': org.contactEmail,
        'contact_phone': org.contactPhone,
        'social_link': org.socialLink,
        'officers': org.officers,
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
      print('Error updating organization in Supabase: $e');
    }
  }

  Future<void> addOrganization({
    required String name,
    required String logoAsset,
    required String shortDesc,
    String acronym = '',
    String category = '',
    String about = '',
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
        'mission_vision': missionVision,
        'adviser': adviser,
        'contact_email': contactEmail,
        'contact_phone': contactPhone,
        'social_link': socialLink,
        'officers': [],
        'activities_highlights': [],
        'officer_password': officerPassword,
      });
      organizations.add(newOrg);
      notifyListeners();
    } catch (e) {
      print('Error adding organization to Supabase: $e');
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
            avatarUrl:
                response['avatar_url'] ?? '', // ✅ fresh URL from Supabase
            joinedOrgIds: currentStudent?.joinedOrgIds ?? [],
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

          notifyListeners();
        }
      }
    } catch (e) {
      print('Error fetching profile from Supabase: $e');
    }
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
          'joined_org_ids': jsonEncode(currentStudent!.joinedOrgIds),
        };

        await supabase.Supabase.instance.client
            .from('profiles')
            .upsert(profileData)
            .select();
      } catch (e) {
        print('Error saving profile to Supabase: $e');
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
      print('Error uploading event image: $e');
      return null;
    }
  }
}
