import 'package:flutter/material.dart' hide Notification;
import '../../../core/app_state.dart';
import 'home_tokens.dart';
import 'home_data.dart';
import 'home_event_utils.dart';
import 'event_details_sheet.dart';

enum _When { all, week, month }

enum _Sort { soonest, newest }

const double _maxW = 1120; // max content width on large screens
const double _bp = 600; // below this: compact list, above: grid

class AllUpcomingEventsPage extends StatefulWidget {
  const AllUpcomingEventsPage({super.key});

  @override
  State<AllUpcomingEventsPage> createState() => _AllUpcomingEventsPageState();
}

class _AllUpcomingEventsPageState extends State<AllUpcomingEventsPage> {
  Map<String, int> _interest = {};
  String _lastLoadedKey = '';
  _Sort _sort = _Sort.soonest;
  _When _when = _When.all;
  String _query = '';
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- data

  Future<void> _fetchInterests(List<String> ids) async {
    if (ids.isEmpty) return;
    _lastLoadedKey = ids.join(',');
    try {
      final counts = await HomeData.fetchEventInterestCounts(ids);
      if (!mounted) return;
      setState(() => _interest = counts);
    } catch (e) {
      debugPrint('Error fetching event interest counts: $e');
    }
  }

  Future<void> _reloadInterest() async {
    _lastLoadedKey = '';
    final ids = HomeData.upcomingEvents().map((e) => e.id).toList()..sort();
    await _fetchInterests(ids);
  }

