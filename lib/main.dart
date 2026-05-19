import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ Supabase SDK
import 'core/app_state.dart'; // Import AppState for initialization

// Import your screens
import 'screens/organizations/org_list_screen.dart';
import 'screens/auth/sign_in_page.dart';
import 'screens/auth/sign_up_page.dart';
import 'screens/role_selection_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/Student_Role/student_dashboard_screen.dart';
import 'screens/Student_Role/student_dashboard_events.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize Supabase
  await Supabase.initialize(
      url: 'https://pevurkusuxubpntiqdca.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBldnVya3VzdXh1YnBudGlxZGNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY5NTI4MzQsImV4cCI6MjA5MjUyODgzNH0.00bDYZHXUND-jaLuQEVBYG_XEFOb0HFwHaf4X0hTFwY');

  // Initialize AppState to load saved profile
  await AppState.instance.loadStudentProfile();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OrgConnect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF79CFC4),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            fontSize: 20,
            color: Colors.white,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        scaffoldBackgroundColor: const Color(0xFFEAF6F0),
      ),
      initialRoute: '/calendar', // Start with the calendar dashboard screen
      routes: {
        '/role': (context) => const RoleSelectionScreen(),
        '/orglist': (context) => const OrgListScreen(),
        '/signin': (context) => const SignInPage(),
        '/signup': (context) => const SignUpPage(),

        '/home': (context) =>
            const StudentDashboardScreen(), // Profile/Org/Notification dashboard
        '/profile': (context) => const ProfileScreen(),
        '/calendar': (context) =>
            const StudentDashboard(), // Calendar dashboard
      },
    );
  }
}
