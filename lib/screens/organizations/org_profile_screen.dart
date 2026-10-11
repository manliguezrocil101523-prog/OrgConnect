import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_state.dart';
import 'org_form_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

abstract class _C {
  static const green = Color(0xFF0F8A61);
  static const bright = Color(0xFF20B77D);
  static const dark = Color(0xFF075A42);
  static const mint = Color(0xFFE4F7EF);
  static const bg = Color(0xFFF1FAF6);
  static const ink = Color(0xFF173B30);
  static const muted = Color(0xFF6B8178);
  static const line = Color(0xFFCBE8DC);
}

class OrgDetailScreen extends StatefulWidget {
  final String orgId;
  const OrgDetailScreen({super.key, required this.orgId});

  @override
  State<OrgDetailScreen> createState() => _OrgDetailScreenState();
}

class _OrgDetailScreenState extends State<OrgDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool get _loggedIn => Supabase.instance.client.auth.currentUser != null;
  List<Map<String, dynamic>> _orgPeople = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _loggedIn ? 3 : 2, vsync: this);
    _loadOrganizationPeople();
  }

  Future<void> _loadOrganizationPeople() async {
    try {
      final rows = await Supabase.instance.client
          .from('profiles')
          .select('id,name,role,avatar_url,assigned_org_id,org_id')
          .or('assigned_org_id.eq.${widget.orgId},org_id.eq.${widget.orgId}')
          .order('name');
      if (!mounted) return;
      setState(() {
        _orgPeople = List<Map<String, dynamic>>.from(rows);
      });
    } catch (_) {
      // The About tab still shows names and clean square placeholders when
      // profile photos are unavailable.
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches = AppState.instance.organizations.where((o) => o.id == widget.orgId);
    if (matches.isEmpty) {
      return const Scaffold(body: Center(child: Text('Organization not found')));
    }
    final org = matches.first;
    final loggedIn = _loggedIn;

    return Scaffold(
      backgroundColor: _C.bg,
      body: Column(
        children: [
          // Fixed organization header: it stays visible while the tab content scrolls.
          SizedBox(
            height: 156,
            child: Stack(
              children: [
                Positioned.fill(child: _Hero(org: org)),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 6,
                  left: 12,
                  child: IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 58,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: _C.green.withValues(alpha: .08), blurRadius: 16, offset: const Offset(0, 5))],
            ),
            child: TabBar(
              controller: _tabs,
              labelColor: _C.green,
              unselectedLabelColor: _C.muted,
              indicatorColor: _C.green,
              indicatorWeight: 3,
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
              tabs: [
                const Tab(icon: Icon(Icons.dashboard_rounded, size: 18), text: 'Dashboard'),
                const Tab(icon: Icon(Icons.info_outline_rounded, size: 18), text: 'About'),
                if (loggedIn) const Tab(icon: Icon(Icons.volunteer_activism_rounded, size: 18), text: 'Apply'),
              ],
            ),
          ),
          const Divider(height: 1, color: _C.line),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _OrgDashboard(org: org),
                _AboutTab(org: org, people: _orgPeople),
                if (loggedIn) _ApplyTab(org: org),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final Organization org;
  const _Hero({required this.org});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [_C.dark, _C.green, _C.bright]),
      ),
      child: Stack(children: [
        Positioned(top: -55, right: -35, child: _orb(180, Colors.white.withValues(alpha: .08))),
        Positioned(bottom: -45, left: -45, child: _orb(140, Colors.black.withValues(alpha: .07))),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(64, 8, 24, 8),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _Logo(asset: org.logoAsset, size: 54),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(org.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 19, height: 1.08, fontWeight: FontWeight.w900)),
                        if (org.category.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Align(alignment: Alignment.centerLeft, child: _Pill(org.category)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (org.shortDesc.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(org.shortDesc, textAlign: TextAlign.left, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withValues(alpha: .82), fontSize: 11.5, height: 1.25)),
              ],
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _orb(double size, Color color) => Container(width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color));
}

class _Logo extends StatelessWidget {
  final String asset;
  final double size;
  const _Logo({required this.asset, required this.size});

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (asset.startsWith('http')) {
      image = CachedNetworkImage(imageUrl: asset, fit: BoxFit.contain,
          errorWidget: (_, __, ___) => const _FallbackLogo());
    } else {
      final p = asset.isEmpty ? 'assets/primerabida.jpg' : asset;
      image = Image.asset(p, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const _FallbackLogo());
    }
    return Container(width: size + 18, height: size + 18,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .16),
          border: Border.all(color: Colors.white.withValues(alpha: .26))),
      child: ClipOval(child: image));
  }
}