  Future<void> _refresh() async {
    try {
      await AppState.instance.fetchEvents();
      await _reloadInterest();
    } catch (e) {
      debugPrint('Error refreshing upcoming events: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text("Couldn't refresh events."),
            action: SnackBarAction(label: 'Retry', onPressed: _refresh),
          ),
        );
    }
  }

  List<Event> _visible(List<Event> all) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final terms = _query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    final list = all.where((e) {
      if (terms.isNotEmpty) {
        final hay = '${e.title} ${e.orgName} ${e.venue}'.toLowerCase();
        if (!terms.every((t) => hay.contains(t))) return false;
      }
      final days = DateUtils.dateOnly(e.date).difference(today).inDays;
      return switch (_when) {
        _When.all => true,
        _When.week => days >= 0 && days <= 7,
        _When.month =>
          days >= 0 && e.date.year == now.year && e.date.month == now.month,
      };
    }).toList();
    list.sort((a, b) {
      final c = _sort == _Sort.newest
          ? b.createdAt.compareTo(a.createdAt)
          : a.date.compareTo(b.date);
      return c != 0 ? c : a.title.compareTo(b.title);
    });
    return list;
  }

  void _clearFilters() {
    _search.clear();
    setState(() {
      _query = '';
      _when = _When.all;
    });
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return HomeLayout.capText(
      context,
      AnimatedBuilder(
        animation: AppState.instance,
        builder: (context, _) {
          final all = HomeData.upcomingEvents();
          final ids = all.map((e) => e.id).toList()..sort();
          if (ids.join(',') != _lastLoadedKey) {
            _lastLoadedKey = ids.join(',');
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _fetchInterests(ids));
          }
          final events = _visible(all);

          return Scaffold(
            backgroundColor: HC.bg,
            body: LayoutBuilder(
              builder: (context, box) {
                final w = box.maxWidth;
                final isGrid = w >= _bp;
                final hPad = isGrid ? 24.0 : 16.0;
                final side = w > _maxW + 2 * hPad ? (w - _maxW) / 2 : hPad;
                final bottom = 32 + MediaQuery.paddingOf(context).bottom;

                Widget card(Event e) => _EventCard(
                      event: e,
                      compact: !isGrid,
                      interestedCount: _interest[e.id] ?? 0,
                      onTap: () => showEventDetailsSheet(
                        context,
                        event: e,
                        interestedCount: _interest[e.id] ?? 0,
                        onInterestChanged: _reloadInterest,
                      ),
                    );

                return RefreshIndicator(
                  color: HC.primary,
                  onRefresh: _refresh,
                  child: CustomScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child:
                            _header(context, side, events.length, all.length),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                            height: 56 * _scale(context),
                            child: _filterBar(side)),
                      ),
                      if (events.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _EmptyState(
                            filtered: all.isNotEmpty,
                            onClear: _clearFilters,
                          ),
                        )
                      else
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(side, 8, side, bottom),
                          sliver: isGrid
                              ? SliverGrid.builder(
                                  gridDelegate:
                                      SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 380,
                                    mainAxisExtent: 148 + 150 * _scale(context),
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                  ),
                                  itemCount: events.length,
                                  itemBuilder: (_, i) => card(events[i]),
                                )
                              : SliverList.separated(
                                  itemCount: events.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (_, i) => card(events[i]),
                                ),
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context, double side, int shown, int total) {
    final noun = total == 1 ? 'event' : 'events';
    final subtitle = shown == total ? '$total $noun' : '$shown of $total $noun';

    return Container(
      decoration: const BoxDecoration(
        gradient: HC.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        side,
        MediaQuery.paddingOf(context).top + 8,
        side,
        16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                tooltip: 'Back',
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Upcoming Events',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              autocorrect: false,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                hintText: 'Search events, organizations, venues',
                hintStyle: const TextStyle(color: HC.muted, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: HC.muted),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterBar(double side) {
    Widget chip(String label, _When value) {
      final selected = _when == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => setState(() => _when = value),
          selectedColor: HC.mint,
          backgroundColor: Colors.white,
          side: BorderSide(
            color: selected ? HC.primary.withValues(alpha: 0.45) : HC.line,
          ),
          visualDensity: VisualDensity.compact,
          labelStyle: TextStyle(
            fontSize: 13,
            color: selected ? HC.dark : HC.ink,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: side),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  chip('All', _When.all),
                  chip('Next 7 days', _When.week),
                  chip('This month', _When.month),
                ],
              ),
            ),
          ),
          PopupMenuButton<_Sort>(
            tooltip: 'Sort',
            initialValue: _sort,
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _Sort.soonest, child: Text('Event date')),
              PopupMenuItem(value: _Sort.newest, child: Text('Recently added')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.swap_vert_rounded,
                      size: 18, color: HC.primary),
                  const SizedBox(width: 4),
                  Text(
                    _sort == _Sort.soonest ? 'Date' : 'Recent',
                    style: const TextStyle(
                      color: HC.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
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

// ------------------------------------------------------------- helpers

// ------------------------------------------------------------- helpers

double _scale(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4).toDouble();

/// "Today", "Tomorrow", "In 3 days" for events within a week, else null.
String? _relativeDay(DateTime d) {
  final n = DateTime.now();
  final diff =
      DateUtils.dateOnly(d).difference(DateTime(n.year, n.month, n.day)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff > 1 && diff <= 7) return 'In $diff days';
  return null;
}

String _fmt12(int h, String m) {
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:$m ${h >= 12 ? 'PM' : 'AM'}';
}

String _safeTime(String label) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})\s*[–-]\s*(\d{1,2}):(\d{2})$')
      .firstMatch(label.trim());
  if (m == null) return label;
  final sh = int.parse(m[1]!), eh = int.parse(m[3]!);
  final start = sh * 60 + int.parse(m[2]!);
  final end = eh * 60 + int.parse(m[4]!);
  final from = _fmt12(sh, m[2]!);
  return end > start ? '$from – ${_fmt12(eh, m[4]!)}' : from;
}

// --------------------------------------------------------------- cards

class _EventCard extends StatelessWidget {
  final Event event;
  final int interestedCount;
  final bool compact;
  final VoidCallback onTap;

  const _EventCard({
    required this.event,
    required this.interestedCount,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final url = eventCoverImage(event);
    final rel = _relativeDay(event.date);
    final time = event.timeLabel.isNotEmpty
        ? _safeTime(event.timeLabel)
        : formatDateShort(event.date);

    final cover = Stack(
      fit: StackFit.expand,
      children: [
        url != null ? EventImage(url: url) : eventGradientFallback(),
        Positioned(top: 8, left: 8, child: _DateBadge(date: event.date)),
        if (rel != null) Positioned(bottom: 8, left: 8, child: _Tag(rel)),
      ],
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          event.orgName.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: HC.primary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          event.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: HC.ink,
            fontSize: 15.5,
            fontWeight: FontWeight.bold,
            height: 1.25,
          ),
        ),
        const Spacer(),
        if (event.venue.isNotEmpty) ...[
          _Meta(Icons.location_on_rounded, event.venue),
          const SizedBox(height: 4),
        ],
        Row(
          children: [
            Expanded(child: _Meta(Icons.access_time_rounded, time)),
            if (interestedCount > 0) ...[
              const SizedBox(width: 8),
              _InterestPill(interestedCount, compact: compact),
            ],
          ],
        ),
      ],
    );

    return Semantics(
      button: true,
      excludeSemantics: true,
      onTap: onTap,
      label: '${event.title}, ${event.orgName}, ${formatDateShort(event.date)}',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: HC.line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x100F8A61),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: compact
                  ? SizedBox(
                      height: 132 * _scale(context),
                      child: Row(
                        children: [
                          SizedBox(width: 108, child: cover),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: details,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        SizedBox(
                            height: 148, width: double.infinity, child: cover),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: details,
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
}

class _DateBadge extends StatelessWidget {
  final DateTime date;
  const _DateBadge({required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            monthShortUpper(date.month),
            style: const TextStyle(
              color: HC.primary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            '${date.day}',
            style: const TextStyle(
              color: HC.ink,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: HC.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: HC.muted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: HC.muted, fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}

class _InterestPill extends StatelessWidget {
  final int count;
  final bool compact;
  const _InterestPill(this.count, {this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: HC.mint,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_alt_rounded, size: 13, color: HC.primary),
          const SizedBox(width: 4),
          Text(
            compact ? '$count' : '$count interested',
            maxLines: 1,
            style: const TextStyle(
              color: HC.primary,
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool filtered; // true = events exist but filters hide them all
  final VoidCallback onClear;
  const _EmptyState({required this.filtered, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: HC.mint,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  filtered
                      ? Icons.search_off_rounded
                      : Icons.event_busy_rounded,
                  size: 34,
                  color: HC.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                filtered ? 'No matching events' : 'No upcoming events yet',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: HC.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                filtered
                    ? 'Try a different search or clear your filters.'
                    : 'Events from campus organizations will appear here.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: HC.muted, fontSize: 14),
              ),
              if (filtered) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: onClear,
                  child: const Text('Clear filters'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
