import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdviserAccountsScreen extends StatefulWidget {
  final String orgId, orgName;
  const AdviserAccountsScreen({super.key, required this.orgId, required this.orgName});

  @override
  State<AdviserAccountsScreen> createState() => _AdviserAccountsScreenState();
}

class _AdviserAccountsScreenState extends State<AdviserAccountsScreen> {
  static const green = Color(0xFF128058);
  static const dark = Color(0xFF12352A);
  static const muted = Color(0xFF4D6F62);
  static const bg = Color(0xFFE6F7EE);
  static const card = Color(0xFFF5FFF9);

  final db = Supabase.instance.client;
  bool loading = true;
  List<Map<String, dynamic>> members = [];
  final ScrollController _accountsScrollController = ScrollController();

  // Only these three officers have access to the Officer dashboard.
  // Adviser assignment creates/updates the member's own login account; there
  // is no shared officer account.
  static const officerPositions = <String>[
    'President',
    'Vice President',
    'Secretary',
  ];

  @override
  void dispose() {
    _accountsScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) setState(() => loading = true);
    try {
      // Supabase `members` is the single source of truth. Officers must have
      // an actual membership row for this organization, so we never fabricate
      // member records from `profiles.role` or `assigned_org_id`.
      final response = await db
          .from('members')
          .select('id,name,position,profile_id,profiles(id,name,email,role,active,avatar_url,student_id)')
          .eq('org_id', widget.orgId)
          .order('name');
      final rows = List<Map<String, dynamic>>.from(response as List);
      if (!mounted) return;
      setState(() => members = rows);
    } catch (e) {
      if (mounted) _snack('Could not load accounts: $e', true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> changeRole(Map<String, dynamic> member) async {
    final profile = member['profiles'];
    if (profile is! Map || profile['id'] == null) {
      _snack('This member is not linked to a login account.', true);
      return;
    }

    final name = profile['name']?.toString().trim().isNotEmpty == true
        ? profile['name'].toString()
        : member['name']?.toString() ?? 'Member';
    final current = member['position']?.toString() ?? 'Member';
    String position = officerPositions.contains(current) ? current : 'Member';

    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(children: [
            const Icon(Icons.workspace_premium_rounded, color: green),
            const SizedBox(width: 10),
            Expanded(child: Text('Assign position to $name', maxLines: 2, overflow: TextOverflow.ellipsis)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'The adviser assigns the member position. President, Vice President, and Secretary can use their own accounts to open the Officer area.',
                style: TextStyle(color: muted, height: 1.4, fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              const Text('Organization position', style: TextStyle(fontWeight: FontWeight.w800, color: dark)),
              const SizedBox(height: 7),
              DropdownButtonFormField<String>(
                initialValue: position,
                isExpanded: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.badge_rounded, color: green),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                items: [
                  const DropdownMenuItem(value: 'Member', child: Text('Member')),
                  ...officerPositions.map((v) => DropdownMenuItem(value: v, child: Text(v))),
                ],
                onChanged: (v) => setDialogState(() => position = v ?? 'Member'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: green, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, position),
              child: const Text('Save Position'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    final makeOfficer = officerPositions.contains(result);

    try {
      // The member keeps their own Supabase account. Assigning an officer
      // position changes access on that account; no shared officer account is created.
      await db.from('profiles').update({
        'role': makeOfficer ? 'officer' : 'student',
        'assigned_org_id': makeOfficer ? widget.orgId : null,
      }).eq('id', profile['id'].toString());

      await db.from('members').update({
        'position': result,
      }).eq('id', member['id'].toString()).eq('org_id', widget.orgId);

      if (!mounted) return;
      _snack(makeOfficer ? '$name is now $result and can access the Officer area.' : '$name is now a regular member.');
      await load();
    } catch (e) {
      if (!mounted) return;
      _snack('Could not change position: $e', true);
    }
  }

  void _snack(String message, [bool error = false]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: loading
          ? const Center(child: CircularProgressIndicator(color: green))
          : SafeArea(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF1FCF6), Color(0xFFE1F6EB), Color(0xFFD1EFDF)],
                  ),
                ),
                child: Column(
                  children: [
                    // The green header stays fixed; scrolling starts with the
                    // Students / Officers / Members section below it.
                    _accountHeader(),
                    Expanded(
                      child: RefreshIndicator(
                        color: green,
                        backgroundColor: card,
                        onRefresh: load,
                        child: Scrollbar(
                          controller: _accountsScrollController,
                          thumbVisibility: true,
                          trackVisibility: true,
                          radius: const Radius.circular(10),
                          thickness: 7,
                          child: ListView(
                            controller: _accountsScrollController,
                            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 34),
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Organization Members',
                                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: dark),
                                    ),
                                  ),
                                  Text(
                                    '${members.length} total',
                                    style: const TextStyle(color: muted, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (members.isEmpty)
                                _empty()
                              else
                                ...members.asMap().entries.map((e) => _memberCard(e.value, e.key)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _accountHeader() => SizedBox(
        width: double.infinity,
        height: 126,
        child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF064E3B), Color(0xFF128058), Color(0xFF22C55E)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.zero,
        ),
        child: Stack(
          children: [
            Positioned(
              top: 4,
              left: 0,
              child: IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(56, 25, 52, 8),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .15),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: .24), width: 1.4),
                    ),
                    child: const Icon(Icons.manage_accounts_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ORGANIZATION ACCOUNTS',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          widget.orgName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, height: 1.0),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ));

  Widget _memberCard(Map<String, dynamic> member, int index) {
    final p = member['profiles'];
    final x = p is Map ? p : <String, dynamic>{};
    final role = x['role']?.toString() ?? 'student';
    final officer = role == 'officer';
    final avatar = x['avatar_url']?.toString() ?? '';
    final name = x['name']?.toString().trim().isNotEmpty == true
        ? x['name'].toString()
        : member['name']?.toString() ?? 'Member';
    final active = x['active'] == true;
    final position = member['position']?.toString() ?? 'Member';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: green.withValues(alpha: .09)),
        boxShadow: [BoxShadow(color: green.withValues(alpha: .055), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 58,
                height: 58,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: officer ? green.withValues(alpha: .18) : const Color(0xFFDBEAFE),
                ),
                child: CircleAvatar(
                  backgroundColor: officer ? const Color(0xFFE0F7EA) : const Color(0xFFEFF6FF),
                  backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                  child: avatar.isEmpty
                      ? Icon(officer ? Icons.workspace_premium_rounded : Icons.person_rounded, color: officer ? green : const Color(0xFF2563EB), size: 27)
                      : null,
                ),
              ),
              Positioned(
                right: 1,
                bottom: 1,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: active ? green : Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(color: card, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, color: dark, fontSize: 15)),
                const SizedBox(height: 3),
                Text(x['email']?.toString() ?? 'No email linked', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: muted)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(color: green.withValues(alpha: .10), borderRadius: BorderRadius.circular(30)),
                      child: Text(officer ? position.toUpperCase() : 'MEMBER', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: green, letterSpacing: .45)),
                    ),
                    const SizedBox(width: 7),
                    Text(active ? 'Active' : 'Inactive', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: active ? green : muted)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Change member role',
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: green, size: 28),
            onPressed: () => changeRole(member),
          ),
        ],
      ),
    );
  }

  Widget _empty() => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(25), border: Border.all(color: green.withValues(alpha: .10))),
        child: const Column(
          children: [
            Icon(Icons.groups_2_outlined, color: green, size: 45),
            SizedBox(height: 10),
            Text('No members yet', style: TextStyle(color: dark, fontSize: 17, fontWeight: FontWeight.w900)),
            SizedBox(height: 4),
            Text('Approved organization members will appear here.', textAlign: TextAlign.center, style: TextStyle(color: muted, height: 1.4)),
          ],
        ),
      );
}
