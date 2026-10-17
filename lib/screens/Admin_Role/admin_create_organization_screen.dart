import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin-only screen that creates a row in `organizations`, optionally uploads a
/// logo to the `org-assets` bucket, and optionally assigns an officer by
/// updating `profiles.role` and `profiles.assigned_org_id`.
///
/// Pops with `true` when the organization was created.
class AdminCreateOrganizationScreen extends StatefulWidget {
  const AdminCreateOrganizationScreen({super.key});

  @override
  State<AdminCreateOrganizationScreen> createState() =>
      _AdminCreateOrganizationScreenState();
}

class _AdminCreateOrganizationScreenState
    extends State<AdminCreateOrganizationScreen> {
  static const green = Color(0xFF128058);
  static const dark = Color(0xFF073B2A);
  static const muted = Color(0xFF4D6F62);
  static const bg = Color(0xFFE6F7EE);
  static const mint = Color(0xFFDDF4E8);
  static const line = Color(0xFFB9E4CF);

  static const _bucket = 'org-assets';
  static const _maxLogoBytes = 5 * 1024 * 1024;
  static const _allowedExt = ['jpg', 'jpeg', 'png', 'webp'];
  static const _categoryHints = [
    'Arts & Performance',
    'Sports & Recreation',
    'Academic & Leadership',
  ];

  final db = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _acronym = TextEditingController();
  final _category = TextEditingController();
  final _shortDesc = TextEditingController();
  final _picker = ImagePicker();

  Uint8List? _logoBytes;
  String _logoExt = 'jpg';
  Map<String, dynamic>? _officer;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _acronym.dispose();
    _category.dispose();
    _shortDesc.dispose();
    super.dispose();
  }

  void _snack(String message, {bool ok = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: ok ? green : null),
    );
  }

  String _contentType(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _pickLogo() async {
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;
      final name = file.name.toLowerCase();
      final ext = name.contains('.') ? name.split('.').last : '';
      if (!_allowedExt.contains(ext)) {
        _snack('Please choose a JPG, PNG or WebP image.');
        return;
      }
      final bytes = await file.readAsBytes();
      if (bytes.lengthInBytes > _maxLogoBytes) {
        _snack('Logo is too large. Please use an image under 5 MB.');
        return;
      }
      if (!mounted) return;
      setState(() {
        _logoBytes = bytes;
        _logoExt = ext;
      });
    } catch (error) {
      _snack('Could not open the image: $error');
    }
  }

  Future<void> _pickOfficer() async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _OfficerPickerSheet(),
    );
    if (picked != null && mounted) setState(() => _officer = picked);
  }

  /// organizations.id is TEXT with no default; the app uses zero-padded
  /// numbers ('001', '002', ...) and next = max + 1.
  String _nextId(List<Map<String, dynamic>> rows) {
    var max = 0;
    for (final row in rows) {
      final n = int.tryParse(row['id']?.toString() ?? '');
      if (n != null && n > max) max = n;
    }
    return (max + 1).toString().padLeft(3, '0');
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final me = db.auth.currentUser;
    if (me == null) {
      _snack('You are signed out. Please log in again.');
      return;
    }

    setState(() => _saving = true);
    String? uploadedPath;
    try {
      // UI-level guard. (Today the database itself does not enforce this.)
      final myProfile = await db
          .from('profiles')
          .select('role')
          .eq('id', me.id)
          .maybeSingle();
      if (myProfile?['role']?.toString() != 'admin') {
        _snack('Only admins can create organizations.');
        return;
      }

      final name = _name.text.trim();
      final existing = List<Map<String, dynamic>>.from(
        await db.from('organizations').select('id,name') as List,
      );
      final duplicate = existing.any(
        (row) =>
            (row['name']?.toString() ?? '').trim().toLowerCase() ==
            name.toLowerCase(),
      );
      if (duplicate) {
        _snack('An organization named "$name" already exists.');
        return;
      }

      var id = _nextId(existing);

      // Logo is optional. Column default is '' so we only set it when present.
      var logoUrl = '';
      final bytes = _logoBytes;
      if (bytes != null) {
        final path =
            'org_logos/${id}_${DateTime.now().millisecondsSinceEpoch}.$_logoExt';
        await db.storage.from(_bucket).uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(
                contentType: _contentType(_logoExt),
                upsert: false,
              ),
            );
        uploadedPath = path;
        logoUrl = db.storage.from(_bucket).getPublicUrl(path);
      }

      // Insert, retrying with a fresh id if two admins pick the same number.
      for (var attempt = 0;; attempt++) {
        try {
          await db.from('organizations').insert({
            'id': id,
            'name': name,
            'logo_asset': logoUrl,
            'acronym': _acronym.text.trim(),
            'category': _category.text.trim(),
            'short_desc': _shortDesc.text.trim(),
          });
          break;
        } on PostgrestException catch (e) {
          if (e.code == '23505' && attempt < 2) {
            final fresh = List<Map<String, dynamic>>.from(
              await db.from('organizations').select('id') as List,
            );
            id = _nextId(fresh);
            continue;
          }
          rethrow;
        }
      }
      uploadedPath = null; // org exists now, keep the logo file

      // Optional officer assignment.
      String? officerWarning;
      final officer = _officer;
      if (officer != null) {
        try {
          final updated = await db
              .from('profiles')
              .update({
                'role': 'officer',
                'assigned_org_id': id,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', officer['id'].toString())
              .select('id');
          if ((updated as List).isEmpty) {
            officerWarning =
                'The organization was created, but the officer could not be assigned (no row updated).';
          }
        } catch (error) {
          officerWarning =
              'The organization was created, but assigning the officer failed: $error';
        }
      }

      if (!mounted) return;
      if (officerWarning != null) {
        _snack(officerWarning);
      } else {
        _snack('"$name" was created.', ok: true);
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      // Insert failed after a logo upload: don't leave an orphan file behind.
      if (uploadedPath != null) {
        try {
          await db.storage.from(_bucket).remove([uploadedPath]);
        } catch (_) {}
      }
      _snack('Could not create organization: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: green, width: 1.6),
        ),
      );

  Widget _card(String title, String subtitle, Widget child) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFF5FFF9)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w900, color: dark)),
            const SizedBox(height: 3),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 11.5, color: muted, height: 1.35)),
            const SizedBox(height: 14),
            child,
          ],
        ),
      );

  Widget _logoPicker() {
    final bytes = _logoBytes;
    return Row(
      children: [
        Container(
          width: 84,
          height: 84,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: line),
          ),
          child: ClipOval(
            child: bytes != null
                ? Image.memory(bytes, fit: BoxFit.cover)
                : Container(
                    color: mint,
                    child: const Icon(Icons.groups_rounded,
                        color: green, size: 38),
                  ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickLogo,
                icon: const Icon(Icons.image_rounded, size: 18),
                label: Text(bytes == null ? 'Choose logo' : 'Change logo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: green,
                  side: const BorderSide(color: green),
                ),
              ),
              if (bytes != null)
                TextButton(
                  onPressed:
                      _saving ? null : () => setState(() => _logoBytes = null),
                  child: const Text('Remove'),
                ),
              const Text('Optional. JPG, PNG or WebP, up to 5 MB.',
                  style: TextStyle(fontSize: 11, color: muted)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _officerPicker() {
    final officer = _officer;
    if (officer == null) {
      return OutlinedButton.icon(
        onPressed: _saving ? null : _pickOfficer,
        icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
        label: const Text('Choose an officer'),
        style: OutlinedButton.styleFrom(
          foregroundColor: green,
          side: const BorderSide(color: green),
        ),
      );
    }
    final name = (officer['name']?.toString().trim() ?? '').isNotEmpty
        ? officer['name'].toString().trim()
        : 'Unnamed user';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: mint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: line),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(Icons.badge_rounded, color: green),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: dark)),
                Text(officer['email']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: muted)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: _saving ? null : () => setState(() => _officer = null),
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: green,
          foregroundColor: Colors.white,
          title: const Text('New organization',
              style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _card(
                  'Organization details',
                  'Only the name is required. Students see these on the organization list.',
                  Column(
                    children: [
                      TextFormField(
                        controller: _name,
                        enabled: !_saving,
                        textCapitalization: TextCapitalization.words,
                        maxLength: 100,
                        decoration: _dec('Organization name *'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Organization name is required'
                            : null,
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _acronym,
                        enabled: !_saving,
                        maxLength: 20,
                        decoration: _dec('Acronym (optional)'),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _category,
                        enabled: !_saving,
                        maxLength: 60,
                        decoration: _dec('Category (optional)'),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            for (final hint in _categoryHints)
                              ActionChip(
                                label: Text(hint,
                                    style: const TextStyle(fontSize: 11)),
                                backgroundColor: mint,
                                side: const BorderSide(color: line),
                                onPressed: _saving
                                    ? null
                                    : () =>
                                        setState(() => _category.text = hint),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _shortDesc,
                        enabled: !_saving,
                        maxLines: 3,
                        maxLength: 200,
                        decoration: _dec('Short description (optional)'),
                      ),
                    ],
                  ),
                ),
                _card(
                  'Logo',
                  'Optional. Without one, a default group icon is shown.',
                  _logoPicker(),
                ),
                _card(
                  'Officer',
                  'Optional. The chosen account becomes an officer of this organization.',
                  _officerPicker(),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: green,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.2, color: Colors.white),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(
                      _saving ? 'Creating…' : 'Create organization',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet that lists accounts that can be made an officer:
/// students, and officers who are not assigned to any organization yet.
/// Admins and advisers are never listed, so they can't be demoted by mistake.
class _OfficerPickerSheet extends StatefulWidget {
  const _OfficerPickerSheet();

  @override
  State<_OfficerPickerSheet> createState() => _OfficerPickerSheetState();
}

class _OfficerPickerSheetState extends State<_OfficerPickerSheet> {
  static const green = Color(0xFF128058);
  static const dark = Color(0xFF073B2A);
  static const muted = Color(0xFF4D6F62);
  static const line = Color(0xFFB9E4CF);

  final db = Supabase.instance.client;
  final _search = TextEditingController();
  List<Map<String, dynamic>> _all = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _search.addListener(
        () => setState(() => _query = _search.text.trim().toLowerCase()));
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = List<Map<String, dynamic>>.from(await db
          .from('profiles')
          .select('id,name,email,role,assigned_org_id,active')
          .inFilter('role', ['student', 'officer']).order('name') as List);
      final eligible = rows.where((p) {
        if (p['active'] == false) return false;
        final role = p['role']?.toString();
        final assigned = p['assigned_org_id']?.toString().trim() ?? '';
        return role == 'student' || (role == 'officer' && assigned.isEmpty);
      }).toList();
      if (!mounted) return;
      setState(() {
        _all = eligible;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_query.isEmpty) return _all;
    return _all.where((p) {
      final name = p['name']?.toString().toLowerCase() ?? '';
      final email = p['email']?.toString().toLowerCase() ?? '';
      return name.contains(_query) || email.contains(_query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.75;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final rows = _filtered;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          color: Color(0xFFF5FFF9),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: line,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 14, 18, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Choose an officer',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: dark)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: 'Search by name or email',
                  prefixIcon: const Icon(Icons.search_rounded, color: green),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: green, width: 1.6),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: green))
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text('Could not load accounts: $_error',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: muted)),
                          ),
                        )
                      : rows.isEmpty
                          ? const Center(
                              child: Text('No matching accounts.',
                                  style: TextStyle(color: muted)))
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                              itemCount: rows.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1, color: line),
                              itemBuilder: (_, i) {
                                final p = rows[i];
                                final name =
                                    (p['name']?.toString().trim() ?? '')
                                            .isNotEmpty
                                        ? p['name'].toString().trim()
                                        : 'Unnamed user';
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFFDDF4E8),
                                    child: Icon(Icons.person_rounded,
                                        color: green),
                                  ),
                                  title: Text(name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: dark)),
                                  subtitle: Text(
                                    '${p['email'] ?? ''} • ${p['role']}',
                                    style: const TextStyle(
                                        fontSize: 11, color: muted),
                                  ),
                                  onTap: () => Navigator.pop(context, p),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
