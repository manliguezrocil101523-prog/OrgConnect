import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_state.dart';
import '../analytics/event_comments_sheet.dart';
import '../community/org_community_chat_screen.dart';
import 'officer_applications_screen.dart';
import 'officer_events_screen.dart';
import 'officer_members_screen.dart';
import 'officer_profile_screen.dart';

const Color _primary = Color(0xFF16A34A);
const Color _secondary = Color(0xFF0F766E);
const Color _background = Color(0xFFF0FDF4);
const Color _text = Color(0xFF173B30);
const Color _muted = Color(0xFF6B8178);

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
  List<Map<String, dynamic>> _publishedEvents = <Map<String, dynamic>>[];
  bool _loadingEvents = true;

  @override
  void initState() {
    super.initState();
    _loadPublishedEvents();
  }

  Future<void> _loadPublishedEvents() async {
    try {
      final response = await Supabase.instance.client
          .from('events')
          .select('*')
          .eq('org_id', widget.orgId)
          .order('date', ascending: true);

      final rows = List<Map<String, dynamic>>.from(response as List);
      final filtered = rows.where((event) {
        if (!event.containsKey('status')) return true;
        final status = event['status']?.toString().toLowerCase() ?? '';
        return status.isEmpty ||
            status == 'published' ||
            status == 'approved' ||
            status == 'posted';
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

  void _openApplications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OfficerApplicationsScreen()),
    );
  }

  void _openMembers() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OfficerMembersScreen()),
    );
  }

  void _openEvents() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OfficerEventsScreen(
          orgId: widget.orgId,
          orgName: widget.orgName,
        ),
      ),
    );
  }

  void _openCommunity() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrgCommunityChatScreen(
          orgId: widget.orgId,
          orgName: widget.orgName,
          showBackButton: true,
        ),
      ),
    );
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OfficerProfileScreen()),
    );
  }


  @override
  Widget build(BuildContext context) {
    Organization? organization;
    for (final item in AppState.instance.organizations) {
      if (item.id == widget.orgId) {
        organization = item;
        break;
      }
    }

    return WillPopScope(
      onWillPop: _handleBack,
      child: Scaffold(
        backgroundColor: _background,
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            _HomeTab(
              orgName: widget.orgName,
              logoAsset: organization?.logoAsset ?? '',
              events: _publishedEvents,
              loadingEvents: _loadingEvents,
              onRefresh: _loadPublishedEvents,
            ),
            const SizedBox.shrink(),
            const SizedBox.shrink(),
            const SizedBox.shrink(),
            const SizedBox.shrink(),
            const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
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
                icon: Icons.assignment_rounded,
                label: 'Applications',
                selected: _selectedIndex == 1,
                onTap: () {
                  setState(() => _selectedIndex = 1);
                  _openApplications();
                },
              ),
              _NavItem(
                icon: Icons.groups_rounded,
                label: 'Members',
                selected: _selectedIndex == 2,
                onTap: () {
                  setState(() => _selectedIndex = 2);
                  _openMembers();
                },
              ),
              _NavItem(
                icon: Icons.event_rounded,
                label: 'Events',
                selected: _selectedIndex == 3,
                onTap: () {
                  setState(() => _selectedIndex = 3);
                  _openEvents();
                },
              ),
              _NavItem(
                icon: Icons.forum_rounded,
                label: 'Community',
                selected: _selectedIndex == 4,
                onTap: () {
                  setState(() => _selectedIndex = 4);
                  _openCommunity();
                },
              ),
              _NavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                selected: _selectedIndex == 5,
                onTap: () {
                  setState(() => _selectedIndex = 5);
                  _openProfile();
                },
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
  final String logoAsset;
  final List<Map<String, dynamic>> events;
  final bool loadingEvents;
  final Future<void> Function() onRefresh;

  const _HomeTab({
    required this.orgName,
    required this.logoAsset,
    required this.events,
    required this.loadingEvents,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // The Officer Portal header stays visible. The scrollbar begins
        // with the welcome content below it, matching the Student layout.
        _HeroHeader(orgName: orgName, logoAsset: logoAsset),
        Expanded(
          child: RefreshIndicator(
            color: _primary,
            onRefresh: onRefresh,
            child: Scrollbar(
              thumbVisibility: true,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                      child: _WelcomeCard(orgName: orgName),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Posted Events',
                            style: TextStyle(
                              color: _text,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (events.isNotEmpty)
                            Text(
                              '${events.length} posted',
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (loadingEvents)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 70),
                        child: Center(
                          child: CircularProgressIndicator(color: _primary),
                        ),
                      ),
                    )
                  else if (events.isEmpty)
                    const SliverToBoxAdapter(child: _EmptyEventsState())
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 32),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _OfficerEventCard(
                            event: events[index],
                          ),
                          childCount: events.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroHeader extends StatelessWidget {
  final String orgName;
  final String logoAsset;

  const _HeroHeader({required this.orgName, required this.logoAsset});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_primary, _secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
          child: Row(
            children: [
              _OrganizationLogo(logoAsset: logoAsset, radius: 31),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Officer Portal',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      orgName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
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
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final String orgName;
  const _WelcomeCard({required this.orgName});

  @override
  Widget build(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD5EEE0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F8A61),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFE5F7ED),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.verified_user_rounded, color: _primary),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome to $orgName',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email.isEmpty
                      ? 'Manage your organization from one place.'
                      : 'Signed in as $email',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfficerEventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  const _OfficerEventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final imageUrl = _eventImage(event);
    final title = event['title']?.toString().trim().isNotEmpty == true
        ? event['title'].toString()
        : 'Organization Event';
    final description = event['description']?.toString() ?? '';
    final eventId = event['id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD5EEE0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F8A61),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 8.5,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _EventImageFallback(),
              ),
            )
          else
            const SizedBox(height: 125, child: _EventImageFallback()),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: _text,
                  ),
                ),
                if (description.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: _muted,
                    ),
                  ),
                ],
                if (eventId.isNotEmpty) ...[
                  const SizedBox(height: 7),
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
                        foregroundColor: _primary,
                        textStyle: const TextStyle(fontWeight: FontWeight.w800),
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
}


class _EmptyEventsState extends StatelessWidget {
  const _EmptyEventsState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 56),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: const Color(0xFFE5F7ED),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.event_available_rounded,
              color: _primary,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No posted events yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Events approved and posted by the adviser will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
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
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? _primary : _muted,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                  color: selected ? _primary : _muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrganizationLogo extends StatelessWidget {
  final String logoAsset;
  final double radius;

  const _OrganizationLogo({
    required this.logoAsset,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final value = logoAsset.trim();
    Widget image;

    if (value.isEmpty) {
      image = Icon(
        Icons.groups_rounded,
        size: radius,
        color: _primary,
      );
    } else if (value.startsWith('http://') || value.startsWith('https://')) {
      image = Image.network(
        value,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(
          Icons.groups_rounded,
          size: radius,
          color: _primary,
        ),
      );
    } else {
      image = Image.asset(
        value,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(
          Icons.groups_rounded,
          size: radius,
          color: _primary,
        ),
      );
    }

    return Container(
      width: radius * 2,
      height: radius * 2,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ClipOval(child: image),
    );
  }
}

class _EventImageFallback extends StatelessWidget {
  const _EventImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE5F7ED),
      alignment: Alignment.center,
      child: const Icon(
        Icons.event_available_rounded,
        color: _primary,
        size: 44,
      ),
    );
  }
}
