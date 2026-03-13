import 'package:flutter/material.dart'; // Import Flutter's material design library for building UI components in the authentication page

class AuthPage extends StatefulWidget {
  // Define the AuthPage class extending StatefulWidget for a screen that manages authentication state, used for sign in and sign up in the organization management system
  const AuthPage(
      {super.key}); // Constructor for AuthPage with optional key parameter for widget identification

  @override // Override the createState method from StatefulWidget to create the state object
  State<AuthPage> createState() =>
      _AuthPageState(); // Create the state object for the authentication page
}

class _AuthPageState extends State<AuthPage> {
  // Define the state class for AuthPage, managing the state of authentication form and processes
  final _emailController =
      TextEditingController(); // Create a text editing controller for the email input field
  final _passwordController =
      TextEditingController(); // Create a text editing controller for the password input field
  final _nameController =
      TextEditingController(); // Create a text editing controller for the name input field
  final _studentIdController =
      TextEditingController(); // Create a text editing controller for the student ID input field

  bool _isSignUp =
      false; // Boolean flag to track if the form is in sign up mode
  bool _isLoading =
      false; // Boolean flag to track if authentication is in progress

  final darkGreen = const Color(
      0xFF79CFC4); // Define a constant color for the dark green theme used in the authentication page

  @override // Override the dispose method from State to clean up resources
  void dispose() {
    // Dispose method to clean up controllers when the widget is removed
    _emailController.dispose(); // Dispose the email controller
    _passwordController.dispose(); // Dispose the password controller
    _nameController.dispose(); // Dispose the name controller
    _studentIdController.dispose(); // Dispose the student ID controller
    super.dispose(); // Call the super dispose method
  }

  Future<void> _signIn() async {
    // Define the sign in method to handle user authentication
    setState(() => _isLoading = true); // Set loading state to true
    // Placeholder for sign in logic - Supabase removed
    await Future.delayed(const Duration(seconds: 1)); // Simulate delay
    if (mounted) {
      // Check if widget is mounted
      ScaffoldMessenger.of(context).showSnackBar(
        // Show snack bar with message
        const SnackBar(
            content: Text(
                'Sign in not implemented - Supabase removed')), // Placeholder message
      );
      setState(() => _isLoading = false); // Set loading to false
    }
  }

  Future<void> _signUp() async {
    // Define the sign up method to handle user registration
    setState(() => _isLoading = true); // Set loading state to true
    // Placeholder for sign up logic - Supabase removed
    await Future.delayed(const Duration(seconds: 1)); // Simulate delay
    if (mounted) {
      // Check if widget is mounted
      ScaffoldMessenger.of(context).showSnackBar(
        // Show snack bar with message
        const SnackBar(
            content: Text(
                'Sign up not implemented - Supabase removed')), // Placeholder message
      );
      setState(() => _isLoading = false); // Set loading to false
    }
  }

