import 'package:flutter/material.dart'; // Import Flutter's material design library for building UI components in the role selection screen
import '../core/app_state.dart'; // Import the app state manager for accessing and updating global application state in the role selection screen
import 'role_router.dart'; // Import the role router widget for navigating based on selected user role
import 'Officer_Role/officer_authorization_screen.dart'; // Import the officer authorization screen for officer role authentication
import 'Admin_Role/admin_authorization_screen.dart'; // Import the admin authorization screen for admin role authentication

class RoleSelectionScreen extends StatelessWidget { // Define the RoleSelectionScreen class extending StatelessWidget for a screen that doesn't manage state, used for selecting user roles in the organization management system
  const RoleSelectionScreen({Key? key}) : super(key: key); // Constructor for RoleSelectionScreen with optional key parameter for widget identification in the Flutter widget tree

  static const Color mintBg = Color(0xFFEAF6F0); // Define a static constant color for the background, using a mint green shade for the screen's background in the app's theme
  static const Color tealHeader = Color(0xFF79CFC4); // Define a static constant color for headers, using a teal shade for app bars and buttons in the app's theme

  @override // Override the build method from StatelessWidget to define the UI structure of the role selection screen
  Widget build(BuildContext context) { // Build method that constructs the widget tree for the role selection screen, taking BuildContext for accessing theme and navigation
    final state = AppState.instance; // Get the singleton instance of AppState to access global application state
    if (state.selectedRole != null) { // Check if a role has already been selected in the app state
      return const RoleRouter(); // Return the RoleRouter widget if a role is selected, to route to the appropriate screen based on the role
    }
    return Scaffold( // Return a Scaffold widget as the root of the screen's layout, providing structure for app bar and body
      backgroundColor: mintBg, // Set the background color of the Scaffold to the mint background color defined above
      appBar: AppBar( // Define the app bar for the screen with title and styling
        backgroundColor: tealHeader, // Set the background color of the app bar to the teal header color
        elevation: 0, // Remove shadow elevation from the app bar for a flat design
        title: const Text( // Set the title text for the app bar
          'Select Role', // Title text indicating the purpose of the screen
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.0), // Style the title text with bold weight and letter spacing
        ),
        centerTitle: true, // Center the title in the app bar
      ),
      body: Center( // Center the body content vertically and horizontally
        child: Padding( // Add padding around the body content
          padding: const EdgeInsets.all(20.0), // Set padding of 20 pixels on all sides
          child: ConstrainedBox( // Constrain the width of the content for better layout on larger screens
            constraints: const BoxConstraints(maxWidth: 560), // Set maximum width to 560 pixels
            child: Column( // Arrange children in a vertical column
              mainAxisAlignment: MainAxisAlignment.center, // Center the column's children vertically
              children: [ // List of child widgets in the column
                _roleButton(context, 'Student', Icons.school_outlined, // Call the helper method to create a button for Student role with icon
                    UserRole.student), // Pass the Student role enum value
                const SizedBox(height: 16), // Add vertical space of 16 pixels between buttons
                _roleButton(context, 'Organization Officer', // Call the helper method for Officer role
                    Icons.badge_outlined, UserRole.officer), // Pass icon and role
                const SizedBox(height: 16), // Add vertical space
                _roleButton(context, 'Admin', // Call for Admin role
                    Icons.admin_panel_settings_outlined, UserRole.admin), // Pass icon and role
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleButton( // Define a private helper method to create role selection buttons
      BuildContext context, String label, IconData icon, UserRole role) { // Parameters: context for navigation, label text, icon, and role enum
    return SizedBox( // Return a SizedBox to control the button's width
      width: double.infinity, // Set width to fill available space
      child: ElevatedButton.icon( // Create an elevated button with an icon
        onPressed: () { // Define the callback when the button is pressed
          AppState.instance.setRole(role); // Set the selected role in the app state
          // Route to appropriate screen based on role // Comment indicating the start of routing logic
          switch (role) { // Switch statement to handle different roles
            case UserRole.student: // Case for student role
              // Student goes to SignIn/SignUp flow first // Comment explaining student routing
              Navigator.pushReplacementNamed(context, '/signin'); // Navigate to sign-in screen, replacing current route
              break; // Break from switch
            case UserRole.officer: // Case for officer role
              // Officer needs to select organization and authenticate // Comment explaining officer routing
              Navigator.push( // Push a new route for officer authorization
                context, // BuildContext
                MaterialPageRoute( // MaterialPageRoute for navigation
                  builder: (context) => const OfficerAuthorizationScreen(), // Builder function returning the officer auth screen
                ),
              );
              break; // Break
            case UserRole.admin: // Case for admin role
              // Admin needs password authentication // Comment explaining admin routing
              Navigator.push( // Push route for admin auth
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminAuthorizationScreen(), // Return admin auth screen
                ),
              );
              break; // Break
          }
        },
        style: ElevatedButton.styleFrom( // Define the style for the elevated button
          backgroundColor: tealHeader, // Set background color to teal
          foregroundColor: Colors.white, // Set text and icon color to white
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16), // Set padding inside button
          shape: RoundedRectangleBorder( // Set shape to rounded rectangle
            borderRadius: BorderRadius.circular(28), // Border radius of 28 pixels
          ),
          elevation: 2, // Set elevation for shadow
        ),
        icon: Icon(icon, size: 20), // Set the icon with size 20
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
