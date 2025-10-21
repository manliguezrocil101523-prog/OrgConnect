import 'package:flutter/material.dart'; // Import Flutter's material design library
import '../../core/app_state.dart'; // Import AppState for managing global state

// A StatefulWidget that represents the Sign In page
class SignInPage extends StatefulWidget {
  const SignInPage({super.key}); // Constructor with optional key

  @override
  State<SignInPage> createState() => _SignInPageState(); // Create the state object
}

// The state class for SignInPage
class _SignInPageState extends State<SignInPage> {
  final _studentIdController = TextEditingController(); // Controller for Student ID input
  final _passwordController = TextEditingController(); // Controller for Password input
  bool _isFormValid = false; // Tracks whether form is valid (both fields filled)

  final darkGreen = const Color(0xFF79CFC4); // Custom theme color

  @override
  void initState() {
    super.initState();
    // Add listeners to input fields to validate the form when user types
    _studentIdController.addListener(_validateForm);
    _passwordController.addListener(_validateForm);
  }

  @override
  void dispose() {
    // Remove listeners when widget is disposed to prevent memory leaks
    _studentIdController.removeListener(_validateForm);
    _passwordController.removeListener(_validateForm);
    super.dispose();
  }

  // Validates the form: both studentId and password must not be empty
  void _validateForm() {
    setState(() {
      _isFormValid = _studentIdController.text.trim().isNotEmpty &&
          _passwordController.text.trim().isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold( // Base page structure
      body: Container( // Container with full screen gradient background
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient( // Top-to-bottom gradient
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE8F5E9), // Light green
              Color(0xFFB2DFDB), // Teal shade
            ],
          ),
        ),
        child: SafeArea( // Ensures content stays inside safe screen area
          child: SingleChildScrollView( // Allows scrolling on small screens
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column( // Layout widgets vertically
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40), // Spacing at top
                // Logo container
                Container(
                  height: 140,
                  width: 140,
                  decoration: BoxDecoration(
                    color: Colors.white, // White background
                    borderRadius: BorderRadius.circular(20), // Rounded corners
                    boxShadow: const [ // Drop shadow
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/orgconnectLogo.jpg', // App logo
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const SizedBox(height: 32),
                // Student ID input field
                TextField(
                  controller: _studentIdController, // Connect controller
                  decoration: buildInputDecoration('Student ID'), // Custom input style
                  keyboardType: TextInputType.text, // Text input
                ),
                const SizedBox(height: 20),
                // Password input field
                TextField(
                  controller: _passwordController,
                  decoration: buildInputDecoration('Password'),
                  obscureText: true, // Hide text for password
                ),
                const SizedBox(height: 12),
                // "Forgot Password?" link
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {}, // TODO: Add forgot password logic
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(color: darkGreen, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                // Row with Sign In and Sign Up buttons
                Row(
                  children: [
                    // Sign In button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isFormValid // Enabled only if form is valid
                            ? () {
                                // Validate again in case of errors
                                if (_studentIdController.text.trim().isEmpty ||
                                    _passwordController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Please fill in all fields'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }
                                // Create a profile from the entered data
                                final profile = StudentProfile(
                                  id: 'student-${DateTime.now().millisecondsSinceEpoch}', // Unique ID
                                  name: _studentIdController.text.trim(), // Temp name = student ID
                                  email: '',
                                  studentId: _studentIdController.text.trim(),
                                  contact: '',
                                  facebook: '',
                                  avatarUrl: '',
                                  joinedOrgIds: [],
                                );
                                // Save profile to global app state
                                AppState.instance.setStudentProfile(profile);
                                // Navigate to home page
                                Navigator.pushReplacementNamed(
                                    context, '/home');
                              }
                            : null, // Disabled if form invalid
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _isFormValid ? darkGreen : Colors.grey, // Active vs disabled color
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 0,
                        ),
                        child: const Text('Sign in'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Sign Up button
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            Navigator.pushReplacementNamed(context, '/signup'), // Go to SignUp page
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: darkGreen,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          side: BorderSide(color: darkGreen.withOpacity(0.4)), // Outline color
                        ),
                        child: const Text('Sign up'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 140),
                // Continue button (same logic as Sign In)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isFormValid
                        ? () {
                            if (_studentIdController.text.trim().isEmpty ||
                                _passwordController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please fill in all fields'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            final profile = StudentProfile(
                              id: 'student-${DateTime.now().millisecondsSinceEpoch}',
                              name: _studentIdController.text.trim(),
                              email: '',
                              studentId: _studentIdController.text.trim(),
                              contact: '',
                              facebook: '',
                              avatarUrl: '',
                              joinedOrgIds: [],
                            );
                            AppState.instance.setStudentProfile(profile);
                            Navigator.pushReplacementNamed(context, '/home');
                          }
                        : null, // Disabled if invalid
                    style: _isFormValid
                        ? buildMainButtonStyle()
                        : buildMainButtonStyle().copyWith(
                            backgroundColor:
                                WidgetStateProperty.all(Colors.grey),
                          ),
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to build input decorations for text fields
  InputDecoration buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint, // Placeholder text
      fillColor: Colors.white,
      filled: true, // Filled background
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: darkGreen, width: 1.5), // Highlight when focused
      ),
    );
  }

  // Helper method to build the main button style
  ButtonStyle buildMainButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: darkGreen, // Main color
      foregroundColor: Colors.white, // Text color
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24), // Rounded corners
      ),
      textStyle: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
      elevation: 3, // Slight shadow
    );
  }
}
