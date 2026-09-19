import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'org_profile_screen.dart';
import '../../core/app_state.dart';

class _AppColors {
  static const background = Color(0xFFF1FAF6);
  static const surface = Color(0xFFFFFFFF);
  static const mint = Color(0xFFE2F6ED);
  static const accent = Color(0xFF13A76E);
  static const accent2 = Color(0xFF1EBD7D);
  static const accentDark = Color(0xFF087A50);
  static const textPrimary = Color(0xFF143A2C);
  static const textSecondary = Color(0xFF5B776B);
  static const border = Color(0xFFCDEBDD);
}

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await AppState.instance.fetchOrganizations();
    });
  }

  void _onSearchChanged() {
    if (!mounted) return;
    setState(() => _query = _searchController.text.trim().toLowerCase());
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  List<Organization> get _filtered {
    final organizations = AppState.instance.organizations;
    if (_query.isEmpty) return organizations;
    return organizations.where((org) {
      final values = [
        org.name,
        org.acronym,
        org.category,
        org.shortDesc,
      ].map((e) => e.toLowerCase());
      return values.any((value) => value.contains(_query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final organizations = _filtered;
        return Scaffold(
          backgroundColor: _AppColors.background,
          body: SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(child: _HeaderSection()),
                SliverToBoxAdapter(
                  child: _SearchBar(controller: _searchController),
                ),
                SliverToBoxAdapter(
                  child: _ResultHeader(count: organizations.length),
                ),
                if (organizations.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _OrgCard(org: organizations[index]),
                        childCount: organizations.length,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.88,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_AppColors.accent, _AppColors.accent2],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [          Row(
            children: [
              IconButton(
                tooltip: 'Back',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 25),
                onPressed: () {
                  Navigator.of(context).maybePop();
                },
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Organizations',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Find your campus community',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Explore clubs, communities, and groups that match your interests.',
            style: TextStyle(
              color: Color(0xFFE4FFF4),
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.explore_rounded, size: 16, color: Colors.white),
                SizedBox(width: 7),
                Text(
                  'Campus • Clubs • Community',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;

  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
      child: Material(
        color: _AppColors.surface,
        elevation: 0,
        borderRadius: BorderRadius.circular(18),
        child: TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          style: const TextStyle(
            color: _AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Search organizations…',
            hintStyle: const TextStyle(color: _AppColors.textSecondary),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: _AppColors.accent,
            ),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, __) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      onPressed: controller.clear,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: _AppColors.textSecondary,
                        size: 19,
                      ),
                    ),
            ),
            filled: true,
            fillColor: _AppColors.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 15),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: _AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide:
                  const BorderSide(color: _AppColors.accent, width: 1.4),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultHeader extends StatelessWidget {
  final int count;
  const _ResultHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 10),
      child: Row(
        children: [
          const Text(
            'Campus organizations',
            style: TextStyle(
              color: _AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: _AppColors.mint,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count found',
              style: const TextStyle(
                color: _AppColors.accentDark,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrgCard extends StatelessWidget {
  final Organization org;
  const _OrgCard({required this.org});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrgDetailScreen(orgId: org.id),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1013A76E),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: _AppColors.mint,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: _OrganizationImage(logoAsset: org.logoAsset),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(9, 4, 9, 12),
                  child: Column(
                    children: [
                      Text(
                        org.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _AppColors.textPrimary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrganizationImage extends StatelessWidget {
  final String logoAsset;
  const _OrganizationImage({required this.logoAsset});

  @override
  Widget build(BuildContext context) {
    final path = logoAsset.trim();
    if (path.isEmpty) return const _ImageFallback();

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: path,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
        placeholder: (_, __) => const _ImageLoading(),
        errorWidget: (_, __, ___) => const _ImageFallback(),
      );
    }

    // Local organization logos are stored as JPGs in older records. The project
    // ships transparent PNG companions, so a JPG path is upgraded automatically.
    final transparentPath = path.toLowerCase().endsWith('.jpg')
        ? '${path.substring(0, path.length - 4)}.png'
        : path.toLowerCase().endsWith('.jpeg')
            ? '${path.substring(0, path.length - 5)}.png'
            : path;

    return Image.asset(
      transparentPath,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        path,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const _ImageFallback(),
      ),
    );
  }
}

class _ImageLoading extends StatelessWidget {
  const _ImageLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 25,
        height: 25,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: _AppColors.accent,
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.groups_rounded,
        color: _AppColors.accent,
        size: 42,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.search_off_rounded, size: 52, color: _AppColors.accent),
            SizedBox(height: 12),
            Text(
              'No organizations found',
              style: TextStyle(
                color: _AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Try a different keyword.',
              style: TextStyle(color: _AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
