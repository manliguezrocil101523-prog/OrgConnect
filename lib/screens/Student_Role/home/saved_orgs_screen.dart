import 'package:flutter/material.dart' hide Notification;

import '../../../core/app_state.dart';
import '../../organizations/org_profile_screen.dart';
import 'home_org_logo.dart';
import 'home_saved_orgs.dart';
import 'home_tokens.dart';

/// Lists every organization the student saved with the heart button.
class SavedOrgsScreen extends StatefulWidget {
  const SavedOrgsScreen({super.key});

  @override
  State<SavedOrgsScreen> createState() => _SavedOrgsScreenState();
}

class _SavedOrgsScreenState extends State<SavedOrgsScreen> {
  @override
  void initState() {
    super.initState();
    SavedOrgs.instance.addListener(_refresh);
    AppState.instance.addListener(_refresh);
    SavedOrgs.instance.load();
  }

  @override
  void dispose() {
    SavedOrgs.instance.removeListener(_refresh);
    AppState.instance.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {});
  }

  List<Organization> _savedOrganizations() {
    final byId = <String, Organization>{
      for (final organization in AppState.instance.organizations)
        organization.id: organization,
    };

    // Ids of deleted organizations are silently skipped.
    final list = SavedOrgs.instance.ids
        .map((id) => byId[id])
        .whereType<Organization>()
        .toList()
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

    return list;
  }

  void _open(Organization organization) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrgDetailScreen(
          orgId: organization.id,
          initialTab: 0,
        ),
      ),
    );
  }

  Future<void> _unsave(Organization organization) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await SavedOrgs.instance.toggle(organization.id);

    if (!mounted) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Removed ${organization.name} from saved'
                : 'Could not update. Check your connection and try again.',
          ),
          action: ok
              ? SnackBarAction(
                  label: 'Undo',
                  onPressed: () {
                    SavedOrgs.instance.toggle(organization.id);
                  },
                )
              : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final saved = SavedOrgs.instance;
    final organizations = _savedOrganizations();

    return Scaffold(
      backgroundColor: HC.mint.withValues(alpha: 0.35),
      appBar: AppBar(
        title: const Text(
          'Saved Organizations',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: HC.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: !saved.isLoaded
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => SavedOrgs.instance.load(force: true),
              child: organizations.isEmpty
                  ? _EmptyState(onBrowse: () => Navigator.of(context).pop())
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: organizations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final organization = organizations[index];
                        return _SavedOrgTile(
                          organization: organization,
                          onTap: () => _open(organization),
                          onUnsave: () => _unsave(organization),
                        );
                      },
                    ),
            ),
    );
  }
}

class _SavedOrgTile extends StatelessWidget {
  final Organization organization;
  final VoidCallback onTap;
  final VoidCallback onUnsave;

  const _SavedOrgTile({
    required this.organization,
    required this.onTap,
    required this.onUnsave,
  });

  String _subtitle() {
    final category = organization.category.trim();
    final description = organization.shortDesc.trim();
    if (category.isNotEmpty) return category;
    if (description.isNotEmpty) return description;
    return 'Student organization';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(14),
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
          child: Row(
            children: [
              OrgLogoAvatar(
                logoAsset: organization.logoAsset,
                size: 52,
                radius: 16,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    const SizedBox(height: 4),
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
                  ],
                ),
              ),
              IconButton(
                onPressed: onUnsave,
                tooltip: 'Remove ${organization.name} from saved',
                constraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: 44,
                ),
                icon: const Icon(
                  Icons.favorite_rounded,
                  color: HC.danger,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onBrowse;

  const _EmptyState({required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    // ListView so pull-to-refresh still works on the empty state.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 96, 32, 32),
      children: [
        Icon(
          Icons.favorite_border_rounded,
          size: 64,
          color: HC.primary.withValues(alpha: 0.6),
        ),
        const SizedBox(height: 16),
        const Text(
          'No saved organizations yet',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: HC.ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tap the heart on an organization to keep it here for later.',
          textAlign: TextAlign.center,
          style: TextStyle(color: HC.muted, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 24),
        Center(
          child: FilledButton(
            onPressed: onBrowse,
            style: FilledButton.styleFrom(
              backgroundColor: HC.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(180, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Browse organizations',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}
