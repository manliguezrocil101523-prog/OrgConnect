import 'package:flutter/material.dart'; // Import Flutter's material design library to access UI components like Scaffold, AppBar, and ListView for building the notification interface

class NotificationScreen extends StatefulWidget { // Define NotificationScreen as a StatefulWidget to handle dynamic updates like marking notifications as read in the app's notification system
  const NotificationScreen({Key? key}) : super(key: key); // Constructor for NotificationScreen widget, accepting an optional key for widget identification

  @override
  State<NotificationScreen> createState() => _NotificationScreenState(); // Override createState to return an instance of _NotificationScreenState, managing the screen's state
}

class _NotificationScreenState extends State<NotificationScreen> { // Define the private state class _NotificationScreenState that extends State, handling UI updates and notification data
  static const Color mintBg = Color(0xFFEAF6F0); // Define a constant mint background color for the screen's theme, providing a calm visual base
  static const Color tealHeader = Color(0xFF79CFC4); // Define a constant teal color for headers and accents, matching the app's color scheme

  List<Map<String, dynamic>> _notifications = []; // Initialize an empty list to store notification data as maps, holding details like title, message, and read status

  @override
  void initState() { // Override initState to perform setup when the widget is created, such as loading initial notification data
    super.initState(); // Call the parent's initState to ensure proper initialization
    _loadNotifications(); // Call the method to load demo notifications into the list
  }

  void _loadNotifications() { // Define a method to load notification data, currently using demo data for testing the notification display feature
    // For now, use demo notifications. In real app, load from Supabase
    setState(() { // Call setState to update the UI after loading notifications
      _notifications = [ // Assign a list of demo notification maps to _notifications
        { // First notification map for an application approval
          'id': '1', // Unique identifier for the notification
          'title': 'Application Approved', // Title of the notification, indicating approval status
          'message': // Detailed message explaining the approval
              'Your application to BCC Computer Science Society has been approved!',
          'timestamp': DateTime.now().subtract(const Duration(hours: 2)), // Timestamp set to 2 hours ago for demo purposes
          'type': 'approval', // Type of notification, used to determine icon and behavior
          'read': false, // Boolean indicating if the notification has been read by the user
        },
        { // Second notification map for an interview schedule
          'id': '2', // Unique identifier for this notification
          'title': 'Interview Scheduled', // Title indicating an interview has been set
          'message': // Message with interview details
              'Interview scheduled for tomorrow at 2:00 PM with BCC Computer Science Society.',
          'timestamp': DateTime.now().subtract(const Duration(hours: 1)), // Timestamp set to 1 hour ago
          'type': 'interview', // Type for interview notifications
          'read': false, // Initially unread
        },
      ];
    });
  }

  void _markAsRead(String id) { // Define a method to mark a specific notification as read by its ID, updating the UI to reflect the change
    setState(() { // Call setState to trigger a UI rebuild after updating the notification
      final index = _notifications.indexWhere((n) => n['id'] == id); // Find the index of the notification with the matching ID
      if (index != -1) { // If the notification is found
        _notifications[index]['read'] = true; // Set the 'read' flag to true
      }
    });
  }

