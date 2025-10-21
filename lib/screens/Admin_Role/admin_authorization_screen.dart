import 'package:flutter/material.dart'; // Import Flutter's material design library for building UI components in the admin authorization screen
import 'admin_dashboard_screen.dart'; // Import the admin dashboard screen for navigation after authorization

class AdminAuthorizationScreen extends StatefulWidget { // Define the AdminAuthorizationScreen class extending StatefulWidget for a screen that manages state, used for admin password authentication in the organization management system
  const AdminAuthorizationScreen({Key? key}) : super(key: key); // Constructor for AdminAuthorizationScreen with optional key parameter for widget identification

  @override // Override the createState method from StatefulWidget to create the state object
  State<AdminAuthorizationScreen> createState() => _AdminAuthorizationScreenState(); // Create the state object for the admin authorization screen
}

class _AdminAuthorizationScreenState extends State<AdminAuthorizationScreen> { // Define the state class for AdminAuthorizationScreen, managing the state of the authorization process
  static const Color mintBg = Color(0xFFEAF6F0); // Define a static constant color for the background, using a mint green shade for the screen's background
  static const Color tealHeader = Color(0xFF79CFC4); // Define a static constant color for headers, using a teal shade for app bars and buttons

  final TextEditingController _passwordController = TextEditingController(); // Create a text editing controller for the password input field
  bool _isAuthenticating = false; // Boolean flag to track if authentication is in progress
  String _errorMessage = ''; // String to hold any error message for display

  @override // Override the build method from State to define the UI
  Widget build(BuildContext context) { // Build method that constructs the widget tree for the admin authorization screen
    return Scaffold( // Return a Scaffold widget as the root of the screen's layout, providing structure for app bar and body
      backgroundColor: mintBg, // Set the background color of the Scaffold to the mint background color
      appBar: AppBar( // Define the app bar for the screen with title and styling
        backgroundColor: tealHeader, // Set the background color of the app bar to the teal header color
        elevation: 0, // Remove shadow elevation from the app bar for a flat design
        title: const Text( // Set the title text for the app bar
          'Admin Authorization', // Title text indicating the purpose of the screen
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.0), // Style the title text with bold weight and letter spacing
        ),
        centerTitle: true, // Center the title in the app bar
        leading: IconButton( // Add a leading icon button for back navigation
          icon: const Icon(Icons.arrow_back), // Set the icon to arrow back
          onPressed: () => Navigator.of(context).pop(), // Define the callback to pop the current route
        ),
      ),
      body: Center( // Center the body content vertically and horizontally
        child: Padding( // Add padding around the body content
          padding: const EdgeInsets.all(20.0), // Set padding of 20 pixels on all sides
          child: ConstrainedBox( // Constrain the width of the content for better layout on larger screens
            constraints: const BoxConstraints(maxWidth: 400), // Set maximum width to 400 pixels
            child: Column( // Arrange children in a vertical column
              mainAxisAlignment: MainAxisAlignment.center, // Center the column's children vertically
              children: [ // List of child widgets in the column
                const Icon( // Display an icon for admin panel
                  Icons.admin_panel_settings_outlined, // Set icon to admin panel settings
                  size: 80, // Set icon size to 80
                  color: tealHeader, // Set icon color to teal header
                ),
                const SizedBox(height: 24), // Add vertical space of 24 pixels
                const Text( // Display the title text
                  'Enter Admin Password', // Title text for password entry
                  style: TextStyle( // Style the title text
                    fontSize: 20, // Font size of 20
                    fontWeight: FontWeight.w700, // Bold font weight
                    color: Colors.black87, // Text color
                  ),
                ),
                const SizedBox(height: 8), // Add vertical space of 8 pixels
                const Text( // Display the password hint
                  'Password: 0000', // Hint text showing the password
                  style: TextStyle( // Style the hint text
                    fontSize: 14, // Font size of 14
                    color: Colors.grey, // Text color grey
                  ),
                ),
                const SizedBox(height: 32), // Add vertical space of 32 pixels
                TextField( // Create a text field for password input
                  controller: _passwordController, // Connect the controller to the text field
                  decoration: InputDecoration( // Define the decoration for the text field
                    labelText: 'Admin Password', // Label text for the field
                    border: OutlineInputBorder( // Set border to outline input border
                      borderRadius: BorderRadius.circular(12), // Border radius of 12
                    ),
                    filled: true, // Fill the background
                    fillColor: Colors.white, // Fill color white
                    errorText: _errorMessage.isNotEmpty ? _errorMessage : null, // Show error text if present
                  ),
                  obscureText: true, // Hide the text for password
                  textAlign: TextAlign.center, // Center the text
                  style: const TextStyle(fontSize: 18), // Style the text with font size 18
                ),
                const SizedBox(height: 24), // Add vertical space of 24 pixels
                SizedBox( // Container for the button with full width
                  width: double.infinity, // Set width to infinity for full width
                  child: ElevatedButton( // Create an elevated button for authentication
                    onPressed: _isAuthenticating ? null : _authenticate, // Disable if authenticating, else call authenticate
                    style: ElevatedButton.styleFrom( // Style the elevated button
                      backgroundColor: tealHeader, // Background color teal
                      foregroundColor: Colors.white, // Text color white
                      padding: const EdgeInsets.symmetric(vertical: 16), // Vertical padding of 16
                      shape: RoundedRectangleBorder( // Shape with rounded corners
                        borderRadius: BorderRadius.circular(12), // Border radius of 12
                      ),
                      elevation: 2, // Elevation for shadow
                    ),
                    child: _isAuthenticating // Conditional child based on authenticating state
                        ? const SizedBox( // Show loading indicator if authenticating
                            width: 20, // Width of the indicator
                            height: 20, // Height of the indicator
                            child: CircularProgressIndicator( // Circular progress indicator
                              color: Colors.white, // Indicator color white
                              strokeWidth: 2, // Stroke width of 2
                            ),
                          )
                        : const Text( // Show text if not authenticating
                            'ACCESS ADMIN DASHBOARD', // Button text
                            style: TextStyle( // Style the button text
                              fontSize: 16, // Font size 16
                              fontWeight: FontWeight.w800, // Bold weight
                              letterSpacing: 1.1, // Letter spacing
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _authenticate() async { // Define the authenticate method to handle password verification
    setState(() { // Update the state to show authenticating
      _isAuthenticating = true; // Set authenticating to true
      _errorMessage = ''; // Clear any error message
    });
    await Future.delayed(const Duration(milliseconds: 500)); // Delay for 500 milliseconds to simulate processing
    if (_passwordController.text == '0000') { // Check if the entered password is correct
      if (mounted) { // Check if the widget is still mounted
        Navigator.pushReplacement( // Navigate to admin dashboard, replacing current route
          context, // BuildContext
          MaterialPageRoute( // MaterialPageRoute for navigation
            builder: (context) => const AdminDashboard(), // Builder returning admin dashboard
          ),
        );
      }
    } else { // If password is incorrect
      setState(() { // Update the state to show error
        _isAuthenticating = false; // Set authenticating to false
        _errorMessage = 'Invalid password. Please try again.'; // Set error message
        _passwordController.clear(); // Clear the password field
      });
    }
  }
}
