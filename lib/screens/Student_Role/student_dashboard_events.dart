import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: StudentDashboard.mintBg,
      appBar: AppBar(
        backgroundColor: StudentDashboard.tealHeader,
        elevation: 0,
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white, size: 28),
            onPressed: () {
              // Clear role and navigate to role selection
              AppState.instance.setRole(null);
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/role',
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: AppState.instance,
        builder: (context, _) {
          _loadEvents();
          final events = AppState.instance.eventsForCurrentStudent();
          final applications = AppState.instance.applications
              .where((app) =>
                  app.studentId == AppState.instance.currentStudent?.studentId)
              .toList();

              // Keep events for calendar, but do not surface interview-specific
              // notifications in the dashboard's event list. Interview events
              // will still be present in `AppState.events` (and thus on the
              // calendar), but they are filtered out from the list of events
              // shown under "Organization Events" so students will instead
              // receive interview details via the Notifications screen.
              final regularEvents = events
                .where((event) =>
                  !event.title.toLowerCase().contains('interview'))
                .toList();

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.05,
              vertical: 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting Section
                const Text(
                  'Welcome Back!',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Track your events and applications below.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 20),

                // Calendar Section Card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: TableCalendar<Event>(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) =>
                          isSameDay(_selectedDay, day),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                        _showEventsForDay(selectedDay);
                      },
                      eventLoader: (day) => _events[day] ?? [],
                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(
                          color: StudentDashboard.tealHeader
                              .withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: const BoxDecoration(
                          color: StudentDashboard.tealHeader,
                          shape: BoxShape.circle,
                        ),
                        markersAlignment: Alignment.bottomCenter,
                        markerDecoration: const BoxDecoration(
                          color: Colors.teal,
                          shape: BoxShape.circle,
                        ),
                      ),
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Sections with cards
                if (applications.isNotEmpty)
                  _buildSection(
                    title: 'My Applications',
                    children: applications
                        .map((app) => _buildApplicationCard(app))
                        .toList(),
                  ),

                if (regularEvents.isNotEmpty)
                  _buildSection(
                    title: 'Organization Events',
                    children: regularEvents
                        .map((event) => _buildEventCard(event))
                        .toList(),
                  ),

                if (events.isEmpty && applications.isEmpty)
                  Center(
                    child: Column(
                      children: [
                        const Icon(Icons.event_note_outlined,
                            size: 90, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'No events yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection(
      {required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildApplicationCard(Application app) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: const Icon(Icons.assignment, color: Color(0xFF79CFC4)),
        title: Text(app.orgName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Status: ${_getStatusText(app.status)}'),
        trailing: _statusChip(app.status),
      ),
    );
  }

  Widget _statusChip(ApplicationStatus status) {
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case ApplicationStatus.pending:
        bg = Colors.orange.withValues(alpha: 0.1);
        fg = Colors.orange;
        label = 'Pending';
        break;
      case ApplicationStatus.for_approval:
        bg = Colors.orange.withValues(alpha: 0.1);
        fg = Colors.orange;
        label = 'For Approval';
        break;
      case ApplicationStatus.accepted:
        bg = Colors.green.withValues(alpha: 0.1);
        fg = Colors.green;
        label = 'Accepted';
        break;
      case ApplicationStatus.interview_scheduled:
        bg = Colors.orange.withValues(alpha: 0.1);
        fg = Colors.orange;
        label = 'Interview Scheduled';
        break;
      case ApplicationStatus.declined:
        bg = Colors.red.withValues(alpha: 0.1);
        fg = Colors.red;
        label = 'Declined';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child:
          Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildEventCard(Event event) {
    final isUpcoming = event.date.isAfter(DateTime.now());
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(Icons.event,
            color: isUpcoming ? Colors.teal : Colors.grey, size: 30),
        title: Text(event.title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(event.description,
            maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Text(
          _formatDateTime(event.date),
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now).inDays;
    if (difference == 0) return 'Today ${_formatTime(dateTime)}';
    if (difference == 1) return 'Tomorrow ${_formatTime(dateTime)}';
    return '${DateFormat('MMM d, yyyy').format(dateTime)} ${_formatTime(dateTime)}';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12
        ? dateTime.hour - 12
        : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _getStatusText(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.pending:
        return 'Pending Review';
      case ApplicationStatus.for_approval:
        return 'For Approval';
      case ApplicationStatus.accepted:
        return 'Accepted';
      case ApplicationStatus.interview_scheduled:
        return 'Interview Scheduled';
      case ApplicationStatus.declined:
        return 'Declined';
    }
  }
}
