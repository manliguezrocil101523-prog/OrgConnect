import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/analytics_service.dart';
import '../../core/app_state.dart';
import '../auth/unified_login_page.dart';
import '../analytics/event_comments_sheet.dart';
import '../organizations/org_list_screen.dart';
import '../organizations/org_profile_screen.dart';

class PublicEventsScreen extends StatefulWidget {
  const PublicEventsScreen({super.key});

  @override
  State<PublicEventsScreen> createState() => _PublicEventsScreenState();
}

class _PublicEventsScreenState extends State<PublicEventsScreen> {
  static const _green = Color(0xFF128058);
  static const _greenDark = Color(0xFF075A3D);
  static const _greenBright = Color(0xFF20B77D);
  static const _mint = Color(0xFFF0F9F5);
  static const _ink = Color(0xFF17382C);
  static const _muted = Color(0xFF6B8178);
  static const _line = Color(0xFFD7EBE2);

  List<Event> _events = <Event>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await Supabase.instance.client
          .from('events')
          .select('*')
          .order('date', ascending: true)
          .limit(30);

      final now = DateTime.now();
      final result = <Event>[];
      for (final row in rows as List) {
        final imageUrls = row['image_urls'] is List
            ? List<String>.from(row['image_urls'] as List)
            : <String>[];
        final eventDate = DateTime.tryParse(row['date']?.toString() ?? '');
        if (eventDate == null || !eventDate.isAfter(now)) continue;
        result.add(Event(
          id: row['id'].toString(),
          title: row['title']?.toString() ?? '',
          date: eventDate,
          description: row['description']?.toString() ?? '',
          orgName: row['org_name']?.toString() ?? '',
          orgId: row['org_id']?.toString(),
          imageUrl: row['image_url']?.toString(),
          imageUrls: imageUrls,
        ));
      }

