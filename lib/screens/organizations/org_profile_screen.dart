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

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _loggedIn ? 3 : 2, vsync: this);
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
            height: 210,
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
            height: 54,
            color: _C.bg,
            child: TabBar(
              controller: _tabs,
              labelColor: _C.green,
              unselectedLabelColor: _C.muted,
              indicatorColor: _C.green,
              indicatorWeight: 3,
              tabs: [
                const Tab(icon: Icon(Icons.dashboard_rounded, size: 18), text: 'Dashboard'),
                const Tab(icon: Icon(Icons.auto_awesome_rounded, size: 18), text: 'About'),
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
                _AboutTab(org: org),
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
        Positioned(top: -55, right: -35, child: _orb(180, Colors.white.withOpacity(.08))),
        Positioned(bottom: -45, left: -45, child: _orb(140, Colors.black.withOpacity(.07))),
        SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 8, 24, 10),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _Logo(asset: org.logoAsset, size: 64),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(org.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 21, height: 1.1, fontWeight: FontWeight.w900)),
                        if (org.category.isNotEmpty) ...[
                          const SizedBox(height: 9),
                          Align(alignment: Alignment.centerLeft, child: _Pill(org.category)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (org.shortDesc.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(org.shortDesc, textAlign: TextAlign.left, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withOpacity(.82), fontSize: 12.5, height: 1.35)),
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
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(.16),
          border: Border.all(color: Colors.white.withOpacity(.26))),
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
    decoration: BoxDecoration(color: Colors.white.withOpacity(.15), borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(.22))),
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
    final events = AppState.instance.events.where((e) =>
        e.orgId == org.id || (e.orgId == null && e.orgName.toLowerCase() == org.name.toLowerCase())).toList();
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
          SizedBox(height: 245, child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _EventVisualCard(event: events[i]),
          )),
        ] else ...[
          const SizedBox(height: 14),
          _SoftEmpty(icon: Icons.event_note_rounded, title: 'No upcoming events yet',
              subtitle: 'New activities from this organization will appear here.'),
        ],
        if (_isReligious()) ...[
          const SizedBox(height: 18),
          _WeeklyCard(org: org),
        ],
        if (media.isNotEmpty) ...[
          const SizedBox(height: 20),
          _TitleRow(title: 'Activities & highlights', icon: Icons.photo_library_rounded, count: media.length),
          const SizedBox(height: 10),
          SizedBox(height: 190, child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: media.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _MediaTile(item: media[i]),
          )),
        ],
      ]),
    );
  }
}

class _EventVisualCard extends StatelessWidget {
  final Event event;
  const _EventVisualCard({required this.event});
  @override
  Widget build(BuildContext context) {
    final image = event.imageUrl ?? (event.imageUrls.isNotEmpty ? event.imageUrls.first : '');
    return Container(width: 255, clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: _C.line),
          boxShadow: const [BoxShadow(color: Color(0x100F8A61), blurRadius: 15, offset: Offset(0, 7))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(height: 128, width: double.infinity, child: image.isNotEmpty
            ? Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _eventArt())
            : _eventArt()),
        Padding(padding: const EdgeInsets.fromLTRB(13, 11, 13, 13), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _C.ink, fontWeight: FontWeight.w900, fontSize: 15, height: 1.15)),
          const SizedBox(height: 7),
          Row(children: [const Icon(Icons.calendar_month_rounded, size: 14, color: _C.green), const SizedBox(width: 5),
            Expanded(child: Text('${event.date.month}/${event.date.day}/${event.date.year}', style: const TextStyle(color: _C.muted, fontSize: 11.5, fontWeight: FontWeight.w700)))]),
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
        boxShadow: [BoxShadow(color: _C.green.withOpacity(.16), blurRadius: 18, offset: const Offset(0, 8))]),
    child: Row(children: [
      Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.white.withOpacity(.13), borderRadius: BorderRadius.circular(16)),
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
  @override
  Widget build(BuildContext context) {
    final isVideo = item.type == 'video';
    return Container(width: 180, clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _C.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Stack(children: [Positioned.fill(child: item.content.startsWith('http')
          ? Image.network(item.content, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _mediaFallback())
          : _mediaFallback()), if (isVideo) const Positioned(right: 9, top: 9, child: CircleAvatar(radius: 16, backgroundColor: Color(0xAA0F8A61), child: Icon(Icons.play_arrow_rounded, color: Colors.white)))])),
        if (item.caption.isNotEmpty) Padding(padding: const EdgeInsets.all(10), child: Text(item.caption, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _C.ink, fontSize: 11.5, fontWeight: FontWeight.w700))),
      ]));
  }
  Widget _mediaFallback() => Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [_C.mint, Color(0xFFC7EDDD)])),
      child: const Center(child: Icon(Icons.photo_rounded, color: _C.green, size: 32)));
}

