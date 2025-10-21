import 'package:flutter/foundation.dart';

/// Roles supported by the app
enum UserRole { student, officer, admin }

/// Application status lifecycle
enum ApplicationStatus { pending, accepted, declined }

/// In-app notifications
class Notification {
  final String id;
  final String title;
  final String message;
  final DateTime date;
  bool read;
  final String? orgId;

  Notification({
    required this.id,
    required this.title,
    required this.message,
    required this.date,
    this.read = false,
    this.orgId,
  });

  Notification copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? date,
    bool? read,
    String? orgId,
  }) {
    return Notification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      date: date ?? this.date,
      read: read ?? this.read,
      orgId: orgId ?? this.orgId,
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

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
  });

  User copyWith(
          {String? id,
          String? name,
          String? email,
          UserRole? role,
          bool? active}) =>
      User(
        id: id ?? this.id,
        name: name ?? this.name,
        email: email ?? this.email,
        role: role ?? this.role,
        active: active ?? this.active,
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
/// In-memory only to keep your current project simple and theme-focused.
class AppState extends ChangeNotifier {
  AppState._internal() {
    organizations = [
      Organization(
        id: '1',
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
        officerPassword: '1',
      ),
      Organization(
        id: '2',
        name: 'EL TIATRO',
        logoAsset: 'assets/eltiatro.jpg',
        shortDesc: 'Experimental theater group pushing creative boundaries',
        acronym: 'ET',
        category: 'Arts & Performance',
        about:
            'El Tiatro is an experimental theater group that pushes the boundaries of traditional theater, exploring innovative forms of storytelling and performance art.',
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
        officerPassword: '2',
      ),
      Organization(
        id: '3',
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
        officerPassword: '3',
      ),
      Organization(
        id: '4',
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
        officerPassword: '4',
      ),
      Organization(
        id: '5',
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
        officerPassword: '5',
      ),
      Organization(
        id: '6',
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
        officerPassword: '6',
      ),
      Organization(
        id: '7',
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
        officerPassword: '7',
      ),
      Organization(
        id: '8',
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
        officerPassword: '8',
      ),
      Organization(
        id: '9',
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
        officerPassword: '9',
      ),
      Organization(
        id: '10',
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
        officerPassword: '10',
      ),
      Organization(
        id: '11',
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
        officerPassword: '11',
      ),
      Organization(
        id: '12',
        name: 'CULTURA DE FELIPINO',
        logoAsset: 'assets/culturadefelipino.jpg',
        shortDesc: 'Filipino culture and heritage organization',
        acronym: 'CDF',
        category: 'Cultural & Heritage',
        about:
            'Cultura de Felipino promotes Filipino culture, traditions, and heritage among students through various cultural activities.',
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
        officerPassword: '12',
      ),
      Organization(
        id: '13',
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
        officerPassword: '13',
      ),
      Organization(
        id: '14',
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
        officerPassword: '14',
      ),
      Organization(
        id: '15',
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
        officerPassword: '15',
      ),
      Organization(
        id: '16',
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
        officerPassword: '16',
      ),
      Organization(
        id: '17',
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
        officerPassword: '17',
      ),
      Organization(
        id: '18',
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
        officerPassword: '18',
      ),
      Organization(
        id: '19',
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
        officerPassword: '19',
      ),
      Organization(
        id: '20',
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
        officerPassword: '20',
      ),
      Organization(
        id: '21',
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
        officerPassword: '21',
      ),
      Organization(
        id: '22',
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
        officerPassword: '22',
      ),
    ];
  }
  static final AppState instance = AppState._internal();

  late final List<Organization> organizations;

  // Current selected role (Student, Officer, Admin)
  UserRole? selectedRole;

  // Current logged-in student profile (null initially for new users)
  StudentProfile? currentStudent = null;

  // Current officer org context after authorization
  String? currentOfficerOrgId;

  // Data stores
  final List<Application> applications = <Application>[
    Application(
      id: 'app-1',
      orgName: 'BCC Debate Society',
      orgId: '1',
      studentId: 'demo-student-1',
      name: 'Demo Student',
      contact: '+63 912 345 6789',
      email: 'student@university.edu',
      reason:
          'I want to improve my public speaking skills and engage in intellectual discussions.',
      skills: 'Research, Critical Thinking, Public Speaking',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      status: ApplicationStatus.pending,
    ),
    Application(
      id: 'app-2',
      orgName: 'BCC Musicality',
      orgId: '3',
      studentId: 'demo-student-1',
      name: 'Demo Student',
      contact: '+63 912 345 6789',
      email: 'student@university.edu',
      reason: 'I love music and want to be part of a creative community.',
      skills: 'Singing, Music Theory, Performance',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      status: ApplicationStatus.accepted,
    ),
  ];
  final List<Member> members = <Member>[];
  final List<Event> events = <Event>[
    Event(
      id: 'event-1',
      orgName: 'PRIMERA BIDA',
      orgId: '1',
      title: 'Annual Debate Competition',
      description: 'Join us for the biggest debate competition of the year!',
      date: DateTime.now().add(const Duration(days: 7)),
    ),
    Event(
      id: 'event-2',
      orgName: 'BCC MUSICALITY',
      orgId: '4',
      title: 'Spring Concert',
      description: 'Experience beautiful music from our talented members.',
      date: DateTime.now().add(const Duration(days: 14)),
    ),
    Event(
      id: 'event-3',
      orgName: 'BCC DRUM AND LYRE CORPS',
      orgId: '5',
      title: 'Dance Workshop',
      description: 'Learn new dance moves and techniques.',
      date: DateTime.now().add(const Duration(days: 3)),
    ),
  ];
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
        active: true),
  ];
  final List<Notification> notifications = <Notification>[];

  // Notifications
  void addNotification(Notification notification) {
    notifications.add(notification);
    notifyListeners();
  }

  bool updateNotification(Notification notification) {
    final idx = notifications.indexWhere((n) => n.id == notification.id);
    if (idx == -1) return false;
    notifications[idx] = notification;
    notifyListeners();
    return true;
  }

  bool removeNotification(String id) {
    final before = notifications.length;
    notifications.removeWhere((n) => n.id == id);
    final removed = notifications.length < before;
    if (removed) notifyListeners();
    return removed;
  }

  void markNotificationRead(String id) {
    final idx = notifications.indexWhere((n) => n.id == id);
    if (idx != -1 && !notifications[idx].read) {
      notifications[idx] = notifications[idx].copyWith(read: true);
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
  void setStudentProfile(StudentProfile profile) {
    currentStudent = profile;
    notifyListeners();
  }

  void updateStudentProfile(StudentProfile Function(StudentProfile) updater) {
    final s = currentStudent;
    if (s == null) return;
    currentStudent = updater(s);
    notifyListeners();
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
  Application submitApplication({
    required String orgName,
    required String studentId,
    required String name,
    required String contact,
    required String email,
    required String reason,
    required String skills,
    List<String> attachments = const [],
  }) {
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
    notifyListeners();
    return app;
  }

  bool setApplicationStatus(String applicationId, ApplicationStatus status) {
    final idx = applications.indexWhere((a) => a.id == applicationId);
    if (idx == -1) return false;
    applications[idx] = applications[idx].copyWith(status: status);
    notifyListeners();
    return true;
  }

  bool approveApplication(String applicationId,
      {String defaultPosition = 'Member'}) {
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
}