class _FallbackLogo extends StatelessWidget {
  const _FallbackLogo();
  @override
  Widget build(BuildContext context) => Container(color: _C.mint,
      child: const Icon(Icons.groups_rounded, color: _C.green, size: 38));
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill(this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .15), borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .22))),
    child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
  );
}

class _OrgDashboard extends StatelessWidget {
  final Organization org;
  const _OrgDashboard({required this.org});

  bool _isReligious() {
    final text = '${org.name} ${org.category} ${org.about} ${org.missionVision}'.toLowerCase();
    return text.contains('christian') || text.contains('religious') || text.contains('faith') ||
        text.contains('church') || text.contains('spiritual') || text.contains('ministry');
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final events = AppState.instance.events.where((e) {
      final eventDay = DateTime(e.date.year, e.date.month, e.date.day);
      return !eventDay.isBefore(today) &&
          (e.orgId == org.id || (e.orgId == null && e.orgName.toLowerCase() == org.name.toLowerCase()));
    }).toList();
    events.sort((a, b) => a.date.compareTo(b.date));
    final media = org.activitiesHighlights.where((m) => m.type == 'image' || m.type == 'video').toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 48),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _SectionIntro(icon: Icons.dashboard_rounded, title: 'Inside the organization',
            subtitle: 'See what they do, what is coming up, and moments from campus life.'),
        if (events.isNotEmpty) ...[
          const SizedBox(height: 16),
          _TitleRow(title: 'Upcoming events', icon: Icons.event_available_rounded, count: events.length),
          const SizedBox(height: 10),
          Column(
            children: events.map((event) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _EventVisualCard(event: event, expanded: true),
            )).toList(),
          ),
        ] else ...[
          const SizedBox(height: 14),
          _SoftEmpty(icon: Icons.event_note_rounded, title: 'No upcoming events yet',
              subtitle: 'New activities from this organization will appear here.'),
        ],
        if (_isReligious()) ...[
          const SizedBox(height: 18),
          _WeeklyCard(org: org),
        ],
        const SizedBox(height: 20),
        _TitleRow(title: 'Highlights & activities', icon: Icons.photo_library_rounded, count: media.length),
        const SizedBox(height: 10),
        if (media.isEmpty)
          _SoftEmpty(
            icon: Icons.photo_library_outlined,
            title: 'No highlights posted yet',
            subtitle: "Photos from this organization's activities will appear here.",
          )
        else
          SizedBox(height: 205, child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: media.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _MediaTile(item: media[i]),
          )),
      ]),
    );
  }
}

class _EventVisualCard extends StatelessWidget {
  final Event event;
  final bool expanded;
  const _EventVisualCard({required this.event, this.expanded = false});
  @override
  Widget build(BuildContext context) {
    final image = event.imageUrl ?? (event.imageUrls.isNotEmpty ? event.imageUrls.first : '');
    return Container(width: expanded ? double.infinity : 255, clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: _C.line),
          boxShadow: const [BoxShadow(color: Color(0x100F8A61), blurRadius: 15, offset: Offset(0, 7))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(height: expanded ? 205 : 128, width: double.infinity, child: image.isNotEmpty
            ? Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _eventArt())
            : _eventArt()),
        Padding(padding: const EdgeInsets.fromLTRB(13, 11, 13, 13), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _C.ink, fontWeight: FontWeight.w900, fontSize: expanded ? 18 : 15, height: 1.15)),
          const SizedBox(height: 7),
          Row(children: [const Icon(Icons.calendar_month_rounded, size: 14, color: _C.green), const SizedBox(width: 5),
            Expanded(child: Text('${event.date.month}/${event.date.day}/${event.date.year}', style: TextStyle(color: _C.muted, fontSize: expanded ? 12.5 : 11.5, fontWeight: FontWeight.w700)))]),
        ])),
      ]));
  }
  Widget _eventArt() => Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [_C.dark, _C.bright])),
      child: const Center(child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 34)));
}

class _WeeklyCard extends StatelessWidget {
  final Organization org;
  const _WeeklyCard({required this.org});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(gradient: const LinearGradient(colors: [_C.dark, _C.green]), borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: _C.green.withValues(alpha: .16), blurRadius: 18, offset: const Offset(0, 8))]),
    child: Row(children: [
      Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .13), borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.groups_rounded, color: Colors.white, size: 25)),
      const SizedBox(width: 12),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Weekly fellowship', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
        SizedBox(height: 4),
        Text('A regular time to meet, connect, reflect, and grow together.', style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.35)),
      ])),
      const Icon(Icons.calendar_view_week_rounded, color: Colors.white70),
    ]));
}

