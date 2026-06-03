import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import 'org_form_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

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
                _MediaGalleryCard(
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

// =============================================================================
// _MediaGalleryCard — rich display for Activities & Events
// =============================================================================
class _MediaGalleryCard extends StatelessWidget {
  final List<OrgMediaItem> items;
  final Color accentColor;

  const _MediaGalleryCard({
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.event_note_rounded,
                    color: accentColor, size: 18),
              ),
              const SizedBox(width: 12),
              const Text(
                'ACTIVITIES & EVENTS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _AppColors.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Media items ───────────────────────────────────────────────────
          ...items.map((item) => _buildItem(context, item)),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, OrgMediaItem item) {
    switch (item.type) {
      case 'image':
        return _ImageItem(item: item, accentColor: accentColor);
      case 'video':
        return _VideoItem(item: item);
      case 'text':
      default:
        return _TextItem(item: item, accentColor: accentColor);
    }
  }
}

// ── Text item ──────────────────────────────────────────────────────────────
class _TextItem extends StatelessWidget {
  final OrgMediaItem item;
  final Color accentColor;
  const _TextItem({required this.item, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6, right: 10),
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              item.content,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: _AppColors.textDark,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Image item ─────────────────────────────────────────────────────────────
class _ImageItem extends StatelessWidget {
  final OrgMediaItem item;
  final Color accentColor;
  const _ImageItem({required this.item, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: () => _openFullscreen(context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: item.content,
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder: (_, __) => Container(
                  height: 180,
                  color: Colors.grey.shade100,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (_, __, ___) => Container(
                  height: 100,
                  color: Colors.grey.shade100,
                  child: const Icon(Icons.broken_image_rounded,
                      color: Colors.grey),
                ),
              ),
            ),
          ),
          if (item.caption.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.caption,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  void _openFullscreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: item.caption.isNotEmpty
                ? Text(item.caption,
                    style: const TextStyle(color: Colors.white, fontSize: 14))
                : null,
          ),
          body: Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: item.content,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Video item ─────────────────────────────────────────────────────────────
class _VideoItem extends StatefulWidget {
  final OrgMediaItem item;
  const _VideoItem({required this.item});

  @override
  State<_VideoItem> createState() => _VideoItemState();
}

class _VideoItemState extends State<_VideoItem> {
  late VideoPlayerController _ctrl;
  ChewieController? _chewieCtrl;
  bool _initialized = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.item.content))
      ..initialize().then((_) {
        if (mounted) {
          _chewieCtrl = ChewieController(
            videoPlayerController: _ctrl,
            autoPlay: false,
            looping: false,
            allowFullScreen: true,
            aspectRatio: _ctrl.value.aspectRatio,
            placeholder: Container(color: Colors.black12),
          );
          setState(() => _initialized = true);
        }
      }).catchError((_) {
        if (mounted) setState(() => _error = true);
      });
  }

  @override
  void dispose() {
    _chewieCtrl?.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _error
                ? Container(
                    height: 120,
                    color: Colors.grey.shade100,
                    child: const Center(
                        child: Icon(Icons.videocam_off_rounded,
                            color: Colors.grey, size: 36)),
                  )
                : !_initialized
                    ? Container(
                        height: 180,
                        color: Colors.black12,
                        child: const Center(child: CircularProgressIndicator()),
                      )
                    : AspectRatio(
                        aspectRatio: _ctrl.value.aspectRatio,
                        child: Chewie(controller: _chewieCtrl!),
                      ),
          ),
          if (widget.item.caption.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              widget.item.caption,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
