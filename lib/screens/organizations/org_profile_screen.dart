import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import 'org_form_screen.dart';

// =============================================================================
// DESIGN SYSTEM TOKENS
// Centralized to prevent repeating across classes.
// Ideally, these should live in your Theme.of(context).
// =============================================================================
abstract class _AppColors {
  static const primary = Color(0xFF4F46E5);
  static const secondary = Color(0xFF06B6D4);
  static const background = Color(0xFFF8FAFC);
  static const textDark = Color(0xFF0F172A);
  static const textMuted = Color(0xFF94A3B8);
}

class OrgDetailScreen extends StatefulWidget {
  final String orgId;
  const OrgDetailScreen({super.key, required this.orgId});

  @override
  State<OrgDetailScreen> createState() => _OrgDetailScreenState();
}

class _OrgDetailScreenState extends State<OrgDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    // REMOVED: _tabCtrl.addListener(() => setState(() {}));
    // TabBarView handles its own state. Do not trigger global rebuilds.
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // FIXED: Safe retrieval. Prevents 'StateError' crashes if org is missing.
    // In a real app, you would show a "404 Not Found" widget if org == null.
    final orgMatches =
        AppState.instance.organizations.where((o) => o.id == widget.orgId);

    if (orgMatches.isEmpty) {
      return const Scaffold(
          body: Center(child: Text('Organization not found')));
    }

    final org = orgMatches.first;

    return Scaffold(
      backgroundColor: _AppColors.background,
      body: NestedScrollView(
        physics: const BouncingScrollPhysics(),
        floatHeaderSlivers: true,
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: MediaQuery.of(context).size.height * 0.38,
            backgroundColor: _AppColors.primary,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  Navigator.pushReplacementNamed(context, '/home');
                }
              },
            ),
            title: Text(
              org.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                letterSpacing: 0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            centerTitle: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _OrgHeroHeader(org: org),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabCtrl,
                  labelColor: _AppColors.primary,
                  unselectedLabelColor: _AppColors.textMuted,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  indicatorColor: _AppColors.primary,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.label,
                  tabs: const [
                    Tab(text: 'About'),
                    Tab(text: 'Apply'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            PrimaryScrollController.none(child: _ProfileTab(org: org)),
            PrimaryScrollController.none(
                child: _ApplyTab(org: org, orgId: widget.orgId)),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// _OrgHeroHeader
// =============================================================================
class _OrgHeroHeader extends StatelessWidget {
  final Organization org;
  const _OrgHeroHeader({required this.org});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final logoSize = (size.width * 0.22).clamp(72.0, 100.0);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_AppColors.primary, _AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
              top: -30,
              right: -20,
              child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.07)))),
          Positioned(
              bottom: 30,
              left: -40,
              child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.05)))),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 52),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: logoSize + 12,
                    height: logoSize + 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Container(
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle, color: Colors.white),
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: ClipOval(
                            child: org.logoAsset.startsWith('http')
                                ? Image.network(
                                    org.logoAsset,
                                    width: logoSize,
                                    height: logoSize,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => CircleAvatar(
                                      radius: logoSize / 2,
                                      backgroundColor: const Color(0xFFE0E7FF),
                                      child: const Icon(Icons.groups_rounded,
                                          color: _AppColors.primary, size: 36),
                                    ),
                                  )
                                : Image.asset(
                                    org.logoAsset.isNotEmpty
                                        ? org.logoAsset
                                        : 'assets/primerabida.jpg',
                                    width: logoSize,
                                    height: logoSize,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => CircleAvatar(
                                      radius: logoSize / 2,
                                      backgroundColor: const Color(0xFFE0E7FF),
                                      child: const Icon(Icons.groups_rounded,
                                          color: _AppColors.primary, size: 36),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      org.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (org.acronym.isNotEmpty) ...[
                        _HeaderPill(org.acronym),
                        const SizedBox(width: 8),
                      ],
                      if (org.category.isNotEmpty) _HeaderPill(org.category),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  final String text;
  const _HeaderPill(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.30), width: 1),
        ),
        child: Text(text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            )),
      );
}

