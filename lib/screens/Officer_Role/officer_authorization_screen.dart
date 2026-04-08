import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import 'officer_rule_screen.dart';

class OfficerAuthorizationScreen extends StatefulWidget {
  const OfficerAuthorizationScreen({super.key});

  @override
  State<OfficerAuthorizationScreen> createState() =>
      _OfficerAuthorizationScreenState();
}

class _OfficerAuthorizationScreenState extends State<OfficerAuthorizationScreen>
    with SingleTickerProviderStateMixin {
  // ─── Color tokens — unified with ProfileScreen & Dashboard ────────────────
  static const Color _primary = Color(0xFF4F46E5);
  static const Color _secondary = Color(0xFF06B6D4);
  static const Color _background = Color(0xFFF1F5F9);
  static const Color _error = Color(0xFFE11D48);

  // ─── State ─────────────────────────────────────────────────────────────────
  Organization? _selectedOrganization;
  List<Organization> _filteredOrgs = [];
  bool _isAuthenticating = false;
  bool _obscurePassword = true;
  String _errorMessage = '';

  // ─── Controllers ───────────────────────────────────────────────────────────
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _passwordSectionKey = GlobalKey();
  late final AnimationController _formAnim;
  late final Animation<double> _formFade;
  late final Animation<Offset> _formSlide;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _filteredOrgs = List.from(AppState.instance.organizations);

    _formAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _formFade = CurvedAnimation(parent: _formAnim, curve: Curves.easeOut);
    _formSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _formAnim, curve: Curves.easeOutCubic));

    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _formAnim.dispose();
    _passwordController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ─── Handlers ──────────────────────────────────────────────────────────────

  void _onSearch() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredOrgs = query.isEmpty
          ? List.from(AppState.instance.organizations)
          : AppState.instance.organizations
              .where((o) => o.name.toLowerCase().contains(query))
              .toList();
    });
  }

  void _selectOrg(Organization org) {
    final wasSelected = _selectedOrganization?.id == org.id;
    setState(() {
      _selectedOrganization = wasSelected ? null : org;
      _errorMessage = '';
      _passwordController.clear();
    });
    if (!wasSelected) {
      _formAnim.forward(from: 0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ctx = _passwordSectionKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: 0.05,
          );
        }
      });
    } else {
      _formAnim.reverse();
    }
  }

  Future<void> _authenticate() async {
    if (_selectedOrganization == null) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isAuthenticating = true;
      _errorMessage = '';
    });

    await Future.delayed(const Duration(milliseconds: 500));

    if (_passwordController.text == _selectedOrganization!.id) {
      AppState.instance.setCurrentOfficerOrgId(_selectedOrganization!.id);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BaseOfficerDashboard(
              orgId: _selectedOrganization!.id,
              orgName: _selectedOrganization!.name,
            ),
          ),
        );
      }
    } else {
      setState(() {
        _isAuthenticating = false;
        _errorMessage = 'Incorrect password. Hint: use the organization ID.';
        _passwordController.clear();
      });
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;

    return Scaffold(
      backgroundColor: _background,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── SLIVER APP BAR ──────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: MediaQuery.of(context).size.height * 0.20,
            backgroundColor: _primary,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Officer Authorization',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 17,
                letterSpacing: 0.3,
              ),
            ),
            centerTitle: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _HeroHeader(
                primary: _primary,
                secondary: _secondary,
              ),
            ),
          ),

          // ── BODY ────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isTablet ? 540 : double.infinity,
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isTablet ? 0 : 20,
                    28,
                    isTablet ? 0 : 20,
                    48,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Search bar ───────────────────────────────────────
                      const _SectionLabel(text: 'Find Organization'),
                      const SizedBox(height: 12),
                      _SearchBar(controller: _searchController),
                      const SizedBox(height: 20),

                      // ── Organization list ────────────────────────────────
                      const _SectionLabel(text: 'Select Organization'),
                      const SizedBox(height: 12),
                      _OrgListCard(
                        organizations: _filteredOrgs,
                        selectedOrg: _selectedOrganization,
                        onSelect: _selectOrg,
                        searchQuery: _searchController.text.trim(),
                      ),

                      // ── Password form (animated) ─────────────────────────
                      if (_selectedOrganization != null) ...[
                        const SizedBox(height: 24),
                        KeyedSubtree(
                          key: _passwordSectionKey,
                          child: FadeTransition(
                            opacity: _formFade,
                            child: SlideTransition(
                              position: _formSlide,
                              child: _PasswordForm(
                                selectedOrg: _selectedOrganization!,
                                controller: _passwordController,
                                errorMessage: _errorMessage,
                                isAuthenticating: _isAuthenticating,
                                obscurePassword: _obscurePassword,
                                onToggleObscure: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                                onAuthenticate: _authenticate,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
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

// =============================================================================
// _HeroHeader
// =============================================================================
class _HeroHeader extends StatelessWidget {
  final Color primary;
  final Color secondary;

  const _HeroHeader({required this.primary, required this.secondary});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -20,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -10,
            left: -40,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 52, left: 24, right: 24),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.30),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Officer Access',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Select your organization to continue',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.72),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _SearchBar
// =============================================================================
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withOpacity(0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          hintText: 'Search organization name...',
          hintStyle: const TextStyle(
            color: Color(0xFFCBD5E1),
            fontSize: 13.5,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF4F46E5),
            size: 20,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) => value.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF94A3B8),
                      size: 18,
                    ),
                    onPressed: controller.clear,
                  )
                : const SizedBox.shrink(),
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.8),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        ),
      ),
    );
  }
}

