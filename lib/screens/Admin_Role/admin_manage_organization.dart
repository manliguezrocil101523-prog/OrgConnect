import 'package:flutter/material.dart';
import '../../core/app_state.dart';

class AdminOrganizationsScreen extends StatefulWidget {
  const AdminOrganizationsScreen({super.key});

  @override
  State<AdminOrganizationsScreen> createState() =>
      _AdminOrganizationsScreenState();
}

class _AdminOrganizationsScreenState extends State<AdminOrganizationsScreen> {
  @override
  void initState() {
    super.initState();
    _precacheOrgImages();
  }

  Future<void> _precacheOrgImages() async {
    final orgs = AppState.instance.organizations;
    for (final o in orgs) {
      if (!mounted) return;
      if (o.logoAsset.startsWith('http')) {
        await precacheImage(NetworkImage(o.logoAsset), context);
      } else if (o.logoAsset.isNotEmpty) {
        await precacheImage(AssetImage(o.logoAsset), context);
      }
    }
  }

  static const Color accent = Color(0xFF6366F1);
  static const Color danger = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    final isDark = AppState.instance.isDark;
    final background =
        isDark ? const Color(0xFF0F1117) : const Color(0xFFF5F7FA);
    final cardColor = isDark ? const Color(0xFF181C27) : Colors.white;
    final primary = isDark ? const Color(0xFF181C27) : const Color(0xFF1E293B);
    final textMain = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B);
    final textSub = isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600;
    final textSub2 = isDark ? const Color(0xFF64748B) : Colors.grey.shade700;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primary,
        title: const Text(
          'Manage Organizations',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context),
        backgroundColor: accent,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: AnimatedBuilder(
        animation: AppState.instance,
        builder: (context, _) {
          final isLoading = AppState.instance.isLoadingOrganizations;
          final orgs = AppState.instance.organizations;

          if (isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (orgs.isEmpty) {
            return const Center(child: Text('No organizations'));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: orgs.length,
            itemBuilder: (context, index) {
              final o = orgs[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: o.logoAsset.startsWith('http')
                          ? Image.network(
                              o.logoAsset,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              // ✅ Smooth fade-in while loading from network
                              frameBuilder: (context, child, frame,
                                  wasSynchronouslyLoaded) {
                                if (wasSynchronouslyLoaded || frame != null) {
                                  return child; // already cached — show instantly
                                }
                                return AnimatedOpacity(
                                  opacity: frame == null ? 0.0 : 1.0,
                                  duration: const Duration(milliseconds: 350),
                                  curve: Curves.easeIn,
                                  child: child,
                                );
                              },
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  width: 56,
                                  height: 56,
                                  color: accent.withOpacity(0.15),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: accent,
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (_, __, ___) => Container(
                                width: 56,
                                height: 56,
                                color: accent.withOpacity(0.15),
                                child:
                                    Icon(Icons.groups_outlined, color: accent),
                              ),
                            )
                          : o.logoAsset.isNotEmpty
                              ? Image.asset(
                                  o.logoAsset,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  // ✅ Smooth fade-in for asset images too
                                  frameBuilder: (context, child, frame,
                                      wasSynchronouslyLoaded) {
                                    if (wasSynchronouslyLoaded || frame != null)
                                      return child;
                                    return AnimatedOpacity(
                                      opacity: frame == null ? 0.0 : 1.0,
                                      duration:
                                          const Duration(milliseconds: 350),
                                      curve: Curves.easeIn,
                                      child: child,
                                    );
                                  },
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 56,
                                    height: 56,
                                    color: accent.withOpacity(0.15),
                                    child: Icon(Icons.groups_outlined,
                                        color: accent),
                                  ),
                                )
                              : Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: accent.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.groups_outlined,
                                      color: accent),
                                ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            o.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: textMain,
                            ),
                          ),
                          if (o.category.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              o.category,
                              style: TextStyle(
                                color: textSub,
                                fontSize: 13,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            o.shortDesc,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textSub2,
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: danger),
                      onPressed: () => _confirmDelete(context, o),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add organization'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Short description',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final desc = descCtrl.text.trim();
              if (name.isEmpty || desc.isEmpty) return;
              try {
                await AppState.instance.addOrganization(
                  name: name,
                  logoAsset: '',
                  shortDesc: desc,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Organization added successfully'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Failed to add organization'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Organization o) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove organization?'),
        content: Text(
          'This will remove "${o.name}" from the list. This cannot be undone in the demo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: danger),
            onPressed: () async {
              try {
                await AppState.instance.removeOrganization(o.id);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Removed ${o.name}'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Failed to remove organization'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
