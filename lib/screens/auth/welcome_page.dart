import 'package:flutter/material.dart'; // Import Flutter's material design library for building UI components in the welcome page
class WelcomePage extends StatelessWidget { // Define the WelcomePage class extending StatelessWidget for a static welcome screen in the organization management app
  const WelcomePage({super.key}); // Constructor for WelcomePage with optional key parameter for widget identification
  @override // Override the build method from StatelessWidget to define the UI
  Widget build(BuildContext context) { // Build method that constructs the welcome page widget tree
    const darkGreen = Color(0xFF496E68); // Define a constant color for the dark green theme used in the welcome page
    return Scaffold( // Return a Scaffold widget as the root of the welcome page layout
      body: Container( // Use a Container for the full-screen background with gradient
        width: double.infinity, // Set width to fill the entire screen width
        height: double.infinity, // Set height to fill the entire screen height
        decoration: const BoxDecoration( // Apply decoration to the container for background styling
          gradient: LinearGradient( // Use a linear gradient for the background
            begin: Alignment.topCenter, // Start gradient from top center
            end: Alignment.bottomCenter, // End gradient at bottom center
            colors: [ // Define the colors for the gradient
              Color(0xFFE8F5E9), // Light green color at the top
              Color(0xFFB2DFDB), // Teal shade at the bottom
            ],
          ),
        ),
        child: SafeArea( // Wrap content in SafeArea to avoid notches and system UI
          child: SingleChildScrollView( // Allow scrolling if content overflows on small screens
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32), // Add padding around the scroll view
            child: Column( // Arrange children in a vertical column
              mainAxisAlignment: MainAxisAlignment.center, // Center the column's children vertically
              children: [ // List of child widgets in the column
                const SizedBox(height: 60), // Add vertical space of 60 pixels at the top
                Container( // Container for the logo display
                  height: 180, // Set height of the logo container
                  width: 180, // Set width of the logo container
                  decoration: BoxDecoration( // Decorate the logo container
                    color: Colors.white, // White background for the logo
                    borderRadius: BorderRadius.circular(20), // Rounded corners with 20 pixel radius
                    boxShadow: const [ // Add shadow to the logo container
                      BoxShadow( // Define the shadow
                        color: Colors.black26, // Semi-transparent black shadow
                        blurRadius: 6, // Blur radius for softness
                        offset: Offset(0, 3), // Offset the shadow down by 3 pixels
                      ),
                    ],
                  ),
                  child: Center( // Center the logo image within the container
                    child: Image.asset( // Display the app logo using an asset image
                      'assets/orgconnectLogo.jpg', // Path to the logo asset
                      fit: BoxFit.contain, // Fit the image to contain within the bounds
                    ),
                  ),
                ),
                const SizedBox(height: 40), // Add vertical space of 40 pixels below the logo
                Text( // Display the welcome title text
                  'W E L C O M E', // The title text with spaced letters
                  style: TextStyle( // Style the title text
                    fontSize: 28, // Font size of 28
                    color: darkGreen, // Use the dark green color
                    fontWeight: FontWeight.bold, // Bold font weight
                    letterSpacing: 6, // Letter spacing of 6 for emphasis
                  ),
                ),
                const SizedBox(height: 20), // Add vertical space of 20 pixels
                Text( // Display the welcome message text
                  'Welcome to Org Connect\n\n' // First line of the message
                  'Your hub for seamless communication, effortless collaboration, ' // Second line
                  'and real-time updates—all in one powerful app.', // Third line
                  style: TextStyle( // Style the message text
                    fontSize: 15, // Font size of 15
                    color: darkGreen.withOpacity(0.85), // Dark green with 85% opacity
                    height: 1.6, // Line height for readability
                  ),
                  textAlign: TextAlign.center, // Center align the text
                ),
                const SizedBox(height: 100), // Add vertical space of 100 pixels
                SizedBox( // Container for the button with full width
                  width: double.infinity, // Set width to infinity for full width
                  child: ElevatedButton( // Create an elevated button for getting started
                    onPressed: () => Navigator.pushReplacementNamed(context, '/home'), // On press, navigate to home screen replacing current
                    style: ElevatedButton.styleFrom( // Style the elevated button
                      backgroundColor: darkGreen, // Background color dark green
                      foregroundColor: Colors.white, // Text color white
                      padding: const EdgeInsets.symmetric(vertical: 16), // Vertical padding of 16
                      shape: RoundedRectangleBorder( // Shape with rounded corners
                        borderRadius: BorderRadius.circular(24), // Border radius of 24
                      ),
                      textStyle: const TextStyle( // Text style for the button
                        fontSize: 18, // Font size 18
                        fontWeight: FontWeight.bold, // Bold weight
                      ),
                    ),
                    child: const Text('Get Started'), // Button text
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
