import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({Key? key}) : super(key: key);

  static const Color mintBg = Color(0xFFEAF6F0);
  static const Color tealHeader = Color(0xFF79CFC4);

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  late Map<DateTime, List<Event>> _events;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = _focusedDay;
    _loadEvents();
  }

  void _loadEvents() {
    final events = AppState.instance.eventsForCurrentStudent();
    _events = {};
    for (var event in events) {
      final day = DateTime(event.date.year, event.date.month, event.date.day);
      _events[day] = (_events[day] ?? [])..add(event);
    }
  }

  void _showEventsForDay(DateTime day) {
    final events = _events[day] ?? [];
    if (events.isEmpty) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Events on ${DateFormat('yyyy-MM-dd').format(day)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...events.map((event) => ListTile(
              title: Text(event.title),
              subtitle: Text(event.description),
              trailing: Text(_formatTime(event.date)),
            )),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _getRelativeDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(date.year, date.month, date.day);
    final difference = eventDay.difference(today).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Tomorrow';
    if (difference == 2) return 'In 2 days';
    if (difference > 2 && difference <= 7) return 'This week';
    if (difference > 7 && difference <= 14) return 'Next week';
    if (difference < 0) return 'Past';
    return DateFormat('MMM d').format(date);
  }

  List<List<Event>> _groupEventsByRelativeDate(List<Event> events) {
    final groups = <String, List<Event>>{};
    for (var event in events) {
      final label = _getRelativeDateLabel(event.date);
      groups[label] = (groups[label] ?? [])..add(event);
    }
    // Sort groups by date
    final sortedKeys = groups.keys.toList()..sort((a, b) {
      if (a == 'Today') return -1;
      if (b == 'Today') return 1;
      if (a == 'Tomorrow') return -1;
      if (b == 'Tomorrow') return 1;
      if (a == 'In 2 days') return -1;
      if (b == 'In 2 days') return 1;
      if (a == 'This week') return -1;
      if (b == 'This week') return 1;
      if (a == 'Next week') return -1;
      if (b == 'Next week') return 1;
      if (a == 'Past') return 1; // Past at end
      return a.compareTo(b);
    });
    return sortedKeys.map((key) => groups[key]!).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StudentDashboard.mintBg,
      appBar: AppBar(
        backgroundColor: StudentDashboard.tealHeader,
        elevation: 0,
        title: const Text(
          'Student Dashboard',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.0),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.groups_outlined),
            onPressed: () => Navigator.pushNamed(context, '/orglist'),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: AppState.instance,
        builder: (context, _) {
          _loadEvents();
          final events = List<Event>.from(AppState.instance.eventsForCurrentStudent())
            ..sort((a, b) => a.date.compareTo(b.date));

          final eventGroups = _groupEventsByRelativeDate(events);

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // Calendar Section
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TableCalendar<Event>(
                  key: ValueKey(_events.values.expand((e) => e).length),
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                    _showEventsForDay(selectedDay);
                  },
                  eventLoader: (day) => _events[day] ?? [],
                  calendarStyle: const CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: Color(0xFF79CFC4),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: Color(0xFF79CFC4),
                      shape: BoxShape.circle,
                    ),
                  ),
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, date, events) {
                      if (events.isNotEmpty) {
                        final count = events.length;
                        return Positioned(
                          right: 1,
                          bottom: 1,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                              count > 3 ? 3 : count, // Max 3 dots
                              (index) => Container(
                                margin: const EdgeInsets.only(left: 2),
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF79CFC4),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                      return null;
                    },
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                ),
              ),

              // Events List
              if (events.isEmpty) ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      'No upcoming activities from your organizations.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ] else ...[
                ...eventGroups.expand((group) {
                  final label = _getRelativeDateLabel(group.first.date);
                  return [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF79CFC4),
                        ),
                      ),
                    ),
                    ...group.map((e) {
                      final dateLbl = DateFormat('MMM d, yyyy').format(e.date);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: StudentDashboard.tealHeader, borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.calendar_today, color: Colors.white),
                          ),
                          title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${e.orgName}\n$dateLbl\n${e.description}'),
                          isThreeLine: true,
                        ),
                      );
                    }),
                  ];
                }),
              ],
            ],
          );
        },
      ),
    );
  }
}
