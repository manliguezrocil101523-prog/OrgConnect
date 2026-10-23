import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Saved organizations of the current user.
///
/// Logged-in users: stored in Supabase table `saved_organizations`
/// (so it survives restarts, other devices and other browser ports).
/// SharedPreferences is only a fallback cache if the network call fails.
/// Guests: stored locally only (same behaviour as before).
///
/// Public API is unchanged: instance, load(), isSaved(), toggle().
class SavedOrgs extends ChangeNotifier {
  SavedOrgs._() {
    // Reload when the user logs in, logs out or switches account.
    supabase.Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      load();
    });
  }

  static final SavedOrgs instance = SavedOrgs._();

  static const String _table = 'saved_organizations';

  final Set<String> _saved = <String>{};

  String? _storageKey;
  bool _loaded = false;
  int _loadGeneration = 0;

  supabase.SupabaseClient get _client => supabase.Supabase.instance.client;

  String? get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null || id.isEmpty) return null;
    return id;
  }

  String _keyFor(String? userId) {
    return userId == null ? 'home_saved_orgs_guest' : 'home_saved_orgs_$userId';
  }

  /// True once the saved list for the current user has been loaded.
  bool get isLoaded => _loaded;

  /// Read-only copy of the saved organization ids.
  Set<String> get ids => Set<String>.unmodifiable(_saved);

  bool isSaved(String orgId) => _saved.contains(orgId);

  Future<Set<String>> _readCache(String key) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return (preferences.getStringList(key) ?? const <String>[])
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (error) {
      debugPrint('Unable to read saved organizations cache: $error');
      return <String>{};
    }
  }

  Future<void> _writeCache(String key, Iterable<String> ids) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final list = ids.toList()..sort();
      await preferences.setStringList(key, list);
    } catch (error) {
      debugPrint('Unable to persist saved organizations cache: $error');
    }
  }

  /// Loads the saved list for the current user. Use force: true to refetch.
  Future<void> load({bool force = false}) async {
    final userId = _userId;
    final key = _keyFor(userId);

    if (!force && _loaded && _storageKey == key) {
      return;
    }

    final generation = ++_loadGeneration;

    if (_storageKey != key) {
      _saved.clear();
      _storageKey = key;
      _loaded = false;
    }

    Set<String>? remoteIds;

    if (userId != null) {
      try {
        final rows =
            await _client.from(_table).select('org_id').eq('user_id', userId);

        remoteIds = <String>{
          for (final row in rows)
            if (row['org_id'] != null &&
                row['org_id'].toString().trim().isNotEmpty)
              row['org_id'].toString(),
        };
      } catch (error) {
        debugPrint('Unable to fetch saved organizations: $error');
      }
    }

    final ids = remoteIds ?? await _readCache(key);

    // A newer load started, or the user changed while we were waiting.
    if (generation != _loadGeneration || key != _keyFor(_userId)) {
      return;
    }

    _saved
      ..clear()
      ..addAll(ids);
    _loaded = true;
    notifyListeners();

    if (remoteIds != null) {
      await _writeCache(key, ids);
    }
  }

  /// Saves or un-saves an organization.
  ///
  /// Updates the UI immediately, then writes to Supabase. If the write fails
  /// the change is reverted and false is returned. Never throws.
  Future<bool> toggle(String orgId) async {
    final id = orgId.trim();
    if (id.isEmpty) return false;

    // Make sure we are toggling against the right user's list.
    if (!_loaded || _storageKey != _keyFor(_userId)) {
      await load();
    }

    final userId = _userId;
    final key = _keyFor(userId);
    final wasSaved = _saved.contains(id);

    if (wasSaved) {
      _saved.remove(id);
    } else {
      _saved.add(id);
    }
    notifyListeners();

    try {
      if (userId != null) {
        if (wasSaved) {
          await _client
              .from(_table)
              .delete()
              .eq('user_id', userId)
              .eq('org_id', id);
        } else {
          await _client.from(_table).upsert(
            {'user_id': userId, 'org_id': id},
            onConflict: 'user_id,org_id',
          );
        }
      }
    } catch (error) {
      debugPrint('Unable to update saved organization $id: $error');

      if (key == _keyFor(_userId)) {
        if (wasSaved) {
          _saved.add(id);
        } else {
          _saved.remove(id);
        }
        notifyListeners();
      }
      return false;
    }

    await _writeCache(key, _saved.toList());
    return true;
  }
}
