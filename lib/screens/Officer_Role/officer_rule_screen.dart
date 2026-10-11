import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_state.dart';
import '../../core/app_state.dart' as app_models;

import '../analytics/event_comments_sheet.dart';
import '../community/org_community_chat_screen.dart';
import 'officer_applications_screen.dart';
import 'officer_events_screen.dart';
import 'officer_members_screen.dart';
import 'officer_profile_screen.dart';
import 'officer_org_profile_screen.dart';
import '../organizations/org_list_screen.dart';

const Color _background = Color(0xFFF0FDF4);

class BaseOfficerDashboard extends StatefulWidget {
  final String orgId;
  final String orgName;

  const BaseOfficerDashboard({
    super.key,
    required this.orgId,
    required this.orgName,
  });

  @override
  State<BaseOfficerDashboard> createState() => _BaseOfficerDashboardState();
}

class _BaseOfficerDashboardState extends State<BaseOfficerDashboard> {
  int _selectedIndex = 0;
  DateTime? _lastBackPressed;
  bool _allowPop = false;
  List<Map<String, dynamic>> _publishedEvents = <Map<String, dynamic>>[];
  bool _loadingEvents = true;
  String _avatarUrl = '';
  String _userName = '';
  String _position = 'Officer';

  @override
  void initState() {
    super.initState();
    _loadOfficerHome();
  }

  Future<void> _loadOfficerHome() async {
    await Future.wait([
      _loadPublishedEvents(),
      _loadOfficerProfile(),
    ]);
  }