class _AboutTab extends StatelessWidget {
  final Organization org;
  const _AboutTab({required this.org});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    physics: const BouncingScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(18, 20, 18, 48),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _SectionIntro(icon: Icons.auto_awesome_rounded, title: 'Get to know the organization', subtitle: 'The people, purpose, and ways to stay connected.'),
      const SizedBox(height: 14),
      if (org.about.isNotEmpty) _StoryCard(icon: Icons.info_rounded, title: 'Who they are', body: org.about),
      if (org.mission.isNotEmpty || org.vision.isNotEmpty || org.missionVision.isNotEmpty) ...[
        const SizedBox(height: 12),
        _MissionVisionCard(mission: org.mission.isNotEmpty ? org.mission : org.missionVision, vision: org.vision),
      ],
      if (org.adviser.isNotEmpty) ...[
        const SizedBox(height: 12),
        _PersonCard(title: 'Adviser', name: org.adviser, icon: Icons.school_rounded),
      ],
      if (org.officers.isNotEmpty) ...[
        const SizedBox(height: 16),
        _OfficerSection(officers: org.officers),
      ],
      if (org.socialLink.isNotEmpty || org.contactEmail.isNotEmpty || org.contactPhone.isNotEmpty) ...[
        const SizedBox(height: 16),
        _ConnectCard(org: org),
      ],
      if (org.about.isEmpty && org.mission.isEmpty && org.vision.isEmpty && org.missionVision.isEmpty && org.adviser.isEmpty && org.officers.isEmpty && org.socialLink.isEmpty)
        _SoftEmpty(icon: Icons.info_outline_rounded, title: 'More details coming soon', subtitle: 'This organization has not added its full profile yet.'),
    ]));
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
  final IconData icon; final String title; final String body;
  const _StoryCard({required this.icon, required this.title, required this.body});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _C.line),
      boxShadow: const [BoxShadow(color: Color(0x090F8A61), blurRadius: 15, offset: Offset(0, 6))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Container(width: 38, height: 38, decoration: BoxDecoration(color: _C.mint, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: _C.green, size: 19)), const SizedBox(width: 10),
      Text(title, style: const TextStyle(color: _C.ink, fontWeight: FontWeight.w900, fontSize: 15))]),
    const SizedBox(height: 12), Text(body, style: const TextStyle(color: _C.muted, fontSize: 13.5, height: 1.55)),
  ]));
}

class _MissionVisionCard extends StatelessWidget {
  final String mission, vision;
  const _MissionVisionCard({required this.mission, required this.vision});
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFE5F8F0), Color(0xFFD2F0E4)]), borderRadius: BorderRadius.circular(20), border: Border.all(color: _C.line)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (mission.isNotEmpty) ...[const Text('MISSION', style: TextStyle(color: _C.green, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .9)), const SizedBox(height: 7), Text(mission, style: const TextStyle(color: _C.ink, fontSize: 13.5, height: 1.55, fontWeight: FontWeight.w600))],
    if (mission.isNotEmpty && vision.isNotEmpty) const SizedBox(height: 15),
    if (vision.isNotEmpty) ...[const Text('VISION', style: TextStyle(color: _C.green, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .9)), const SizedBox(height: 7), Text(vision, style: const TextStyle(color: _C.ink, fontSize: 13.5, height: 1.55, fontWeight: FontWeight.w600))],
  ]));
}

