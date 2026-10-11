import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:my_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});

    await Supabase.initialize(
      url: 'https://cbjttubjzbxrqsnqwoom.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNianR0dWJqemJ4cnFzbnF3b29tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY5MTQ3NDksImV4cCI6MjEwMjQ5MDc0OX0.gfZWRz_XmgLvwM4CGhjvcXS--JEbIxeqc3lzPLtqTyg',
    );
  });

  testWidgets('OrgConnect app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.byType(MyApp), findsOneWidget);
  });
}