  @override
  Widget build(BuildContext context) { // Override the build method to construct the UI for the NotificationScreen
    return Scaffold( // Return a Scaffold widget as the root layout, providing app bar and body structure
      backgroundColor: mintBg, // Set the background color to the mint theme color
      appBar: AppBar( // Define the app bar at the top of the screen
        backgroundColor: tealHeader, // Set the app bar background to teal
        elevation: 0, // Remove shadow for a flat look
        title: const Text( // Set the title text in the app bar
          'Notifications', // Display 'Notifications' as the screen title
          style: TextStyle( // Style the title text
            fontWeight: FontWeight.w700, // Bold font weight
            letterSpacing: 1.0, // Slight letter spacing for emphasis
          ),
        ),
        centerTitle: true, // Center the title in the app bar
        leading: IconButton( // Add a leading icon button for navigation
          icon: const Icon(Icons.arrow_back), // Use a back arrow icon
          onPressed: () => Navigator.pop(context), // Define onPressed to pop the current route, going back
        ),
      ),
      body: _notifications.isEmpty // Check if the notifications list is empty
          ? const Center( // If empty, display a centered message
              child: Text( // Use a Text widget for the empty state message
                'No notifications yet', // Message to show when no notifications are available
                style: TextStyle(fontSize: 16, color: Colors.grey), // Style with grey color and medium size
              ),
            )
          : ListView.builder( // If not empty, build a scrollable list of notifications
              padding: const EdgeInsets.all(16), // Add padding around the list
              itemCount: _notifications.length, // Set the number of items to the length of notifications
              itemBuilder: (context, index) { // Define how to build each list item
                final notification = _notifications[index]; // Get the notification map at the current index
                return Card( // Return a Card widget for each notification item
                  margin: const EdgeInsets.only(bottom: 12), // Add bottom margin for spacing
                  shape: RoundedRectangleBorder( // Shape the card with rounded corners
                    borderRadius: BorderRadius.circular(12), // 12-pixel radius
                  ),
                  elevation: 2, // Add slight elevation for depth
                  child: ListTile( // Use ListTile for structured content in the card
                    leading: CircleAvatar( // Add a leading avatar for visual indicator
                      backgroundColor: // Set background color based on read status
                          notification['read'] ? Colors.grey : tealHeader, // Grey if read, teal if unread
                      child: Icon( // Display an icon in the avatar
                        notification['type'] == 'interview' // Choose icon based on notification type
                            ? Icons.calendar_today // Calendar icon for interviews
                            : Icons.check_circle, // Check circle for approvals
                        color: Colors.white, // White icon color
                      ),
                    ),
                    title: Text( // Display the notification title
                      notification['title'], // The title text from the notification
                      style: TextStyle( // Style the title
                        fontWeight: notification['read'] // Bold if unread, normal if read
                            ? FontWeight.normal
                            : FontWeight.bold,
                      ),
                    ),
                    subtitle: Column( // Use a Column for multiple subtitle elements
                      crossAxisAlignment: CrossAxisAlignment.start, // Align to the start
                      children: [ // List of children in the column
                        Text(notification['message']), // Display the notification message
                        const SizedBox(height: 4), // Add small vertical space
                        Text( // Display the formatted timestamp
                          _formatTimestamp(notification['timestamp']), // Call method to format the timestamp
                          style: // Style the timestamp text
                              const TextStyle(fontSize: 12, color: Colors.grey), // Small grey text
                        ),
                      ],
                    ),
                    trailing: notification['read'] // Add trailing indicator if unread
                        ? null // No trailing if read
                        : Container( // Small blue dot for unread notifications
                            width: 8, // Width of the dot
                            height: 8, // Height of the dot
                            decoration: const BoxDecoration( // Style the dot
                              color: Colors.blue, // Blue color
                              shape: BoxShape.circle, // Circular shape
                            ),
                          ),
                    onTap: () => _markAsRead(notification['id']), // Define onTap to mark the notification as read
                  ),
                );
              },
            ),
    );
  }

  String _formatTimestamp(DateTime timestamp) { // Define a helper method to format a DateTime into a human-readable relative time string
    final now = DateTime.now(); // Get the current time
    final difference = now.difference(timestamp); // Calculate the time difference

    if (difference.inDays > 0) { // If more than a day ago
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago'; // Return days ago
    } else if (difference.inHours > 0) { // If more than an hour ago
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago'; // Return hours ago
    } else if (difference.inMinutes > 0) { // If more than a minute ago
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago'; // Return minutes ago
    } else { // If less than a minute
      return 'Just now'; // Return 'Just now'
    }
  }
}
