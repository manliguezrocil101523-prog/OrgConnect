import 'package:flutter/material.dart'
    hide Notification; // Import Flutter's material design library to access UI components like Scaffold, AppBar, and ListView for building the notification interface
import '../../core/app_state.dart'; // Import the AppState class to access application data and manage state changes like updating application statuses

class NotificationScreen extends StatefulWidget {
  // Define NotificationScreen as a StatefulWidget to handle dynamic updates like marking notifications as read in the app's notification system
  const NotificationScreen(
      {super.key}); // Constructor for NotificationScreen widget, accepting an optional key for widget identification

  @override
  State<NotificationScreen> createState() =>
      _NotificationScreenState(); // Override createState to return an instance of _NotificationScreenState, managing the screen's state
}

class _NotificationScreenState extends State<NotificationScreen> {
  // Define the private state class _NotificationScreenState that extends State, handling UI updates and notification data
  static const Color mintBg = Color(
      0xFFEAF6F0); // Define a constant mint background color for the screen's theme, providing a calm visual base
  static const Color tealHeader = Color(
      0xFF79CFC4); // Define a constant teal color for headers and accents, matching the app's color scheme

  @override
  void initState() {
    // Override initState to perform setup when the widget is created, such as loading initial notification data
    super
        .initState(); // Call the parent's initState to ensure proper initialization
    // Listen to AppState changes
    AppState.instance.addListener(_onAppStateChanged);
    // Fetch notifications from database
    AppState.instance.fetchNotifications();
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onAppStateChanged);
    super.dispose();
  }

  void _onAppStateChanged() {
    setState(() {});
  }

  void _markAsRead(String id) {
    // Define a method to mark a specific notification as read by its ID, updating the UI to reflect the change
    AppState.instance.markNotificationRead(id);
  }

  @override
  Widget build(BuildContext context) {
    // Override the build method to construct the UI for the NotificationScreen
    final notifications = AppState.instance.notifications
        .where(
            (n) => n.studentId == AppState.instance.currentStudent?.studentId)
        .toList();

    // Separate interview notifications from other notifications
    final interviewNotifications = notifications
        .where((n) => n.title.toLowerCase().contains('interview'))
        .toList();
    final otherNotifications = notifications
        .where((n) => !n.title.toLowerCase().contains('interview'))
        .toList();

    return Scaffold(
      // Return a Scaffold widget as the root layout, providing app bar and body structure
      backgroundColor:
          mintBg, // Set the background color to the mint theme color
      appBar: AppBar(
        // Define the app bar at the top of the screen
        backgroundColor: tealHeader, // Set the app bar background to teal
        elevation: 0, // Remove shadow for a flat look
        title: const Text(
          // Set the title text in the app bar
          'Notifications', // Display 'Notifications' as the screen title
          style: TextStyle(
            // Style the title text
            fontWeight: FontWeight.w700, // Bold font weight
            letterSpacing: 1.0, // Slight letter spacing for emphasis
          ),
        ),
        centerTitle: true, // Center the title in the app bar
        leading: IconButton(
          // Add a leading icon button for navigation
          icon: const Icon(Icons.arrow_back), // Use a back arrow icon
          onPressed: () => Navigator.pop(
              context), // Define onPressed to pop the current route, going back
        ),
      ),
      body: notifications.isEmpty // Check if the notifications list is empty
          ? const Center(
              // If empty, display a centered message
              child: Text(
                // Use a Text widget for the empty state message
                'No notifications yet', // Message to show when no notifications are available
                style: TextStyle(
                    fontSize: 16,
                    color:
                        Colors.grey), // Style with grey color and medium size
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Interview Notifications Section
                  if (interviewNotifications.isNotEmpty) ...[
                    Text(
                      'Interview Notifications',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...interviewNotifications
                        .map((notification) =>
                            _buildInterviewCard(notification))
                        .toList(),
                    const SizedBox(height: 20),
                  ],
                  // Other Notifications Section
                  if (otherNotifications.isNotEmpty) ...[
                    Text(
                      'Other Notifications',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...otherNotifications
                        .map((notification) =>
                            _buildNotificationCard(notification))
                        .toList(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildInterviewCard(Notification notification) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.orange.withValues(alpha: 0.05),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange,
          child: const Icon(
            Icons.schedule,
            color: Colors.white,
          ),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight:
                notification.read ? FontWeight.normal : FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(notification.message),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(notification.date),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: notification.read
            ? null
            : Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
        onTap: () => _markAsRead(notification.id),
      ),
    );
  }

  Widget _buildNotificationCard(Notification notification) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              notification.read ? Colors.grey : tealHeader,
          child: const Icon(
            Icons.calendar_today,
            color: Colors.white,
          ),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight:
                notification.read ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(notification.message),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(notification.date),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: notification.read
            ? null
            : Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
        onTap: () => _markAsRead(notification.id),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    // Define a helper method to format a DateTime into a human-readable relative time string
    final now = DateTime.now(); // Get the current time
    final difference =
        now.difference(timestamp); // Calculate the time difference

    if (difference.inDays > 0) {
      // If more than a day ago
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago'; // Return days ago
    } else if (difference.inHours > 0) {
      // If more than an hour ago
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago'; // Return hours ago
    } else if (difference.inMinutes > 0) {
      // If more than a minute ago
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago'; // Return minutes ago
    } else {
      // If less than a minute
      return 'Just now'; // Return 'Just now'
    }
  }
}
