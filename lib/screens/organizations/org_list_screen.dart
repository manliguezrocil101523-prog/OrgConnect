import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'org_profile_screen.dart';
import '../../core/app_state.dart';
import '../Student_Role/home/home_tokens.dart';

class _AppColors {
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const mint = HC.mint;
  static const accent = HC.primary;
  static const accentDark = Color(0xFF0B6B4D);
  static const textPrimary = HC.ink;
  static const textSecondary = HC.muted;
  static const border = HC.line;
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
  String _selectedCategory = 'All';
  String _sortOption = 'Default';
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrganizations();
    });
  }

  Future<void> _loadOrganizations() async {
    if (!mounted) return;
    final hasData = AppState.instance.organizations.isNotEmpty;
    setState(() {
      _isLoading = !hasData;
      _hasError = false;
    });
    try {
      await AppState.instance.fetchOrganizations();
      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _refreshOrganizations() async {
    setState(() => _hasError = false);
    try {
      await AppState.instance.fetchOrganizations();
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasError = true);
    }
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

  List<String> get _availableCategories {
    final orgs = AppState.instance.organizations;
    final set = <String>{};
    for (final org in orgs) {
      final cat = org.category.trim();
      if (cat.isNotEmpty) {
        set.add(cat);
      }
    }
    final list = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['All', ...list];
  }

  List<Organization> get _filtered {
    final organizations = AppState.instance.organizations;
    var list = organizations.where((org) {
      if (_selectedCategory == 'All') return true;
      return org.category.trim().toLowerCase() ==
          _selectedCategory.toLowerCase();
    }).toList();

    if (_query.isNotEmpty) {
      list = list.where((org) {
        final values = [
          org.name,
          org.acronym,
          org.category,
          org.shortDesc,
        ].map((e) => e.toLowerCase());
        return values.any((value) => value.contains(_query));
      }).toList();
    }

    if (_sortOption == 'Name A–Z') {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (_sortOption == 'Name Z–A') {
      list.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
    }

    return list;
  }

  bool get _isFilterModified =>
      _selectedCategory != 'All' || _sortOption != 'Default';

  void _openFilterBottomSheet() {
    String tempCategory = _selectedCategory;
    String tempSort = _sortOption;
    final categories = _availableCategories;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                16,
                24,
                MediaQuery.paddingOf(context).bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Filter & Sort Organizations',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Sort By',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: ['Default', 'Name A–Z', 'Name Z–A'].map((sort) {
                        final isSelected = tempSort == sort;
                        return ChoiceChip(
                          label: Text(sort),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setModalState(() => tempSort = sort);
                            }
                          },
                          selectedColor: _AppColors.mint,
                          backgroundColor: Colors.white,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? _AppColors.accentDark
                                : _AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isSelected
                                  ? _AppColors.accent
                                  : _AppColors.border,
                            ),
                          ),
                          showCheckmark: false,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Category',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((cat) {
                        final isSelected = tempCategory == cat;
                        return ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setModalState(() => tempCategory = cat);
                            }
                          },
                          selectedColor: _AppColors.accent,
                          backgroundColor: Colors.white,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : _AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isSelected
                                  ? _AppColors.accent
                                  : _AppColors.border,
                            ),
                          ),
                          showCheckmark: false,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _selectedCategory = 'All';
                                _sortOption = 'Default';
                              });
                              Navigator.pop(context);
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: _AppColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Reset',
                              style: TextStyle(
                                color: _AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedCategory = tempCategory;
                                _sortOption = tempSort;
                              });
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _AppColors.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Apply',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final categories = _availableCategories;
        if (!categories.contains(_selectedCategory)) {
          _selectedCategory = 'All';
        }

        final filteredOrgs = _filtered;
        final totalOrgsCount = AppState.instance.organizations.length;

        final screenWidth = MediaQuery.sizeOf(context).width;
        final textScaler = MediaQuery.textScalerOf(context);

        int crossAxisCount = 2;
        if (screenWidth >= 900) {
          crossAxisCount = 4;
        } else if (screenWidth >= 600) {
          crossAxisCount = 3;
        }

        const totalHorizontalPadding = 32.0;
        final totalSpacing = 12.0 * (crossAxisCount - 1);
        final itemWidth =
            (screenWidth - totalHorizontalPadding - totalSpacing) /
                crossAxisCount;

        final baseTextHeight = textScaler.scale(13) * 2 * 1.15 +
            10 +
            6 +
            22 +
            6 +
            textScaler.scale(10.5) * 1.3 +
            1 +
            7 +
            textScaler.scale(10.3) * 2 * 1.3 +
            22;
        final mainAxisExtent = (itemWidth * 0.6) + baseTextHeight + 24;

        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            backgroundColor: _AppColors.background,
            body: Column(
              children: [
                _OrgHeader(showBackButton: widget.showBackButton),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshOrganizations,
                    color: _AppColors.accent,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      slivers: [
                        SliverToBoxAdapter(
                          child: _SearchBarAndFilter(
                            controller: _searchController,
                            onFilterPressed: _openFilterBottomSheet,
                            isFiltered: _isFilterModified,
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: _CategoryChips(
                            categories: categories,
                            selectedCategory: _selectedCategory,
                            onSelected: (cat) =>
                                setState(() => _selectedCategory = cat),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: _ResultHeader(count: filteredOrgs.length),
                        ),
                        if (_isLoading && totalOrgsCount == 0)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: _LoadingState(),
                          )
                        else if (_hasError && totalOrgsCount == 0)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _ErrorState(onRetry: _loadOrganizations),
                          )
                        else if (totalOrgsCount == 0)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: _EmptyState(
                              hasFilters: false,
                            ),
                          )
                        else if (filteredOrgs.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _EmptyState(
                              hasFilters: true,
                              onClearFilters: () {
                                setState(() {
                                  _searchController.clear();
                                  _selectedCategory = 'All';
                                  _sortOption = 'Default';
                                });
                              },
                            ),
                          )
                        else
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              4,
                              16,
                              MediaQuery.paddingOf(context).bottom + 80,
                            ),
                            sliver: SliverGrid(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) =>
                                    _OrgCard(org: filteredOrgs[index]),
                                childCount: filteredOrgs.length,
                              ),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                mainAxisExtent: mainAxisExtent,
                              ),
                            ),
                          ),
                      ],
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