class _MediaTile extends StatelessWidget {
  final OrgMediaItem item;
  const _MediaTile({required this.item});

  String get _activityName {
    final title = item.title.trim();
    if (title.isNotEmpty) return title;
    final caption = item.caption.trim();
    if (caption.isNotEmpty) return caption;
    return 'Activity moment';
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = item.type == 'video';
    return GestureDetector(
      onTap: isVideo
          ? () async {
              final uri = Uri.tryParse(item.content);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            }
          : null,
      child: Container(
        width: 190,
        clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.line),
        boxShadow: const [
          BoxShadow(color: Color(0x080F8A61), blurRadius: 12, offset: Offset(0, 5)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          height: 128,
          width: double.infinity,
          child: Stack(children: [
            Positioned.fill(
              child: isVideo
                  ? _videoFallback()
                  : item.content.startsWith('http')
                      ? Image.network(
                          item.content,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _mediaFallback(),
                        )
                      : _mediaFallback(),
            ),
            if (isVideo)
              const Positioned(
                right: 9,
                top: 9,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xAA0F8A61),
                  child: Icon(Icons.play_arrow_rounded, color: Colors.white),
                ),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isVideo ? 'VIDEO' : 'PICTURES',
                style: TextStyle(
                  color: _C.green,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _activityName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _C.ink,
                  fontSize: 13.5,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (item.description.trim().isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  item.description.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _C.muted,
                    fontSize: 10.5,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        ]),
      ),
    );
  }

  Widget _videoFallback() => Container(
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF064E3B), Color(0xFF0F8A61)])),
    child: const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 48)),
  );

  Widget _mediaFallback() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [_C.mint, Color(0xFFC7EDDD)]),
        ),
        child: const Center(
          child: Icon(Icons.photo_rounded, color: _C.green, size: 32),
        ),
      );
}

class _AboutTab extends StatelessWidget {
  final Organization org;
  final List<Map<String, dynamic>> people;
  const _AboutTab({required this.org, required this.people});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 48),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _SectionIntro(icon: Icons.info_outline_rounded, title: 'Get to know the organization', subtitle: 'The people, purpose, and ways to stay connected.'),
      const SizedBox(height: 14),
      if (org.about.isNotEmpty) _StoryCard(icon: Icons.info_rounded, title: 'Who they are', body: org.about),
      if (org.mission.isNotEmpty || org.vision.isNotEmpty || org.missionVision.isNotEmpty) ...[
        const SizedBox(height: 12),
        _MissionVisionCard(
          label: 'MISSION',
          text: org.mission.isNotEmpty
              ? org.mission
              : (org.missionVision.isNotEmpty ? org.missionVision : 'No mission has been added yet.'),
          icon: Icons.flag_rounded,
        ),
        const SizedBox(height: 12),
        _MissionVisionCard(
          label: 'VISION',
          text: org.vision.isNotEmpty ? org.vision : 'No vision has been added yet.',
          icon: Icons.visibility_rounded,
        ),
      ],
      if (org.adviser.isNotEmpty || org.officers.isNotEmpty) ...[
        const SizedBox(height: 16),
        const _PeopleSectionLabel(title: 'Adviser & officers'),
        const SizedBox(height: 10),
        _AboutPeopleGallery(org: org, people: people),
      ],
      if (org.socialLink.isNotEmpty) ...[
        const SizedBox(height: 16),
        _ConnectCard(org: org),
      ],
      if (org.about.isEmpty && org.mission.isEmpty && org.vision.isEmpty && org.missionVision.isEmpty && org.adviser.isEmpty && org.officers.isEmpty && org.socialLink.isEmpty)
        _SoftEmpty(icon: Icons.info_outline_rounded, title: 'More details coming soon', subtitle: 'This organization has not added its full profile yet.'),
    ]));
  }
}

class _SectionIntro extends StatelessWidget {
  final IconData icon; final String title; final String subtitle;
  const _SectionIntro({required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(width: 42, height: 42, decoration: BoxDecoration(gradient: const LinearGradient(colors: [_C.green, _C.bright]), borderRadius: BorderRadius.circular(13)),
        child: Icon(icon, color: Colors.white, size: 20)),
    const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: _C.ink, fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: _C.muted, fontSize: 12.5, height: 1.35)),
    ])),
  ]);
}

