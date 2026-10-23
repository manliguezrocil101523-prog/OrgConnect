import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../core/app_state.dart';

class AdminAccountsScreen extends StatefulWidget {
  const AdminAccountsScreen({super.key});

  @override
  State<AdminAccountsScreen> createState() => _AdminAccountsScreenState();
}

class _AdminAccountsScreenState extends State<AdminAccountsScreen> {
  List<Map<String, dynamic>> dbUsers = [];
  bool isLoading = true;

  // UI-only state for the search and filter bar.
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _roleFilter = 'all'; // all | student | officer | adviser | admin
  String _statusFilter = 'all'; // all | active | inactive

  static const Color accent = Color(0xFF10B981);
  static const Color accentDeep = Color(0xFF059669);
  static const Color success = Color(0xFF10B981);
  static const Color danger = Color(0xFFEF4444);

  static const double _desktopBreakpoint = 1024;
  static const double _maxContentWidth = 1280;

  static const List<String> _officerPositions = [
    'President',
    'Vice President',
    'Secretary',
    'Assistant Secretary',
    'Officer',
  ];

  _Palette get _p => _Palette(AppState.instance.isDark);

  @override
  void initState() {
    super.initState();
    _fetchUsersFromDatabase();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Backend logic (unchanged)
  // ---------------------------------------------------------------------------

  Future<void> _fetchUsersFromDatabase() async {
    try {
      final response =
          await supabase.Supabase.instance.client.from('profiles').select('*');
      setState(() {
        dbUsers = List<Map<String, dynamic>>.from(response as List);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        dbUsers = [];
        isLoading = false;
      });
    }
  }

  Future<void> _updateActiveInDatabase(String userId, bool active) async {
    try {
      await supabase.Supabase.instance.client
          .from('profiles')
          .update({'active': active}).eq('id', userId);
    } catch (e) {
      _showSnack('Failed to update status: $e');
    }
  }

  Future<void> _setOfficerPosition(
    Map<String, dynamic> user,
    String position,
  ) async {
    final userId = user['id'].toString();
    final previousPosition = user['officer_position']?.toString() ?? '';
    setState(() {
      final index = dbUsers.indexWhere((item) => item['id'] == user['id']);
      if (index != -1) dbUsers[index]['officer_position'] = position;
    });

    try {
      await supabase.Supabase.instance.client
          .from('profiles')
          .update({'officer_position': position}).eq('id', userId);
      if (!mounted) return;
      _showSnack('Officer position updated to $position');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final index = dbUsers.indexWhere((item) => item['id'] == user['id']);
        if (index != -1) dbUsers[index]['officer_position'] = previousPosition;
      });
      _showSnack('Failed to update officer position: $e');
    }
  }

  // Show org picker when admin sets role to Officer or Adviser.
  Future<void> _showOrgPickerDialog(
    Map<String, dynamic> user, {
    String role = 'officer',
  }) async {
    final orgs = AppState.instance.organizations;
    final p = _p;

    if (orgs.isEmpty) {
      _showSnack('No organizations found. Please add organizations first.');
      return;
    }

    Organization? selectedOrg;

    // Pre-select if already assigned.
    final currentOrgId = user['assigned_org_id']?.toString();
    if (currentOrgId != null) {
      try {
        selectedOrg = orgs.firstWhere((o) => o.id == currentOrgId);
      } catch (_) {}
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: p.surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: p.border),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.shield_rounded,
                          color: accentDeep,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Assign Organization',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: p.textMain,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select which org ${user['name'] ?? user['email']} can access as ${role == 'adviser' ? 'Adviser' : 'Officer'}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: p.textSub,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: orgs.length,
                  itemBuilder: (_, index) {
                    final org = orgs[index];
                    final isChosen = selectedOrg?.id == org.id;

                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedOrg = org),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isChosen
                              ? accent.withValues(alpha: 0.10)
                              : p.subtle,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isChosen ? accent : p.border,
                            width: isChosen ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isChosen ? accent : p.border,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Icon(
                                isChosen
                                    ? Icons.check_rounded
                                    : Icons.business_rounded,
                                color: isChosen ? Colors.white : p.textSub,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    org.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13.5,
                                      color: isChosen ? accentDeep : p.textMain,
                                    ),
                                  ),
                                  Text(
                                    'ID: ${org.id}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: p.textSub,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: p.textSub),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: selectedOrg == null
                      ? null
                      : () async {
                          Navigator.pop(ctx);

                          final userId = user['id'].toString();
                          final orgId = selectedOrg!.id;

                          try {
                            await supabase.Supabase.instance.client
                                .from('profiles')
                                .update({
                              'role': role,
                              'assigned_org_id': orgId,
                            }).eq('id', userId);

                            if (!mounted) return;

                            setState(() {
                              final idx = dbUsers.indexWhere(
                                (u) => u['id'] == userId,
                              );

                              if (idx != -1) {
                                dbUsers[idx]['role'] = role;
                                dbUsers[idx]['assigned_org_id'] = orgId;
                              }
                            });

                            _showSnack(
                              '${user['name'] ?? user['email']} is now ${role == 'adviser' ? 'Adviser' : 'Officer'} of ${selectedOrg!.name}',
                            );
                          } catch (e) {
                            if (!mounted) return;
                            _showSnack('Error: $e');
                          }
                        },
                  child: const Text(
                    'Confirm',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Small data helpers
  // ---------------------------------------------------------------------------

  String _roleOf(Map<String, dynamic> u) => u['role']?.toString() ?? 'student';

  bool _isActiveOf(Map<String, dynamic> u) => (u['active'] ?? true) as bool;

  int _countForRole(String role) {
    if (role == 'all') return dbUsers.length;
    return dbUsers.where((u) => _roleOf(u) == role).length;
  }

  List<Map<String, dynamic>> get _filteredUsers {
    final q = _searchQuery.trim().toLowerCase();

    return dbUsers.where((u) {
      if (_roleFilter != 'all' && _roleOf(u) != _roleFilter) return false;

      final active = _isActiveOf(u);
      if (_statusFilter == 'active' && !active) return false;
      if (_statusFilter == 'inactive' && active) return false;

      if (q.isEmpty) return true;
      final name = (u['name'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();
  }

  bool get _hasActiveFilters =>
      _searchQuery.trim().isNotEmpty ||
      _roleFilter != 'all' ||
      _statusFilter != 'all';

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _roleFilter = 'all';
      _statusFilter = 'all';
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final p = _p;

    return Scaffold(
      backgroundColor: p.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isDesktop = width > _desktopBreakpoint;

          return Column(
            children: [
              // The header stays fixed at the top, including while loading
              // or when there are no accounts.
              _buildHeader(p, isDesktop),
              Expanded(child: _buildContent(p, width, isDesktop)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(_Palette p, double width, bool isDesktop) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: accent, strokeWidth: 3),
      );
    }

    if (dbUsers.isEmpty) {
      return _buildEmptyState(
        p,
        icon: Icons.group_off_rounded,
        title: 'No users found',
      );
    }

    final filtered = _filteredUsers;

    final sections = <_Section>[
      _Section(
        'Students',
        filtered.where((u) => _roleOf(u) == 'student').toList(),
      ),
      _Section(
        'Officers',
        filtered.where((u) => _roleOf(u) == 'officer').toList(),
      ),
      _Section(
        'Advisers',
        filtered.where((u) => _roleOf(u) == 'adviser').toList(),
      ),
      _Section(
        'Admins',
        filtered.where((u) => _roleOf(u) == 'admin').toList(),
      ),
    ].where((s) => s.users.isNotEmpty).toList();

    final columns = !isDesktop ? 1 : (width >= 1280 ? 3 : 2);

    // Flatten into section headers and rows of cards (1 card per row on
    // mobile, 2-3 on desktop) so ListView.builder can build lazily.
    final entries = <Object>[];
    for (final s in sections) {
      entries.add(s);
      for (var i = 0; i < s.users.length; i += columns) {
        final end =
            (i + columns > s.users.length) ? s.users.length : i + columns;
        entries.add(s.users.sublist(i, end));
      }
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: entries.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _centered(
            isDesktop,
            _buildFilterBar(p, isDesktop, filtered.length),
          );
        }

        if (index == entries.length + 1) {
          if (entries.isEmpty) {
            return _centered(
              isDesktop,
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: _buildNoResults(p),
              ),
            );
          }
          return const SizedBox(height: 32);
        }

        final entry = entries[index - 1];

        if (entry is _Section) {
          return _centered(isDesktop, _buildSectionHeader(p, entry));
        }

        final row = (entry as List).cast<Map<String, dynamic>>();
        return _centered(isDesktop, _buildUserRow(p, row, columns));
      },
    );
  }

  Widget _centered(bool isDesktop, Widget child) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16),
          child: child,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader(_Palette p, bool isDesktop) {
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 24 : 16,
                vertical: isDesktop ? 20 : 14,
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: p.isDark ? 0.16 : 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withValues(alpha: 0.25)),
                    ),
                    child: Icon(
                      Icons.manage_accounts_rounded,
                      color: p.accentText,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Accounts',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isDesktop ? 22 : 19,
                            fontWeight: FontWeight.w700,
                            color: p.textMain,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Manage accounts, roles, and access',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: p.textSub,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: p.isDark ? 0.16 : 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${dbUsers.length} ACCOUNTS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: p.accentText,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search and filters
  // ---------------------------------------------------------------------------

  Widget _buildFilterBar(_Palette p, bool isDesktop, int shownCount) {
    final search = SizedBox(
      height: 44,
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: TextStyle(color: p.textMain, fontSize: 14),
        cursorColor: accent,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search by name or email',
          hintStyle: TextStyle(color: p.textSub, fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: p.textSub, size: 20),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close_rounded, color: p.textSub, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
          filled: true,
          fillColor: p.surface,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: p.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: p.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: accent, width: 1.5),
          ),
        ),
      ),
    );

    const roleOptions = <String, String>{
      'all': 'All',
      'student': 'Students',
      'officer': 'Officers',
      'adviser': 'Advisers',
      'admin': 'Admins',
    };

    const statusOptions = <String, String>{
      'all': 'Any status',
      'active': 'Active',
      'inactive': 'Inactive',
    };

    final chips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final e in roleOptions.entries) ...[
            _buildChip(
              p,
              label: e.value,
              count: _countForRole(e.key),
              selected: _roleFilter == e.key,
              onTap: () => setState(() => _roleFilter = e.key),
            ),
            const SizedBox(width: 6),
          ],
          Container(
            width: 1,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: p.border,
          ),
          for (final e in statusOptions.entries) ...[
            _buildChip(
              p,
              label: e.value,
              selected: _statusFilter == e.key,
              onTap: () => setState(() => _statusFilter = e.key),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(top: isDesktop ? 24 : 16, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDesktop)
            Row(
              children: [
                SizedBox(width: 360, child: search),
                const SizedBox(width: 16),
                Expanded(child: chips),
              ],
            )
          else ...[
            search,
            const SizedBox(height: 10),
            chips,
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Showing $shownCount of ${dbUsers.length} accounts',
                style: TextStyle(fontSize: 12, color: p.textSub),
              ),
              if (_hasActiveFilters) ...[
                const SizedBox(width: 10),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _clearFilters,
                    child: Text(
                      'Clear filters',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: p.accentText,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(
    _Palette p, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
    int? count,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: p.isDark ? 0.18 : 0.10)
                : p.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? accent.withValues(alpha: 0.55) : p.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? p.accentText : p.textSub,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? p.accentText.withValues(alpha: 0.8)
                        : p.textSub.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section header
  // ---------------------------------------------------------------------------

  Widget _buildSectionHeader(_Palette p, _Section section) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 12),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            section.title,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: p.textMain,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: p.subtle,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: p.border),
            ),
            child: Text(
              '${section.users.length}',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: p.textSub,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Container(height: 1, color: p.border)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // User cards
  // ---------------------------------------------------------------------------

  Widget _buildUserRow(
    _Palette p,
    List<Map<String, dynamic>> row,
    int columns,
  ) {
    if (columns == 1) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildUserCard(p, row.first),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < columns; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(
                child: i < row.length
                    ? _buildUserCard(p, row[i])
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(_Palette p, Map<String, dynamic> u) {
    final role = _roleOf(u);
    final isActive = _isActiveOf(u);
    final assignedOrgId = u['assigned_org_id']?.toString();

    String? assignedOrgName;

    if (assignedOrgId != null) {
      try {
        assignedOrgName = AppState.instance.organizations
            .firstWhere((o) => o.id == assignedOrgId)
            .name;
      } catch (_) {
        assignedOrgName = assignedOrgId;
      }
    }

    return _HoverCard(
      surface: p.surface,
      border: p.border,
      hoverBorder: accent.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(u),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u['name']?.toString() ?? 'No Name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                        color: p.textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      u['email']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.textSub, fontSize: 12.5),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildRolePill(p, role),
                        if (assignedOrgName != null && role == 'adviser')
                          _buildOrgPill(p, assignedOrgName),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _buildStatusBadge(p, isActive),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, thickness: 1, color: p.border),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: role == 'officer'
                        ? _buildOfficerPositionDropdown(p, u)
                        : _buildRoleDropdown(p, u, role),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _buildActiveSwitch(u, isActive),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(Map<String, dynamic> u) {
    final hasName = u['name']?.toString().isNotEmpty == true;
    final initial = hasName ? u['name'].toString()[0].toUpperCase() : '?';

    final fallback = Text(
      initial,
      style: const TextStyle(
        color: accentDeep,
        fontWeight: FontWeight.w800,
        fontSize: 18,
      ),
    );

    final hasAvatar = u['avatar_url']?.toString().isNotEmpty ?? false;

    return CircleAvatar(
      radius: 24,
      backgroundColor: accent.withValues(alpha: 0.14),
      child: hasAvatar
          ? ClipOval(
              child: Image.network(
                u['avatar_url'].toString(),
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(child: fallback),
              ),
            )
          : fallback,
    );
  }

  Widget _buildRolePill(_Palette p, String role) {
    final s = _roleStyle(role, p.isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: 12, color: s.fg),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              s.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: s.fg,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrgPill(_Palette p, String orgName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: p.subtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.apartment_rounded, size: 12, color: p.accentText),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              orgName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: p.textMain,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(_Palette p, bool isActive) {
    final color = isActive ? success : danger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: p.isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              color: isActive ? p.accentText : danger,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Controls (dropdowns and switch). Callbacks are the original logic.
  // ---------------------------------------------------------------------------

  Widget _dropdownShell(_Palette p, Widget dropdown) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: p.subtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.border),
      ),
      child: DropdownButtonHideUnderline(child: dropdown),
    );
  }

  Widget _buildOfficerPositionDropdown(_Palette p, Map<String, dynamic> u) {
    return _dropdownShell(
      p,
      DropdownButton<String>(
        value: _officerPositions.contains(u['officer_position']?.toString())
            ? u['officer_position'].toString()
            : 'Officer',
        isDense: true,
        isExpanded: true,
        borderRadius: BorderRadius.circular(12),
        dropdownColor: p.surface,
        style: TextStyle(
          color: p.textMain,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: p.textSub,
          size: 20,
        ),
        items: const [
          DropdownMenuItem(value: 'President', child: Text('President')),
          DropdownMenuItem(
              value: 'Vice President', child: Text('Vice President')),
          DropdownMenuItem(value: 'Secretary', child: Text('Secretary')),
          DropdownMenuItem(
              value: 'Assistant Secretary', child: Text('Assistant Secretary')),
          DropdownMenuItem(value: 'Officer', child: Text('Officer')),
        ],
        onChanged: (position) {
          if (position != null) {
            _setOfficerPosition(u, position);
          }
        },
      ),
    );
  }

  Widget _buildRoleDropdown(_Palette p, Map<String, dynamic> u, String role) {
    return _dropdownShell(
      p,
      DropdownButton<String>(
        value: role,
        isDense: true,
        isExpanded: true,
        borderRadius: BorderRadius.circular(12),
        dropdownColor: p.surface,
        style: TextStyle(
          color: p.textMain,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: p.textSub,
          size: 20,
        ),
        items: const [
          DropdownMenuItem(
            value: 'student',
            child: Text('Student'),
          ),
          DropdownMenuItem(
            value: 'admin',
            child: Text('Admin'),
          ),
          DropdownMenuItem(
            value: 'adviser',
            child: Text('Adviser'),
          ),
        ],
        onChanged: (val) async {
          if (val == null) return;

          if (val == 'adviser') {
            await _showOrgPickerDialog(
              u,
              role: val,
            );
          } else {
            await supabase.Supabase.instance.client.from('profiles').update({
              'role': val,
              'assigned_org_id': null,
            }).eq('id', u['id'].toString());

            if (!mounted) return;

            setState(() {
              final realIdx = dbUsers.indexWhere(
                (d) => d['id'] == u['id'],
              );

              if (realIdx != -1) {
                dbUsers[realIdx]['role'] = val;
                dbUsers[realIdx]['assigned_org_id'] = null;
              }
            });

            _showSnack('Role updated to $val');
          }
        },
      ),
    );
  }

  Widget _buildActiveSwitch(Map<String, dynamic> u, bool isActive) {
    return Switch.adaptive(
      value: isActive,
      activeThumbColor: Colors.white,
      activeTrackColor: success,
      inactiveThumbColor: Colors.white,
      inactiveTrackColor: const Color(0xFFD1D5DB),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onChanged: (value) async {
        await _updateActiveInDatabase(
          u['id'].toString(),
          value,
        );

        if (!mounted) return;

        setState(() {
          final realIdx = dbUsers.indexWhere(
            (d) => d['id'] == u['id'],
          );

          if (realIdx != -1) {
            dbUsers[realIdx]['active'] = value;
          }
        });

        _showSnack(
          value ? 'User activated' : 'User disabled',
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Empty states
  // ---------------------------------------------------------------------------

  Widget _buildNoResults(_Palette p) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 36, color: p.textSub),
          const SizedBox(height: 12),
          Text(
            'No matching accounts',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: p.textMain,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try a different name or email, or clear the filters.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: p.textSub),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _clearFilters,
            style: OutlinedButton.styleFrom(
              foregroundColor: p.accentText,
              side: BorderSide(color: accent.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Clear filters'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    _Palette p, {
    required IconData icon,
    required String title,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: p.subtle,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.border),
            ),
            child: Icon(icon, color: p.textSub, size: 26),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              color: p.textSub,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Supporting types
// -----------------------------------------------------------------------------

class _Section {
  final String title;
  final List<Map<String, dynamic>> users;

  const _Section(this.title, this.users);
}

class _Palette {
  final bool isDark;

  const _Palette(this.isDark);

  Color get background =>
      isDark ? const Color(0xFF0B1210) : const Color(0xFFF9FAFB);
  Color get surface => isDark ? const Color(0xFF131A16) : Colors.white;
  Color get subtle =>
      isDark ? const Color(0xFF1A231E) : const Color(0xFFF3F4F6);
  Color get border =>
      isDark ? const Color(0xFF243029) : const Color(0xFFE5E7EB);
  Color get textMain =>
      isDark ? const Color(0xFFF3F4F6) : const Color(0xFF111827);
  Color get textSub =>
      isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
  Color get accentText =>
      isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
}

class _RoleStyle {
  final String label;
  final IconData icon;
  final Color fg;
  final Color bg;

  const _RoleStyle(this.label, this.icon, this.fg, this.bg);
}

_RoleStyle _roleStyle(String role, bool isDark) {
  Color bgOf(Color fg) => fg.withValues(alpha: isDark ? 0.16 : 0.10);

  switch (role) {
    case 'officer':
      final fg = isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
      return _RoleStyle(
        'Officer — assigned by Adviser',
        Icons.lock_person_rounded,
        fg,
        bgOf(fg),
      );
    case 'adviser':
      final fg = isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E);
      return _RoleStyle('Adviser', Icons.school_rounded, fg, bgOf(fg));
    case 'admin':
      final fg = isDark ? const Color(0xFFE5E7EB) : const Color(0xFF111827);
      return _RoleStyle(
        'Admin',
        Icons.admin_panel_settings_rounded,
        fg,
        bgOf(fg),
      );
    default:
      final fg = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
      return _RoleStyle('Student', Icons.person_rounded, fg, bgOf(fg));
  }
}

/// Outlined card with a soft hover border and shadow on desktop and web.
class _HoverCard extends StatefulWidget {
  final Widget child;
  final Color surface;
  final Color border;
  final Color hoverBorder;

  const _HoverCard({
    required this.child,
    required this.surface,
    required this.border,
    required this.hoverBorder,
  });

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovered ? widget.hoverBorder : widget.border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _hovered ? 0.07 : 0.03),
              blurRadius: _hovered ? 18 : 8,
              offset: Offset(0, _hovered ? 6 : 2),
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}