// =============================================================================
// _OrgListCard — virtualized list, no logo logo is replaced by check on select
// =============================================================================
class _OrgListCard extends StatelessWidget {
  final List<Organization> organizations;
  final Organization? selectedOrg;
  final ValueChanged<Organization> onSelect;
  final String searchQuery;

  const _OrgListCard({
    required this.organizations,
    required this.selectedOrg,
    required this.onSelect,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    if (organizations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F46E5).withOpacity(0.07),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                color: Color(0xFF4F46E5),
                size: 26,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No results for "$searchQuery"',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              'Try a different keyword',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    // Cap list height so the password field stays just below this card instead
    // of after every row (avoids long scroll to reach password).
    const double approxRowHeight = 86;
    final double maxCap =
        (MediaQuery.sizeOf(context).height * 0.42).clamp(240.0, 460.0);
    final double contentHeight =
        organizations.length * approxRowHeight + 8;
    final double listHeight = contentHeight > maxCap
        ? maxCap
        : contentHeight.clamp(120.0, maxCap);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: listHeight,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: organizations.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              thickness: 1,
              indent: 76,
              endIndent: 18,
              color: Colors.grey.shade100,
            ),
            itemBuilder: (context, index) {
              final org = organizations[index];
              return _OrgRow(
                org: org,
                isSelected: selectedOrg?.id == org.id,
                isLast: true,
                onTap: () => onSelect(org),
              );
            },
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _OrgRow — single organization row, const-safe
// =============================================================================
class _OrgRow extends StatelessWidget {
  final Organization org;
  final bool isSelected;
  final bool isLast;
  final VoidCallback onTap;

  const _OrgRow({
    required this.org,
    required this.isSelected,
    required this.isLast,
    required this.onTap,
  });

  static const Color _primary = Color(0xFF4F46E5);
  static const Color _secondary = Color(0xFF06B6D4);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: _primary.withOpacity(0.06),
            highlightColor: _primary.withOpacity(0.04),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              color:
                  isSelected ? _primary.withOpacity(0.05) : Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  // Logo / check container
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [_primary, _secondary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isSelected ? null : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: _primary.withOpacity(0.28),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 20,
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              org.logoAsset,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.business_rounded,
                                color: Color(0xFF94A3B8),
                                size: 20,
                              ),
                            ),
                          ),
                  ),

                  const SizedBox(width: 14),

                  // Org details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          org.name,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color:
                                isSelected ? _primary : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Adviser: ${org.adviser}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'ID: ${org.id}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Arrow / selected indicator
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: isSelected
                        ? Container(
                            key: const ValueKey('selected'),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _primary.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Selected',
                              style: TextStyle(
                                fontSize: 10,
                                color: _primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : Icon(
                            key: const ValueKey('arrow'),
                            Icons.chevron_right_rounded,
                            color: const Color(0xFFCBD5E1),
                            size: 20,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            thickness: 1,
            indent: 76,
            endIndent: 18,
            color: Colors.grey.shade100,
          ),
      ],
    );
  }
}

// =============================================================================
// _PasswordForm — extracted widget for clean rebuilds
// =============================================================================
class _PasswordForm extends StatelessWidget {
  final Organization selectedOrg;
  final TextEditingController controller;
  final String errorMessage;
  final bool isAuthenticating;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final VoidCallback onAuthenticate;

  static const Color _primary = Color(0xFF4F46E5);
  static const Color _secondary = Color(0xFF06B6D4);
  static const Color _error = Color(0xFFE11D48);

  const _PasswordForm({
    required this.selectedOrg,
    required this.controller,
    required this.errorMessage,
    required this.isAuthenticating,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.onAuthenticate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel(text: 'Enter Password'),
        const SizedBox(height: 12),

        // Selected org summary chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _primary.withOpacity(0.08),
                _secondary.withOpacity(0.06),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _primary.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: _primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selectedOrg.name,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Accessing officer dashboard',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: _primary.withOpacity(0.70),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Password field
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _primary.withOpacity(0.07),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            obscureText: obscurePassword,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
              letterSpacing: 1.5,
            ),
            onSubmitted: (_) => onAuthenticate(),
            decoration: InputDecoration(
              hintText: 'Enter organization password',
              hintStyle: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 13.5,
                letterSpacing: 0,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(10),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: _primary,
                    size: 16,
                  ),
                ),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: const Color(0xFF94A3B8),
                  size: 20,
                ),
                onPressed: onToggleObscure,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _primary, width: 1.8),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _error, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _error, width: 1.8),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),

        // Error message
        if (errorMessage.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _error.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _error.withOpacity(0.25), width: 1),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: _error,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorMessage,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: _error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Access button
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: isAuthenticating ? null : onAuthenticate,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              height: 54,
              decoration: BoxDecoration(
                gradient: isAuthenticating
                    ? null
                    : const LinearGradient(
                        colors: [_primary, _secondary],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                color: isAuthenticating ? const Color(0xFFE2E8F0) : null,
                borderRadius: BorderRadius.circular(14),
                boxShadow: isAuthenticating
                    ? null
                    : [
                        BoxShadow(
                          color: _primary.withOpacity(0.32),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: Center(
                child: isAuthenticating
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: _primary,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shield_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Access Dashboard',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// _SectionLabel — unified across all screens
// =============================================================================
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
            color: Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}