  @override // Override the build method from State to define the UI
  Widget build(BuildContext context) {
    // Build method that constructs the widget tree for the authentication page
    return Scaffold(
      // Return a Scaffold widget as the root of the screen's layout
      body: Container(
        // Use a Container for the full-screen background with gradient
        width: double.infinity, // Set width to fill the entire screen width
        height: double.infinity, // Set height to fill the entire screen height
        decoration: const BoxDecoration(
          // Apply decoration to the container for background styling
          gradient: LinearGradient(
            // Use a linear gradient for the background
            begin: Alignment.topCenter, // Start gradient from top center
            end: Alignment.bottomCenter, // End gradient at bottom center
            colors: [
              // Define the colors for the gradient
              Color(0xFFE8F5E9), // Light green color at the top
              Color(0xFFB2DFDB), // Teal shade at the bottom
            ],
          ),
        ),
        child: SafeArea(
          // Wrap content in SafeArea to avoid notches and system UI
          child: SingleChildScrollView(
            // Allow scrolling if content overflows on small screens
            padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 32), // Add padding around the scroll view
            child: Column(
              // Arrange children in a vertical column
              mainAxisAlignment: MainAxisAlignment
                  .center, // Center the column's children vertically
              children: [
                // List of child widgets in the column
                const SizedBox(
                    height: 40), // Add vertical space of 40 pixels at the top
                Container(
                  // Container for the logo display
                  height: 140, // Set height of the logo container
                  width: 140, // Set width of the logo container
                  decoration: BoxDecoration(
                    // Decorate the logo container
                    color: Colors.white, // White background for the logo
                    borderRadius: BorderRadius.circular(
                        20), // Rounded corners with 20 pixel radius
                    boxShadow: const [
                      // Add shadow to the logo container
                      BoxShadow(
                        // Define the shadow
                        color: Colors.black26, // Semi-transparent black shadow
                        blurRadius: 6, // Blur radius for softness
                        offset:
                            Offset(0, 3), // Offset the shadow down by 3 pixels
                      ),
                    ],
                  ),
                  child: const Center(
                    // Center the logo icon within the container
                    child: // Display the school icon
                        Icon(Icons.school,
                            size: 60,
                            color: Color(
                                0xFF79CFC4)), // Icon for school with size and color
                  ),
                ),
                const SizedBox(height: 32), // Add vertical space of 32 pixels
                Text(
                  // Display the title text
                  _isSignUp
                      ? 'Create Account'
                      : 'Welcome Back', // Conditional title based on sign up mode
                  style: const TextStyle(
                    // Style the title text
                    fontSize: 24, // Font size of 24
                    fontWeight: FontWeight.bold, // Bold font weight
                    color: Colors.black87, // Text color
                  ),
                ),
                const SizedBox(height: 32), // Add vertical space of 32 pixels
                if (_isSignUp) ...[
                  // Conditional rendering for sign up fields
                  _buildTextField(
                      // Call helper method for name field
                      'Full Name',
                      _nameController,
                      'Enter your full name'), // Parameters for name field
                  const SizedBox(height: 16), // Add vertical space
                  _buildTextField(
                      'Student ID',
                      _studentIdController, // Call for student ID field
                      'Enter your student ID'), // Parameters for student ID field
                  const SizedBox(height: 16), // Add vertical space
                ],
                _buildTextField('Email', _emailController,
                    'Enter your email'), // Call for email field
                const SizedBox(height: 16), // Add vertical space
                _buildTextField(
                    // Call for password field
                    'Password',
                    _passwordController,
                    'Enter your password', // Parameters for password field
                    obscureText: true), // Set obscure text to true
                const SizedBox(height: 32), // Add vertical space
                SizedBox(
                  // Container for the button with full width
                  width:
                      double.infinity, // Set width to infinity for full width
                  child: ElevatedButton(
                    // Create an elevated button for authentication
                    onPressed: // Set onPressed callback
                        _isLoading
                            ? null
                            : (_isSignUp
                                ? _signUp
                                : _signIn), // Disable if loading, else call sign up or sign in
                    style: ElevatedButton.styleFrom(
                      // Style the elevated button
                      backgroundColor: darkGreen, // Background color dark green
                      foregroundColor: Colors.white, // Text color white
                      padding: const EdgeInsets.symmetric(
                          vertical: 16), // Vertical padding of 16
                      shape: RoundedRectangleBorder(
                        // Shape with rounded corners
                        borderRadius:
                            BorderRadius.circular(24), // Border radius of 24
                      ),
                      textStyle: const TextStyle(
                        // Text style for the button
                        fontWeight: FontWeight.bold, // Bold weight
                        fontSize: 18, // Font size 18
                      ),
                      elevation: 3, // Elevation for shadow
                    ),
                    child:
                        _isLoading // Conditional child based on loading state
                            ? const CircularProgressIndicator(
                                color: Colors.white) // Show loading indicator
                            : Text(_isSignUp
                                ? 'Sign Up'
                                : 'Sign In'), // Show button text
                  ),
                ),
                const SizedBox(height: 16), // Add vertical space
                TextButton(
                  // Create a text button for switching modes
                  onPressed: () => setState(
                      () => _isSignUp = !_isSignUp), // Toggle sign up mode
                  child: Text(
                    // Display the switch text
                    _isSignUp // Conditional text based on sign up mode
                        ? 'Already have an account? Sign In' // Text for sign in
                        : 'Don\'t have an account? Sign Up', // Text for sign up
                    style: TextStyle(
                        color:
                            darkGreen), // Style the text with dark green color
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      // Define a private helper method to create text fields
      String label,
      TextEditingController controller,
      String hint, // Required parameters
      {bool obscureText = false}) {
    // Optional parameter for obscure text
    return Column(
      // Return a column for label and text field
      crossAxisAlignment: CrossAxisAlignment.start, // Align children to start
      children: [
        // List of children
        Text(
          // Display the label text
          label, // Label text
          style: const TextStyle(
            // Style the label
            fontSize: 16, // Font size 16
            fontWeight: FontWeight.w600, // Semi-bold weight
            color: Colors.black87, // Text color
          ),
        ),
        const SizedBox(height: 8), // Add vertical space
        TextField(
          // Create a text field
          controller: controller, // Connect the controller
          obscureText: obscureText, // Set obscure text
          decoration: InputDecoration(
            // Define the decoration
            hintText: hint, // Hint text
            fillColor: Colors.white, // Fill color white
            filled: true, // Fill the background
            contentPadding: // Set content padding
                const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14), // Padding values
            border: OutlineInputBorder(
              // Set border
              borderRadius: BorderRadius.circular(24), // Border radius
              borderSide:
                  const BorderSide(color: Colors.black12), // Border side
            ),
            focusedBorder: OutlineInputBorder(
              // Set focused border
              borderRadius: BorderRadius.circular(24), // Border radius
              borderSide: const BorderSide(
                  color: Color(0xFF79CFC4),
                  width: 1.5), // Border side with color and width
            ),
          ),
        ),
      ],
    );
  }
}
