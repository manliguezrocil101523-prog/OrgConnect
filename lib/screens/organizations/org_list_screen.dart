import 'package:flutter/material.dart';
import 'org_profile_screen.dart';

// ─────────────────────────────────────────────
// Data model for an organization entry
// ─────────────────────────────────────────────
class OrgData {
  final String id; // zero-padded, e.g. "001"
  final String name; // display name, e.g. "Primera Bida"
  final String asset; // asset path

  const OrgData({
    required this.id,
    required this.name,
    required this.asset,
  });
}

// ─────────────────────────────────────────────
// Master list of all 22 organizations
// ─────────────────────────────────────────────
const List<OrgData> _allOrgs = [
  OrgData(id: '001', name: 'Primera Bida', asset: 'assets/primerabida.jpg'),
  OrgData(id: '002', name: 'El Tiatro', asset: 'assets/eltiatro.jpg'),
  OrgData(id: '003', name: 'Cronica', asset: 'assets/cronica.jpg'),
  OrgData(id: '004', name: 'BCC Musicality', asset: 'assets/bccmusicality.jpg'),
  OrgData(id: '005', name: 'Drum and Lyre', asset: 'assets/drumandlyre.jpg'),
  OrgData(
      id: '006',
      name: 'Page Turners Book Club',
      asset: 'assets/pageturnersbookclub.jpg'),
  OrgData(id: '007', name: 'Gender United', asset: 'assets/genderunited.jpg'),
  OrgData(
      id: '008', name: 'College Elegante', asset: 'assets/collegeelegante.jpg'),
  OrgData(id: '009', name: 'SCAP', asset: 'assets/scap.jpg'),
  OrgData(
      id: '010', name: 'BCC Nightingale', asset: 'assets/bccnigthngale.jpg'),
  OrgData(id: '011', name: 'Speakiconics', asset: 'assets/speakiconics.jpg'),
  OrgData(
      id: '012',
      name: 'Kultura de Filipino',
      asset: 'assets/culturadefelipino.jpg'),
  OrgData(id: '013', name: 'Inkwell', asset: 'assets/inkwell.jpg'),
  OrgData(
      id: '014',
      name: 'Christian Campus Ministry',
      asset: 'assets/christiancampusministry.jpg'),
  OrgData(id: '015', name: 'BCC ACES', asset: 'assets/bccaces.jpg'),
  OrgData(
      id: '016',
      name: 'Crafty Creators Club',
      asset: 'assets/craftycreatorsclub.jpg'),
  OrgData(id: '017', name: 'SSG', asset: 'assets/ssg.jpg'),
  OrgData(id: '018', name: 'Kasanga Squad', asset: 'assets/kasangasquad.jpg'),
  OrgData(id: '019', name: 'CodeHex', asset: 'assets/codehex.jpg'),
  OrgData(id: '020', name: 'Moto Club', asset: 'assets/motoclub.jpg'),
  OrgData(id: '021', name: 'BCC DC', asset: 'assets/bccdc.jpg'),
  OrgData(
      id: '022',
      name: 'Peer Facilitators Circle',
      asset: 'assets/peerfacilatatorscircles.jpg'),
];

// ─────────────────────────────────────────────
// Color palette & shared constants
// ─────────────────────────────────────────────
class _AppColors {
  static const background = Color(0xFFF0F7F4);
  static const cardBg = Color(0xFFFFFFFF);
  static const accent = Color(0xFF2DBD96); // fresh teal-green
  static const accentDark = Color(0xFF1A8A6C);
  static const textPrimary = Color(0xFF1B3A34);
  static const textSecondary = Color(0xFF5A7A72);
  static const borderColor = Color(0xFFD4EDE5);
  static const searchBg = Color(0xFFFFFFFF);
}

// ─────────────────────────────────────────────
// Main screen (StatefulWidget for search state)
// ─────────────────────────────────────────────
class OrgListScreen extends StatefulWidget {
  const OrgListScreen({super.key});

  @override
  State<OrgListScreen> createState() => _OrgListScreenState();
}