class _SearchBarAndFilter extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onFilterPressed;
  final bool isFiltered;

  const _SearchBarAndFilter({
    required this.controller,
    required this.onFilterPressed,
    required this.isFiltered,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: _AppColors.surface,
              elevation: 0,
              borderRadius: BorderRadius.circular(18),
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.search,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Search organizations…',
                  hintStyle: const TextStyle(
                    color: _AppColors.textSecondary,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Colors.black,
                  ),
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (_, value, __) => value.text.isEmpty
                        ? const SizedBox.shrink()
                        : IconButton(
                            onPressed: controller.clear,
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.black,
                              size: 19,
                            ),
                          ),
                  ),
                  filled: true,
                  fillColor: _AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Colors.black),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide:
                        const BorderSide(color: Colors.black, width: 1.4),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Tooltip(
            message: 'Filter and Sort',
            child: SizedBox(
              width: 48,
              height: 48,
              child: Material(
                color: _AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: onFilterPressed,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(
                          Icons.tune_rounded,
                          color: Colors.black,
                          size: 22,
                        ),
                        if (isFiltered)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
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
        ],
      ),
    );
  }
}

class _CategoryChips extends StatefulWidget {
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelected;

  const _CategoryChips({
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  @override
  State<_CategoryChips> createState() => _CategoryChipsState();
}

class _CategoryChipsState extends State<_CategoryChips> {
  late final ScrollController _scrollController;
  bool _showChevron = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_checkScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkScroll());
  }

