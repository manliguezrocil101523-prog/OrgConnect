import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Stores the current user's saved organization IDs across app launches.
class SavedOrgs extends ChangeNotifier {
  SavedOrgs._();

  static final SavedOrgs instance = SavedOrgs._();

  final Set<String> _saved = <String>{};

  String? _storageKey;
  bool _loaded = false;
  int _loadGeneration = 0;

  String _currentStorageKey() {
    final userId = supabase.Supabase.instance.client.auth.currentUser?.id;

    if (userId == null || userId.isEmpty) {
      return 'home_saved_orgs_guest';
    }

    return 'home_saved_orgs_$userId';
  }

  /// Loads saved organizations for the currently authenticated user.
  ///
  /// A user change invalidates the previous in-memory set. Storage failures
  /// are handled without propagating exceptions to the UI.
  Future<void> load() async {
    final key = _currentStorageKey();

    if (_loaded && _storageKey == key) {
      return;
    }

    final generation = ++_loadGeneration;

    if (_storageKey != key) {
      _saved.clear();
      _storageKey = key;
      _loaded = false;
    }

    try {
      final preferences = await SharedPreferences.getInstance();
      final savedIds = preferences.getStringList(key) ?? const <String>[];

      if (generation != _loadGeneration || key != _currentStorageKey()) {
        return;
      }

      _saved
        ..clear()
        ..addAll(
          savedIds.where((id) => id.trim().isNotEmpty),
        );

      _loaded = true;
    } catch (error) {
      debugPrint('Unable to load saved organizations: $error');

      if (generation != _loadGeneration || key != _currentStorageKey()) {
        return;
      }

      _saved.clear();
      _loaded = true;
    }

    if (generation == _loadGeneration && key == _currentStorageKey()) {
      notifyListeners();
    }
  }

  /// Returns whether an organization is saved for the current in-memory user.
  bool isSaved(String orgId) {
    return _saved.contains(orgId);
  }

  /// Updates the in-memory set immediately, notifies listeners, then persists.
  Future<void> toggle(String orgId) async {
    if (orgId.trim().isEmpty) {
      return;
    }

    final key = _currentStorageKey();

    if (_storageKey != key) {
      _loadGeneration++;
      _saved.clear();
      _storageKey = key;
      _loaded = false;
    }

    if (!_saved.add(orgId)) {
      _saved.remove(orgId);
    }

    notifyListeners();

    final snapshot = _saved.toList()..sort();

    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(key, snapshot);
    } catch (error) {
      debugPrint('Unable to persist saved organizations: $error');
    }
  }
}
