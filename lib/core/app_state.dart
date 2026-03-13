import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Roles supported by the app
enum UserRole { student, officer, admin }

/// Application status lifecycle
enum ApplicationStatus { pending, for_approval, accepted, interview_scheduled, declined }

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
  final List<String> joinedOrgIds; // org IDs the student belongs to

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
  final String orgName; // kept for backward compatibility
  final String? orgId; // preferred linkage
  final String studentId;
  final String name;
  final String contact;
  final String email;
  final String reason;
  final String skills;
  final DateTime createdAt;
  ApplicationStatus status;
  final DateTime? interviewAt;
  final List<String> attachments; // file names only (in-memory placeholder)

  Application({
    required this.id,
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
  });

  Application copyWith({
    String? id,
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
  final String position; // e.g., Officer, Member
  final String orgName; // kept for backward compatibility
  final String? orgId; // preferred linkage

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
class Event {
  final String id;
  final String title;
  final DateTime date;
  final String description;
  final String orgName; // kept for backward compatibility
  final String? orgId; // preferred linkage

  Event({
    required this.id,
    required this.title,
    required this.date,
    required this.description,
    required this.orgName,
    this.orgId,
  });

  Event copyWith({
    String? id,
    String? title,
    DateTime? date,
    String? description,
    String? orgName,
    String? orgId,
  }) =>
      Event(
        id: id ?? this.id,
        title: title ?? this.title,
        date: date ?? this.date,
        description: description ?? this.description,
        orgName: orgName ?? this.orgName,
        orgId: orgId ?? this.orgId,
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

/// Organization metadata
class Organization {
  final String id;
  final String name;
  final String logoAsset;
  final String shortDesc;

  // Extended profile fields (optional)
  final String acronym;
  final String category; // Academic, Sports, Arts, etc.
  final String about; // description / about (long)
  final String missionVision;
  final String adviser;
  final String contactEmail;
  final String contactPhone;
  final String socialLink;
  final List<String> officers; // President, VP, etc. (display only)
  final List<String> activitiesHighlights; // highlights/upcoming (display only)

  // Officer login
  final String officerPassword; // simple in-memory password for the org officer

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
    this.activitiesHighlights = const [],
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
    List<String>? activitiesHighlights,
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
/// Persists student profile data using SharedPreferences.
class AppState extends ChangeNotifier {
  AppState._internal() {
    loadStudentProfile();
    organizations = [
      Organization(
        id: '001',
        name: 'PRIMERA BIDA',
        logoAsset: 'assets/primerabida.jpg',
        shortDesc: 'Premier theater organization showcasing student talent',
        acronym: 'PB',
        category: 'Arts & Performance',
        about:
            'Primera Bida is the premier theater organization dedicated to nurturing and showcasing the dramatic talents of students. We provide a platform for creative expression through various theatrical productions.',
        missionVision:
            'To foster artistic excellence and provide students with opportunities to explore their creative potential through theater arts.',
        adviser: 'Prof. Maria Santos',
        contactEmail: 'primerabida@university.edu',
        contactPhone: '+63 912 345 6789',
        socialLink: 'facebook.com/primerabida',
        officers: [
          'President: Juan Cruz',
          'Vice President: Ana Reyes',
          'Secretary: Mark Santos'
        ],
        activitiesHighlights: [
          'Annual Theater Festival',
          'Drama Workshops',
          'Student Play Productions'
        ],
        officerPassword: '001',
      ),
      Organization(
        id: '002',
        name: 'EL TEATRO',
        logoAsset: 'assets/eltiatro.jpg',
        shortDesc: 'Experimental theater group pushing creative boundaries',
        acronym: 'ET',
        category: 'Arts & Performance',
        about:
            'El Teatro is an experimental theater group that pushes the boundaries of traditional theater, exploring innovative forms of storytelling and performance art.',
        missionVision:
            'To challenge conventional theater norms and inspire creative innovation among students.',
        adviser: 'Prof. Roberto Garcia',
        contactEmail: 'eltiatro@university.edu',
        contactPhone: '+63 923 456 7890',
        socialLink: 'facebook.com/eltiatro',
        officers: [
          'Artistic Director: Sofia Martinez',
          'Production Manager: Luis Torres',
          'Creative Head: Carla Mendoza'
        ],
        activitiesHighlights: [
          'Experimental Plays',
          'Improv Nights',
          'Performance Art Shows'
        ],
        officerPassword: '002',
      ),
      Organization(
        id: '003',
        name: 'CRONICA',
        logoAsset: 'assets/cronica.jpg',
        shortDesc: 'Student publication covering campus news and events',
        acronym: 'CRN',
        category: 'Media & Publications',
        about:
            'Cronica is the official student publication that covers campus news, events, and issues affecting the student community.',
        missionVision:
            'To inform, engage, and empower the student body through quality journalism and creative writing.',
        adviser: 'Prof. Elena Rodriguez',
        contactEmail: 'cronica@university.edu',
        contactPhone: '+63 934 567 8901',
        socialLink: 'facebook.com/cronica',
        officers: [
          'Editor-in-Chief: Miguel Santos',
          'Managing Editor: Patricia Cruz',
          'News Editor: Ramon Garcia'
        ],
        activitiesHighlights: [
          'Monthly Newsletter',
          'Campus News Coverage',
          'Feature Writing Workshops'
        ],
        officerPassword: '003',
      ),
      Organization(
        id: '004',
        name: 'BCC MUSICALITY',
        logoAsset: 'assets/bccmusicality.jpg',
        shortDesc: 'Music organization promoting musical talents',
        acronym: 'BCM',
        category: 'Arts & Performance',
        about:
            'BCC Musicality is dedicated to promoting musical talents and providing opportunities for students to express themselves through various musical genres.',
        missionVision:
            'To cultivate musical appreciation and provide a platform for student musicians to showcase their talents.',
        adviser: 'Prof. Antonio Reyes',
        contactEmail: 'bccmusicality@university.edu',
        contactPhone: '+63 945 678 9012',
        socialLink: 'facebook.com/bccmusicality',
        officers: [
          'Music Director: Isabella Cruz',
          'Choir Master: Gabriel Santos',
          'Band Coordinator: Natalia Garcia'
        ],
        activitiesHighlights: [
          'Concert Series',
          'Music Workshops',
          'Talent Shows'
        ],
        officerPassword: '004',
      ),
      Organization(
        id: '005',
        name: 'BCC DRUM AND LYRE CORPS',
        logoAsset: 'assets/drumandlyre.jpg',
        shortDesc: 'Marching band organization',
        acronym: 'BDLC',
        category: 'Arts & Performance',
        about:
            'BCC Drum and Lyre Corps is a marching band organization that performs at various school and community events.',
        missionVision:
            'To promote discipline, teamwork, and musical excellence through marching band performances.',
        adviser: 'Prof. Francisco Mendoza',
        contactEmail: 'drumandlyre@university.edu',
        contactPhone: '+63 956 789 0123',
        socialLink: 'facebook.com/drumandlyre',
        officers: [
          'Corps Commander: Diego Rodriguez',
          'Drum Major: Carmen Santos',
          'Section Leader: Paolo Cruz'
        ],
        activitiesHighlights: [
          'Marching Band Performances',
          'Parades',
          'Competitions'
        ],
        officerPassword: '005',
      ),
      Organization(
        id: '006',
        name: 'BCC PAGE TURNERS BOOK CLUB',
        logoAsset: 'assets/pageturnersbookclub.jpg',
        shortDesc: 'Literary organization for book lovers',
        acronym: 'PTBC',
        category: 'Academic & Literary',
        about:
            'BCC Page Turners Book Club is a literary organization that promotes reading culture and literary appreciation among students.',
        missionVision:
            'To foster a love for reading and create a community of literature enthusiasts.',
        adviser: 'Prof. Carmen Lopez',
        contactEmail: 'pageturners@university.edu',
        contactPhone: '+63 967 890 1234',
        socialLink: 'facebook.com/pageturners',
        officers: [
          'Club President: Andrea Martinez',
          'Vice President: Carlos Reyes',
          'Secretary: Lucia Torres'
        ],
        activitiesHighlights: [
          'Book Discussions',
          'Author Meetups',
          'Reading Challenges'
        ],
        officerPassword: '006',
      ),
      Organization(
        id: '007',
        name: 'GENDER UNITED',
        logoAsset: 'assets/genderunited.jpg',
        shortDesc: 'Organization promoting gender equality',
        acronym: 'GU',
        category: 'Advocacy & Social',
        about:
            'Gender United is an organization dedicated to promoting gender equality and supporting gender-related initiatives on campus.',
        missionVision:
            'To create an inclusive campus environment that respects and celebrates gender diversity.',
        adviser: 'Prof. Teresa Santos',
        contactEmail: 'genderunited@university.edu',
        contactPhone: '+63 978 901 2345',
        socialLink: 'facebook.com/genderunited',
        officers: [
          'President: Maria Elena Cruz',
          'Advocacy Officer: Jose Garcia',
          'Events Coordinator: Ana Maria Santos'
        ],
        activitiesHighlights: [
          'Gender Equality Workshops',
          'Awareness Campaigns',
          'Support Groups'
        ],
        officerPassword: '007',
      ),
      Organization(
        id: '008',
        name: 'COLLEGE ELEGANTE',
        logoAsset: 'assets/collegeelegante.jpg',
        shortDesc: 'Fashion and lifestyle organization',
        acronym: 'CE',
        category: 'Arts & Lifestyle',
        about:
            'College Elegante is a fashion and lifestyle organization that promotes style, creativity, and personal expression.',
        missionVision:
            'To inspire students to express their unique style and foster creativity in fashion and lifestyle.',
        adviser: 'Prof. Isabella Rodriguez',
        contactEmail: 'collegeelegante@university.edu',
        contactPhone: '+63 989 012 3456',
        socialLink: 'facebook.com/collegeelegante',
        officers: [
          'Fashion Director: Sophia Martinez',
          'Style Editor: Lucas Torres',
          'Events Manager: Valentina Cruz'
        ],
        activitiesHighlights: [
          'Fashion Shows',
          'Style Workshops',
          'Lifestyle Events'
        ],
        officerPassword: '008',
      ),
      Organization(
        id: '009',
        name: 'SCAP',
        logoAsset: 'assets/scap.jpg',
        shortDesc: 'Student Council of Academic Programs',
        acronym: 'SCAP',
        category: 'Academic & Leadership',
        about:
            'SCAP represents student interests in academic programs and works to improve the quality of education and student life.',
        missionVision:
            'To serve as the voice of students in academic matters and promote excellence in education.',
        adviser: 'Prof. Ricardo Santos',
        contactEmail: 'scap@university.edu',
        contactPhone: '+63 912 345 6789',
        socialLink: 'facebook.com/scap',
        officers: [
          'Chairperson: Antonio Reyes',
          'Vice Chair: Carmen Garcia',
          'Secretary: Miguel Torres'
        ],
        activitiesHighlights: [
          'Academic Forums',
          'Student Feedback Sessions',
          'Program Reviews'
        ],
        officerPassword: '009',
      ),
      Organization(
        id: '010',
        name: 'BCC NIGHTINGALE',
        logoAsset: 'assets/bccnigthngale.jpg',
        shortDesc: 'Healthcare and wellness organization',
        acronym: 'BCN',
        category: 'Health & Wellness',
        about:
            'BCC Nightingale is dedicated to promoting health awareness and providing support for student wellness initiatives.',
        missionVision:
            'To promote health consciousness and provide resources for student well-being.',
        adviser: 'Prof. Elena Cruz',
        contactEmail: 'bccnightingale@university.edu',
        contactPhone: '+63 923 456 7890',
        socialLink: 'facebook.com/bccnightingale',
        officers: [
          'Health Director: Patricia Santos',
          'Wellness Coordinator: Roberto Garcia',
          'Support Officer: Maria Torres'
        ],
        activitiesHighlights: [
          'Health Awareness Campaigns',
          'Wellness Workshops',
          'Support Programs'
        ],
        officerPassword: '010',
      ),
      Organization(
        id: '011',
        name: 'SPEAK ICONICS',
        logoAsset: 'assets/speakiconics.jpg',
        shortDesc: 'Public speaking and debate organization',
        acronym: 'SI',
        category: 'Academic & Communication',
        about:
            'Speak Iconics develops public speaking and debate skills among students through various training programs and competitions.',
        missionVision:
            'To empower students with effective communication skills and confidence in public speaking.',
        adviser: 'Prof. Francisco Martinez',
        contactEmail: 'speakiconics@university.edu',
        contactPhone: '+63 934 567 8901',
        socialLink: 'facebook.com/speakiconics',
        officers: [
          'President: Elena Rodriguez',
          'Training Director: Carlos Santos',
          'Competition Manager: Lucia Garcia'
        ],
        activitiesHighlights: [
          'Public Speaking Workshops',
          'Debate Competitions',
          'Speech Contests'
        ],
        officerPassword: '011',
      ),
      Organization(
        id: '012',
        name: 'KULTURA DE FILIPINO',
        logoAsset: 'assets/culturadefelipino.jpg',
        shortDesc: 'Filipino culture and heritage organization',
        acronym: 'CDF',
        category: 'Cultural & Heritage',
        about:
            'Kultura De Filipino promotes Filipino culture, traditions, and heritage among students through various cultural activities.',
        missionVision:
            'To preserve and celebrate Filipino cultural heritage and traditions.',
        adviser: 'Prof. Antonio Cruz',
        contactEmail: 'culturafelipino@university.edu',
        contactPhone: '+63 945 678 9012',
        socialLink: 'facebook.com/culturafelipino',
        officers: [
          'Cultural Director: Rosa Santos',
          'Heritage Coordinator: Pedro Garcia',
          'Events Manager: Carmen Torres'
        ],
        activitiesHighlights: [
          'Cultural Festivals',
          'Traditional Dance',
          'Heritage Workshops'
        ],
        officerPassword: '012',
      ),
      Organization(
        id: '013',
        name: 'INK-WELL SOCIETY',
        logoAsset: 'assets/inkwell.jpg',
        shortDesc: 'Creative writing and poetry organization',
        acronym: 'IWS',
        category: 'Literary & Creative',
        about:
            'Ink-Well Society nurtures creative writing talents and provides a platform for literary expression through various writing activities.',
        missionVision:
            'To inspire creativity and foster a community of writers and poets.',
        adviser: 'Prof. Maria Elena Reyes',
        contactEmail: 'inkwellsociety@university.edu',
        contactPhone: '+63 956 789 0123',
        socialLink: 'facebook.com/inkwellsociety',
        officers: [
          'President: Gabriel Cruz',
          'Poetry Editor: Sofia Martinez',
          'Prose Coordinator: Lucas Santos'
        ],
        activitiesHighlights: [
          'Writing Workshops',
          'Poetry Readings',
          'Literary Magazine'
        ],
        officerPassword: '013',
      ),
      Organization(
        id: '014',
        name: 'CHRISTIAN CAMPUS MINISTRY',
        logoAsset: 'assets/christiancampusministry.jpg',
        shortDesc: 'Faith-based organization for spiritual growth',
        acronym: 'CCM',
        category: 'Faith & Spirituality',
        about:
            'Christian Campus Ministry provides spiritual guidance and fellowship opportunities for Christian students on campus.',
        missionVision:
            'To foster spiritual growth and provide a supportive Christian community.',
        adviser: 'Prof. Roberto Santos',
        contactEmail: 'christiancampus@university.edu',
        contactPhone: '+63 967 890 1234',
        socialLink: 'facebook.com/christiancampus',
        officers: [
          'Ministry Leader: Ana Maria Cruz',
          'Fellowship Coordinator: Jose Garcia',
          'Outreach Director: Maria Santos'
        ],
        activitiesHighlights: [
          'Bible Studies',
          'Fellowship Meetings',
          'Community Service'
        ],
        officerPassword: '014',
      ),
      Organization(
        id: '015',
        name: 'BCC ACES',
        logoAsset: 'assets/bccaces.jpg',
        shortDesc: 'Academic excellence organization',
        acronym: 'BCA',
        category: 'Academic & Leadership',
        about:
            'BCC ACES promotes academic excellence and provides support for students striving for academic achievement.',
        missionVision:
            'To encourage and support academic excellence among students.',
        adviser: 'Prof. Carmen Rodriguez',
        contactEmail: 'bccaces@university.edu',
        contactPhone: '+63 978 901 2345',
        socialLink: 'facebook.com/bccaces',
        officers: [
          'President: Miguel Torres',
          'Academic Coordinator: Patricia Cruz',
          'Study Group Leader: Ramon Santos'
        ],
        activitiesHighlights: [
          'Study Groups',
          'Academic Workshops',
          'Tutoring Programs'
        ],
        officerPassword: '015',
      ),
      Organization(
        id: '016',
        name: 'CRAFTY CREATORS CLUB',
        logoAsset: 'assets/craftycreatorsclub.jpg',
        shortDesc: 'Arts and crafts organization',
        acronym: 'CCC',
        category: 'Arts & Crafts',
        about:
            'Crafty Creators Club encourages creativity through various arts and crafts activities and workshops.',
        missionVision:
            'To inspire creativity and provide opportunities for artistic expression.',
        adviser: 'Prof. Isabella Martinez',
        contactEmail: 'craftycreators@university.edu',
        contactPhone: '+63 989 012 3456',
        socialLink: 'facebook.com/craftycreators',
        officers: [
          'Club President: Sofia Garcia',
          'Workshop Coordinator: Lucas Torres',
          'Materials Manager: Valentina Cruz'
        ],
        activitiesHighlights: [
          'Craft Workshops',
          'Art Exhibitions',
          'DIY Projects'
        ],
        officerPassword: '016',
      ),
      Organization(
        id: '017',
        name: 'BCC SUPREME STUDENT GOVERMENT',
        logoAsset: 'assets/ssg.jpg',
        shortDesc: 'Student government organization',
        acronym: 'SSG',
        category: 'Leadership & Governance',
        about:
            'BCC Supreme Student Government represents the student body and works to improve campus life and address student concerns.',
        missionVision:
            'To serve as the voice of students and promote positive change in the campus community.',
        adviser: 'Prof. Ricardo Garcia',
        contactEmail: 'ssg@university.edu',
        contactPhone: '+63 912 345 6789',
        socialLink: 'facebook.com/ssg',
        officers: [
          'Governor: Antonio Reyes',
          'Vice Governor: Carmen Santos',
          'Secretary: Miguel Cruz'
        ],
        activitiesHighlights: [
          'Student Assembly',
          'Policy Reviews',
          'Campus Improvements'
        ],
        officerPassword: '017',
      ),
      Organization(
        id: '018',
        name: 'KASANGA SQUAD',
        logoAsset: 'assets/kasangasquad.jpg',
        shortDesc: 'Dance and performance group',
        acronym: 'KS',
        category: 'Arts & Performance',
        about:
            'Kasanga Squad is a dynamic dance group that showcases various dance styles and performances.',
        missionVision:
            'To promote dance as an art form and provide performance opportunities for students.',
        adviser: 'Prof. Elena Torres',
        contactEmail: 'kasangasquad@university.edu',
        contactPhone: '+63 923 456 7890',
        socialLink: 'facebook.com/kasangasquad',
        officers: [
          'Dance Director: Patricia Rodriguez',
          'Choreographer: Roberto Santos',
          'Performance Manager: Maria Cruz'
        ],
        activitiesHighlights: [
          'Dance Performances',
          'Choreography Workshops',
          'Dance Competitions'
        ],
        officerPassword: '018',
      ),
      Organization(
        id: '019',
        name: 'CODEHEX',
        logoAsset: 'assets/codehex.jpg',
        shortDesc: 'Programming and technology organization',
        acronym: 'CH',
        category: 'Technology & Innovation',
        about:
            'CodeHex is a programming and technology organization that promotes coding skills and technological innovation.',
        missionVision:
            'To foster technological skills and encourage innovation among students.',
        adviser: 'Prof. Francisco Santos',
        contactEmail: 'codehex@university.edu',
        contactPhone: '+63 934 567 8901',
        socialLink: 'facebook.com/codehex',
        officers: [
          'Tech Lead: Gabriel Martinez',
          'Project Manager: Sofia Torres',
          'Workshop Coordinator: Lucas Cruz'
        ],
        activitiesHighlights: ['Coding Workshops', 'Hackathons', 'Tech Talks'],
        officerPassword: '019',
      ),
      Organization(
        id: '020',
        name: 'BCC MOTO CLUB',
        logoAsset: 'assets/motoclub.jpg',
        shortDesc: 'Motorcycle enthusiasts club',
        acronym: 'BMC',
        category: 'Sports & Recreation',
        about:
            'BCC Moto Club brings together motorcycle enthusiasts and promotes safe riding practices.',
        missionVision:
            'To promote motorcycle safety and create a community of responsible riders.',
        adviser: 'Prof. Antonio Rodriguez',
        contactEmail: 'motoclub@university.edu',
        contactPhone: '+63 945 678 9012',
        socialLink: 'facebook.com/motoclub',
        officers: [
          'Club President: Diego Santos',
          'Safety Officer: Carmen Garcia',
          'Events Coordinator: Pedro Torres'
        ],
        activitiesHighlights: [
          'Safety Workshops',
          'Group Rides',
          'Maintenance Clinics'
        ],
        officerPassword: '020',
      ),
      Organization(
        id: '021',
        name: 'BCC DANCE COMPANY',
        logoAsset: 'assets/bccdc.jpg',
        shortDesc: 'Professional dance company',
        acronym: 'BDC',
        category: 'Arts & Performance',
        about:
            'BCC Dance Company is a professional dance organization that performs various dance styles and productions.',
        missionVision:
            'To promote dance excellence and provide professional performance opportunities.',
        adviser: 'Prof. Maria Carmen Reyes',
        contactEmail: 'bccdc@university.edu',
        contactPhone: '+63 956 789 0123',
        socialLink: 'facebook.com/bccdc',
        officers: [
          'Artistic Director: Isabella Cruz',
          'Rehearsal Director: Gabriel Santos',
          'Production Manager: Natalia Garcia'
        ],
        activitiesHighlights: [
          'Dance Productions',
          'Professional Performances',
          'Training Programs'
        ],
        officerPassword: '021',
      ),
      Organization(
        id: '022',
        name: 'BCC PEERS FACILATATORS CIRLCES',
        logoAsset: 'assets/peerfacilatatorscircles.jpg',
        shortDesc: 'Peer support and mentoring organization',
        acronym: 'PFC',
        category: 'Support & Mentoring',
        about:
            'BCC Peers Facilitators Circles provides peer support and mentoring services to help students succeed academically and personally.',
        missionVision:
            'To create a supportive peer network that helps students thrive in their academic journey.',
        adviser: 'Prof. Roberto Martinez',
        contactEmail: 'peersfacilitators@university.edu',
        contactPhone: '+63 967 890 1234',
        socialLink: 'facebook.com/peersfacilitators',
        officers: [
          'Lead Facilitator: Ana Maria Santos',
          'Mentoring Coordinator: Jose Cruz',
          'Support Manager: Maria Elena Garcia'
        ],
        activitiesHighlights: [
          'Peer Mentoring',
          'Support Groups',
          'Academic Assistance'
        ],
        officerPassword: '022',
      ),
    ];
  }
  static final AppState instance = AppState._internal();

  late final List<Organization> organizations;

  // Current selected role (Student, Officer, Admin)
  UserRole? selectedRole;

  // Current logged-in student profile (null initially for new users)
  StudentProfile? currentStudent;

  // SharedPreferences instance
  SharedPreferences? _prefs;

  // Current officer org context after authorization
  String? currentOfficerOrgId;

  // Data stores
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

  // Notifications
  Future<void> fetchNotifications() async {
    try {
      final response = await supabase.Supabase.instance.client
          .from('notifications')
          .select('*')
          .order('date', ascending: false);

      notifications.clear();
      for (var item in response) {
        notifications.add(Notification(
          id: item['id'],
          title: item['title'],
          message: item['message'],
          date: DateTime.parse(item['date']),
          read: item['read'] ?? false,
          orgId: item['org_id'],
          studentId: item['student_id'],
        ));
      }
      notifyListeners();
    } catch (e) {
      // Handle error, perhaps log or show snackbar
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
      // Handle error
    }
  }

  Future<bool> updateNotification(Notification notification) async {
    try {
      await supabase.Supabase.instance.client
          .from('notifications')
          .update({
            'title': notification.title,
            'message': notification.message,
            'date': notification.date.toIso8601String(),
            'read': notification.read,
            'org_id': notification.orgId,
            'student_id': notification.studentId,
          })
          .eq('id', notification.id);

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

  static const List<String> orgName = [
    'PRIMERA BIDA',
    'EL TIATRO',
    'CRONICA',
    'BCC MUSICALITY',
    'BCC DRUM AND LYRE CORPS',
    'BCC PAGE TURNERS BOOK CLUB',
    'GENDER UNITED',
    'COLLEGE ELEGANTE',
    'SCAP',
    'BCC NIGHTINGALE',
    'SPEAK ICONICS',
    'CULTURA DE FELIPINO',
    'INK-WELL SOCIETY',
    'CHRISTIAN CAMPUS MINISTRY',
    'BCC ACES',
    'CRAFTY CREATORS CLUB',
    'BCC SUPREME STUDENT GOVERMENT',
    'KASANGA SQUAD',
    'CODEHEX',
    'BCC MOTO CLUB',
    'BCC DANCE COMPANY',
    'BCC PEERS FACILATATORS CIRLCES',
  ];

  // Role selection
  void setRole(UserRole? role) {
    selectedRole = role;
    notifyListeners();
  }

  // Student profile
  Future<void> setStudentProfile(StudentProfile profile) async {
    currentStudent = profile;
    notifyListeners();
    await _saveStudentProfile();
  }

  Future<void> updateStudentProfile(StudentProfile Function(StudentProfile) updater) async {
    final s = currentStudent;
    if (s == null) return;
    currentStudent = updater(s);
    notifyListeners();
    await _saveStudentProfile();
  }

  // Officer auth context
  void setOfficerOrgContext(String orgId) {
    currentOfficerOrgId = orgId;
    notifyListeners();
  }

  void setCurrentOfficerOrgId(String orgId) {
    currentOfficerOrgId = orgId;
    notifyListeners();
  }

  // Applications
  Future<Application> submitApplication({
    required String orgName,
    required String studentId,
    required String name,
    required String contact,
    required String email,
    required String reason,
    required String skills,
    List<String> attachments = const [],
  }) async {
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
    );
    applications.add(app);
    // Persist to Supabase applications table (best-effort)
    try {
      await supabase.Supabase.instance.client.from('applications').upsert({
        'id': app.id,
        'org_name': app.orgName,
        'org_id': app.orgId,
        'student_id': app.studentId,
        'name': app.name,
        'contact': app.contact,
        'email': app.email,
        'reason': app.reason,
        'skills': app.skills,
        'attachments': jsonEncode(app.attachments),
        'created_at': app.createdAt.toIso8601String(),
        'status': app.status.toString().split('.').last,
      }).select();
    } catch (e) {
      // Log and continue; UI still works with local data
      print('Error persisting application to Supabase: $e');
    }

    notifyListeners();
    return app;
  }

  bool setApplicationStatus(String applicationId, ApplicationStatus status) {
    final idx = applications.indexWhere((a) => a.id == applicationId);
    if (idx == -1) return false;
    applications[idx] = applications[idx].copyWith(status: status);
    // Debug log to trace status changes
    try {
      print('setApplicationStatus: applicationId=$applicationId status=${status.toString()}');
    } catch (_) {}
    // Persist status change to Supabase (best-effort)
    try {
      final a = applications[idx];
      supabase.Supabase.instance.client.from('applications').upsert({
        'id': a.id,
        'status': a.status.toString().split('.').last,
      }).select();
    } catch (e) {
      print('Error updating application status in Supabase: $e');
    }

    notifyListeners();
    return true;
  }

  Future<bool> approveApplication(String applicationId,
      {String defaultPosition = 'Member'}) async {
    final idx = applications.indexWhere((a) => a.id == applicationId);
    if (idx == -1) return false;
    final app = applications[idx];
    applications[idx] = app.copyWith(status: ApplicationStatus.accepted);

    // Add to members list
    addMember(
      name: app.name,
      position: defaultPosition,
      orgName: app.orgName,
      orgId: app.orgId,
    );

    // If the current student is the applicant, add org to joined list
    if (currentStudent != null && currentStudent!.studentId == app.studentId) {
      final joined = Set<String>.from(currentStudent!.joinedOrgIds);
      final orgId = app.orgId ?? _findOrgByName(app.orgName)?.id;
      if (orgId != null) {
        joined.add(orgId);
        currentStudent =
            currentStudent!.copyWith(joinedOrgIds: joined.toList());
      }
    }

    // Send notification to the student
    await addNotification(Notification(
      id: _genId(),
      title: 'Application Accepted',
      message: 'Your application to ${app.orgName} has been accepted. You are now a member.',
      date: DateTime.now(),
      studentId: app.studentId,
      orgId: app.orgId,
    ));

    notifyListeners();
    return true;
  }

  /// Schedule an interview for an application and mark its status accordingly.
  Future<bool> scheduleInterview(String applicationId, DateTime interviewAt) async {
    final idx = applications.indexWhere((a) => a.id == applicationId);
    if (idx == -1) return false;
    final app = applications[idx];

    applications[idx] = app.copyWith(
      status: ApplicationStatus.for_approval,
      interviewAt: interviewAt,
    );

    final orgId = app.orgId ?? _findOrgByName(app.orgName)?.id;

    // Notify the student
    await addNotification(Notification(
      id: _genId(),
      title: 'Interview Scheduled',
      message:
          'Your interview for ${app.orgName} has been scheduled on ${interviewAt.toLocal().toString()}.',
      date: DateTime.now(),
      orgId: orgId,
      studentId: app.studentId,
    ));

    // Persist interview schedule to Supabase (best-effort)
    try {
      await supabase.Supabase.instance.client.from('applications').upsert({
        'id': app.id,
        'status': 'interview_scheduled',
        'interview_at': interviewAt.toIso8601String(),
      }).select();
    } catch (e) {
      print('Error saving interview schedule to Supabase: $e');
    }

    notifyListeners();
    return true;
  }

  // Members
  Member addMember(
      {required String name,
      required String position,
      required String orgName,
      String? orgId}) {
    final m = Member(
        id: _genId(),
        name: name,
        position: position,
        orgName: orgName,
        orgId: orgId);
    members.add(m);
    notifyListeners();
    return m;
  }

  bool updateMember(Member member) {
    final idx = members.indexWhere((m) => m.id == member.id);
    if (idx == -1) return false;
    members[idx] = member;
    notifyListeners();
    return true;
  }

  bool removeMember(String id) {
    final before = members.length;
    members.removeWhere((m) => m.id == id);
    final removed = members.length < before;
    if (removed) notifyListeners();
    return removed;
  }

  // Events
  Event addEvent({
    required String title,
    required DateTime date,
    required String description,
    required String orgName,
    String? orgId,
  }) {
    final e = Event(
        id: _genId(),
        title: title,
        date: date,
        description: description,
        orgName: orgName,
        orgId: orgId);
    events.add(e);
    notifyListeners();
    return e;
  }

  /// Remove multiple applications by id and notify listeners.
  void removeApplications(List<String> ids) {
    applications.removeWhere((a) => ids.contains(a.id));
    notifyListeners();
  }

  // Convenience for officer context
  Event? addEventForCurrentOfficer({
    required String title,
    required DateTime date,
    required String description,
  }) {
    final orgId = currentOfficerOrgId;
    if (orgId == null) return null;
    final org = _findOrgById(orgId);
    if (org == null) return null;
    return addEvent(
        title: title,
        date: date,
        description: description,
        orgName: org.name,
        orgId: org.id);
  }

  bool updateEvent(Event event) {
    final idx = events.indexWhere((e) => e.id == event.id);
    if (idx == -1) return false;
    events[idx] = event;
    notifyListeners();
    return true;
  }

  bool removeEvent(String id) {
    final before = events.length;
    events.removeWhere((e) => e.id == id);
    final removed = events.length < before;
    if (removed) notifyListeners();
    return removed;
  }

  List<Event> eventsForCurrentStudent() {
    // Return all events for students to see events from all organizations
    return events;
  }

  // Admin methods
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

  void removeOrganization(String orgId) {
    organizations.removeWhere((o) => o.id == orgId);
    notifyListeners();
  }

  void addOrganization({
    required String name,
    required String logoAsset,
    required String shortDesc,
  }) {
    final newOrg = Organization(
      id: _genId(),
      name: name,
      logoAsset: logoAsset,
      shortDesc: shortDesc,
    );
    organizations.add(newOrg);
    notifyListeners();
  }

  void updateOrganization(Organization org) {
    final idx = organizations.indexWhere((o) => o.id == org.id);
    if (idx != -1) {
      organizations[idx] = org;
      notifyListeners();
    }
  }

  // Helper methods
  static String _genId() => 'id-${DateTime.now().millisecondsSinceEpoch}';

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

  // Persistence methods for student profile
  Future<void> loadStudentProfile() async {
    _prefs ??= await SharedPreferences.getInstance();
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
      } catch (e) {
        // If parsing fails, keep currentStudent as null
      }
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
      
      // Save to SharedPreferences
      await _prefs!.setString('student_profile', jsonEncode(data));
      
      // Save to Supabase profiles table
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
        
        print('Saving profile to Supabase with data: $profileData');
        
        final response = await supabase.Supabase.instance.client
            .from('profiles')
            .upsert(profileData)
            .select();
        
        print('Profile saved to Supabase successfully: $response');
      } catch (e) {
        print('Error saving profile to Supabase: $e');
      }
    } else {
      await _prefs!.remove('student_profile');
    }
  }
}
