import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart' hide Notification;

import '../../../core/app_state.dart';
import '../../organizations/org_profile_screen.dart';
import 'home_data.dart';
import 'home_org_logo.dart';
import 'home_recommendations.dart';
import 'home_saved_orgs.dart';
import 'home_tokens.dart';

/// Displays organization recommendations responsively on the Student Home
/// screen, using a horizontal scroller on mobile and a grid on wider screens.
class HomeRecommendedSection extends StatefulWidget {
  final VoidCallback onViewAll;

  const HomeRecommendedSection({
    super.key,
    required this.onViewAll,
  });

  @override
  State<HomeRecommendedSection> createState() => _HomeRecommendedSectionState();
}

/// Manages recommendation counts and saved-organization updates.
class _HomeRecommendedSectionState extends State<HomeRecommendedSection> {
  /// Last fetched member counts, kept for the app session. NewHomeTab's
  /// ListView disposes this State when the section scrolls far off-screen,
  /// so a fresh State would otherwise rank with empty counts first.
  static Map<String, int> _cachedCounts = <String, int>{};

  Map<String, int> _counts = _cachedCounts;
  String? _lastCountOrgKey;

  @override
  void initState() {
    super.initState();

    SavedOrgs.instance.addListener(_onSavedOrgsChanged);
    AppState.instance.addListener(_onAppStateChanged);

    SavedOrgs.instance.load();

    final initialKey = _organizationIdsKey();
    _lastCountOrgKey = initialKey;
    _fetchMemberCounts(initialKey);
  }

  @override
  void dispose() {
    SavedOrgs.instance.removeListener(_onSavedOrgsChanged);
    AppState.instance.removeListener(_onAppStateChanged);
    super.dispose();
  }

  String _organizationIdsKey() {
    final ids = AppState.instance.organizations
        .map((organization) => organization.id)
        .toList()
      ..sort();

    return ids.join('\u001F');
  }

