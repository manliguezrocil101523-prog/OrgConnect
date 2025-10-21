import 'package:flutter/material.dart'; // Import Flutter's material design library for building UI components in the app
import 'package:my_app/screens/Student_Role/student_dashboard_screen.dart'; // Import the student dashboard screen widget for displaying student-specific content
import 'package:my_app/core/supabase_client.dart'; // Import the Supabase client manager for database interactions in the system

// import your pages // Comment indicating the start of importing various screen pages used in the app
import 'screens/organizations/org_list_screen.dart'; // Import the organization list screen for viewing available organizations
import 'screens/auth/sign_in_page.dart'; // Import the sign-in page for user authentication
import 'screens/auth/sign_up_page.dart'; // Import the sign-up page for new user registration
import 'screens/role_selection_screen.dart'; // Import the role selection screen for choosing user roles (Student, Officer, Admin)
import 'screens/profile/profile_screen.dart'; // Import the profile screen for managing user profile information
import 'screens/Student_Role/student_dashboard_events.dart'; // Import the student dashboard events screen for event-related features

void main() async { // Define the main entry point function for the Flutter app, marked as async for asynchronous operations
  WidgetsFlutterBinding.ensureInitialized(); // Ensure Flutter widgets are initialized before running the app, necessary for plugins
  await SupabaseClientManager.initialize(); // Initialize the Supabase client for connecting to the backend database system
  runApp(const MyApp()); // Run the main app widget, passing an instance of MyApp
}

class MyApp extends StatelessWidget { // Define the main app class extending StatelessWidget, which doesn't manage state
  const MyApp({super.key}); // Constructor for MyApp with a key parameter for widget identification in the Flutter widget tree

  @override // Override the build method from StatelessWidget to define the UI
  Widget build(BuildContext context) { // Build method that returns the widget tree for the app
    return MaterialApp( // Return a MaterialApp widget, the root of the app providing material design theming and navigation
      title: 'Organization List', // Set the title of the app, displayed in the app switcher or task manager
      debugShowCheckedModeBanner: false, // Hide the debug banner in the top-right corner during development
      theme: ThemeData( // Define the theme for the app using ThemeData, customizing colors and styles
        appBarTheme: const AppBarTheme( // Customize the AppBar theme for consistent styling across screens
          backgroundColor: Color(0xFF79CFC4), // Set the background color of the app bar to a teal shade
          elevation: 0, // Remove shadow/elevation from the app bar for a flat design
          centerTitle: true, // Center the title text in the app bar
          titleTextStyle: TextStyle( // Define the text style for the app bar title
            fontWeight: FontWeight.w700, // Set font weight to bold for emphasis
            letterSpacing: 1.0, // Add letter spacing for better readability
            fontSize: 20, // Set font size to 20 for visibility
            color: Colors.white, // Set text color to white for contrast
          ),
          iconTheme: IconThemeData(color: Colors.white), // Set icon color to white in the app bar
        ),
        scaffoldBackgroundColor: const Color(0xFFEAF6F0), // Set the default background color for Scaffold widgets to a light green
        useMaterial3: false, // Disable Material 3 design for compatibility with Material 2
      ),
      initialRoute: '/event', // ✅ Fixed: string route name // Set the initial route to '/event' for the student dashboard events screen
      routes: { // Define named routes for navigation within the app
        '/role': (context) => RoleSelectionScreen(), // Route to role selection screen for choosing user type
        '/orglist': (context) => OrgListScreen(), // Route to organization list screen for browsing organizations
        '/signin': (context) => SignInPage(), // Route to sign-in page for user login
        '/signup': (context) => SignUpPage(), // Route to sign-up page for user registration
        '/event': (context) => StudentDashboard(), // Route to student dashboard events screen
        '/home': (context) => StudentDashboardScreen(), // Route to main student dashboard screen
        '/profile': (context) => const ProfileScreen(), // Route to profile screen for user details
      },
    );
  }
}
