import 'package:supabase_flutter/supabase_flutter.dart'; // Import the Supabase Flutter package for integrating Supabase backend services in the app

class SupabaseClientManager { // Define a singleton class to manage Supabase client initialization and access
  static const String supabaseUrl = 'https://lzxfoypsdtgpvoelmirr.supabase.co'; // Define a constant string for the Supabase project URL, used for backend connection
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx6eGZveXBzZHRncHZvZWxtaXJyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA5MDA4MzQsImV4cCI6MjA3NjQ3NjgzNH0.OWYn4LGpRC20FRwcIMv6bMbO2_EFauynHn1MXtaM05k'; // Define a constant string for the anonymous key, allowing public access to Supabase features

  static Future<void> initialize() async { // Define a static asynchronous method to initialize the Supabase client
    await Supabase.initialize( // Call Supabase's initialize method to set up the connection
      url: supabaseUrl, // Pass the Supabase URL for the project
      anonKey: supabaseAnonKey, // Pass the anonymous key for authentication
    );
  }

  static SupabaseClient get client => Supabase.instance.client; // Define a getter to access the Supabase client instance for database operations
}