class _PersonCard extends StatelessWidget {
  final String title; final String name; final IconData icon;
  const _PersonCard({required this.title, required this.name, required this.icon});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _C.line)),
    child: Row(children: [Container(width: 52, height: 52, decoration: BoxDecoration(gradient: const LinearGradient(colors: [_C.green, _C.bright]), shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 23)), const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title.toUpperCase(), style: const TextStyle(color: _C.muted, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .8)), const SizedBox(height: 3), Text(name, style: const TextStyle(color: _C.ink, fontSize: 14.5, fontWeight: FontWeight.w900))]))]));
}

class _OfficerSection extends StatelessWidget {
  final List<String> officers; const _OfficerSection({required this.officers});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _C.line)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Row(children: [Icon(Icons.groups_rounded, color: _C.green, size: 19), SizedBox(width: 7), Text('Officers', style: TextStyle(color: _C.ink, fontSize: 15, fontWeight: FontWeight.w900))]), const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: officers.map((o) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: _C.mint, borderRadius: BorderRadius.circular(13)), child: Row(mainAxisSize: MainAxisSize.min, children: [const CircleAvatar(radius: 13, backgroundColor: _C.green, child: Icon(Icons.person_rounded, color: Colors.white, size: 14)), const SizedBox(width: 7), ConstrainedBox(constraints: const BoxConstraints(maxWidth: 180), child: Text(o, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.ink, fontSize: 11.5, fontWeight: FontWeight.w700)))]))).toList())]));
}

class _ConnectCard extends StatelessWidget {
  final Organization org; const _ConnectCard({required this.org});
  Future<void> _openSocial() async {
    final raw = org.socialLink.trim();
    if (raw.isEmpty) return;
    final uri = Uri.tryParse(raw.startsWith('http') ? raw : 'https://$raw');
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: const LinearGradient(colors: [_C.dark, _C.green]), borderRadius: BorderRadius.circular(20)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('STAY CONNECTED', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .9)), const SizedBox(height: 10),
      if (org.socialLink.isNotEmpty) FilledButton.icon(onPressed: _openSocial, style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _C.green, minimumSize: const Size.fromHeight(44)), icon: const Icon(Icons.facebook_rounded), label: const Text('Visit their Facebook / social page', style: TextStyle(fontWeight: FontWeight.w900))),
      if (org.contactEmail.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(org.contactEmail, style: const TextStyle(color: Colors.white, fontSize: 12.5))),
      if (org.contactPhone.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(org.contactPhone, style: const TextStyle(color: Colors.white70, fontSize: 12.5))),
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
            _LazyOrgForm(title: org.name, logoAsset: org.logoAsset),
          ],
        ),
      ),
    );
  }
}

class _LazyOrgForm extends StatefulWidget { final String title; final String logoAsset; const _LazyOrgForm({required this.title, required this.logoAsset}); @override State<_LazyOrgForm> createState() => _LazyOrgFormState(); }
class _LazyOrgFormState extends State<_LazyOrgForm> { bool built = false; Widget? form; @override Widget build(BuildContext context) { if (!built) { built = true; form = OrgFormContent(title: widget.title, logoAsset: widget.logoAsset); } return form!; } }

class _SoftEmpty extends StatelessWidget {
  final IconData icon; final String title; final String subtitle;
  const _SoftEmpty({required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(gradient: const LinearGradient(colors: [_C.mint, Color(0xFFD8F2E7)]), borderRadius: BorderRadius.circular(22), border: Border.all(color: _C.line)),
    child: Column(children: [Container(width: 56, height: 56, decoration: BoxDecoration(color: Colors.white.withOpacity(.7), shape: BoxShape.circle), child: Icon(icon, color: _C.green, size: 27)), const SizedBox(height: 10), Text(title, textAlign: TextAlign.center, style: const TextStyle(color: _C.ink, fontSize: 16, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: _C.muted, fontSize: 12.5, height: 1.4))]));
}
