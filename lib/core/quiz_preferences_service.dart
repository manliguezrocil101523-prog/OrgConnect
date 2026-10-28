import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Stores the result of the "Discover what fits you" interest quiz.
///
/// * Guests: the result is kept on this device (SharedPreferences) so it
///   survives the redirect to the login page.
/// * Students: [syncForCurrentUser] uploads a pending guest result to
///   `public.student_quiz_responses` (newest result wins), then loads the
///   saved result for the account.
///
/// Only the chosen categories are stored, never match scores. Scores are
/// recomputed from the current organizations every time they are needed.
///
/// Suggested location: lib/core/quiz_preferences_service.dart
class QuizPreferencesService extends ChangeNotifier {
  QuizPreferencesService._();

  static final QuizPreferencesService instance = QuizPreferencesService._();

  /// Bump when the quiz questions or categories change. Results saved under
  /// another version are ignored.
  static const int quizVersion = 1;

  /// A guest result older than this is discarded instead of being attached to
  /// whichever account logs in next (matters on shared computers).
  static const Duration guestResultTtl = Duration(days: 7);

  /// Must match the CHECK constraint in student_quiz_responses.sql.
  static const List<String> allowedCategories = <String>[
    'Leadership & Service',
    'Arts & Performance',
    'Media & Creativity',
    'Academic & Technology',
    'Faith & Community',
    'Support & Mentoring',
    'Sports & Wellness',
  ];

  static const int _maxCategories = 10;
  static const String _guestKey = 'guest_quiz_result';
  static const String _table = 'student_quiz_responses';

  List<String> _categories = const <String>[];
  bool _syncing = false;

  supabase.SupabaseClient get _client => supabase.Supabase.instance.client;

  /// Categories chosen in the quiz, or empty when there is no saved result.
  List<String> get categories => List<String>.unmodifiable(_categories);

  bool get hasResult => _categories.isNotEmpty;

  /// How many times each category was picked, e.g. {'Arts & Performance': 3}.
  Map<String, int> get categoryWeights {
    final weights = <String, int>{};
    for (final category in _categories) {
      weights[category] = (weights[category] ?? 0) + 1;
    }
    return weights;
  }

  static bool _isValid(List<String> value) =>
      value.isNotEmpty &&
      value.length <= _maxCategories &&
      value.every(allowedCategories.contains);

  // ---------------------------------------------------------------------------
  // Guest side
  // ---------------------------------------------------------------------------

  /// Call when a guest finishes the quiz.
  Future<void> saveGuestResult(List<String> categories) async {
    if (!_isValid(categories)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _guestKey,
        jsonEncode(<String, Object>{
          'version': quizVersion,
          'categories': categories,
          'savedAt': DateTime.now().toUtc().toIso8601String(),
        }),
      );
    } catch (e) {
      debugPrint('Could not save guest quiz result: $e');
    }
  }

  /// Call from the quiz "reset" button.
  Future<void> clearGuestResult() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_guestKey);
    } catch (e) {
      debugPrint('Could not clear guest quiz result: $e');
    }
  }

  Future<List<String>?> _readGuestResult(SharedPreferences prefs) async {
    final raw = prefs.getString(_guestKey);
    if (raw == null) return null;

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.tryParse('${data['savedAt']}');
      final categories = (data['categories'] as List).map((e) => '$e').toList();

      final isFresh = savedAt != null &&
          DateTime.now().toUtc().difference(savedAt.toUtc()) <= guestResultTtl;

      if (data['version'] == quizVersion && isFresh && _isValid(categories)) {
        return categories;
      }
    } catch (_) {
      // Fall through and discard the unreadable value.
    }

    await prefs.remove(_guestKey);
    return null;
  }

  // ---------------------------------------------------------------------------
  // Student side
  // ---------------------------------------------------------------------------

  /// Call once when the student dashboard opens. Only students reach the
  /// dashboard, so officers/advisers/admins never upload a guest result.
  Future<void> syncForCurrentUser() async {
    if (_syncing) return;

    final user = _client.auth.currentUser;
    if (user == null) return;

    _syncing = true;
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Upload a pending guest result (newest result wins).
      final pending = await _readGuestResult(prefs);
      if (pending != null) {
        try {
          await _client.from(_table).upsert(
            <String, Object>{
              'user_id': user.id,
              'quiz_version': quizVersion,
              'categories': pending,
            },
            onConflict: 'user_id',
          );
          await prefs.remove(_guestKey);
        } catch (e) {
          // Keep the local copy so the next sync can retry.
          debugPrint('Could not upload guest quiz result: $e');
        }
      }

      // 2. Load the saved result for this account.
      final row = await _client
          .from(_table)
          .select('categories, quiz_version')
          .eq('user_id', user.id)
          .maybeSingle();

      var saved = <String>[];
      if (row != null && row['quiz_version'] == quizVersion) {
        saved = (row['categories'] as List).map((e) => '$e').toList();
      }

      _setCategories(_isValid(saved) ? saved : const <String>[]);
    } catch (e) {
      debugPrint('Quiz preference sync failed: $e');
    } finally {
      _syncing = false;
    }
  }

  /// Call when the user signs out so nothing carries over to the next person.
  Future<void> onSignedOut() async {
    await clearGuestResult();
    _setCategories(const <String>[]);
  }

  void _setCategories(List<String> value) {
    if (listEquals(_categories, value)) return;
    _categories = List<String>.unmodifiable(value);
    notifyListeners();
  }
}
