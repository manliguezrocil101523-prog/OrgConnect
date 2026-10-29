import 'package:flutter/material.dart';

class AdminUpcomingEventsScreen extends StatefulWidget {
  const AdminUpcomingEventsScreen({
    super.key,
    required this.events,
    this.initialFilter = 'all',
  });

  final List<Map<String, dynamic>> events;
  final String initialFilter;

  @override
  State<AdminUpcomingEventsScreen> createState() =>
      _AdminUpcomingEventsScreenState();
}

class _AdminUpcomingEventsScreenState extends State<AdminUpcomingEventsScreen> {
  // Design tokens
  static const green = Color(0xFF059669);
  static const accent = Color(0xFF10B981);
  static const dark = Color(0xFF111827);
  static const muted = Color(0xFF6B7280);
  static const bg = Color(0xFFF9FAFB);
  static const line = Color(0xFFE5E7EB);
  static const emeraldSoft = Color(0xFFECFDF5);
  static const emeraldBorder = Color(0xFFA7F3D0);
  static const emeraldDeep = Color(0xFF047857);

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  late String _filter;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _selectedOrg = 'All organizations';
  String _sortOrder = 'nearest';
  bool _showBackToTop = false;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    final show = offset > 300;
    if (show != _showBackToTop) {
      setState(() => _showBackToTop = show);
    }
  }

  String _formatDate(DateTime d) =>
      '${_months[d.month - 1]} ${d.day}, ${d.year}';

  String? _eventTime(Map<String, dynamic> e, DateTime? date) {
    final raw = (e['time'] ?? e['start_time'] ?? '').toString().trim();
    if (raw.isNotEmpty) return raw;
    if (date != null && (date.hour != 0 || date.minute != 0)) {
      final h = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final m = date.minute.toString().padLeft(2, '0');
      return '$h:$m ${date.hour >= 12 ? 'PM' : 'AM'}';
    }
    return null;
  }

  bool _isHttpUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        uri.hasAuthority &&
        (uri.scheme == 'http' || uri.scheme == 'https');
  }

  List<String> get _availableOrgs {
    final set = <String>{};
    for (final e in widget.events) {
      final org = (e['org_name'] ?? '').toString().trim();
      if (org.isNotEmpty) {
        set.add(org);
      }
    }
    final list = set.toList();
    list.sort();
    return list;
  }

  List<Map<String, dynamic>> get _filteredEvents {
    final query = _searchController.text.trim().toLowerCase();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekEnd =
        DateTime(today.year, today.month, today.day + (7 - today.weekday));

    final filtered = widget.events.where((e) {
      if (query.isNotEmpty) {
        final title = (e['title'] ?? '').toString().toLowerCase();
        final orgName = (e['org_name'] ?? '').toString().toLowerCase();
        final place =
            (e['location'] ?? e['venue'] ?? '').toString().toLowerCase();
        if (!title.contains(query) &&
            !orgName.contains(query) &&
            !place.contains(query)) {
          return false;
        }
      }

      if (_selectedOrg != 'All organizations') {
        final orgName = (e['org_name'] ?? '').toString().trim();
        final targetOrg = orgName.isEmpty ? 'Organization' : orgName;
        if (targetOrg != _selectedOrg) {
          return false;
        }
      }

      final dateStr = e['date']?.toString();
      final date = DateTime.tryParse(dateStr ?? '');
      if (date == null) {
        if (_filter != 'all') return false;
      } else {
        final eventDay = DateTime(date.year, date.month, date.day);
        if (_filter == 'today') {
          if (eventDay != today) return false;
        } else if (_filter == 'week') {
          if (eventDay.isBefore(today) || eventDay.isAfter(weekEnd)) {
            return false;
          }
        } else if (_filter == 'month') {
          if (eventDay.year != today.year || eventDay.month != today.month) {
            return false;
          }
        }
      }

      return true;
    }).toList();

    filtered.sort((a, b) {
      final dateA = DateTime.tryParse(a['date']?.toString() ?? '');
      final dateB = DateTime.tryParse(b['date']?.toString() ?? '');

      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;

      if (_sortOrder == 'latest') {
        return dateB.compareTo(dateA);
      } else {
        return dateA.compareTo(dateB);
      }
    });

    return filtered;
  }

  bool get _isFilterActive {
    return _searchController.text.trim().isNotEmpty ||
        _filter != 'all' ||
        _selectedOrg != 'All organizations' ||
        _sortOrder != 'nearest';
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _filter = 'all';
      _selectedOrg = 'All organizations';
      _sortOrder = 'nearest';
    });
  }

  Widget _card({
    required Widget child,
    VoidCallback? onTap,
    EdgeInsets padding = const EdgeInsets.all(16),
    double radius = 16,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }

  Widget _eventCard(Map<String, dynamic> e) {
    final imgs =
        (e['image_urls'] is List ? e['image_urls'] as List : const <dynamic>[])
            .whereType<String>()
            .toList();
    final single = e['image_url']?.toString();
    if (single != null && single.isNotEmpty && !imgs.contains(single)) {
      imgs.insert(0, single);
    }
    final imageUrl = imgs.firstWhere(_isHttpUrl, orElse: () => '');
    final date = DateTime.tryParse(e['date']?.toString() ?? '');
    final dateText = date == null ? 'Date to be announced' : _formatDate(date);
    final timeText = _eventTime(e, date);
    final place = (e['location'] ?? e['venue'] ?? '').toString().trim();
    final description = (e['description'] ?? '').toString().trim();
    final rawOrg = (e['org_name'] ?? '').toString().trim();
    final orgName = rawOrg.isEmpty ? 'Organization' : rawOrg;
    final rawTitle = (e['title'] ?? '').toString().trim();
    final title = rawTitle.isEmpty ? 'Untitled event' : rawTitle;

    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= 440;
      final thumbW = wide ? 104.0 : 88.0;
      final thumbH = wide ? 112.0 : 96.0;
      return _card(
        padding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: thumbH),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _eventThumb(imageUrl, thumbW, thumbH),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _orgBadge(orgName),
                    const SizedBox(height: 6),
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: dark,
                            height: 1.25)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 12, runSpacing: 4, children: [
                      _meta(Icons.calendar_month_rounded, dateText),
                      if (timeText != null)
                        _meta(Icons.schedule_rounded, timeText),
                    ]),
                    if (place.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _meta(Icons.location_on_outlined, place),
                    ],
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: muted, height: 1.4, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _eventThumb(String url, double width, double height) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: width,
          height: height,
          child: url.isEmpty
              ? _eventPlaceholder()
              : Image.network(
                  url.trim(),
                  fit: BoxFit.cover,
                  cacheWidth: 320,
                  errorBuilder: (_, __, ___) => _eventPlaceholder(),
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : _eventPlaceholder(),
                ),
        ),
      );

  Widget _eventPlaceholder() => Container(
        color: emeraldSoft,
        alignment: Alignment.center,
        child: const Icon(Icons.event_rounded, color: green, size: 28),
      );

  Widget _meta(IconData icon, String text) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: green),
        const SizedBox(width: 5),
        Flexible(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: muted, fontSize: 12.5, fontWeight: FontWeight.w500)),
        ),
      ]);

  Widget _orgBadge(String text) => Row(children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: emeraldSoft,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: emeraldBorder),
            ),
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: emeraldDeep,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ]);

  Widget _buildFixedHeader(BuildContext context) {
    final totalEvents = widget.events.length;
    final subtitle = totalEvents == 0
        ? 'No events'
        : totalEvents == 1
            ? '1 event'
            : '$totalEvents events';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: line)),
      ),
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  color: dark,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(40, 40),
                    side: const BorderSide(color: line),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Upcoming Events',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: dark,
                          letterSpacing: -.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context, double maxWidth) {
    final isWide = maxWidth >= 700;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search events by title, organization, or venue...',
            hintStyle: const TextStyle(color: muted, fontSize: 13.5),
            prefixIcon:
                const Icon(Icons.search_rounded, color: muted, size: 20),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon:
                        const Icon(Icons.clear_rounded, size: 18, color: muted),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: green, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildChip('all', 'All'),
              const SizedBox(width: 8),
              _buildChip('today', 'Today'),
              const SizedBox(width: 8),
              _buildChip('week', 'This Week'),
              const SizedBox(width: 8),
              _buildChip('month', 'This Month'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (isWide)
          Row(
            children: [
              Expanded(child: _buildOrgDropdownButton(context)),
              const SizedBox(width: 12),
              _buildSortButton(context),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildOrgDropdownButton(context),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: _buildSortButton(context),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildChip(String key, String label) {
    final selected = _filter == key;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 36),
      child: Material(
        color: selected ? emeraldSoft : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () => setState(() => _filter = key),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? emeraldBorder : line,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? emeraldDeep : muted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrgDropdownButton(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _openOrgFilterPicker(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: line),
          ),
          child: Row(
            children: [
              const Icon(Icons.apartment_rounded, size: 18, color: green),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _selectedOrg,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: dark,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_drop_down_rounded, color: muted, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortButton(BuildContext context) {
    final sortLabel =
        _sortOrder == 'nearest' ? 'Nearest first' : 'Latest first';
    return PopupMenuButton<String>(
      initialValue: _sortOrder,
      onSelected: (val) => setState(() => _sortOrder = val),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'nearest',
          child: Text('Nearest first',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        const PopupMenuItem(
          value: 'latest',
          child: Text('Latest first',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort_rounded, size: 18, color: green),
            const SizedBox(width: 8),
            Text(
              sortLabel,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: dark,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down_rounded, color: muted, size: 20),
          ],
        ),
      ),
    );
  }

  void _openOrgFilterPicker(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 700) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => _OrgFilterPickerContent(
          allOrgs: _availableOrgs,
          selectedOrg: _selectedOrg,
          onSelected: (org) {
            setState(() => _selectedOrg = org);
            Navigator.pop(ctx);
          },
        ),
      );
    } else {
      showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460, maxHeight: 500),
            child: _OrgFilterPickerContent(
              allOrgs: _availableOrgs,
              selectedOrg: _selectedOrg,
              onSelected: (org) {
                setState(() => _selectedOrg = org);
                Navigator.pop(ctx);
              },
            ),
          ),
        ),
      );
    }
  }

  Widget _buildResultLine(int shownCount, int totalCount) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Showing $shownCount of $totalCount events',
            style: const TextStyle(fontSize: 12.5, color: muted),
          ),
        ),
        if (_isFilterActive)
          TextButton(
            onPressed: _clearFilters,
            style: TextButton.styleFrom(
              foregroundColor: green,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Clear filters',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    if (widget.events.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: emeraldSoft,
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.event_busy_rounded, color: green, size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'No upcoming events posted yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: dark,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: emeraldSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_busy_rounded, color: green, size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            'No events found',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: dark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try a different search or clear the filters.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _clearFilters,
            style: FilledButton.styleFrom(
              backgroundColor: emeraldSoft,
              foregroundColor: emeraldDeep,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: emeraldBorder),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Clear filters',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsGrid(List<Map<String, dynamic>> eventsList) {
    if (eventsList.isEmpty) {
      return _buildEmptyState();
    }

    const gap = 12.0;
    return LayoutBuilder(builder: (context, box) {
      final maxWidth = box.maxWidth;
      final cols = ((maxWidth + gap) / (380 + gap)).floor().clamp(1, 3);
      final tileWidth = (maxWidth - gap * (cols - 1)) / cols;

      final cardWidgets = eventsList.map((e) => _eventCard(e)).toList();

      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final card in cardWidgets)
            SizedBox(
              width: tileWidth,
              child: card,
            ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final hPad = width < 600 ? 16.0 : (width <= 1024 ? 24.0 : 32.0);
    final filtered = _filteredEvents;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFixedHeader(context),
            Expanded(
              child: ListView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 116),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildControls(context, width),
                          const SizedBox(height: 16),
                          _buildResultLine(
                              filtered.length, widget.events.length),
                          const SizedBox(height: 16),
                          _buildEventsGrid(filtered),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: AnimatedOpacity(
        opacity: _showBackToTop ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: AnimatedScale(
          scale: _showBackToTop ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: !_showBackToTop,
            child: Tooltip(
              message: 'Back to top',
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 3,
                shadowColor: Colors.black.withValues(alpha: .2),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: Icon(
                        Icons.arrow_circle_up_rounded,
                        color: green,
                        size: 44,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrgFilterPickerContent extends StatefulWidget {
  const _OrgFilterPickerContent({
    required this.allOrgs,
    required this.selectedOrg,
    required this.onSelected,
  });

  final List<String> allOrgs;
  final String selectedOrg;
  final ValueChanged<String> onSelected;

  @override
  State<_OrgFilterPickerContent> createState() =>
      _OrgFilterPickerContentState();
}

class _OrgFilterPickerContentState extends State<_OrgFilterPickerContent> {
  final TextEditingController _pickerSearchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _pickerSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredOrgs = widget.allOrgs
        .where((o) => o.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Filter by Organization',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pickerSearchController,
            onChanged: (val) => setState(() => _query = val),
            decoration: InputDecoration(
              hintText: 'Search organizations...',
              hintStyle:
                  const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: Color(0xFF6B7280), size: 18),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: Color(0xFF059669), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  title: const Text(
                    'All organizations',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  trailing: widget.selectedOrg == 'All organizations'
                      ? const Icon(Icons.check_rounded,
                          color: Color(0xFF059669))
                      : null,
                  onTap: () => widget.onSelected('All organizations'),
                ),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                for (final org in filteredOrgs) ...[
                  ListTile(
                    title: Text(
                      org,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF111827),
                      ),
                    ),
                    trailing: widget.selectedOrg == org
                        ? const Icon(Icons.check_rounded,
                            color: Color(0xFF059669))
                        : null,
                    onTap: () => widget.onSelected(org),
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
