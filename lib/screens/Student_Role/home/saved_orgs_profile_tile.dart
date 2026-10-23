import 'package:flutter/material.dart' hide Notification;

import 'home_saved_orgs.dart';
import 'home_tokens.dart';
import 'saved_orgs_screen.dart';

/// Button for the Profile page. Shows the saved count and opens
/// [SavedOrgsScreen]. Usage in profile_screen.dart:
///   const SavedOrgsProfileTile(),
class SavedOrgsProfileTile extends StatefulWidget {
  const SavedOrgsProfileTile({super.key});

  @override
  State<SavedOrgsProfileTile> createState() => _SavedOrgsProfileTileState();
}

class _SavedOrgsProfileTileState extends State<SavedOrgsProfileTile> {
  @override
  void initState() {
    super.initState();
    SavedOrgs.instance.load(); // so the count is right even if Home never ran
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SavedOrgs.instance,
      builder: (context, _) {
        final count = SavedOrgs.instance.ids.length;

        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SavedOrgsScreen(),
                ),
              );
            },
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: HC.line),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: HC.mint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: HC.danger,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Saved Organizations',
                          style: TextStyle(
                            color: HC.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          count == 0 ? 'Nothing saved yet' : '$count saved',
                          style: const TextStyle(
                            color: HC.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: HC.muted),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