// =============================================================================
// _ProfileTab
// =============================================================================
class _ProfileTab extends StatefulWidget {
  final Organization org;
  const _ProfileTab({required this.org});

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by mixin
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.org.about.isNotEmpty)
                _InfoCard(
                    icon: Icons.info_rounded,
                    label: 'About',
                    value: widget.org.about,
                    multiLine: true),
              if (widget.org.missionVision.isNotEmpty)
                _InfoCard(
                    icon: Icons.flag_rounded,
                    label: 'Mission & Vision',
                    value: widget.org.missionVision,
                    multiLine: true),
              if (widget.org.adviser.isNotEmpty)
                _InfoCard(
                    icon: Icons.person_rounded,
                    label: 'Adviser',
                    value: widget.org.adviser),
              if (widget.org.contactEmail.isNotEmpty ||
                  widget.org.contactPhone.isNotEmpty ||
                  widget.org.socialLink.isNotEmpty)
                _ContactCard(org: widget.org),
              if (widget.org.officers.isNotEmpty)
                _ListCard(
                  icon: Icons.people_rounded,
                  label: 'Officers',
                  items: widget.org.officers,
                  accentColor: _AppColors.primary,
                ),
              if (widget.org.activitiesHighlights.isNotEmpty)
                _ListCard(
                  icon: Icons.event_note_rounded,
                  label: 'Activities & Events',
                  items: widget.org.activitiesHighlights,
                  accentColor: _AppColors.secondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _ApplyTab
// =============================================================================
class _ApplyTab extends StatelessWidget {
  final Organization org;
  final String orgId;
  const _ApplyTab({required this.org, required this.orgId});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_AppColors.primary, _AppColors.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _AppColors.primary.withOpacity(0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.assignment_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Join the Organization',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text(
                          'Apply to ${org.name}',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.78),
                              fontSize: 12.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              // UNTOUCHED: original form widget
              // Lazy-loaded: only builds when Apply tab is first shown
              _LazyOrgForm(title: org.name, logoAsset: org.logoAsset),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Shared info row widgets
// =============================================================================

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool multiLine;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    this.multiLine = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: _AppColors.primary.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 5)),
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment:
            multiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _AppColors.textMuted,
                      letterSpacing: 0.8,
                    )),
                const SizedBox(height: 4),
                Text(value,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: _AppColors.textDark,
                      height: multiLine ? 1.5 : 1.2,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final Organization org;
  const _ContactCard({required this.org});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: _AppColors.primary.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _AppColors.secondary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.contact_mail_rounded,
                color: _AppColors.secondary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CONTACT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _AppColors.textMuted,
                      letterSpacing: 0.8,
                    )),
                const SizedBox(height: 6),
                if (org.contactEmail.isNotEmpty)
                  _contactRow(Icons.email_rounded, org.contactEmail),
                if (org.contactPhone.isNotEmpty)
                  _contactRow(Icons.phone_rounded, org.contactPhone),
                if (org.socialLink.isNotEmpty)
                  _contactRow(Icons.link_rounded, org.socialLink),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(children: [
          Icon(icon, size: 13, color: _AppColors.textMuted),
          const SizedBox(width: 6),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _AppColors.textDark,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis)),
        ]),
      );
}

class _ListCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<String> items;
  final Color accentColor;

  const _ListCard({
    required this.icon,
    required this.label,
    required this.items,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: accentColor.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _AppColors.textMuted,
                      letterSpacing: 0.8,
                    )),
                const SizedBox(height: 8),
                ...items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(top: 5, right: 8),
                            decoration: BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                              child: Text(item,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                    color: _AppColors.textDark,
                                    height: 1.4,
                                  ))),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LazyOrgForm extends StatefulWidget {
  final String title;
  final String logoAsset;
  const _LazyOrgForm({required this.title, required this.logoAsset});

  @override
  State<_LazyOrgForm> createState() => _LazyOrgFormState();
}

class _LazyOrgFormState extends State<_LazyOrgForm> {
  bool _hasBuilt = false;
  Widget? _form;

  @override
  Widget build(BuildContext context) {
    if (!_hasBuilt) {
      _hasBuilt = true;
      _form = OrgFormContent(title: widget.title, logoAsset: widget.logoAsset);
    }
    return _form!;
  }
}