      if (mounted) {
        setState(() {
          _events = result.take(8).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }

    await AnalyticsService.instance.logUsage('guest_open', route: 'guest/events');
  }

  void _openLogin() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const UnifiedLoginPage()));
  }

  void _openOrganizations() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const OrgListScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _mint,
      body: SafeArea(
        child: RefreshIndicator(
          color: _green,
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _hero()),
              const SliverToBoxAdapter(child: _InterestMatchCard()),
              SliverToBoxAdapter(child: _sectionHeader()),
              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator(color: _green)),
                )
              else if (_events.isEmpty)
                SliverToBoxAdapter(child: _emptyState())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                  sliver: SliverList.builder(
                    itemCount: _events.length,
                    itemBuilder: (_, index) => _eventCard(_events[index], index == 0),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_greenDark, _green, _greenBright],
          stops: [0, .52, 1],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: _green.withOpacity(.24), blurRadius: 28, offset: const Offset(0, 14)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(top: -45, right: -35, child: _orb(150, Colors.white.withOpacity(.09))),
          Positioned(top: 95, right: 35, child: _orb(52, Colors.white.withOpacity(.07))),
          Positioned(bottom: -70, left: -45, child: _orb(145, Colors.black.withOpacity(.08))),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.13),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(.22)),
                      ),
                      child: Image.asset('assets/OrgConnectLogo.png', fit: BoxFit.contain),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ORGCONNECT', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                          SizedBox(height: 2),
                          Text('Campus community hub', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _openLogin,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
                      ),
                      child: const Text('Log in', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 31),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.12),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(.17)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.white),
                      SizedBox(width: 6),
                      Text('OPEN CAMPUS ACCESS', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .7)),
                    ],
                  ),
                ),
                const SizedBox(height: 13),
                const Text(
                  'Discover campus life\nbefore you log in.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    height: 1.04,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.9,
                  ),
                ),
                const SizedBox(height: 11),
                Text(
                  'Find organizations, discover what is happening next, and choose where you want to belong.',
                  style: TextStyle(color: Colors.white.withOpacity(.84), height: 1.42, fontSize: 14),
                ),
                const SizedBox(height: 21),
                Row(
                  children: [
                    Expanded(child: _heroAction(Icons.event_available_rounded, 'Explore events', filled: true, onTap: _scrollToEvents)),
                    const SizedBox(width: 9),
                    Expanded(child: _heroAction(Icons.groups_rounded, 'Organizations', filled: false, onTap: _openOrganizations)),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    _miniTrust(Icons.visibility_outlined, 'Browse freely'),
                    const SizedBox(width: 14),
                    _miniTrust(Icons.login_rounded, 'Join when ready'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _orb(double size, Color color) {
    return Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color));
  }

  Widget _heroAction(IconData icon, String label, {required bool filled, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            color: filled ? Colors.white : Colors.white.withOpacity(.11),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(filled ? .1 : .2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: filled ? _greenDark : Colors.white),
              const SizedBox(width: 7),
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: filled ? _greenDark : Colors.white, fontSize: 12, fontWeight: FontWeight.w900))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniTrust(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white.withOpacity(.72)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(.72), fontSize: 10.5, fontWeight: FontWeight.w700)),
      ],
    );
  }

  void _scrollToEvents() {
    // The events section is immediately below the hero; this keeps the action useful
    // without introducing another route or duplicating content.
    Scrollable.ensureVisible(
      _eventsKey.currentContext ?? context,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  final GlobalKey _eventsKey = GlobalKey();

  Widget _sectionHeader() {
    return Padding(
      key: _eventsKey,
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Upcoming events', style: TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -.3)),
                SizedBox(height: 4),
                Text('See what organizations are planning next.', style: TextStyle(color: _muted, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _eventCard(Event event, bool featured) {
    final image = event.imageUrl ?? (event.imageUrls.isNotEmpty ? event.imageUrls.first : null);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _line),
        boxShadow: [BoxShadow(color: _greenDark.withOpacity(.06), blurRadius: 18, offset: const Offset(0, 7))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (image != null && image.isNotEmpty)
            SizedBox(
              height: featured ? 180 : 145,
              width: double.infinity,
              child: Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _imagePlaceholder()),
            )
          else
            _imagePlaceholder(height: featured ? 130 : 105),
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 15, 17, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(event.orgName.isEmpty ? 'Campus organization' : event.orgName, style: const TextStyle(color: _green, fontSize: 12, fontWeight: FontWeight.w900))),
                    if (featured)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(color: const Color(0xFFE4F4EC), borderRadius: BorderRadius.circular(10)),
                        child: const Text('Featured', style: TextStyle(color: _greenDark, fontSize: 10, fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(event.title, style: const TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w900, height: 1.15)),
                if (event.description.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(event.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, height: 1.4, fontSize: 13)),
                ],
                const SizedBox(height: 13),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 16, color: _green),
                    const SizedBox(width: 7),
                    Expanded(child: Text(DateFormat('MMM d, yyyy • h:mm a').format(event.date), style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w700))),
                    IconButton(
                      tooltip: 'Comments',
                      onPressed: () async {
                        await AnalyticsService.instance.logEventView(event.id);
                        if (!context.mounted) return;
                        await showEventComments(context, eventId: event.id, eventTitle: event.title);
                      },
                      icon: const Icon(Icons.forum_outlined, size: 19, color: _green),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder({double height = 110}) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFFDDF5E9), Color(0xFFB6E5D0)]),
      ),
      child: const Center(child: Icon(Icons.auto_awesome_rounded, color: _greenDark, size: 30)),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE9F9F2), Color(0xFFCDEEDF)],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFB8E3D0)),
          boxShadow: [BoxShadow(color: _greenDark.withOpacity(.09), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Stack(
          children: [
            Positioned(right: -35, top: -35, child: _orb(115, const Color(0xFFE4F7EE))),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 25),
              child: Column(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_green, _greenBright]),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [BoxShadow(color: _green.withOpacity(.18), blurRadius: 15, offset: const Offset(0, 7))],
                    ),
                    child: const Icon(Icons.event_available_rounded, color: Colors.white, size: 31),
                  ),
                  const SizedBox(height: 15),
                  const Text('Your campus calendar starts here', textAlign: TextAlign.center, style: TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 18, height: 1.15)),
                  const SizedBox(height: 7),
                  const Text('No public events have been posted yet. Explore campus organizations while you wait.', textAlign: TextAlign.center, style: TextStyle(color: _muted, height: 1.45, fontSize: 13)),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.45),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(.65)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 15, color: _greenDark),
                        SizedBox(width: 7),
                        Text('New campus events will appear here', style: TextStyle(color: _greenDark, fontSize: 11, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _InterestMatchCard extends StatefulWidget {
  const _InterestMatchCard();
  @override
  State<_InterestMatchCard> createState() => _InterestMatchCardState();
}

class _InterestMatchCardState extends State<_InterestMatchCard> {
  List<String>? _answers;
  final List<String> _answerCategories = <String>[];

  // Six dimensions are used instead of four broad buckets so the result can
  // distinguish, for example, theater/music from journalism and coding.
  static const _dimensions = <String>[
    'Leadership & Service',
    'Arts & Performance',
    'Media & Creativity',
    'Academic & Technology',
    'Faith & Community',
    'Support & Mentoring',
    'Sports & Wellness',
  ];

  final _questions = const <Map<String, dynamic>>[
    {
      'question': 'When you picture your ideal campus experience, which moment would make you feel most fulfilled?',
      'options': <String>[
        'Leading a project that helps students or the campus',
        'Creating a performance, artwork, or music people remember',
        'Writing, filming, designing, or sharing stories with others',
        'Building a useful solution with technology or academic skills',
      ],
      'categories': <String>[
        'Leadership & Service',
        'Arts & Performance',
        'Media & Creativity',
        'Academic & Technology',
      ],
    },
    {
      'question': 'When a group needs someone to step forward, which kind of role feels most natural to you?',
      'options': <String>[
        'Organizing people, projects, and community activities',
        'Performing, rehearsing, or directing a creative production',
        'Writing articles, creating media, or documenting events',
        'Helping classmates, mentoring others, or building a support network',
      ],
      'categories': <String>[
        'Leadership & Service',
        'Arts & Performance',
        'Media & Creativity',
        'Support & Mentoring',
      ],
    },
    {
      'question': 'If you could spend your free time doing one thing on campus, what would leave you feeling that your time mattered?',
      'options': <String>[
        'Advocating for students and helping improve campus life',
        'Making art, music, theater, dance, or crafts',
        'Reading, writing, photography, video, or digital storytelling',
        'Coding, research, problem-solving, or learning new technology',
      ],
      'categories': <String>[
        'Leadership & Service',
        'Arts & Performance',
        'Media & Creativity',
        'Academic & Technology',
      ],
    },
    {
      'question': 'After a difficult week, what kind of campus activity would you naturally want to return to?',
      'options': <String>[
        'An active group where I can train, compete, or stay healthy',
        'A creative space where I can express myself through performance',
        'A community where I can reflect, serve, and reconnect with others',
        'A supportive group where I can mentor, encourage, or be encouraged',
      ],
      'categories': <String>[
        'Sports & Wellness',
        'Arts & Performance',
        'Faith & Community',
        'Support & Mentoring',
      ],
    },
    {
      'question': 'Which community would you still choose to belong to even if nobody asked you to join?',
      'options': <String>[
        'A community that creates change and serves students',
        'A community that celebrates creativity and expression',
        'A community built around faith, care, and service',
        'A community built around wellness, teamwork, and active challenges',
      ],
      'categories': <String>[
        'Leadership & Service',
        'Arts & Performance',
        'Faith & Community',
        'Sports & Wellness',
      ],
    },
  ];

  Future<void> _startQuiz() async {
    final answers = <String>[];
    final categories = <String>[];

    for (var index = 0; index < _questions.length; index++) {
      final q = _questions[index];
      final question = q['question'] as String;
      final options = List<String>.from(q['options'] as List);
      final optionCategories = List<String>.from(q['categories'] as List);

      final answer = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFFF1FAF6),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          contentPadding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF075A42), Color(0xFF20B77D)],
                      ),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.psychology_alt_rounded, color: Colors.white, size: 19),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    'Question ${index + 1} of ${_questions.length}',
                    style: const TextStyle(
                      color: Color(0xFF0F8A61),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                question,
                style: const TextStyle(
                  color: Color(0xFF17382C),
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Choose the option that feels most like you.',
                style: TextStyle(color: Color(0xFF6B8178), fontSize: 11.5, height: 1.35),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options
                .map(
                  (option) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: SizedBox(
                      width: double.infinity,
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        child: InkWell(
                          onTap: () => Navigator.pop(context, option),
                          borderRadius: BorderRadius.circular(15),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: const Color(0xFFCBE8DC)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE4F7EF),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF0F8A61), size: 15),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    option,
                                    style: const TextStyle(
                                      color: Color(0xFF17382C),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                      height: 1.25,
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
                )
                .toList(),
          ),
        ),
      );

      if (answer == null) return;
      final selectedIndex = options.indexOf(answer);
      if (selectedIndex < 0) return;
      answers.add(answer);
      categories.add(optionCategories[selectedIndex]);
    }

    if (mounted) {
      setState(() {
        _answers = answers;
        _answerCategories
          ..clear()
          ..addAll(categories);
      });
    }
  }

  Map<String, double> _interestProfile() {
    final profile = <String, double>{
      for (final dimension in _dimensions) dimension: 0.0,
    };
    for (final category in _answerCategories) {
      if (profile.containsKey(category)) profile[category] = profile[category]! + 1.0;
    }
    return profile;
  }

  Map<String, double> _organizationProfile(Organization org) {
    final scores = <String, double>{
      for (final dimension in _dimensions) dimension: 0.0,
    };
    final category = org.category.toLowerCase();

    const categoryMap = <String, Map<String, double>>{
      'arts & performance': {'Arts & Performance': 1.0},
      'arts & crafts': {'Arts & Performance': 1.0},
      'arts & lifestyle': {'Arts & Performance': .72, 'Media & Creativity': .30},
      'media & publications': {'Media & Creativity': 1.0},
      'literary & creative': {'Media & Creativity': .92, 'Arts & Performance': .35},
      'academic & literary': {'Academic & Technology': .75, 'Media & Creativity': .55},
      'academic & communication': {'Academic & Technology': .65, 'Media & Creativity': .75},
      'technology & innovation': {'Academic & Technology': 1.0, 'Media & Creativity': .25},
      'academic & leadership': {'Academic & Technology': .60, 'Leadership & Service': .90},
      'leadership & governance': {'Leadership & Service': 1.0},
      'advocacy & social': {'Leadership & Service': .95, 'Faith & Community': .20},
      'support & mentoring': {'Support & Mentoring': 1.0, 'Leadership & Service': .30},
      'faith & spirituality': {'Faith & Community': 1.0},
      'health & wellness': {'Sports & Wellness': .92, 'Faith & Community': .18},
      'sports & recreation': {'Sports & Wellness': 1.0},
      'cultural & heritage': {'Arts & Performance': .62, 'Media & Creativity': .50},
    };

    for (final entry in categoryMap.entries) {
      if (category == entry.key) {
        entry.value.forEach((key, value) => scores[key] = scores[key]! + value);
      }
    }

    final text = '${org.name} ${org.category} ${org.shortDesc} ${org.about} ${org.missionVision} ${org.activitiesHighlights.map((e) => '${e.type} ${e.content} ${e.caption}').join(' ')}'.toLowerCase();
    const keywordMap = <String, List<String>>{
      'Leadership & Service': ['student government', 'student council', 'governance', 'leadership', 'advocacy', 'volunteer', 'community service', 'student voice', 'campus improvement', 'academic programs'],
      'Arts & Performance': ['theater', 'theatre', 'music', 'dance', 'performance', 'drama', 'marching band', 'drum', 'lyre', 'arts', 'craft', 'fashion'],
      'Media & Creativity': ['publication', 'journalism', 'newsletter', 'writing', 'literary', 'poetry', 'photography', 'media', 'storytelling', 'creative writing'],
      'Academic & Technology': ['academic', 'study', 'tutoring', 'research', 'coding', 'programming', 'technology', 'innovation', 'hackathon', 'workshop'],
      'Faith & Community': ['christian', 'faith', 'spiritual', 'ministry', 'bible', 'fellowship', 'worship'],
      'Support & Mentoring': ['peer support', 'mentoring', 'support group', 'facilitator', 'student support', 'peer'],
      'Sports & Wellness': ['sport', 'sports', 'fitness', 'wellness', 'athletic', 'recreation', 'motorcycle', 'riding', 'competition', 'training'],
    };

    for (final entry in keywordMap.entries) {
      var hits = 0;
      for (final keyword in entry.value) {
        if (text.contains(keyword)) hits++;
      }
      scores[entry.key] = scores[entry.key]! + (hits * .12).clamp(0.0, .42).toDouble();
    }

    return scores;
  }

  double _cosineSimilarity(Map<String, double> a, Map<String, double> b) {
    double dot = 0;
    double normA = 0;
    double normB = 0;
    for (final dimension in _dimensions) {
      final av = a[dimension] ?? 0;
      final bv = b[dimension] ?? 0;
      dot += av * bv;
      normA += av * av;
      normB += bv * bv;
    }
    if (normA == 0 || normB == 0) return 0;
    return dot / (math.sqrt(normA) * math.sqrt(normB));
  }

  List<MapEntry<Organization, int>> _recommendations() {
    if ((_answers ?? []).isEmpty || _answerCategories.isEmpty) return [];

    final profile = _interestProfile();
    final entries = <MapEntry<Organization, int>>[];

    for (final org in AppState.instance.organizations) {
      final organizationProfile = _organizationProfile(org);
      var similarity = _cosineSimilarity(profile, organizationProfile);

      // Give exact category alignment a small extra lift so an exact match is
      // preferred over an organization that only shares generic keywords.
      final topInterest = profile.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (topInterest.isNotEmpty && topInterest.first.value > 0) {
        final dominant = topInterest.first.key;
        final dominantOrgScore = organizationProfile[dominant] ?? 0;
        if (dominantOrgScore >= .9) similarity += .08;
      }

      final percent = (similarity.clamp(0.0, 1.0) * 100).round();
      entries.add(MapEntry(org, percent));
    }

    entries.sort((a, b) {
      final scoreCompare = b.value.compareTo(a.value);
      if (scoreCompare != 0) return scoreCompare;
      return a.key.name.toLowerCase().compareTo(b.key.name.toLowerCase());
    });

    return entries.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final recs = _answers == null ? const <MapEntry<Organization, int>>[] : _recommendations();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF075A42), Color(0xFF0F8A61), Color(0xFF20B77D)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F8A61).withOpacity(.14),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(17, 17, 17, 17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.12),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: Colors.white.withOpacity(.16)),
                    ),
                    child: const Icon(Icons.psychology_alt_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Discover what fits you', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                        SizedBox(height: 2),
                        Text('Discover your fit through 5 thoughtful questions.', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                      ],
                    ),
                  ),
                  if (_answers != null)
                    IconButton(
                      onPressed: _startQuiz,
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                      tooltip: 'Retake quiz',
                    ),
                ],
              ),
              const SizedBox(height: 13),
              if (_answers == null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        'Your answers create an interest profile and surface organizations whose purpose and activities are closest to what you chose.',
                        style: TextStyle(color: Colors.white.withOpacity(.88), fontSize: 12.5, height: 1.4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _startQuiz,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF075A42),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Discover My Fit', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ],
                )
              else ...[
                const Text('Closest matches to your answers', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                const SizedBox(height: 4),
                const Text('Match score is based on your answer pattern and the organization’s category, description, mission, and activities.', style: TextStyle(color: Colors.white70, fontSize: 10.5, height: 1.3)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 116,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: recs.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 9),
                    itemBuilder: (_, i) {
                      final org = recs[i].key;
                      final percent = recs[i].value;
                      return InkWell(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrgDetailScreen(orgId: org.id))),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 190,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(.18)),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 46,
                                height: 46,
                                child: ClipOval(
                                  child: org.logoAsset.startsWith('http')
                                      ? Image.network(org.logoAsset, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _smallLogo())
                                      : Image.asset(org.logoAsset.isEmpty ? 'assets/primerabida.jpg' : org.logoAsset, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _smallLogo()),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('$percent% match', style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 3),
                                    Text(org.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 3),
                                    Text(org.category.isEmpty ? 'Campus organization' : org.category, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _smallLogo() => Container(color: const Color(0xFFE4F7EF), child: const Icon(Icons.groups_rounded, color: Color(0xFF0F8A61), size: 22));
}

