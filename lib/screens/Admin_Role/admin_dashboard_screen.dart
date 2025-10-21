import 'package:flutter/material.dart'; // Import Flutter's material design library for building UI components in the admin dashboard screen
import '../../core/app_state.dart'; // Import the app state manager for accessing and updating global application state in the admin dashboard
import 'admin_manage_accounts.dart'; // Import the admin manage accounts screen for navigation
import 'admin_reports.dart'; // Import the admin reports screen for navigation
import 'admin_manage_organization.dart'; // Import the admin manage organization screen for navigation

class AdminDashboard extends StatelessWidget { // Define the AdminDashboard class extending StatelessWidget for a static dashboard screen for admin role in the organization management system
  const AdminDashboard({Key? key}) : super(key: key); // Constructor for AdminDashboard with optional key parameter for widget identification

  static const Color mintBg = Color(0xFFEAF6F0); // Define a static constant color for the background, using a mint green shade for the screen's background
  static const Color tealHeader = Color(0xFF79CFC4); // Define a static constant color for headers, using a teal shade for app bars and buttons

  @override // Override the build method from StatelessWidget to define the UI
  Widget build(BuildContext context) { // Build method that constructs the widget tree for the admin dashboard screen
    return Scaffold( // Return a Scaffold widget as the root of the screen's layout, providing structure for app bar and body
      backgroundColor: mintBg, // Set the background color of the Scaffold to the mint background color
      appBar: AppBar( // Define the app bar for the screen with title and styling
        backgroundColor: tealHeader, // Set the background color of the app bar to the teal header color
        elevation: 0, // Remove shadow elevation from the app bar for a flat design
        title: const Text( // Set the title text for the app bar
          'Admin Dashboard', // Title text indicating the purpose of the screen
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.0), // Style the title text with bold weight and letter spacing
        ),
        centerTitle: true, // Center the title in the app bar
        actions: [ // Add actions to the app bar
          IconButton( // Add an icon button for changing role
            tooltip: 'Change Role', // Tooltip for the button
            icon: const Icon(Icons.swap_horiz), // Set the icon to swap horizontal
            onPressed: () { // Define the callback when the button is pressed
              AppState.instance.setRole(null); // Set the role to null to change role
            },
          ),
        ],
      ),
      body: Padding( // Add padding around the body content
        padding: const EdgeInsets.all(20.0), // Set padding of 20 pixels on all sides
        child: Center( // Center the content vertically and horizontally
          child: ConstrainedBox( // Constrain the width of the content for better layout on larger screens
            constraints: const BoxConstraints(maxWidth: 560), // Set maximum width to 560 pixels
            child: Column( // Arrange children in a vertical column
              mainAxisAlignment: MainAxisAlignment.center, // Center the column's children vertically
              children: [ // List of child widgets in the column
                _tile( // Call the helper method to create a tile button
                  context, // Pass the build context
                  'Manage Accounts', // Set the title for the tile
                  Icons.manage_accounts_outlined, // Set the icon for the tile
                  () => Navigator.push( // Define the onTap callback to navigate
                    context, // BuildContext
                    MaterialPageRoute(builder: (_) => const AdminAccountsScreen()), // MaterialPageRoute to admin accounts screen
                  ),
                ),
                const SizedBox(height: 14), // Add vertical space of 14 pixels
                _tile( // Call the helper method for manage organizations tile
                  context,
                  'Manage Organizations',
                  Icons.apartment_outlined,
                  () => Navigator.push( // Navigate to admin organizations screen
                    context,
                    MaterialPageRoute(builder: (_) => const AdminOrganizationsScreen()),
                  ),
                ),
                const SizedBox(height: 14), // Add vertical space
                _tile( // Call for reports tile
                  context,
                  'Reports',
                  Icons.insights_outlined,
                  () => Navigator.push( // Navigate to admin reports screen
                    context,
                    MaterialPageRoute(builder: (_) => const AdminReportsScreen()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, String title, IconData icon, VoidCallback onTap) { // Define a private helper method to create tile buttons
    return SizedBox( // Return a SizedBox to control button width
      width: double.infinity, // Set width to fill available space
      child: ElevatedButton.icon( // Create an elevated button with icon
        onPressed: onTap, // Set the onPressed callback
        style: ElevatedButton.styleFrom( // Style the elevated button
          backgroundColor: tealHeader, // Set background color to teal
          foregroundColor: Colors.white, // Set text and icon color to white
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16), // Set padding
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)), // Set shape to rounded rectangle
        ),
        icon: Icon(icon, size: 20), // Set the icon with size
        label: Text( // Set the label text
          title.toUpperCase(), // Convert title to uppercase
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1.1), // Style the text
        ),
      ),
    );
  }
}
