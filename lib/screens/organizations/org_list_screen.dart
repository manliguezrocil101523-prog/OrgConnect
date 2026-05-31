import 'package:flutter/material.dart';
import 'org_profile_screen.dart';
import '../../core/app_state.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    // Refresh from Supabase every time this screen opens
    @override
    void initState() {
      super.initState();
      _searchController.addListener(_onSearchChanged);

      // ✅ Defer until after the first frame is fully built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppState.instance.fetchOrganizations();
      });
    }
  }

  void _onSearchChanged() {
    setState(() => _query = _searchController.text.trim().toLowerCase());
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  List<Organization> get _filtered {
    final orgs = AppState.instance.organizations;
    if (_query.isEmpty) return orgs;
    return orgs.where((o) => o.name.toLowerCase().contains(_query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final filtered = _filtered;
        return Scaffold(
          backgroundColor: _AppColors.background,
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _HeaderSection(onBack: _goBack)),
                SliverToBoxAdapter(
                  child: _SearchBar(controller: _searchController),
                ),
                SliverToBoxAdapter(
                  child: _ResultCountLabel(count: filtered.length),
                ),
                filtered.isEmpty
                    ? const SliverFillRemaining(child: _EmptyState())
                    : SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _OrgCard(org: filtered[index]),
                            childCount: filtered.length,
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
                const SliverToBoxAdapter(child: _FooterTagline()),
              ],
            ),
          ),
        );
      },
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
  final Organization org;
  const _OrgCard({required this.org});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: // NEW — replace with this
                      org.logoAsset.startsWith('http')
                          ? CachedNetworkImage(
                              imageUrl: org.logoAsset,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                              placeholder: (context, url) => const Center(
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: _AppColors.accent,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => const Icon(
                                Icons.groups_rounded,
                                color: _AppColors.accent,
                                size: 40,
                              ),
                            )
                          : const Icon(
                              Icons.groups_rounded,
                              color: _AppColors.accent,
                              size: 40,
                            ),
                ),
              ),
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