  void _onSavedOrgsChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  void _onAppStateChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  void _scheduleCountRefreshIfNeeded() {
    final currentKey = _organizationIdsKey();

    if (currentKey == _lastCountOrgKey) {
      return;
    }

    // Set the key before the asynchronous request to avoid rebuild loops.
    _lastCountOrgKey = currentKey;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _fetchMemberCounts(currentKey);
    });
  }

  Future<void> _fetchMemberCounts(String requestedKey) async {
    try {
      final counts = await HomeData.fetchOrgMemberCounts();

      if (!mounted || requestedKey != _organizationIdsKey()) {
        return;
      }

      if (counts.isNotEmpty) {
        _cachedCounts = counts;
      }

      setState(() {
        _counts = counts;
      });
    } catch (error) {
      debugPrint('Unable to refresh organization member counts: $error');
    }
  }

  void _openOrganization(
    BuildContext context,
    String orgId, {
    int initialTab = 0,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrgDetailScreen(
          orgId: orgId,
          initialTab: initialTab,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _scheduleCountRefreshIfNeeded();

    final organizations = OrgRecommender.recommend(
      memberCounts: _counts,
    );

    if (organizations.isEmpty) {
      return const SizedBox.shrink();
    }

    final appliedIds = OrgRecommender.appliedOrgIds();

    return LayoutBuilder(
      builder: (context, constraints) {
        final sectionWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        final layout = HomeLayout.of(context);
        final homeHPad = layout.homeHPad;
        final gap = layout.cardGap;

        final innerWidth =
            math.max(0.0, sectionWidth - (2 * homeHPad)).toDouble();

        /// Builds a card while preserving its existing save and navigation
        /// callbacks.
        Widget buildCard(
          Organization organization,
          double cardWidth,
        ) {
          final orgId = organization.id;

          return _RecommendedOrgCard(
            organization: organization,
            cardWidth: cardWidth,
            memberCount: _counts[orgId] ?? 0,
            isSaved: SavedOrgs.instance.isSaved(orgId),
            isApplied: appliedIds.contains(orgId),
            onSave: () {
              SavedOrgs.instance.toggle(orgId);
            },
            onTap: () {
              _openOrganization(context, orgId);
            },
            onAction: () {
              final isApplied = appliedIds.contains(orgId);

              _openOrganization(
                context,
                orgId,
                initialTab: isApplied ? 0 : 2,
              );
            },
          );
        }

        /// Builds the horizontally scrollable card list for mobile widths.
        Widget buildMobileCards() {
          final preferredCardWidth =
              (innerWidth * 0.82).clamp(190.0, 240.0).toDouble();

          final cardWidth = math.min(innerWidth, preferredCardWidth).toDouble();

          return ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: const <PointerDeviceKind>{
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
                PointerDeviceKind.stylus,
              },
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: homeHPad),
              child: IntrinsicHeight(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (var index = 0;
                        index < organizations.length;
                        index++) ...<Widget>[
                      if (index > 0) SizedBox(width: gap),
                      SizedBox(
                        width: cardWidth,
                        child: buildCard(
                          organizations[index],
                          cardWidth,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }

        /// Builds a two-row-maximum grid with equal-width cards, including
        /// empty expanded slots when the final row is incomplete.
        Widget buildWideCards() {
          final columns = HomeLayout.gridColumns(
            innerWidth,
            minItemWidth: 240,
            gap: gap,
            maxColumns: 4,
          );

          final visibleCount =
              math.min(organizations.length, columns * 2).toInt();

          final cardWidth = HomeLayout.gridItemWidth(
            innerWidth,
            columns,
            gap: gap,
          );

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: homeHPad),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var rowStart = 0;
                    rowStart < visibleCount;
                    rowStart += columns) ...<Widget>[
                  if (rowStart > 0) SizedBox(height: gap),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        for (var column = 0;
                            column < columns;
                            column++) ...<Widget>[
                          if (column > 0) SizedBox(width: gap),
                          if (rowStart + column < visibleCount)
                            Expanded(
                              child: buildCard(
                                organizations[rowStart + column],
                                cardWidth,
                              ),
                            )
                          else
                            const Expanded(
                              child: SizedBox.shrink(),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        /// Builds the section heading and its accessible View All action.
        Widget buildSectionHeader() {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: homeHPad),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Recommended For You',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: HC.ink,
                      fontSize: layout.isDesktop ? 19 : 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: widget.onViewAll,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: Colors.black,
                    tapTargetSize: MaterialTapTargetSize.padded,
                  ),
                  child: const Text(
                    'View All →',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final cards = sectionWidth < HomeBreakpoints.tabletMin
            ? buildMobileCards()
            : buildWideCards();

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: 8),
            buildSectionHeader(),
            SizedBox(height: gap),
            cards,
            SizedBox(height: layout.sectionGap),
          ],
        );
      },
    );
  }
}

/// A recommendation card with save, organization navigation, and join actions.
///
/// Its width controls the logo and organization-name sizes. Its height is
/// content-driven, allowing cards in the same row to share a common height.
class _RecommendedOrgCard extends StatelessWidget {
  final Organization organization;
  final double cardWidth;
  final int memberCount;
  final bool isSaved;
  final bool isApplied;
  final VoidCallback onSave;
  final VoidCallback onTap;
  final VoidCallback onAction;

  const _RecommendedOrgCard({
    required this.organization,
    required this.cardWidth,
    required this.memberCount,
    required this.isSaved,
    required this.isApplied,
    required this.onSave,
    required this.onTap,
    required this.onAction,
  });

  /// Whether this card is wide enough for the larger logo and name.
  bool get _isLargeCard => cardWidth >= 280;

  /// Returns the existing category, member-count, or description subtitle.
  String _subtitle() {
    final category = organization.category.trim();
    final description = organization.shortDesc.trim();

    if (category.isNotEmpty && memberCount > 0) {
      return '$category • $memberCount members';
    }

    if (category.isNotEmpty) {
      return category;
    }

    if (memberCount > 0) {
      return '$memberCount members';
    }

    if (description.isNotEmpty) {
      return description;
    }

    return 'Discover this organization';
  }

  /// Returns up to two distinct category and acronym tags.
  List<String> _tags() {
    final tags = <String>[];

    final category = organization.category.trim();
    final acronym = organization.acronym.trim();

    if (category.isNotEmpty) {
      tags.add(category);
    }

    if (acronym.isNotEmpty && acronym.toLowerCase() != category.toLowerCase()) {
      tags.add(acronym);
    }

    return tags.take(2).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tags = _tags();
    final isLargeCard = _isLargeCard;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: HC.line),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: HC.primary.withValues(alpha: 0.07),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    OrgLogoAvatar(
                      logoAsset: organization.logoAsset,
                      size: isLargeCard ? 56 : 52,
                      radius: 16,
                    ),
                    const Spacer(),
                    Semantics(
                      button: true,
                      label: 'Save ${organization.name}',
                      child: IconButton(
                        onPressed: onSave,
                        tooltip: isSaved
                            ? 'Remove ${organization.name} from saved'
                            : 'Save ${organization.name}',
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          isSaved
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: isSaved ? HC.danger : HC.muted,
                          size: 23,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  organization.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: HC.ink,
                    fontSize: isLargeCard ? 16 : 15,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _subtitle(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: HC.muted,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
                if (tags.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      for (final tag in tags) _HomeTagPill(label: tag),
                    ],
                  ),
                ],

                // The Spacer absorbs extra row height so action buttons align.
                // The fixed gap ensures at least 14 logical pixels above them.
                const Spacer(),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: FilledButton(
                    onPressed: onAction,
                    style: FilledButton.styleFrom(
                      backgroundColor: isApplied ? HC.mint : HC.primary,
                      foregroundColor: isApplied ? HC.dark : Colors.white,
                      elevation: 0,
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isApplied ? 'Applied' : 'Apply',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
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

/// Small mint category or acronym tag used inside recommendation cards.
class _HomeTagPill extends StatelessWidget {
  final String label;

  const _HomeTagPill({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 175),
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: HC.mint,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: HC.dark,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
