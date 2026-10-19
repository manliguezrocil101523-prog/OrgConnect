import 'dart:async';

import 'package:flutter/material.dart' hide Notification;

import '../../../core/app_state.dart';
import '../../organizations/org_profile_screen.dart';
import 'event_details_sheet.dart';
import 'home_data.dart';
import 'home_event_utils.dart';
import 'home_org_logo.dart';
import 'home_tokens.dart';

/// Provides full-screen search for organizations and upcoming campus events.
class HomeSearchPage extends StatefulWidget {
  final bool openFiltersOnStart;

  const HomeSearchPage({
    super.key,
    this.openFiltersOnStart = false,
  });

  @override
  State<HomeSearchPage> createState() => _HomeSearchPageState();
}

/// Manages debounced searching, scope selection, and category filtering.
class _HomeSearchPageState extends State<HomeSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  Timer? _debounce;

  String _query = '';
  String? _selectedCategory;
  _SearchScope _scope = _SearchScope.all;

  bool _initialFilterOpened = false;

  @override
  void initState() {
    super.initState();

    if (widget.openFiltersOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _initialFilterOpened) {
          return;
        }

        _initialFilterOpened = true;
        _openCategoryFilter();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();

    // Rebuild immediately so the clear button follows the text field.
    setState(() {});

    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) {
        return;
      }

      setState(() {
        _query = value.trim().toLowerCase();
      });
    });
  }

  void _submitQuery(String value) {
    _debounce?.cancel();

    setState(() {
      _query = value.trim().toLowerCase();
    });

    _searchFocusNode.unfocus();
  }

  void _clearQuery() {
    _debounce?.cancel();
    _searchController.clear();

    setState(() {
      _query = '';
    });
  }

  List<String> _categories() {
    final distinctCategories = <String, String>{};

    for (final organization in AppState.instance.organizations) {
      final category = organization.category.trim();

      if (category.isEmpty) {
        continue;
      }

      distinctCategories.putIfAbsent(
        category.toLowerCase(),
        () => category,
      );
    }

    final result = distinctCategories.values.toList();

    result.sort(
      (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
    );

    return result;
  }

  String? _categoryForEvent(
    Event event,
    Map<String, Organization> organizationsById,
  ) {
    final orgId = event.orgId;

    if (orgId == null || orgId.isEmpty) {
      return null;
    }

    return organizationsById[orgId]?.category.trim();
  }

  bool _matchesQuery(String haystack) {
    final terms =
        _query.split(RegExp(r'\s+')).where((term) => term.isNotEmpty).toList();

    if (terms.isEmpty) {
      return true;
    }

    final normalizedHaystack = haystack.toLowerCase();

    return terms.every(normalizedHaystack.contains);
  }

  bool _matchesCategory(String? category) {
    final selectedCategory = _selectedCategory;

    if (selectedCategory == null) {
      return true;
    }

    return category != null &&
        category.trim().toLowerCase() == selectedCategory.trim().toLowerCase();
  }

  List<Organization> _matchingOrganizations(
    List<Organization> organizations,
  ) {
    final results = organizations.where((organization) {
      if (!_matchesCategory(organization.category)) {
        return false;
      }

      final haystack = [
        organization.name,
        organization.acronym,
        organization.category,
        organization.shortDesc,
        organization.about,
      ].join(' ');

      return _matchesQuery(haystack);
    }).toList();

    results.sort((a, b) {
      final nameA = a.name.toLowerCase();
      final nameB = b.name.toLowerCase();

      int rank(String name) {
        if (_query.isEmpty || name.startsWith(_query)) {
          return 0;
        }

        if (name.contains(_query)) {
          return 1;
        }

        return 2;
      }

      final rankComparison = rank(nameA).compareTo(rank(nameB));

      if (rankComparison != 0) {
        return rankComparison;
      }

      final nameComparison = nameA.compareTo(nameB);

      if (nameComparison != 0) {
        return nameComparison;
      }

      return a.id.compareTo(b.id);
    });

    return results;
  }

  List<Event> _matchingEvents(
    List<Event> events,
    Map<String, Organization> organizationsById,
  ) {
    return events.where((event) {
      final category = _categoryForEvent(
        event,
        organizationsById,
      );

      if (!_matchesCategory(category)) {
        return false;
      }

      final haystack = [
        event.title,
        event.orgName,
        event.description,
        event.venue,
        category ?? '',
      ].join(' ');

      return _matchesQuery(haystack);
    }).toList();
  }

  Future<void> _openCategoryFilter() async {
    final categories = _categories();

    final result = await showModalBottomSheet<_CategoryFilterResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        String? draftCategory = _selectedCategory;

        return HomeLayout.capText(
          sheetContext,
          StatefulBuilder(
            builder: (context, setModalState) {
              final bottomInset = MediaQuery.of(context).viewInsets.bottom;

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  HomeLayout.of(context).hPad,
                  22,
                  HomeLayout.of(context).hPad,
                  20 + bottomInset,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Filter by category',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: HC.ink,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close filters',
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                            },
                            icon: const Icon(
                              Icons.close_rounded,
                              color: HC.muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildCategoryChoiceChip(
                            label: 'All categories',
                            selected: draftCategory == null,
                            onSelected: () {
                              setModalState(() {
                                draftCategory = null;
                              });
                            },
                          ),
                          for (final category in categories)
                            _buildCategoryChoiceChip(
                              label: category,
                              selected: draftCategory?.toLowerCase() ==
                                  category.toLowerCase(),
                              onSelected: () {
                                setModalState(() {
                                  draftCategory = category;
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                draftCategory = null;
                              });
                            },
                            style: TextButton.styleFrom(
                              minimumSize: const Size(70, 44),
                              foregroundColor: HC.primary,
                            ),
                            child: const Text('Reset'),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: () {
                              Navigator.of(sheetContext).pop(
                                _CategoryFilterResult(
                                  applied: true,
                                  category: draftCategory,
                                ),
                              );
                            },
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(100, 44),
                              backgroundColor: HC.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Apply',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
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
          ),
        );
      },
    );

    if (!mounted || result == null || !result.applied) {
      return;
    }

    setState(() {
      _selectedCategory = result.category;
    });
  }

  Widget _buildCategoryChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return SizedBox(
      height: 40,
      child: ChoiceChip(
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        selected: selected,
        onSelected: (_) => onSelected(),
        materialTapTargetSize: MaterialTapTargetSize.padded,
        visualDensity: VisualDensity.standard,
        labelPadding: const EdgeInsets.symmetric(horizontal: 7),
        backgroundColor: Colors.white,
        selectedColor: HC.mint,
        side: BorderSide(
          color: selected ? HC.primary : HC.line,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        labelStyle: TextStyle(
          color: selected ? HC.dark : HC.ink,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final layout = HomeLayout.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        layout.hPad,
        8,
        layout.hPad,
        8,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              tooltip: 'Back',
              onPressed: () {
                Navigator.maybePop(context);
              },
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: HC.ink,
                size: 21,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: HC.line),
                boxShadow: [
                  BoxShadow(
                    color: HC.primary.withValues(alpha: 0.035),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: !widget.openFiltersOnStart,
                textInputAction: TextInputAction.search,
                onChanged: _onQueryChanged,
                onSubmitted: _submitQuery,
                style: const TextStyle(
                  color: HC.ink,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Search organizations, events, or keywords…',
                  hintStyle: const TextStyle(
                    color: HC.muted,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: HC.muted,
                    size: 22,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          tooltip: 'Clear search',
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          onPressed: _clearQuery,
                          icon: const Icon(
                            Icons.close_rounded,
                            color: HC.muted,
                            size: 20,
                          ),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(
                      color: HC.primary,
                      width: 1.2,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              tooltip: 'Filter by category',
              padding: EdgeInsets.zero,
              onPressed: _openCategoryFilter,
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Center(
                    child: Icon(
                      Icons.tune_rounded,
                      color: HC.ink,
                      size: 23,
                    ),
                  ),
                  if (_selectedCategory != null)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: HC.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return SizedBox(
      height: 38,
      child: ChoiceChip(
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        selected: selected,
        onSelected: (_) => onSelected(),
        materialTapTargetSize: MaterialTapTargetSize.padded,
        labelPadding: const EdgeInsets.symmetric(horizontal: 7),
        backgroundColor: Colors.white,
        selectedColor: HC.mint,
        side: BorderSide(
          color: selected ? HC.primary : HC.line,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        labelStyle: TextStyle(
          color: selected ? HC.dark : HC.ink,
          fontSize: 13,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildScopeRow(BuildContext context) {
    final layout = HomeLayout.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        layout.hPad,
        0,
        layout.hPad,
        8,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildScopeChip(
              label: 'All',
              selected: _scope == _SearchScope.all,
              onSelected: () {
                setState(() {
                  _scope = _SearchScope.all;
                });
              },
            ),
            const SizedBox(width: 8),
            _buildScopeChip(
              label: 'Organizations',
              selected: _scope == _SearchScope.organizations,
              onSelected: () {
                setState(() {
                  _scope = _SearchScope.organizations;
                });
              },
            ),
            const SizedBox(width: 8),
            _buildScopeChip(
              label: 'Events',
              selected: _scope == _SearchScope.events,
              onSelected: () {
                setState(() {
                  _scope = _SearchScope.events;
                });
              },
            ),
            if (_selectedCategory != null) ...[
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(maxWidth: 220),
                height: 38,
                padding: const EdgeInsets.only(left: 11, right: 3),
                decoration: BoxDecoration(
                  color: HC.mint,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: HC.primary),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _selectedCategory!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: HC.dark,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove category filter',
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        setState(() {
                          _selectedCategory = null;
                        });
                      },
                      icon: const Icon(
                        Icons.close_rounded,
                        color: HC.dark,
                        size: 17,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIdleContent(
    BuildContext context,
    List<String> categories,
  ) {
    final layout = HomeLayout.of(context);

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        layout.hPad,
        16,
        layout.hPad,
        24,
      ),
      children: [
        if (categories.isNotEmpty) ...[
          const Text(
            'Browse by category',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: HC.ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in categories)
                _buildCategoryChoiceChip(
                  label: category,
                  selected: false,
                  onSelected: () {
                    setState(() {
                      _selectedCategory = category;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        const Text(
          'Search by organization name, event title, venue or keyword.',
          style: TextStyle(
            color: HC.muted,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildNoResults(BuildContext context) {
    final layout = HomeLayout.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: layout.hPad + 8,
          vertical: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: HC.mint,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                color: HC.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No results found',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: HC.ink,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try a different keyword or clear the filters.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: HC.muted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            if (_selectedCategory != null) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedCategory = null;
                  });
                },
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  foregroundColor: HC.primary,
                ),
                child: const Text(
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

  Widget _buildResults(
    BuildContext context,
    List<Organization> organizations,
    List<Event> events,
  ) {
    final layout = HomeLayout.of(context);
    final rows = <_SearchRow>[];

    if (_scope != _SearchScope.events) {
      rows.add(
        _SearchRow(
          type: _SearchRowType.organizationHeader,
          title: 'Organizations (${organizations.length})',
        ),
      );

      for (final organization in organizations) {
        rows.add(
          _SearchRow(
            type: _SearchRowType.organization,
            organization: organization,
          ),
        );
      }
    }

    if (_scope != _SearchScope.organizations) {
      rows.add(
        _SearchRow(
          type: _SearchRowType.eventHeader,
          title: 'Events (${events.length})',
        ),
      );

      for (final event in events) {
        rows.add(
          _SearchRow(
            type: _SearchRowType.event,
            event: event,
          ),
        );
      }
    }

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];

        switch (row.type) {
          case _SearchRowType.organizationHeader:
          case _SearchRowType.eventHeader:
            return _ResultsSectionHeader(
              title: row.title ?? '',
              horizontalPadding: layout.hPad,
            );

          case _SearchRowType.organization:
            final organization = row.organization!;

            return _OrganizationResultTile(
              organization: organization,
              horizontalPadding: layout.hPad,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => OrgDetailScreen(
                      orgId: organization.id,
                    ),
                  ),
                );
              },
            );

          case _SearchRowType.event:
            final event = row.event!;

            return _EventResultTile(
              event: event,
              horizontalPadding: layout.hPad,
              onTap: () {
                showEventDetailsSheet(
                  context,
                  event: event,
                );
              },
            );
        }
      },
    );
  }

  Widget _buildResultsBody(BuildContext context) {
    final appState = AppState.instance;
    final categories = _categories();

    if (_query.isEmpty && _selectedCategory == null) {
      return _buildIdleContent(context, categories);
    }

    final organizationsById = <String, Organization>{
      for (final organization in appState.organizations)
        organization.id: organization,
    };

    final allEvents = HomeData.upcomingEvents(maxAgeDays: 365);

    final matchingOrganizations =
        _matchingOrganizations(appState.organizations);

    final matchingEvents = _matchingEvents(
      allEvents,
      organizationsById,
    );

    final visibleOrganizations = _scope == _SearchScope.events
        ? <Organization>[]
        : matchingOrganizations;

    final visibleEvents =
        _scope == _SearchScope.organizations ? <Event>[] : matchingEvents;

    if (visibleOrganizations.isEmpty && visibleEvents.isEmpty) {
      return _buildNoResults(context);
    }

    return _buildResults(
      context,
      visibleOrganizations,
      visibleEvents,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HC.bg,
      body: SafeArea(
        child: HomeLayout.capText(
          context,
          Column(
            children: [
              _buildTopBar(context),
              _buildScopeRow(context),
              Expanded(
                child: AnimatedBuilder(
                  animation: AppState.instance,
                  builder: (context, _) {
                    return _buildResultsBody(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carries the result of an applied category-filter selection.
class _CategoryFilterResult {
  final bool applied;
  final String? category;

  const _CategoryFilterResult({
    required this.applied,
    required this.category,
  });
}

/// Determines which set of search results is currently visible.
enum _SearchScope {
  all,
  organizations,
  events,
}

/// Identifies each row type in the flat search-results list.
enum _SearchRowType {
  organizationHeader,
  organization,
  eventHeader,
  event,
}

/// Describes a section heading, organization tile, or event tile.
class _SearchRow {
  final _SearchRowType type;
  final String? title;
  final Organization? organization;
  final Event? event;

  const _SearchRow({
    required this.type,
    this.title,
    this.organization,
    this.event,
  });
}

/// Displays a section heading above the associated search-result tiles.
class _ResultsSectionHeader extends StatelessWidget {
  final String title;
  final double horizontalPadding;

  const _ResultsSectionHeader({
    required this.title,
    required this.horizontalPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        14,
        horizontalPadding,
        8,
      ),
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: HC.ink,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Displays an organization search result with its logo and description.
class _OrganizationResultTile extends StatelessWidget {
  final Organization organization;
  final double horizontalPadding;
  final VoidCallback onTap;

  const _OrganizationResultTile({
    required this.organization,
    required this.horizontalPadding,
    required this.onTap,
  });

  String _subtitle() {
    final category = organization.category.trim();

    if (category.isNotEmpty) {
      return category;
    }

    final shortDescription = organization.shortDesc.trim();

    if (shortDescription.isNotEmpty) {
      return shortDescription;
    }

    return 'Organization';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HC.line),
        boxShadow: [
          BoxShadow(
            color: HC.primary.withValues(alpha: 0.055),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                OrgLogoAvatar(
                  logoAsset: organization.logoAsset,
                  size: 48,
                  radius: 14,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        organization.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: HC.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _subtitle(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: HC.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: HC.muted,
                  size: 23,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Displays a searchable event with its cover, organization, and date.
class _EventResultTile extends StatelessWidget {
  final Event event;
  final double horizontalPadding;
  final VoidCallback onTap;

  const _EventResultTile({
    required this.event,
    required this.horizontalPadding,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cover = eventCoverImage(event);
    final timeLabel = event.timeLabel.trim();

    final dateLabel = timeLabel.isEmpty
        ? formatDateShort(event.date)
        : '${formatDateShort(event.date)} • $timeLabel';

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HC.line),
        boxShadow: [
          BoxShadow(
            color: HC.primary.withValues(alpha: 0.055),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: cover == null || cover.isEmpty
                        ? eventGradientFallback(iconSize: 22)
                        : EventImage(
                            url: cover,
                            fit: BoxFit.cover,
                            fallback: eventGradientFallback(iconSize: 22),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: HC.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        event.orgName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: HC.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: HC.muted,
                          fontSize: 11,
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
