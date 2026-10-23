import 'package:flutter/material.dart' hide Notification;

import '../../../core/app_state.dart';
import '../../organizations/org_profile_screen.dart';
import 'home_data.dart';
import 'home_org_logo.dart';
import 'home_recommendations.dart';
import 'home_saved_orgs.dart';
import 'home_tokens.dart';

/// Displays horizontally scrolling organization recommendations on the
/// student Home screen.
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
  Map<String, int> _counts = <String, int>{};
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

    final layout = HomeLayout.of(context);
    final cardWidth = layout.cardWidth(min: 190, max: 240);
    final appliedIds = OrgRecommender.appliedOrgIds();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: layout.hPad),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Recommended For You',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: HC.ink,
                    fontSize: 17,
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
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: layout.hPad),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < organizations.length; index++) ...[
                  if (index > 0) const SizedBox(width: 12),
                  SizedBox(
                    width: cardWidth,
                    child: _RecommendedOrgCard(
                      organization: organizations[index],
                      memberCount: _counts[organizations[index].id] ?? 0,
                      isSaved: SavedOrgs.instance.isSaved(
                        organizations[index].id,
                      ),
                      isApplied: appliedIds.contains(
                        organizations[index].id,
                      ),
                      onSave: () {
                        SavedOrgs.instance.toggle(organizations[index].id);
                      },
                      onTap: () {
                        _openOrganization(
                          context,
                          organizations[index].id,
                        );
                      },
                      onAction: () {
                        final isApplied =
                            appliedIds.contains(organizations[index].id);

                        _openOrganization(
                          context,
                          organizations[index].id,
                          initialTab: isApplied ? 0 : 2,
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

/// A recommendation card with save, organization navigation, and join actions.
class _RecommendedOrgCard extends StatelessWidget {
  final Organization organization;
  final int memberCount;
  final bool isSaved;
  final bool isApplied;
  final VoidCallback onSave;
  final VoidCallback onTap;
  final VoidCallback onAction;

  const _RecommendedOrgCard({
    required this.organization,
    required this.memberCount,
    required this.isSaved,
    required this.isApplied,
    required this.onSave,
    required this.onTap,
    required this.onAction,
  });

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
            boxShadow: [
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
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OrgLogoAvatar(
                      logoAsset: organization.logoAsset,
                      size: 52,
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
                  style: const TextStyle(
                    color: HC.ink,
                    fontSize: 15,
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
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in tags) _HomeTagPill(label: tag),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  height: 44,
                  child: FilledButton(
                    onPressed: onAction,
                    style: FilledButton.styleFrom(
                      backgroundColor: isApplied ? HC.mint : HC.primary,
                      foregroundColor: isApplied ? HC.dark : Colors.white,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(44),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isApplied ? 'Applied' : 'Join',
                      maxLines: 1,
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