class _TitleRow extends StatelessWidget {
  final String title; final IconData icon; final int count;
  const _TitleRow({required this.title, required this.icon, required this.count});
  @override
  Widget build(BuildContext context) => Row(children: [Icon(icon, size: 18, color: _C.green), const SizedBox(width: 7),
    Expanded(child: Text(title, style: const TextStyle(color: _C.ink, fontWeight: FontWeight.w900, fontSize: 16))),
    Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: _C.mint, borderRadius: BorderRadius.circular(20)),
      child: Text('$count', style: const TextStyle(color: _C.green, fontSize: 10.5, fontWeight: FontWeight.w900))) ]);
}

class _StoryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _StoryCard({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE5F8F0), Color(0xFFD2F0E4)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180F8A61),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .96),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: _C.green, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _C.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
            child: Text(
              body,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 13.5,
                height: 1.58,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionVisionCard extends StatelessWidget {
  final String label;
  final String text;
  final IconData icon;
  const _MissionVisionCard({required this.label, required this.text, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFFE5F8F0), Color(0xFFD2F0E4)]),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _C.line),
      boxShadow: const [BoxShadow(color: Color(0x070F8A61), blurRadius: 12, offset: Offset(0, 5))],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .72), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: _C.green, size: 19),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: _C.green, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .9)),
              const SizedBox(height: 7),
              Text(text, style: const TextStyle(color: _C.ink, fontSize: 13.5, height: 1.55, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PeopleSectionLabel extends StatelessWidget {
  final String title;
  const _PeopleSectionLabel({required this.title});
  @override
  Widget build(BuildContext context) => Row(children: [
    const Icon(Icons.badge_rounded, color: _C.green, size: 19),
    const SizedBox(width: 7),
    Text(title, style: const TextStyle(color: _C.ink, fontSize: 16, fontWeight: FontWeight.w900)),
  ]);
}

class _AboutPeopleGallery extends StatelessWidget {
  final Organization org;
  final List<Map<String, dynamic>> people;
  const _AboutPeopleGallery({required this.org, required this.people});

  Map<String, dynamic>? _findByName(String name) {
    final target = name.trim().toLowerCase();
    if (target.isEmpty) return null;
    for (final p in people) {
      final n = p['name']?.toString().trim().toLowerCase() ?? '';
      if (n == target) return p;
    }
    return null;
  }

  String _officerName(String raw) {
    final text = raw.trim();
    final split = text.indexOf(':');
    return split == -1 ? text : text.substring(split + 1).trim();
  }

  String _officerRole(String raw) {
    final text = raw.trim();
    final split = text.indexOf(':');
    return split == -1 ? 'Officer' : text.substring(0, split).trim();
  }

  @override
  Widget build(BuildContext context) {
    final adviserProfile = people.cast<Map<String, dynamic>?>().firstWhere(
      (p) => p?['role']?.toString().toLowerCase() == 'adviser',
      orElse: () => null,
    );
    final officers = org.officers.map((raw) {
      final name = _officerName(raw);
      OrgOfficerProfile? savedProfile;
      for (final profile in org.officerProfiles) {
        if (profile.name.trim().toLowerCase() == name.trim().toLowerCase()) {
          savedProfile = profile;
          break;
        }
      }
      return <String, dynamic>{
        'name': name,
        'role': savedProfile?.role ?? _officerRole(raw),
        'avatar_url': savedProfile?.avatarUrl.isNotEmpty == true
            ? savedProfile!.avatarUrl
            : (_findByName(name)?['avatar_url']?.toString() ?? ''),
      };
    }).toList();

    if (adviserProfile == null && org.adviser.isEmpty && officers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (adviserProfile != null || org.adviser.isNotEmpty) ...[
          const Text('Adviser', style: TextStyle(color: _C.muted, fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _CompactPersonCard(
            name: adviserProfile?['name']?.toString().trim().isNotEmpty == true
                ? adviserProfile!['name'].toString()
                : org.adviser,
            role: 'Adviser',
            avatarUrl: adviserProfile?['avatar_url']?.toString() ?? '',
          ),
          const SizedBox(height: 14),
        ],
        if (officers.isNotEmpty) ...[
          const Text('Officers', style: TextStyle(color: _C.muted, fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          SizedBox(
            height: 214,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: officers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _SquarePersonCard(
                name: officers[i]['name'].toString(),
                role: officers[i]['role'].toString(),
                avatarUrl: officers[i]['avatar_url'].toString(),
                width: 144,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SquarePersonCard extends StatelessWidget {
  final String name;
  final String role;
  final String avatarUrl;
  final double width;
  const _SquarePersonCard({required this.name, required this.role, required this.avatarUrl, this.width = 156});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF3FCF6)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.line, width: 1.1),
        boxShadow: const [
          BoxShadow(color: Color(0x080F8A61), blurRadius: 12, offset: Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: SizedBox(
              height: 122,
              child: avatarUrl.trim().isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: avatarUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _squareFallback(),
                    )
                  : _squareFallback(),
            ),
          ),
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F7EA),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              role,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF15803D),
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                letterSpacing: .45,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _C.ink,
              fontSize: 13.5,
              height: 1.14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _squareFallback() => Container(
    color: _C.mint,
    child: const Center(child: Icon(Icons.person_rounded, color: _C.green, size: 34)),
  );
}

class _CompactPersonCard extends StatelessWidget {
  final String name;
  final String role;
  final String avatarUrl;
  const _CompactPersonCard({required this.name, required this.role, required this.avatarUrl});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _C.line),
      boxShadow: const [BoxShadow(color: Color(0x080F8A61), blurRadius: 12, offset: Offset(0, 5))],
    ),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 74,
            height: 74,
            child: avatarUrl.trim().isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: avatarUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _fallback(),
                  )
                : _fallback(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                role,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _C.green,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .6,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _C.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _fallback() => Container(
    color: _C.mint,
    child: const Center(child: Icon(Icons.person_rounded, color: _C.green, size: 30)),
  );
}

class _ConnectCard extends StatelessWidget {
  final Organization org; const _ConnectCard({required this.org});
  Future<void> _openSocial() async {
    final raw = org.socialLink.trim();
    if (raw.isEmpty) return;
    final candidate = raw.contains('://') ? raw : 'https://$raw';
    Uri? uri = Uri.tryParse(candidate);
    final host = uri?.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    if (host == 'facebook.com' && uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    // Support page usernames saved before URL validation was added.
    if (!raw.contains('/') && !raw.contains(' ') && !raw.contains('.')) {
      uri = Uri.parse('https://www.facebook.com/$raw');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: const LinearGradient(colors: [_C.dark, _C.green]), borderRadius: BorderRadius.circular(20)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('STAY CONNECTED', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .9)), const SizedBox(height: 10),
      if (org.socialLink.isNotEmpty)
        FilledButton.icon(
          onPressed: _openSocial,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: _C.green,
            minimumSize: const Size.fromHeight(44),
          ),
          icon: const Icon(Icons.facebook_rounded),
          label: const Text(
            'Visit their official Facebook page',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
    ]));
}

class _ApplyTab extends StatelessWidget {
  final Organization org;
  const _ApplyTab({required this.org});

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      thumbVisibility: true,
      interactive: true,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The scrollable area starts here, at "Ready to join?".
            _SectionIntro(
              icon: Icons.volunteer_activism_rounded,
              title: 'Ready to join?',
              subtitle: 'Send your application when you are ready to become part of this community.',
            ),
            const SizedBox(height: 16),
            _LazyOrgForm(title: org.name, logoAsset: org.logoAsset, orgId: org.id, category: org.category),
          ],
        ),
      ),
    );
  }
}

class _LazyOrgForm extends StatefulWidget { final String title; final String logoAsset; final String orgId; final String category; const _LazyOrgForm({required this.title, required this.logoAsset, required this.orgId, required this.category}); @override State<_LazyOrgForm> createState() => _LazyOrgFormState(); }
class _LazyOrgFormState extends State<_LazyOrgForm> { bool built = false; Widget? form; @override Widget build(BuildContext context) { if (!built) { built = true; form = OrgFormContent(title: widget.title, logoAsset: widget.logoAsset, orgId: widget.orgId, category: widget.category); } return form!; } }

class _SoftEmpty extends StatelessWidget {
  final IconData icon; final String title; final String subtitle;
  const _SoftEmpty({required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(gradient: const LinearGradient(colors: [_C.mint, Color(0xFFD8F2E7)]), borderRadius: BorderRadius.circular(22), border: Border.all(color: _C.line)),
    child: Column(children: [Container(width: 56, height: 56, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .7), shape: BoxShape.circle), child: Icon(icon, color: _C.green, size: 27)), const SizedBox(height: 10), Text(title, textAlign: TextAlign.center, style: const TextStyle(color: _C.ink, fontSize: 16, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: _C.muted, fontSize: 12.5, height: 1.4))]));
}

