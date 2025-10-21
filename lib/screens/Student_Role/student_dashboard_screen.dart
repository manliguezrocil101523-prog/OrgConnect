import 'package:flutter/material.dart'; // Import Flutter's material design library for building UI components in the student dashboard screen
// Import the student dashboard events screen for navigation
import '/screens/notifications/notification_screen.dart'; // Import the notification screen for displaying notifications

class StudentDashboardScreen extends StatefulWidget { // Define the StudentDashboardScreen class extending StatefulWidget for a screen that manages state, used for the student dashboard in the organization management system
  const StudentDashboardScreen({Key? key}) : super(key: key); // Constructor for StudentDashboardScreen with optional key parameter for widget identification

  @override // Override the createState method from StatefulWidget to create the state object
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState(); // Create the state object for the student dashboard screen
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> { // Define the state class for StudentDashboardScreen, managing the state of the dashboard
  static const Color mintBg = Color(0xFFEAF6F0); // Define a static constant color for the background, using a mint green shade for the screen's background
  static const Color tealHeader = Color(0xFF79CFC4); // Define a static constant color for headers, using a teal shade for app bars and buttons

  @override // Override the build method from State to define the UI
  Widget build(BuildContext context) { // Build method that constructs the widget tree for the student dashboard screen
    return Scaffold( // Return a Scaffold widget as the root of the screen's layout, providing structure for app bar and body
      backgroundColor: mintBg, // Set the background color of the Scaffold to the mint background color
      appBar: AppBar( // Define the app bar for the screen with title and styling
        backgroundColor: tealHeader, // Set the background color of the app bar to the teal header color
        elevation: 0, // Remove shadow elevation from the app bar for a flat design
        title: const Text( // Set the title text for the app bar
          'Dashboard', // Title text indicating the purpose of the screen
          style: TextStyle( // Style the title text with bold weight and letter spacing
            fontWeight: FontWeight.w700, // Set font weight to bold
            letterSpacing: 1.0, // Add letter spacing
          ),
        ),
        centerTitle: true, // Center the title in the app bar
        leading: IconButton( // Add a leading icon button for back navigation
          icon: const Icon(Icons.arrow_back), // Set the icon to arrow back
          onPressed: () { // Define the callback when the back button is pressed
            Navigator.pushReplacementNamed(context, '/role');// ✅ normal back // Navigate to the role selection screen, replacing the current route
          },
        ),
      ),
      body: LayoutBuilder( // Use LayoutBuilder to get the constraints of the parent widget
        builder: (context, constraints) { // Builder function that takes context and constraints
          final double circleSize = // Calculate the size of the avatar circle based on screen width
              (constraints.maxWidth * 0.40).clamp(120.0, 180.0); // Set circle size to 40% of width, clamped between 120 and 180
          return SingleChildScrollView( // Allow the body to scroll if content overflows
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20), // Add padding around the scroll view
            child: Center( // Center the content horizontally and vertically
              child: ConstrainedBox( // Constrain the width of the content for better layout on larger screens
                constraints: const BoxConstraints(maxWidth: 540), // Set maximum width to 540 pixels
                child: Column( // Arrange children in a vertical column
                  children: [ // List of child widgets in the column
                    // Avatar // Comment indicating the avatar section
                    Container( // Container for the avatar display
                      width: circleSize, // Set width to the calculated circle size
                      height: circleSize, // Set height to the calculated circle size
                      decoration: BoxDecoration( // Decorate the container with circle shape and styling
                        shape: BoxShape.circle, // Set shape to circle
                        color: Colors.white, // Set background color to white
                        border: Border.all( // Add a border around the container
                            color: const Color(0xFF1B5E20), width: 3), // Set border color and width
                        boxShadow: [ // Add shadow to the container
                          BoxShadow( // Define the shadow
                            color: Colors.black.withOpacity(0.10), // Set shadow color with opacity
                            blurRadius: 14, // Set blur radius
                            offset: const Offset(0, 6), // Set offset for the shadow
                          ),
                        ],
                      ),
                      child: ClipOval( // Clip the child to an oval shape
                        child: Icon( // Display an icon for the avatar
                          Icons.person, // Set icon to person
                          size: circleSize * 0.5, // Set icon size to half the circle size
                          color: Colors.grey.shade500, // Set icon color to grey
                        ),
                      ),
                    ),
                    const SizedBox(height: 24), // Add vertical space of 24 pixels
                    // Buttons // Comment indicating the buttons section
                    _actionButton( // Call the helper method to create an action button
                      context: context, // Pass the build context
                      label: 'Profile', // Set the label for the button
                      icon: Icons.groups_outlined, // Set the icon for the button
                      onTap: () => Navigator.pushNamed(context, '/profile'), // Define the onTap callback to navigate to profile
                    ),
                    const SizedBox(height: 12), // Add vertical space of 12 pixels
                    _actionButton( // Call the helper method for organizations button
                      context: context,
                      label: 'Organizations',
                      icon: Icons.groups_outlined,
                      onTap: () => Navigator.pushNamed(context, '/orglist'), // Navigate to organization list
                    ),
                    const SizedBox(height: 12), // Add vertical space
                    // Removed Dashboard button as per user request // Comment indicating removed button
                    // _actionButton( // Commented out button
                    //   context: context,
                    //   label: 'Dashboard',
                    //   icon: Icons.dashboard_outlined,
                    //   onTap: () => Navigator.push(
                    //     context,
                    //     MaterialPageRoute(
                    //         builder: (_) => const StudentDashboard()),
                    //   ),
                    // ),
                    _actionButton( // Call for notifications button
                      context: context,
                      label: 'Notifications',
                      icon: Icons.notifications_outlined,
                      onTap: () => Navigator.push( // Navigate to notification screen
                        context,
                        MaterialPageRoute(
                            builder: (_) => const NotificationScreen()), // Builder for notification screen
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _actionButton({ // Define a private helper method to create action buttons
    required BuildContext context, // Required parameter for context
    required String label, // Required parameter for button label
    required IconData icon, // Required parameter for icon
    required VoidCallback onTap, // Required parameter for onTap callback
  }) {
    return SizedBox( // Return a SizedBox to control button width
      width: double.infinity, // Set width to fill available space
      child: ElevatedButton.icon( // Create an elevated button with icon
        onPressed: onTap, // Set the onPressed callback
        style: ElevatedButton.styleFrom( // Style the elevated button
          backgroundColor: tealHeader, // Set background color to teal
          foregroundColor: Colors.white, // Set text and icon color to white
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16), // Set padding
          shape: RoundedRectangleBorder( // Set shape to rounded rectangle
            borderRadius: BorderRadius.circular(28), // Set border radius
          ),
          elevation: 2, // Set elevation for shadow
        ),
        icon: Icon(icon, size: 20), // Set the icon with size
        label: Text( // Set the label text
          label.toUpperCase(), // Convert label to uppercase
          style: const TextStyle( // Style the text
            fontSize: 14, // Font size 14
            fontWeight: FontWeight.w800, // Bold weight
            letterSpacing: 1.1, // Letter spacing
          ),
        ),
      ),
    );
  }
}