  @override
  void didUpdateWidget(covariant _CategoryChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkScroll());
  }

  void _checkScroll() {
    if (!mounted) return;
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    if (currentScroll >= maxScroll - 5 && _showChevron) {
      setState(() => _showChevron = false);
    } else if (currentScroll < maxScroll - 5 && !_showChevron) {
      setState(() => _showChevron = true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SizedBox(
        height: 40,
        child: Stack(
          children: [
            ListView.separated(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = widget.categories[index];
                final isSelected = widget.selectedCategory.toLowerCase() ==
                    category.toLowerCase();
                return ChoiceChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (_) => widget.onSelected(category),
                  selectedColor: _AppColors.accent,
                  backgroundColor: _AppColors.surface,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : _AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected ? _AppColors.accent : _AppColors.border,
                    ),
                  ),
                  showCheckmark: false,
                );
              },
            ),
            if (_showChevron)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _AppColors.background.withAlpha(0),
                          _AppColors.background,
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.only(left: 16, right: 8),
                    child: IconButton(
                      icon: const Icon(Icons.chevron_right_rounded,
                          color: _AppColors.accentDark),
                      onPressed: () {
                        if (_scrollController.hasClients) {
                          _scrollController.animateTo(
                            _scrollController.offset + 120,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      tooltip: 'More categories',
                    ),
                  ),
                ),
              ),
          ],
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
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
      child: Row(
        children: [
          const Text(
            'Campus organizations',
            style: TextStyle(
              color: _AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _AppColors.mint,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count found',
              style: const TextStyle(
                color: _AppColors.accentDark,
                fontSize: 11,
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
    return Semantics(
      label:
          '${org.name}, category ${org.category}, ${org.shortDesc.isEmpty ? "Campus community" : org.shortDesc}',
      button: true,
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
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrgDetailScreen(orgId: org.id),
                ),
              );
            },
            child: Padding(
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
                  // Reserve exact height for 2 lines using SizedBox
                  SizedBox(
                    height: 13 * 1.15 * 2,
                    child: Text(
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
                  ),
                  if (org.category.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
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
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.people_alt_rounded,
                        size: 13,
                        color: Colors.black,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          () {
                            final count =
                                AppState.instance.memberCountFor(org.id);
                            return count == 1 ? '1 member' : '$count members';
                          }(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 10.5,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
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
                      Tooltip(
                        message: 'View ${org.name}',
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
        memCacheWidth: 300,
        placeholder: (_, __) => const _ImageLoading(),
        errorWidget: (_, __, ___) => const _ImageFallback(),
      );
    }

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
      cacheWidth: 300,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        path,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
        cacheWidth: 300,
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
  final bool hasFilters;
  final VoidCallback? onClearFilters;

  const _EmptyState({
    required this.hasFilters,
    this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded,
                size: 56, color: _AppColors.accent),
            const SizedBox(height: 16),
            Text(
              hasFilters ? 'No organizations found' : 'No organizations yet',
              style: const TextStyle(
                color: _AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasFilters
                  ? 'Try adjusting your search or filters.'
                  : 'Check back later for campus organizations.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: _AppColors.textSecondary, fontSize: 13),
            ),
            if (hasFilters && onClearFilters != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onClearFilters!,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _AppColors.mint,
                  foregroundColor: _AppColors.accentDark,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'Clear filters',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 56, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text(
              'Failed to load organizations',
              style: TextStyle(
                color: _AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: _AppColors.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Try again',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: CircularProgressIndicator(
          color: _AppColors.accent,
          strokeWidth: 3,
        ),
      ),
    );
  }
}

class _OrgHeader extends StatelessWidget {
  final bool showBackButton;
  const _OrgHeader({required this.showBackButton});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        width: double.infinity,
        height: 72 + topInset,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          gradient: HC.heroGradient,
          borderRadius: BorderRadius.only(),
        ),
        child: Stack(
          children: [
            Positioned(right: -45, top: -70, child: _orb(170)),
            Positioned(right: 45, bottom: -70, child: _orb(125)),
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, topInset, 20, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (showBackButton) ...[
                      Material(
                        color: Colors
                            .transparent, // Removes the background highlight box
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.maybePop(context),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons
                                  .chevron_left_rounded, // Less-than / chevron symbol
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    const Expanded(
                      child: Text(
                        'Organizations',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orb(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: .07),
        ),
      );
}