class _OrgListScreenState extends State<OrgListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<OrgData> _filtered = _allOrgs;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  /// Filters orgs in real-time as user types (case-insensitive)
  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? _allOrgs
          : _allOrgs
              .where((o) => o.name.toLowerCase().contains(query))
              .toList();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header image + title ──────────────────
            SliverToBoxAdapter(child: _HeaderSection(onBack: _goBack)),

            // ── Search bar ───────────────────────────
            SliverToBoxAdapter(
              child: _SearchBar(controller: _searchController),
            ),

            // ── Result count label ───────────────────
            SliverToBoxAdapter(
              child: _ResultCountLabel(count: _filtered.length),
            ),

            // ── Organization grid ────────────────────
            _filtered.isEmpty
                ? const SliverFillRemaining(child: _EmptyState())
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _OrgCard(org: _filtered[index]),
                        childCount: _filtered.length,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 1.05,
                      ),
                    ),
                  ),

            // ── Bottom tagline ────────────────────────
            const SliverToBoxAdapter(child: _FooterTagline()),
          ],
        ),
      ),
    );
  }

  void _goBack() => Navigator.pushReplacementNamed(context, '/home');
}

// ─────────────────────────────────────────────
// Header: banner image + back button + title
// ─────────────────────────────────────────────
class _HeaderSection extends StatelessWidget {
  final VoidCallback onBack;
  const _HeaderSection({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Banner image
        ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
          child: Image.asset(
            'assets/newheader.jpg',
            fit: BoxFit.cover,
            width: double.infinity,
            height: 110,
          ),
        ),

        // Dark gradient overlay for readability
        Positioned.fill(
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    _AppColors.textPrimary.withOpacity(0.45),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Back button (top-left)
        Positioned(
          top: 10,
          left: 12,
          child: _BackButton(onTap: onBack),
        ),

        // Title overlay (bottom-left)
        Positioned(
          bottom: 14,
          left: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Organizations',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.3,
                  shadows: [
                    Shadow(
                        blurRadius: 6,
                        color: Colors.black45,
                        offset: Offset(0, 1)),
                  ],
                ),
              ),
              Text(
                'Discover your passion',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Pill-shaped back button
// ─────────────────────────────────────────────
class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.88),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.arrow_back_ios_new_rounded,
                size: 14, color: _AppColors.accentDark),
            SizedBox(width: 4),
            Text(
              'Back',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _AppColors.accentDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Search bar
// ─────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          color: _AppColors.searchBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A2DBD96),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          style: const TextStyle(
            fontSize: 14.5,
            color: _AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Search organizations…',
            hintStyle: const TextStyle(
              color: _AppColors.textSecondary,
              fontSize: 14,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: _AppColors.accent,
              size: 22,
            ),
            // Clear button appears only when there is text
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, __) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: _AppColors.textSecondary, size: 18),
                      onPressed: controller.clear,
                    ),
            ),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Small label showing how many results are visible
// ─────────────────────────────────────────────
class _ResultCountLabel extends StatelessWidget {
  final int count;
  const _ResultCountLabel({required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
      child: Text(
        '$count ${count == 1 ? 'organization' : 'organizations'} found',
        style: const TextStyle(
          fontSize: 12.5,
          color: _AppColors.textSecondary,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Individual organization card
// ─────────────────────────────────────────────
class _OrgCard extends StatelessWidget {
  final OrgData org;
  const _OrgCard({required this.org});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // ── Navigation: original logic untouched ──
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrgDetailScreen(orgId: org.id),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: _AppColors.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _AppColors.borderColor, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x142DBD96),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Column(
            children: [
              // ── Logo area ──────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Image.asset(
                    org.asset,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),

              // ── Name label strip ───────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                decoration: const BoxDecoration(
                  color: Color(0xFFEAF8F3),
                  border: Border(
                    top: BorderSide(color: _AppColors.borderColor, width: 1),
                  ),
                ),
                child: Text(
                  org.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _AppColors.textPrimary,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Empty state when search has no results
// ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded,
              size: 56, color: _AppColors.accent.withOpacity(0.4)),
          const SizedBox(height: 14),
          const Text(
            'No organizations found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try a different keyword',
            style: TextStyle(fontSize: 12.5, color: _AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Bottom motivational tagline
// ─────────────────────────────────────────────
class _FooterTagline extends StatelessWidget {
  const _FooterTagline();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
              width: 32,
              height: 1.5,
              color: _AppColors.accent.withOpacity(0.4)),
          const SizedBox(width: 10),
          const Text(
            'Find your community',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 10),
          Container(
              width: 32,
              height: 1.5,
              color: _AppColors.accent.withOpacity(0.4)),
        ],
      ),
    );
  }
}
