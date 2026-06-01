import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app_state.dart';

import 'screens/organizations/org_list_screen.dart';
import 'screens/auth/sign_up_page.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/Student_Role/student_dashboard_screen.dart';
import 'screens/Student_Role/student_dashboard_events.dart';
import 'screens/auth/unified_login_page.dart';
import 'screens/auth/auth_gate.dart';
import 'screens/auth/forgot_password_page.dart';

// ✅ ADDITION 1 — navigator key declared at top level
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://pevurkusuxubpntiqdca.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBldnVya3VzdXh1YnBudGlxZGNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY5NTI4MzQsImV4cCI6MjA5MjUyODgzNH0.00bDYZHXUND-jaLuQEVBYG_XEFOb0HFwHaf4X0hTFwY',
  );

  await AppState.instance.loadStudentProfile();
  await AppState.instance.loadTheme();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    AppState.instance.addListener(_onAppStateChanged);

    // ✅ ADDITION 2 — listen for password recovery event
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        navigatorKey.currentState?.pushNamed('/reset-password');
      }
    });
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onAppStateChanged);
    super.dispose();
  }

  void _onAppStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OrgConnect',
      debugShowCheckedModeBanner: false,

      // ✅ ADDITION 3 — attach navigatorKey
      navigatorKey: navigatorKey,

      themeMode: AppState.instance.isDark ? ThemeMode.dark : ThemeMode.light,

      theme: ThemeData(
        brightness: Brightness.light,
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

      darkTheme: ThemeData(
        brightness: Brightness.dark,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF181C27),
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
        scaffoldBackgroundColor: const Color(0xFF0F1117),
      ),

      initialRoute: '/',
      routes: {
        '/': (context) => const AuthGate(),
        '/login': (context) => const UnifiedLoginPage(),
        '/reset-password': (_) => const ForgotPasswordPage(),
        '/orglist': (context) => const OrgListScreen(),
        '/signup': (context) => const SignUpPage(),
        '/home': (context) => const StudentDashboardScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/calendar': (context) => const StudentDashboard(),
      },
    );
  }
}