  Future<void> _loadOfficerProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) return;
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('name,avatar_url')
          .eq('id', userId)
          .maybeSingle();
      final membership = await Supabase.instance.client
          .from('members')
          .select('position')
          .eq('org_id', widget.orgId)
          .eq('profile_id', userId)
          .maybeSingle();
      if (!mounted) return;
      final position = membership?['position']?.toString().trim();
      setState(() {
        _userName = profile?['name']?.toString().trim() ?? '';
        _avatarUrl = profile?['avatar_url']?.toString().trim() ?? '';
        _position = position == null || position.isEmpty ? 'Officer' : position;
      });
    } catch (_) {
      // The dashboard remains usable even when profile details cannot load.
    }
  }

  Future<void> _loadPublishedEvents() async {
    try {
      final response = await Supabase.instance.client
          .from('events')
          .select('*')
          .eq('org_id', widget.orgId)
          .order('date', ascending: true);

      final rows = List<Map<String, dynamic>>.from(response as List);
      final now = DateTime.now();
      final filtered = rows.where((event) {
        final status = event['status']?.toString().toLowerCase() ?? '';
        final published = !event.containsKey('status') || status.isEmpty || status == 'published' || status == 'approved' || status == 'posted';
        final date = DateTime.tryParse(event['date']?.toString() ?? '');
        return published && (date == null || !date.isBefore(now));
      }).toList();

      if (!mounted) return;
      setState(() {
        _publishedEvents = filtered;
        _loadingEvents = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _publishedEvents = <Map<String, dynamic>>[];
        _loadingEvents = false;
      });
    }
  }

  Future<bool> _handleBack() async {
    final now = DateTime.now();
    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;
      if (mounted) setState(() => _allowPop = true);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Tap again to exit', textAlign: TextAlign.center),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 140,
            left: 40,
            right: 40,
          ),
        ),
      );
      return false;
    }
    return true;
  }

  void _openOrganizations() {
    if (_selectedIndex == 1) return;
    setState(() => _selectedIndex = 1);
  }

  String _currentOrganizationLogo() {
    for (final org in AppState.instance.organizations) {
      if (org.id == widget.orgId) {
        return org.logoAsset.trim();
      }
    }
    return '';
  }

  void _openEvents() {
    if (_selectedIndex == 2) return;
    setState(() => _selectedIndex = 2);
  }

  void _openProfile() {
    if (_selectedIndex == 3) return;
    setState(() => _selectedIndex = 3);
  }


  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _handleBack();
        }
      },
      child: Scaffold(
        backgroundColor: _background,
        body: Column(
          children: [
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  _HomeTab(
                    orgName: widget.orgName,
                    events: _publishedEvents,
                    loadingEvents: _loadingEvents,
                    onRefresh: _loadOfficerHome,
                    userName: _userName,
                    avatarUrl: _avatarUrl,
                    position: _position,
                  ),
                  _OfficerOrganizationsTab(
                    orgId: widget.orgId,
                    orgName: widget.orgName,
                    position: _position,
                  ),
                  OfficerEventsScreen(
                    orgId: widget.orgId,
                    orgName: widget.orgName,
                    logoAsset: _currentOrganizationLogo(),
                    embedded: true,
                  ),
                  OfficerProfileScreen(
                    initialName: _userName,
                    initialAvatarUrl: _avatarUrl,
                    embedded: true,
                    organizationId: widget.orgId,
                    organizationName: widget.orgName,
                  ),
                ],
              ),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                selected: _selectedIndex == 0,
                onTap: () => setState(() => _selectedIndex = 0),
              ),
              _NavItem(
                icon: Icons.business_rounded,
                label: 'Organizations',
                selected: _selectedIndex == 1,
                onTap: _openOrganizations,
              ),
              _NavItem(
                icon: Icons.event_rounded,
                label: 'Events',
                selected: _selectedIndex == 2,
                onTap: _openEvents,
              ),
              _NavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                selected: _selectedIndex == 3,
                onTap: _openProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  final String orgName;
  final List<Map<String, dynamic>> events;
  final bool loadingEvents;
  final Future<void> Function() onRefresh;
  final String userName;
  final String avatarUrl;
  final String position;

  const _HomeTab({
    required this.orgName,
    required this.events,
    required this.loadingEvents,
    required this.onRefresh,
    required this.userName,
    required this.avatarUrl,
    required this.position,
  });

  int _upcomingCount() {
    final now = DateTime.now();
    return events.where((event) {
      final value = DateTime.tryParse('${event['date'] ?? ''}');
      return value != null && !value.isBefore(now);
    }).length;
  }

  int _pastCount() {
    final now = DateTime.now();
    return events.where((event) {
      final value = DateTime.tryParse('${event['date'] ?? ''}');
      return value != null && value.isBefore(now);
    }).length;
  }

  String _date(dynamic value) {
    final d = DateTime.tryParse('${value ?? ''}');
    if (d == null) return 'No date';
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final suffix = d.hour >= 12 ? 'PM' : 'AM';
    return '$month/$day/${d.year} • $hour:$minute $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final displayName = userName.isNotEmpty ? userName : 'Officer';
    final cleanOrgName = orgName.replaceAll(RegExp(r'tiatro', caseSensitive: false), 'teatro').trim();
    final cleanPosition = position.trim().isEmpty ? 'Officer' : position.trim();
    final orgStatus = '$cleanOrgName $cleanPosition';
    final upcoming = _upcomingCount();
    final past = _pastCount();

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF1FCF6), Color(0xFFE1F6EB), Color(0xFFD1EFDF)],
          ),
        ),
        child: RefreshIndicator(
          color: _green,
          backgroundColor: _card,
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.only(bottom: 34),
            children: [
              _OfficerHomeHero(
                displayName: displayName,
                orgStatus: orgStatus,
                avatarUrl: avatarUrl,
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _OfficerStatCard(
                            icon: Icons.event_rounded,
                            label: 'Posted',
                            value: events.length,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _OfficerStatCard(
                            icon: Icons.upcoming_rounded,
                            label: 'Upcoming',
                            value: upcoming,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _OfficerStatCard(
                            icon: Icons.history_rounded,
                            label: 'Past',
                            value: past,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _OfficerSectionHeader(
                      title: 'Posted Events',
                      subtitle: 'Events approved and posted by the adviser, with their pictures',
                    ),
                    const SizedBox(height: 10),
                    if (loadingEvents)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 72),
                        child: Center(
                          child: CircularProgressIndicator(color: _green),
                        ),
                      )
                    else if (events.isEmpty)
                      const _EmptyEventsState()
                    else
                      ...events.map(
                        (event) => _OfficerEventCard(
                          event: event,
                          dateText: _date(event['date']),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const Color _green = Color(0xFF128058);
const Color _dark = Color(0xFF073B2A);
const Color _muted2 = Color(0xFF4D6F62);
const Color _card = Color(0xFFF5FFF9);
const Color _line = Color(0xFFB9E4CF);

class _OfficerHomeHero extends StatelessWidget {
  final String displayName;
  final String orgStatus;
  final String avatarUrl;

  const _OfficerHomeHero({
    required this.displayName,
    required this.orgStatus,
    required this.avatarUrl,
  });

  Widget _orb(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: .07),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF064E3B), Color(0xFF128058), Color(0xFF22C55E)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Stack(
        children: [
          Positioned(right: -45, top: -70, child: _orb(170)),
          Positioned(right: 45, bottom: -70, child: _orb(125)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 68,
                height: 68,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .20),
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  padding: const EdgeInsets.all(3),
                  child: CircleAvatar(
                    backgroundColor: const Color(0xFFE0F5E8),
                    backgroundImage:
                        avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl.isEmpty
                        ? const Icon(Icons.person_rounded,
                            color: _green, size: 31)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good day, $displayName 👋',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 29,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your organization\'s posted events at a glance',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .86),
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            color: Color(0xFF86EFAC),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            orgStatus,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OfficerStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;

  const _OfficerStatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F8F62), Color(0xFF20B77D)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: .18)),
        boxShadow: [
          BoxShadow(
            color: _green.withValues(alpha: .14),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: Colors.white, size: 19),
          ),
          const SizedBox(height: 10),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              color: Colors.white.withValues(alpha: .82),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfficerSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _OfficerSectionHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: _muted2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OfficerEventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final String dateText;

  const _OfficerEventCard({
    required this.event,
    required this.dateText,
  });

  static String _eventImage(Map<String, dynamic> event) {
    final imageUrl = event['image_url']?.toString() ?? '';
    if (imageUrl.isNotEmpty) return imageUrl;
    final raw = event['image_urls'];
    if (raw is List) {
      for (final value in raw) {
        final url = value?.toString() ?? '';
        if (url.isNotEmpty) return url;
      }
    }
    return '';
  }

  Widget _imagePlaceholder() => Container(
        height: 160,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF064E3B), Color(0xFF20B77D)],
          ),
        ),
        child: const Center(
          child: Icon(Icons.event_rounded, color: Colors.white, size: 42),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final title = event['title']?.toString().trim().isNotEmpty == true
        ? event['title'].toString()
        : 'Untitled event';
    final description = event['description']?.toString() ?? '';
    final imageUrl = _eventImage(event);
    final eventId = event['id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE9FFF2), Color(0xFFBDF3D0)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: _green.withValues(alpha: .08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl.isNotEmpty)
            SizedBox(
              height: 160,
              width: double.infinity,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _imagePlaceholder(),
              ),
            )
          else
            _imagePlaceholder(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      size: 15,
                      color: _green,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        dateText,
                        style: const TextStyle(
                          color: _muted2,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (description.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted2,
                      height: 1.35,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (eventId.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  EventReactionBar(eventId: eventId),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => showEventComments(
                        context,
                        eventId: eventId,
                        eventTitle: title,
                      ),
                      icon: const Icon(Icons.forum_outlined, size: 17),
                      label: const Text('View Comments'),
                      style: TextButton.styleFrom(
                        foregroundColor: _green,
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyEventsState extends StatelessWidget {
  const _EmptyEventsState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF8FFFB), Color(0xFFDDF4E8)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: _green.withValues(alpha: .06),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: .09),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.eco_rounded, color: _green, size: 25),
          ),
          const SizedBox(height: 10),
          const Text(
            'No posted events yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted2,
              height: 1.4,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Approved event creatives will appear here once the adviser posts them.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted2,
              height: 1.4,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfficerOrganizationsTab extends StatelessWidget {
  final String orgId;
  final String orgName;
  final String position;

  const _OfficerOrganizationsTab({
    required this.orgId,
    required this.orgName,
    required this.position,
  });

  static const green = Color(0xFF128058);
  static const bg = Color(0xFFE6F7EE);

  void _openApplications(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OfficerApplicationsScreen()),
    );
  }

  void _openMembers(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OfficerMembersScreen(organizationId: orgId)),
    );
  }

  void _openOrgProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OfficerOrgProfileScreen(orgId: orgId),
      ),
    );
  }

  void _openCommunity(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrgCommunityChatScreen(
          orgId: orgId,
          orgName: orgName,
          showBackButton: true,
        ),
      ),
    );
  }

  void _openJoinedOrganizations(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _OfficerJoinedOrganizationsScreen(
          currentOrgId: orgId,
          currentOrgName: orgName,
        ),
      ),
    );
  }

  void _openBrowseOrganizations(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OrgListScreen(showBackButton: true)),
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

  Widget _organizationHero() {
    final org = AppState.instance.organizations.cast<Organization?>().firstWhere(
      (item) => item?.id == orgId,
      orElse: () => null,
    );
    final logo = org?.logoAsset.trim() ?? '';

    Widget logoWidget() {
      if (logo.isEmpty) {
        return const Icon(Icons.apartment_rounded, color: _green, size: 31);
      }
      if (logo.startsWith('http://') || logo.startsWith('https://')) {
        return Image.network(
          logo,
          width: 58,
          height: 58,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.apartment_rounded,
            color: _green,
            size: 31,
          ),
        );
      }
      return Image.asset(
        logo,
        width: 58,
        height: 58,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.apartment_rounded,
          color: _green,
          size: 31,
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF064E3B), Color(0xFF128058), Color(0xFF22C55E)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Stack(
        children: [
          Positioned(right: -45, top: -70, child: _orb(170)),
          Positioned(right: 45, bottom: -70, child: _orb(125)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 68,
                height: 68,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .20),
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  padding: const EdgeInsets.all(3),
                  child: CircleAvatar(
                    backgroundColor: const Color(0xFFE0F5E8),
                    child: ClipOval(child: logoWidget()),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Organization',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 29,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      orgName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .86),
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFF86EFAC),
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox(width: 9, height: 9),
                        ),
                        SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            'OFFICER ORGANIZATION HUB',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bg,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 30),
          physics: const BouncingScrollPhysics(),
          children: [
            _organizationHero(),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _feature(
                    icon: Icons.assignment_rounded,
                    title: 'Applications',
                    subtitle: 'Review and manage applications for your organization.',
                    onTap: () => _openApplications(context),
                  ),
                  const SizedBox(height: 10),
                  _feature(
                    icon: Icons.groups_rounded,
                    title: 'Members',
                    subtitle: 'Review organization membership and activity.',
                    onTap: () => _openMembers(context),
                  ),
                  const SizedBox(height: 10),
                  _feature(
                    icon: Icons.badge_rounded,
                    title: 'Organization profile',
                    subtitle: 'Edit the public organization information, officers, and highlights.',
                    onTap: () => _openOrgProfile(context),
                  ),
                  const SizedBox(height: 10),
                  _feature(
                    icon: Icons.forum_rounded,
                    title: 'Community Chat',
                    subtitle: 'Open the organization conversation with members and officers.',
                    onTap: () => _openCommunity(context),
                  ),
                  const SizedBox(height: 10),
                  _feature(
                    icon: Icons.groups_rounded,
                    title: 'Orgs Joined',
                    subtitle: 'See every organization you belong to, including your position in each one.',
                    onTap: () => _openJoinedOrganizations(context),
                  ),
                  const SizedBox(height: 10),
                  _feature(
                    icon: Icons.explore_rounded,
                    title: 'Browse Organizations',
                    subtitle: 'Explore other organizations and apply to ones you want to join.',
                    onTap: () => _openBrowseOrganizations(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feature({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F8F62), Color(0xFF20B77D)],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: .18),
            ),
            boxShadow: [
              BoxShadow(
                color: green.withValues(alpha: .13),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .82),
                        fontSize: 11.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }
}





class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected
                    ? const Color(0xFF0F8A61)
                    : const Color(0xFF718078),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? const Color(0xFF0F8A61)
                      : const Color(0xFF718078),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfficerJoinedOrganizationsScreen extends StatefulWidget {
  final String currentOrgId;
  final String currentOrgName;

  const _OfficerJoinedOrganizationsScreen({
    required this.currentOrgId,
    required this.currentOrgName,
  });

  @override
  State<_OfficerJoinedOrganizationsScreen> createState() =>
      _OfficerJoinedOrganizationsScreenState();
}

class _OfficerJoinedOrganizationsScreenState
    extends State<_OfficerJoinedOrganizationsScreen> {
  bool _loading = true;
  final Set<String> _joinedOrgIds = <String>{};
  final Set<String> _joinedOrgNames = <String>{};

  @override
  void initState() {
    super.initState();
    _loadJoinedOrganizations();
  }

  Future<void> _loadJoinedOrganizations() async {
    final ids = <String>{};
    final names = <String>{};

    // The organization that opened this Officer account is always a real
    // membership. Keep it in Orgs Joined even if the membership query is
    // temporarily delayed or an older row has incomplete profile_id data.
    if (widget.currentOrgId.trim().isNotEmpty) {
      ids.add(widget.currentOrgId.trim());
    }
    if (widget.currentOrgName.trim().isNotEmpty) {
      names.add(widget.currentOrgName.trim().toLowerCase());
    }

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null && userId.isNotEmpty) {
        final rows = await Supabase.instance.client
            .from('members')
            .select('org_id, organization_id, org_name, position')
            .eq('profile_id', userId);

        for (final raw in (rows as List)) {
          final row = Map<String, dynamic>.from(raw as Map);
          final id =
              (row['org_id'] ?? row['organization_id'])?.toString().trim();
          final name = row['org_name']?.toString().trim() ?? '';
          if (id != null && id.isNotEmpty) ids.add(id);
          if (name.isNotEmpty) names.add(name.toLowerCase());
        }
      }
    } catch (e) {
      debugPrint('Error loading Officer Orgs Joined: $e');
    }

    // Resolve legacy rows that have the organization name but no org_id.
    for (final org in AppState.instance.organizations) {
      if (names.contains(org.name.trim().toLowerCase())) {
        ids.add(org.id);
      }
    }

    if (!mounted) return;
    setState(() {
      _joinedOrgIds
        ..clear()
        ..addAll(ids);
      _joinedOrgNames
        ..clear()
        ..addAll(names);
      _loading = false;
    });
  }

  Future<String> _fetchPosition(String orgId) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return 'Member';
      final rows = await Supabase.instance.client
          .from('members')
          .select('position')
          .eq('profile_id', userId)
          .eq('org_id', orgId)
          .limit(1);
      if ((rows as List).isNotEmpty) {
        final p = rows.first['position']?.toString().trim();
        if (p != null && p.isNotEmpty) return p;
      }
    } catch (_) {}
    return orgId == widget.currentOrgId ? 'Officer' : 'Member';
  }

  void _openCommunity(BuildContext context, Organization org) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrgCommunityChatScreen(
          orgId: org.id,
          orgName: org.name,
          showBackButton: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final joined = AppState.instance.organizations
            .where((org) =>
                _joinedOrgIds.contains(org.id) ||
                _joinedOrgNames.contains(org.name.trim().toLowerCase()))
            .toList();

        // Make absolutely sure the organization that owns this Officer
        // account is visible even when the organization cache is still loading.
        if (widget.currentOrgId.isNotEmpty &&
            !joined.any((org) => org.id == widget.currentOrgId)) {
          final current = AppState.instance.organizations.cast<Organization?>()
              .firstWhere(
                (org) => org?.id == widget.currentOrgId,
                orElse: () => null,
              );
          if (current != null) joined.insert(0, current);
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF1FAF6),
          body: Column(
            children: [
              const _OfficerJoinedHeader(),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF0F8A61),
                        ),
                      )
                    : joined.isEmpty
                        ? ListView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
                            children: const [
                              SizedBox(height: 80),
                              Icon(Icons.groups_outlined,
                                  size: 56, color: Color(0xFF6B8178)),
                              SizedBox(height: 12),
                              Center(
                                child: Text(
                                  'No organizations joined yet',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF173B30),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            padding:
                                const EdgeInsets.fromLTRB(18, 18, 18, 36),
                            itemCount: joined.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) {
                              final org = joined[i];
                              final isCurrent =
                                  org.id == widget.currentOrgId;
                              return _OfficerJoinedOrgCard(
                                org: org,
                                isCurrentOrganization: isCurrent,
                                onCommunity: isCurrent
                                    ? null
                                    : () => _openCommunity(context, org),
                                fetchPosition: _fetchPosition,
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OfficerJoinedHeader extends StatelessWidget {
  const _OfficerJoinedHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      width: double.infinity,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F766E), Color(0xFF16A34A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -35,
              top: -45,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .08),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(64, 12, 20, 0),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .16),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .28),
                        ),
                      ),
                      child: const Icon(
                        Icons.groups_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Organizations Joined',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Your organization communities',
                            style: TextStyle(
                              color: Color(0xD1FFFFFF),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 8,
              top: MediaQuery.of(context).padding.top + 4,
              child: IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfficerJoinedOrgCard extends StatefulWidget {
  final Organization org;
  final bool isCurrentOrganization;
  final VoidCallback? onCommunity;
  final Future<String> Function(String orgId) fetchPosition;

  const _OfficerJoinedOrgCard({
    required this.org,
    required this.isCurrentOrganization,
    required this.onCommunity,
    required this.fetchPosition,
  });

  @override
  State<_OfficerJoinedOrgCard> createState() => _OfficerJoinedOrgCardState();
}

class _OfficerJoinedOrgCardState extends State<_OfficerJoinedOrgCard> {
  String _position = 'Member';


  @override
  void initState() {
    super.initState();
    _loadPosition();
  }

  Future<void> _loadPosition() async {
    final position = await widget.fetchPosition(widget.org.id);
    if (!mounted) return;
    setState(() => _position = position);
  }

  @override
  Widget build(BuildContext context) {
    final updates = AppState.instance.notifications
        .where((n) =>
            n.orgId == widget.org.id &&
            !n.read &&
            !_isWorkflowOrganizationNotification(n) &&
            !_isStudentPersonalNotification(n))
        .length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: widget.isCurrentOrganization
              ? const Color(0xFF9BD7BA)
              : const Color(0xFFCBE8DC),
          width: widget.isCurrentOrganization ? 1.4 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x090F8A61),
            blurRadius: 15,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                _OfficerOrgLogo(asset: widget.org.logoAsset, size: 62),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.org.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF173B30),
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (widget.isCurrentOrganization)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2F6EA),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'CURRENT',
                                style: TextStyle(
                                  color: Color(0xFF0F8A61),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.isCurrentOrganization
                            ? '${_position == 'Member' ? 'Officer' : _position} • Your officer organization'
                            : (_position == 'Member'
                                ? (widget.org.shortDesc.isEmpty
                                    ? 'Your member community'
                                    : widget.org.shortDesc)
                                : _position),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF6B8178),
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          const Icon(
                            Icons.campaign_rounded,
                            size: 14,
                            color: Color(0xFF0F8A61),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            updates == 0
                                ? 'No new updates'
                                : '$updates new update${updates == 1 ? '' : 's'}',
                            style: const TextStyle(
                              color: Color(0xFF0F8A61),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _OfficerOrgLogo extends StatelessWidget {
  final String asset;
  final double size;

  const _OfficerOrgLogo({
    required this.asset,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    if (asset.trim().isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFE7F5EE),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(
          Icons.groups_rounded,
          color: Color(0xFF0F8A61),
          size: 30,
        ),
      );
    }
    if (asset.startsWith('http://') || asset.startsWith('https://')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.network(
          asset,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F5EE),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: Color(0xFF0F8A61),
              size: 30,
            ),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFFE7F5EE),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.groups_rounded,
            color: Color(0xFF0F8A61),
            size: 30,
          ),
        ),
      ),
    );
  }
}

bool _isStudentPersonalNotification(app_models.Notification n) {
  final title = n.title.trim().toLowerCase();
  final message = n.message.trim().toLowerCase();
  return title.contains('interview scheduled') ||
      title == 'application update' ||
      title.contains('congratulations') ||
      message.contains('your interview') ||
      message.contains('your application') ||
      message.contains('officially a member');
}

bool _isWorkflowOrganizationNotification(app_models.Notification n) {
  final title = n.title.trim().toLowerCase();
  final message = n.message.trim().toLowerCase();
  const workflowWords = [
    'proposal approved',
    'proposal forwarded',
    'proposal revision',
    'proposal sent back',
    'admin / cso',
    'final posting',
    'creative submitted',
    'revision requested',
    'forwarded to admin',
    'approved and published',
    'has been approved and published',
    'final pictures',
  ];
  return workflowWords.any(
        (word) => title.contains(word) || message.contains(word),
      ) ||
      title == 'new event';
}
