import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'org_profile_screen.dart';
import '../../core/app_state.dart';
import '../../widgets/app_header.dart';

class _AppColors {
  static const background = Color(0xFFF1FAF6);
  static const surface = Color(0xFFFFFFFF);
  static const mint = Color(0xFFE2F6ED);
  static const accent = Color(0xFF13A76E);
  static const accentDark = Color(0xFF087A50);
  static const textPrimary = Color(0xFF143A2C);
  static const textSecondary = Color(0xFF5B776B);
  static const border = Color(0xFFCDEBDD);
}

class OrgListScreen extends StatefulWidget {
  final bool showBackButton;

  const OrgListScreen({super.key, this.showBackButton = false});

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
          body: Column(
            children: [
              AppHeader(
                title: 'Organizations',
                subtitle: 'Find your campus community',
                status:
                    '${AppState.instance.organizations.length} ORGANIZATIONS',
                icon: Icons.groups_rounded,
                onBack: widget.showBackButton
                    ? () => Navigator.of(context).maybePop()
                    : null,
              ),
              Expanded(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
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
                            (context, index) =>
                                _OrgCard(org: organizations[index]),
                            childCount: organizations.length,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.73,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;

  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 3),
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
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0F8A61),
                blurRadius: 16,
                offset: Offset(0, 7),
              ),
            ],
          ),
          padding: const EdgeInsets.all(11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFEFFBF5), Color(0xFFDDF4E8)],
                    ),
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: _AppColors.border),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: _OrganizationImage(logoAsset: org.logoAsset),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                org.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
              if (org.category.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _AppColors.mint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    org.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _AppColors.accentDark,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      org.shortDesc.isEmpty
                          ? 'Campus community'
                          : org.shortDesc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _AppColors.textSecondary,
                        fontSize: 10.3,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _AppColors.mint,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 15,
                      color: _AppColors.accentDark,
                    ),
                  ),
                ],
              ),
            ],
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
