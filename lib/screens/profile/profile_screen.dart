import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_state.dart';
import '../../widgets/app_header.dart';
import '../auth/unified_login_page.dart';
import '../analytics/student_impact_screen.dart';
import '../notifications/notification_screen.dart';
import '../Student_Role/home/home_saved_orgs.dart' show SavedOrgs;
import '../Student_Role/home/saved_orgs_screen.dart' show SavedOrgsScreen;

// ─── Shared constants (Main Profile Screen) ──────────────────────────────────
const _kPrimary = Color(0xFF16A34A);
const _kSecondary = Color(0xFF0F766E);
const _kSuccess = Color(0xFF22C55E);
const _kBg = Color(0xFFFFFFFF);
const _kSlate0F = Color(0xFF0F172A);
const _kSlate94 = Color(0xFF94A3B8);
const _kSlateE2 = Color(0xFFE2E8F0);
const _kSlateF8 = Color(0xFFF0FDF4);
const _kRed = Color(0xFFE11D48);
const _kViolet = Color(0xFF6D28D9);
const _kDivider = Color(0xFFF5F5F5);

// ─── Minimal Black & White constants (Edit Profile & Change Password) ────────
const _kBwText = Color(0xFF111111);
const _kBwBorder = Color(0xFFE5E5E5);
const _kBwBg = Color(0xFFFAFAFA);
const _kBwHint = Color(0xFF757575);
const _kBwIconBg = Color(0xFFF0F0F0);

LinearGradient get _kGrad => const LinearGradient(
      colors: [_kPrimary, _kSecondary],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

BoxDecoration _cardDecoration() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
            color: _kPrimary.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 8)),
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2)),
      ],
    );

InputDecoration _fieldDecoration({
  required IconData icon,
  required Color iconColor,
  String? hint,
  VoidCallback? onToggleObscure,
  bool obscure = false,
}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
          color: Color(0xFFCBD5E1),
          fontSize: 13.5,
          fontWeight: FontWeight.w400),
      filled: true,
      fillColor: _kSlateF8,
      prefixIcon: Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 17),
        ),
      ),
      suffixIcon: onToggleObscure != null
          ? IconButton(
              onPressed: onToggleObscure,
              icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _kSlate94,
                  size: 20),
            )
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: _kSlateE2.withValues(alpha: 0.7), width: 1)),
      disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kPrimary, width: 1.6)),
    );

InputDecoration _bwFieldDecoration({
  required IconData icon,
  String? hint,
  VoidCallback? onToggleObscure,
  bool obscure = false,
}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
          color: _kBwHint, fontSize: 13.5, fontWeight: FontWeight.w400),
      filled: true,
      fillColor: Colors.white,
      prefixIcon: Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          width: 34,
          height: 34,
          decoration:
              const BoxDecoration(color: _kBwIconBg, shape: BoxShape.circle),
          child: Icon(icon, color: _kBwText, size: 17),
        ),
      ),
      suffixIcon: onToggleObscure != null
          ? IconButton(
              onPressed: onToggleObscure,
              icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _kBwHint,
                  size: 20),
            )
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kBwBorder, width: 1)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kBwBorder, width: 1)),
      disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kBwBorder, width: 1)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kBwText, width: 1.5)),
    );

String _s(dynamic v) => v == null ? '' : v.toString().trim();

enum _ProfileBreakpoint { compact, medium, expanded }

_ProfileBreakpoint _profileBreakpointFor(double width) => width < 600
    ? _ProfileBreakpoint.compact
    : width < 960
        ? _ProfileBreakpoint.medium
        : _ProfileBreakpoint.expanded;

const _sheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
);

class _OrgBrief {
  final String id, name, acronym, shortDesc, logo;
  const _OrgBrief({
    required this.id,
    required this.name,
    required this.acronym,
    required this.shortDesc,
    required this.logo,
  });

  factory _OrgBrief.fromMap(Map<String, dynamic> m) => _OrgBrief(
        id: _s(m['id']),
        name: _s(m['name']),
        acronym: _s(m['acronym']),
        shortDesc: _s(m['short_desc']),
        logo: _s(m['logo_asset']),
      );
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final studentIdCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final contactCtrl = TextEditingController();
  final facebookCtrl = TextEditingController();

  Uint8List? _avatarBytes;
  bool _isLoading = true;
  bool _showZoom = false;
  Map<String, dynamic>? _profile;

  final Map<String, _OrgBrief> _orgCache = {};
  Map<String, String> _positions = {};
  List<String> _joinedIds = [];
  List<double> _impact = <double>[0, 0, 0, 0];
  bool _orgsLoading = true;
  bool _orgsError = false;
  bool _extrasRunning = false;

  static const _orgCols = 'id,name,acronym,short_desc,logo_asset';

  static const _fields = [
    _FieldDef(Icons.badge_rounded, 'Student ID', 'student_id',
        Color(0xFF16A34A), 'Add student ID'),
    _FieldDef(Icons.person_rounded, 'Full Name', 'name', Color(0xFF0891B2),
        'Add full name'),
    _FieldDef(
        Icons.email_rounded, 'Email', 'email', Color(0xFF0D9488), 'Add email'),
    _FieldDef(Icons.phone_rounded, 'Contact', 'contact', Color(0xFF16A34A),
        'Add contact number'),
    _FieldDef(Icons.facebook_rounded, 'Facebook', 'facebook', Color(0xFF2563EB),
        'Add Facebook link'),
  ];

  @override
  void initState() {
    super.initState();
    SavedOrgs.instance.load();
    SavedOrgs.instance.addListener(_onSavedChanged);
    _loadProfile();
  }

  @override
  void dispose() {
    SavedOrgs.instance.removeListener(_onSavedChanged);
    for (final c in [
      studentIdCtrl,
      nameCtrl,
      emailCtrl,
      contactCtrl,
      facebookCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _syncFromStudent() {
    final cur = AppState.instance.currentStudent;
    if (cur == null) return false;
    _profile = {
      'student_id': cur.studentId,
      'name': cur.name,
      'email': cur.email,
      'contact': cur.contact,
      'facebook': cur.facebook,
      'avatar_url': cur.avatarUrl,
    };
    _populateControllers();
    return true;
  }

  Future<void> _loadProfile() async {
    try {
      await AppState.instance.loadStudentProfile();
    } catch (_) {}
    if (!_syncFromStudent()) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final json = prefs.getString('student_profile');
        if (json != null) {
          final d = jsonDecode(json) as Map<String, dynamic>;
          _profile = {
            'student_id': d['studentId'] ?? '',
            'name': d['name'] ?? '',
            'email': d['email'] ?? '',
            'contact': d['contact'] ?? '',
            'facebook': d['facebook'] ?? '',
            'avatar_url': d['avatarUrl'] ?? '',
          };
          _populateControllers();
        }
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
    _loadExtras();
  }

  Future<void> _onRefresh() async {
    try {
      await AppState.instance.loadStudentProfile();
    } catch (_) {}
    if (!mounted) return;
    if (_syncFromStudent()) setState(() {});
    await _loadExtras();
  }

  void _populateControllers() {
    if (_profile == null) return;
    studentIdCtrl.text = _profile!['student_id'] ?? '';
    nameCtrl.text = _profile!['name'] ?? '';
    emailCtrl.text = _profile!['email'] ?? '';
    contactCtrl.text = _profile!['contact'] ?? '';
    facebookCtrl.text = _profile!['facebook'] ?? '';
  }

  Future<List<Map<String, dynamic>>?> _query(Future<dynamic>? q) async {
    if (q == null) return <Map<String, dynamic>>[];
    try {
      final r = await q;
      return (r as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return null;
    }
  }

  List<double> _averages(List<Map<String, dynamic>> rows) {
    const keys = ['academic', 'social', 'leadership', 'confidence'];
    final sums = List<double>.filled(4, 0);
    final counts = List<int>.filled(4, 0);
    for (final r in rows) {
      for (var i = 0; i < 4; i++) {
        for (final e in r.entries) {
          if (e.key.toLowerCase().startsWith(keys[i])) {
            final v = num.tryParse(e.value.toString());
            if (v != null) {
              sums[i] += v;
              counts[i]++;
            }
            break;
          }
        }
      }
    }
    return [
      for (var i = 0; i < 4; i++)
        counts[i] == 0
            ? 0.0
            : (sums[i] / counts[i]).roundToDouble().clamp(0.0, 100.0).toDouble()
    ];
  }

  Future<void> _loadExtras() async {
    if (_extrasRunning) return;
    _extrasRunning = true;
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      final joined = <String>[
        for (final e in AppState.instance.currentStudent?.joinedOrgIds ??
            const <String>[])
          e.toString()
      ].where((e) => e.isNotEmpty).toList();

      final res = await Future.wait<List<Map<String, dynamic>>?>([
        _query(uid == null
            ? null
            : client
                .from('members')
                .select('org_id,position')
                .eq('profile_id', uid)),
        _query(uid == null
            ? null
            : client.from('student_impact').select().eq('student_id', uid)),
      ]);
      if (!mounted) return;
      final memRows = res[0] ?? const <Map<String, dynamic>>[];
      final impRows = res[1] ?? const <Map<String, dynamic>>[];

      final memberOrgs =
          [for (final r in memRows) _s(r['org_id'])].where((e) => e.isNotEmpty);
      final all = <String>{...joined, ...memberOrgs}.toList();
      final saved = SavedOrgs.instance.ids.take(3).map((e) => e.toString());
      final needed = <String>{...all, ...saved}.toList();

      final orgRows = needed.isEmpty
          ? <Map<String, dynamic>>[]
          : await _query(client
              .from('organizations')
              .select(_orgCols)
              .inFilter('id', needed));
      if (!mounted) return;

      setState(() {
        _joinedIds = all;
        _positions = {
          for (final r in memRows)
            _s(r['org_id']):
                _s(r['position']).isEmpty ? 'Member' : _s(r['position'])
        };
        if (orgRows != null) {
          for (final r in orgRows) {
            final b = _OrgBrief.fromMap(r);
            _orgCache[b.id] = b;
          }
        }
        _orgsError = orgRows == null;
        _impact = _averages(impRows);
        _orgsLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _orgsLoading = false;
          _orgsError = true;
        });
      }
    } finally {
      _extrasRunning = false;
    }
  }

  void _onSavedChanged() {
    final missing = SavedOrgs.instance.ids
        .take(3)
        .map((e) => e.toString())
        .where((id) => !_orgCache.containsKey(id))
        .toList();
    if (missing.isEmpty) return;
    _fetchOrgs(missing);
  }

  Future<void> _fetchOrgs(List<String> ids) async {
    final rows = await _query(Supabase.instance.client
        .from('organizations')
        .select(_orgCols)
        .inFilter('id', ids));
    if (!mounted || rows == null || rows.isEmpty) return;
    setState(() {
      for (final r in rows) {
        final b = _OrgBrief.fromMap(r);
        _orgCache[b.id] = b;
      }
    });
  }

  List<_OrgBrief> get _joinedOrgs => [
        for (final id in _joinedIds)
          if (_orgCache[id] != null) _orgCache[id]!
      ];

  Future<Uint8List?> _pickAvatar() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'heic', 'webp'],
        withData: true,
      );
      final bytes =
          result?.files.isNotEmpty == true ? result!.files.first.bytes : null;
      if (bytes != null && mounted) {
        setState(() => _avatarBytes = bytes);
      }
      return bytes;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload profile photo: $e')),
      );
      return null;
    }
  }

  Future<Uint8List?> _takeAvatarPhoto() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 88,
        maxWidth: 1200,
      );
      if (image == null) return null;
      final bytes = await image.readAsBytes();
      if (mounted) {
        setState(() => _avatarBytes = bytes);
      }
      return bytes;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera could not be opened: $e')),
      );
      return null;
    }
  }

  ImageProvider? _currentAvatarImage() {
    if (_avatarBytes != null) return MemoryImage(_avatarBytes!);
    final url = (_profile?['avatar_url'] ?? '').toString();
    if (url.startsWith('data:')) {
      try {
        return MemoryImage(base64Decode(url.substring(url.indexOf(',') + 1)));
      } catch (_) {
        return null;
      }
    }
    if (url.isNotEmpty) return CachedNetworkImageProvider(url);
    return null;
  }

  Future<bool> _saveProfile() async {
    if (studentIdCtrl.text.trim().isEmpty ||
        nameCtrl.text.trim().isEmpty ||
        emailCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in required fields')));
      return false;
    }

    setState(() => _isLoading = true);

    try {
      final userId = AppState.instance.currentStudent?.id ?? '';
      String avatarUrl = AppState.instance.currentStudent?.avatarUrl ?? '';
      if (_avatarBytes != null && userId.isNotEmpty) {
        avatarUrl = await AppState.instance.uploadAvatar(_avatarBytes!, userId);
      }

      final updated = StudentProfile(
        id: userId,
        name: nameCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        studentId: studentIdCtrl.text.trim(),
        contact: contactCtrl.text.trim(),
        facebook: facebookCtrl.text.trim(),
        avatarUrl: avatarUrl,
        joinedOrgIds: AppState.instance.currentStudent?.joinedOrgIds ?? [],
      );
      await AppState.instance.setStudentProfile(updated);

      if (!mounted) return true;
      setState(() {
        _avatarBytes = null;
        _isLoading = false;
        _profile = {
          'student_id': studentIdCtrl.text.trim(),
          'name': nameCtrl.text.trim(),
          'email': emailCtrl.text.trim(),
          'contact': contactCtrl.text.trim(),
          'facebook': facebookCtrl.text.trim(),
          'avatar_url': updated.avatarUrl,
        };
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text('Profile saved successfully!'),
        ]),
        backgroundColor: _kSuccess,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error saving profile: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
      return false;
    }
  }

  Future<void> _openEdit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _EditProfilePage(
          studentIdCtrl: studentIdCtrl,
          nameCtrl: nameCtrl,
          emailCtrl: emailCtrl,
          contactCtrl: contactCtrl,
          facebookCtrl: facebookCtrl,
          avatarImage: _currentAvatarImage(),
          onUploadAvatar: _pickAvatar,
          onTakePhoto: _takeAvatarPhoto,
          onSave: _saveProfile,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(m),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
  }

  String _positionOf(String orgId) => _positions[orgId] ?? 'Member';

  void _openOrgSheet(_OrgBrief o) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: _sheetShape,
      constraints: const BoxConstraints(maxWidth: 540),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _Handle(),
              const SizedBox(height: 18),
              _OrgLogo(org: o, size: 64, radius: 18),
              const SizedBox(height: 12),
              Text(
                o.name.isEmpty ? 'Organization' : o.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _kSlate0F),
              ),
              if (o.acronym.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(o.acronym,
                    style: const TextStyle(fontSize: 13, color: _kSlate94)),
              ],
              const SizedBox(height: 10),
              _Tag(_positionOf(o.id)),
              if (o.shortDesc.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  o.shortDesc,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13.5, height: 1.45, color: Color(0xFF475569)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openAllOrgs(List<_OrgBrief> orgs) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: _sheetShape,
      constraints: BoxConstraints(
        maxWidth: 540,
        maxHeight: math
            .max(
              0.0,
              math.min(
                MediaQuery.sizeOf(context).height * 0.75,
                MediaQuery.sizeOf(context).height -
                    MediaQuery.paddingOf(context).vertical -
                    16,
              ),
            )
            .toDouble(),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const _Handle(),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('My Organizations (${orgs.length})',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _kSlate0F)),
              ),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                itemCount: orgs.length,
                separatorBuilder: (_, __) => const Divider(
                    height: 1, indent: 64, endIndent: 12, color: _kDivider),
                itemBuilder: (_, i) {
                  final o = orgs[i];
                  return ListTile(
                    leading: _OrgLogo(org: o, size: 44, radius: 12),
                    title: Text(o.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: _kSlate0F)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Align(
                          alignment: Alignment.centerLeft,
                          child: _Tag(_positionOf(o.id))),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: _kSlate94),
                    onTap: () {
                      Navigator.pop(ctx);
                      if (mounted) _openOrgSheet(o);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() => showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Container(
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 40,
                        offset: const Offset(0, 16)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: _kRed.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: _kRed,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Log out of OrgConnect?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _kSlate0F,
                          letterSpacing: 0.1),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Are you sure you want to log out of your account? You will need to enter your credentials to log back in.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13.5,
                          color: _kSlate94,
                          height: 1.5,
                          fontWeight: FontWeight.w400),
                    ),
                    const SizedBox(height: 28),
                    Row(children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: _kBg,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(color: _kSlateE2, width: 1.2),
                            ),
                            child: const Center(
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: _kSlate0F),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            Navigator.pop(ctx);
                            await Supabase.instance.client.auth.signOut();
                            if (!mounted) return;
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const UnifiedLoginPage()),
                              (route) => false,
                            );
                          },
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: _kRed,
                              borderRadius: BorderRadius.circular(13),
                              boxShadow: [
                                BoxShadow(
                                    color: _kRed.withValues(alpha: 0.30),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4)),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                'Log Out',
                                style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  Future<void> _changePassword() async {
    final client = Supabase.instance.client;
    final email = client.auth.currentUser?.email ?? '';
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Session expired. Please log in again.')));
      return;
    }

    final currentController = TextEditingController();
    final controller = TextEditingController();
    final confirmController = TextEditingController();
    bool currentObscure = true;
    bool obscure = true;
    bool confirmObscure = true;
    bool isSaving = false;
    String? errorText;

    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void fail(String msg) => setDialogState(() {
                isSaving = false;
                errorText = msg;
              });

          Future<void> submit() async {
            final current = currentController.text.trim();
            final password = controller.text.trim();
            final confirm = confirmController.text.trim();

            if (current.isEmpty) {
              fail('Please enter your current password.');
              return;
            }
            if (password.length < 6) {
              fail('New password must be at least 6 characters.');
              return;
            }
            if (password != confirm) {
              fail('New passwords do not match.');
              return;
            }
            if (password == current) {
              fail(
                  'New password must be different from your current password.');
              return;
            }

            setDialogState(() {
              isSaving = true;
              errorText = null;
            });

            try {
              await client.auth
                  .signInWithPassword(email: email, password: current);
            } on AuthException catch (e) {
              if (!ctx.mounted) return;
              final msg = e.message.toLowerCase().contains('invalid')
                  ? 'Current password is incorrect.'
                  : e.message;
              fail(msg);
              return;
            } catch (_) {
              if (!ctx.mounted) return;
              fail('Could not verify your password. Check your connection.');
              return;
            }

            try {
              await client.auth.updateUser(UserAttributes(password: password));
              if (ctx.mounted) Navigator.pop(ctx, true);
            } on AuthException catch (e) {
              if (ctx.mounted) fail(e.message);
            } catch (_) {
              if (ctx.mounted) fail('Could not change password. Try again.');
            }
          }

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            title: const Row(
              children: [
                Icon(Icons.lock_reset_rounded, color: _kBwText),
                SizedBox(width: 10),
                Flexible(
                  child: Text('Change Password',
                      style: TextStyle(
                          color: _kBwText, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentController,
                    obscureText: currentObscure,
                    enabled: !isSaving,
                    style: const TextStyle(color: _kBwText, fontSize: 14.5),
                    decoration: _bwFieldDecoration(
                      icon: Icons.lock_clock_outlined,
                      hint: 'Enter your current password',
                      onToggleObscure: () => setDialogState(
                          () => currentObscure = !currentObscure),
                      obscure: currentObscure,
                    ).copyWith(
                        labelText: 'Current password',
                        labelStyle: const TextStyle(color: _kBwHint)),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    obscureText: obscure,
                    enabled: !isSaving,
                    style: const TextStyle(color: _kBwText, fontSize: 14.5),
                    decoration: _bwFieldDecoration(
                      icon: Icons.lock_outline_rounded,
                      hint: 'Enter a new password',
                      onToggleObscure: () =>
                          setDialogState(() => obscure = !obscure),
                      obscure: obscure,
                    ).copyWith(
                        labelText: 'New password',
                        labelStyle: const TextStyle(color: _kBwHint)),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: confirmController,
                    obscureText: confirmObscure,
                    enabled: !isSaving,
                    style: const TextStyle(color: _kBwText, fontSize: 14.5),
                    decoration: _bwFieldDecoration(
                      icon: Icons.verified_user_outlined,
                      hint: 'Re-enter your new password',
                      onToggleObscure: () => setDialogState(
                          () => confirmObscure = !confirmObscure),
                      obscure: confirmObscure,
                    ).copyWith(
                        labelText: 'Confirm new password',
                        labelStyle: const TextStyle(color: _kBwHint)),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(errorText!,
                          style: const TextStyle(
                              color: _kRed,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx, false),
                  child: const Text('Cancel',
                      style: TextStyle(
                          color: _kBwText, fontWeight: FontWeight.w600))),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF334155),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: isSaving ? null : submit,
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Update Password'),
              ),
            ],
          );
        },
      ),
    );

    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully.')));
    }
  }

  List<Widget> _settingsTiles(BuildContext ctx) => [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF334155).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF334155),
              size: 20,
            ),
          ),
          title: const Text(
            'Notifications',
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14.5, color: _kSlate0F),
          ),
          subtitle: const Text(
            'Manage alerts and updates',
            style: TextStyle(fontSize: 12, color: _kSlate94),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: _kSlate94),
          onTap: () {
            Navigator.pop(ctx);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => NotificationScreen()),
            );
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF334155).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: Color(0xFF334155),
              size: 20,
            ),
          ),
          title: const Text(
            'Change Password',
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14.5, color: _kSlate0F),
          ),
          subtitle: const Text(
            'Update your account password',
            style: TextStyle(fontSize: 12, color: _kSlate94),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: _kSlate94),
          onTap: () {
            Navigator.pop(ctx);
            _changePassword();
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF334155).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Color(0xFF334155),
              size: 20,
            ),
          ),
          title: const Text(
            'Privacy',
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14.5, color: _kSlate0F),
          ),
          subtitle: const Text(
            'Review privacy controls',
            style: TextStyle(fontSize: 12, color: _kSlate94),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: _kSlate94),
          onTap: () {
            Navigator.pop(ctx);
            _snack('Coming soon');
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF334155).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.help_outline_rounded,
              color: Color(0xFF334155),
              size: 20,
            ),
          ),
          title: const Text(
            'Help & Support',
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14.5, color: _kSlate0F),
          ),
          subtitle: const Text(
            'Get assistance or contact support',
            style: TextStyle(fontSize: 12, color: _kSlate94),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: _kSlate94),
          onTap: () {
            Navigator.pop(ctx);
            _snack('Coming soon');
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF334155).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFF334155),
              size: 20,
            ),
          ),
          title: const Text(
            'About',
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14.5, color: _kSlate0F),
          ),
          subtitle: const Text(
            'OrgConnect v1.0.0',
            style: TextStyle(fontSize: 12, color: _kSlate94),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: _kSlate94),
          onTap: () {
            Navigator.pop(ctx);
            _snack('Coming soon');
          },
        ),
      ];
  // Modern Professional Settings Bottom Sheet
  // Modern Professional Settings Bottom Sheet
  void _openSettingsModal() {
    if (MediaQuery.sizeOf(context).width < 600) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: _sheetShape,
        constraints: const BoxConstraints(maxWidth: 540),
        builder: (ctx) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: _Handle()),
                const SizedBox(height: 18),
                const Text(
                  'Settings & Account',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _kSlate0F,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Manage app preferences, notifications, and security',
                  style: TextStyle(fontSize: 13, color: _kSlate94),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: _kDivider),
                const SizedBox(height: 8),
                ..._settingsTiles(ctx),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 460,
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Settings & Account',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _kSlate0F,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Manage app preferences, notifications, and security',
                              style: TextStyle(
                                fontSize: 13,
                                color: _kSlate94,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: _kSlate94,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: _kDivider),
                  const SizedBox(height: 8),
                  ..._settingsTiles(ctx),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _personalCard({bool expanded = false}) {
    if (!expanded) {
      return _Card(
        child: Column(
          children: [
            for (int i = 0; i < _fields.length; i++) ...[
              _InfoRow(
                def: _fields[i],
                value: _s(_profile?[_fields[i].key]),
                onEmptyTap: _openEdit,
              ),
              if (i < _fields.length - 1)
                const Divider(
                    height: 1, indent: 70, endIndent: 16, color: _kDivider),
            ],
          ],
        ),
      );
    }

    Widget info(int index) => _InfoRow(
          def: _fields[index],
          value: _s(_profile?[_fields[index].key]),
          onEmptyTap: _openEdit,
        );

    Widget pair(int first, int second) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: info(first)),
            const SizedBox(width: 8),
            Expanded(child: info(second)),
          ],
        );

    return _Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            pair(0, 1),
            const Divider(
                height: 1, indent: 16, endIndent: 16, color: _kDivider),
            pair(2, 3),
            const Divider(
                height: 1, indent: 16, endIndent: 16, color: _kDivider),
            info(4),
          ],
        ),
      ),
    );
  }

  Widget _orgsBody(List<_OrgBrief> orgs, double cardW,
      {bool expanded = false}) {
    if (_orgsLoading) {
      final skeletons = [
        for (int i = 0; i < 2; i++)
          Container(
            width: cardW,
            height: 128,
            decoration: BoxDecoration(
              color: _kSlateE2.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
      ];
      if (expanded) {
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: skeletons,
        );
      }
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < skeletons.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              skeletons[i],
            ],
          ],
        ),
      );
    }

    if (orgs.isEmpty) {
      return _EmptyCard(
        icon: _orgsError ? Icons.cloud_off_rounded : Icons.groups_rounded,
        text: _orgsError
            ? "Couldn't load organizations. Pull down to retry."
            : "You haven't joined any organization yet.",
      );
    }

    Widget orgCard(_OrgBrief org) => SizedBox(
          width: cardW,
          child: _Card(
            radius: 18,
            child: InkWell(
              onTap: () => _openOrgSheet(org),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _OrgLogo(org: org, size: 52, radius: 14),
                    const SizedBox(height: 8),
                    Text(
                      org.name.isEmpty ? 'Organization' : org.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _kSlate0F),
                    ),
                    const SizedBox(height: 6),
                    _Tag(_positionOf(org.id)),
                  ],
                ),
              ),
            ),
          ),
        );

    if (expanded) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [for (final org in orgs) orgCard(org)],
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      physics: const BouncingScrollPhysics(),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < orgs.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              orgCard(orgs[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _savedCard() {
    return ListenableBuilder(
      listenable: SavedOrgs.instance,
      builder: (context, _) {
        final ids = SavedOrgs.instance.ids.map((e) => e.toString()).toList();
        final count = ids.length;
        final logos = [
          for (final id in ids.take(3))
            if (_orgCache[id] != null) _orgCache[id]!
        ];
        return _Card(
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SavedOrgsScreen()),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                        color: Colors.transparent, shape: BoxShape.circle),
                    child: const Icon(Icons.favorite_rounded,
                        color: _kRed, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      count == 0
                          ? 'No saved organizations yet'
                          : '$count saved',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: count == 0
                          ? const TextStyle(fontSize: 13, color: _kSlate94)
                          : const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: _kSlate0F),
                    ),
                  ),
                  if (count > 0 && logos.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 30.0 + (logos.length - 1) * 20.0,
                      height: 30,
                      child: Stack(
                        children: [
                          for (int i = 0; i < logos.length; i++)
                            Positioned(
                              left: i * 20.0,
                              child: Container(
                                width: 30,
                                height: 30,
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle),
                                child: _OrgLogo(
                                    org: logos[i], size: 26, circle: true),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded, color: _kSlate0F),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _profileSections(
    List<_OrgBrief> orgs,
    double cardW, {
    required bool expanded,
    bool includeSaved = true,
  }) {
    const sectionSpacing = SizedBox(height: 28);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Personal Information'),
        const SizedBox(height: 14),
        _personalCard(expanded: expanded),
        sectionSpacing,
        _SectionTitle(
          'My Organizations',
          trailing: orgs.isEmpty
              ? null
              : InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _openAllOrgs(orgs),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Text(
                      'See all',
                      style: TextStyle(
                        color: _kPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 14),
        _orgsBody(orgs, cardW, expanded: expanded),
        sectionSpacing,
        _ImpactCard(
          values: _impact,
          grid: expanded,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const StudentImpactScreen(),
            ),
          ),
        ),
        if (includeSaved) ...[
          sectionSpacing,
          const _SectionTitle('Saved Organizations'),
          const SizedBox(height: 14),
          _savedCard(),
        ],
      ],
    );
  }

  Widget _logoutButton() => OutlinedButton.icon(
        onPressed: _showLogoutDialog,
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: const Text('Log out',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          foregroundColor: _kRed,
          backgroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: _kRed, width: 1.4),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );

  Widget _versionText() => const Center(
        child: Text('OrgConnect v1.0.0',
            style: TextStyle(fontSize: 11.5, color: _kSlate94)),
      );

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _kBg,
        body: Center(
          child: CircularProgressIndicator(
            color: _kPrimary,
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    final mq = MediaQuery.of(context);
    final avatar = _currentAvatarImage();
    final name = _s(_profile?['name']);
    final studentId = _s(_profile?['student_id']);
    final orgs = _joinedOrgs;
    final headerHeight = 72.0 + mq.padding.top;

    return MediaQuery(
      data: mq.copyWith(
        textScaler:
            mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.3),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final breakpoint = _profileBreakpointFor(width);
          final expanded = breakpoint == _ProfileBreakpoint.expanded;
          final pad = width < 360 ? 16.0 : 20.0;
          final cardW = expanded
              ? 160.0
              : ((width - 2 * pad) * 0.36)
                  .clamp(
                    112.0,
                    breakpoint == _ProfileBreakpoint.medium ? 170.0 : 150.0,
                  )
                  .toDouble();
          final bodyMaxWidth = switch (breakpoint) {
            _ProfileBreakpoint.compact => 540.0,
            _ProfileBreakpoint.medium => 640.0,
            _ProfileBreakpoint.expanded => 1100.0,
          };
          final headerMaxWidth =
              expanded ? bodyMaxWidth : bodyMaxWidth + 2 * pad;
          final details = _profileSections(
            orgs,
            cardW,
            expanded: expanded,
            includeSaved: !expanded,
          );

          Widget responsiveScroll(Widget child) {
            final configured = ScrollConfiguration(
              behavior:
                  const MaterialScrollBehavior().copyWith(scrollbars: false),
              child: child,
            );
            if (breakpoint == _ProfileBreakpoint.compact) return configured;
            return Scrollbar(child: configured);
          }

          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light
                .copyWith(statusBarColor: Colors.transparent),
            child: Scaffold(
              backgroundColor: _kBg,
              body: Stack(
                fit: StackFit.expand,
                children: [
                  if (!expanded)
                    RefreshIndicator(
                      color: _kPrimary,
                      edgeOffset: headerHeight + 12,
                      onRefresh: _onRefresh,
                      child: responsiveScroll(
                        SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          // Change headerHeight + 20 to headerHeight to eliminate the gap
                          padding: EdgeInsets.fromLTRB(
                            0,
                            headerHeight, // <-- Updated from headerHeight + 20
                            0,
                            36 + mq.padding.bottom,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Gray background container will now touch the header seamlessly
                              Container(
                                width: double.infinity,
                                color: const Color(0xFFD9D9D9),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 20, horizontal: 16),
                                child: _ProfileIdentity(
                                  name: name,
                                  studentId: studentId,
                                  avatar: avatar,
                                  avatarSize: 104,
                                  onAvatarTap: () =>
                                      setState(() => _showZoom = true),
                                  onEdit: _openEdit,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Rest of your content with margins
                              Center(
                                child: ConstrainedBox(
                                  constraints:
                                      BoxConstraints(maxWidth: bodyMaxWidth),
                                  child: Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: pad),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        details,
                                        const SizedBox(height: 28),
                                        _logoutButton(),
                                        const SizedBox(height: 18),
                                        _versionText(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Positioned.fill(
                      top: headerHeight,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: SizedBox(
                            height: math
                                .max(0.0, constraints.maxHeight - headerHeight)
                                .toDouble(),
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: pad),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    width: 340,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 20,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            child: Scrollbar(
                                              child: SingleChildScrollView(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: [
                                                    _Card(
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(18),
                                                        child: _ProfileIdentity(
                                                          name: name,
                                                          studentId: studentId,
                                                          avatar: avatar,
                                                          avatarSize: 96,
                                                          onAvatarTap: () =>
                                                              setState(() =>
                                                                  _showZoom =
                                                                      true),
                                                          onEdit: _openEdit,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 24),
                                                    const _SectionTitle(
                                                      'Saved Organizations',
                                                    ),
                                                    const SizedBox(height: 14),
                                                    _savedCard(),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          _logoutButton(),
                                          const SizedBox(height: 18),
                                          _versionText(),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: RefreshIndicator(
                                      color: _kPrimary,
                                      onRefresh: _onRefresh,
                                      child: responsiveScroll(
                                        SingleChildScrollView(
                                          physics:
                                              const AlwaysScrollableScrollPhysics(
                                            parent: BouncingScrollPhysics(),
                                          ),
                                          padding: EdgeInsets.fromLTRB(
                                            0,
                                            20,
                                            0,
                                            36 + mq.padding.bottom,
                                          ),
                                          child: details,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Fixed sticky header.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _ProfileHeader(
                      hPad: pad,
                      onSettings: _openSettingsModal,
                      onRefresh: breakpoint == _ProfileBreakpoint.compact
                          ? null
                          : _onRefresh,
                      centered: breakpoint != _ProfileBreakpoint.compact,
                      contentMaxWidth: headerMaxWidth,
                    ),
                  ),

                  // Zoom overlay remains above the page content.
                  _AvatarZoomOverlay(
                    isVisible: _showZoom,
                    avatarImage: avatar,
                    displayName: name,
                    onClose: () => setState(() => _showZoom = false),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

String _initials(String n) {
  final p = n.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (p.isEmpty) return '';
  final a = p.first[0];
  final b = p.length > 1 ? p.last[0] : '';
  return (a + b).toUpperCase();
}

class _ProfileHeader extends StatelessWidget {
  final double hPad;
  final VoidCallback? onSettings;
  final VoidCallback? onRefresh;
  final bool centered;
  final double? contentMaxWidth;

  const _ProfileHeader({
    required this.hPad,
    this.onSettings,
    this.onRefresh,
    this.centered = false,
    this.contentMaxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final headerRow = Padding(
      padding: EdgeInsets.fromLTRB(hPad, top, hPad, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Flexible(
            child: Text(
              'My Profile',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onRefresh != null)
                IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded,
                      color: Colors.white, size: 21),
                  tooltip: 'Refresh profile',
                ),
              if (onSettings != null)
                IconButton(
                  onPressed: onSettings,
                  icon: const Icon(Icons.settings_outlined,
                      color: Colors.white, size: 22),
                  tooltip: 'Settings',
                ),
            ],
          ),
        ],
      ),
    );

    return Container(
      width: double.infinity,
      height: 72.0 + top,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        gradient: AppHeader.brandGradient,
        borderRadius: BorderRadius.only(),
      ),
      child: Stack(
        children: [
          Positioned(right: -45, top: -70, child: _headerOrb(170)),
          Positioned(right: 45, bottom: -70, child: _headerOrb(125)),
          Positioned.fill(
            child: centered
                ? Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: contentMaxWidth ?? 1100,
                      ),
                      child: headerRow,
                    ),
                  )
                : headerRow,
          ),
        ],
      ),
    );
  }

  Widget _headerOrb(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: .07),
        ),
      );
}

class _ProfileIdentity extends StatelessWidget {
  final String name, studentId;
  final ImageProvider? avatar;
  final double avatarSize;
  final VoidCallback onAvatarTap, onEdit;

  const _ProfileIdentity({
    required this.name,
    required this.studentId,
    required this.avatar,
    required this.avatarSize,
    required this.onAvatarTap,
    required this.onEdit,
  });

  Widget _initialsView() {
    final ini = _initials(name);
    return Container(
      color: _kViolet,
      alignment: Alignment.center,
      child: ini.isEmpty
          ? Icon(Icons.person_rounded,
              color: Colors.white, size: avatarSize * 0.5)
          : Text(ini,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: avatarSize * 0.34,
                  fontWeight: FontWeight.w800)),
    );
  }

  Widget _avatarView() {
    return SizedBox(
      width: avatarSize,
      height: avatarSize,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onAvatarTap,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kViolet,
              border: Border.all(
                  color: _kPrimary.withValues(alpha: 0.25), width: 3),
            ),
            child: ClipOval(
              child: avatar != null
                  ? Image(
                      image: avatar!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => _initialsView(),
                    )
                  : _initialsView(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayStudentId = studentId.isEmpty ? 'N/A' : studentId;
    return SizedBox(
      width: double.infinity,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _avatarView(),
              const SizedBox(height: 12),
              Text(
                name.isEmpty ? 'Your Name' : name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _kSlate0F,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                displayStudentId,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _kSlate94,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _kBwIconBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.school_rounded, color: _kSlate0F, size: 13),
                    SizedBox(width: 4),
                    Text(
                      'Student',
                      style: TextStyle(
                        color: _kSlate0F,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Tooltip(
              message: 'Edit profile',
              child: Material(
                color: _kBwIconBg,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onEdit,
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(Icons.edit_rounded, color: _kSlate0F, size: 18),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final double radius;
  const _Card({required this.child, this.radius = 20});

  @override
  Widget build(BuildContext context) => Container(
        decoration: _cardDecoration()
            .copyWith(borderRadius: BorderRadius.circular(radius)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Material(color: Colors.transparent, child: child),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const _SectionTitle(this.text, {this.trailing});

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: _kSlate0F)),
        ),
        if (trailing != null) trailing!,
      ]);
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: _kPrimary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: _kPrimary, fontSize: 10.5, fontWeight: FontWeight.w700)),
      );
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: _kSlateE2,
          borderRadius: BorderRadius.circular(2),
        ),
      );
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => _Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(icon, color: _kSlate94, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 13.5, height: 1.35, color: Color(0xFF64748B))),
            ),
          ]),
        ),
      );
}

class _OrgLogo extends StatelessWidget {
  final _OrgBrief org;
  final double size, radius;
  final bool circle;
  const _OrgLogo({
    required this.org,
    required this.size,
    this.radius = 14,
    this.circle = false,
  });

  static const _palette = [
    Color(0xFF16A34A),
    Color(0xFF0891B2),
    Color(0xFF7C3AED),
    Color(0xFFEA580C),
    Color(0xFFDB2777),
  ];

  Widget _fallback() {
    final t = (org.acronym.isNotEmpty ? org.acronym : org.name).trim();
    final n = org.acronym.isNotEmpty ? 3 : 2;
    final label = t.isEmpty ? '?' : t.substring(0, math.min(n, t.length));
    return Container(
      color: _palette[org.id.hashCode.abs() % _palette.length],
      alignment: Alignment.center,
      child: Text(label.toUpperCase(),
          maxLines: 1,
          style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.32,
              fontWeight: FontWeight.w800)),
    );
  }

  ImageProvider? _provider() {
    final logo = org.logo;
    if (logo.isEmpty) return null;
    try {
      if (logo.startsWith('http')) return CachedNetworkImageProvider(logo);
      if (logo.startsWith('data:')) {
        return MemoryImage(base64Decode(logo.substring(logo.indexOf(',') + 1)));
      }
      if (logo.startsWith('assets/')) return AssetImage(logo);
      return CachedNetworkImageProvider(Supabase.instance.client.storage
          .from('org-assets')
          .getPublicUrl(logo));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _provider();
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(circle ? size / 2 : radius),
        child: p == null
            ? _fallback()
            : Image(
                image: p,
                fit: BoxFit.cover,
                width: size,
                height: size,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => _fallback(),
              ),
      ),
    );
  }
}

class _FieldDef {
  final IconData icon;
  final String label, key, hint;
  final Color color;
  const _FieldDef(this.icon, this.label, this.key, this.color, this.hint);
}

class _InfoRow extends StatelessWidget {
  final _FieldDef def;
  final String value;
  final VoidCallback onEmptyTap;
  const _InfoRow({
    required this.def,
    required this.value,
    required this.onEmptyTap,
  });

  @override
  Widget build(BuildContext context) {
    final empty = value.isEmpty;
    return InkWell(
      onTap: empty ? onEmptyTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
                color: Colors.transparent, shape: BoxShape.circle),
            child: Icon(def.icon, color: def.color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(def.label,
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _kSlate94)),
                const SizedBox(height: 2),
                Text(
                  empty ? def.hint : value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: empty
                      ? const TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFFCBD5E1))
                      : const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: _kSlate0F),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _ImpactCard extends StatelessWidget {
  final List<double> values;
  final VoidCallback onTap;
  final bool grid;

  const _ImpactCard({
    required this.values,
    required this.onTap,
    this.grid = false,
  });

  static const _labels = [
    'Academic',
    'Social',
    'Leadership',
    'Confidence',
  ];

  static const _tintStart = Color(0xFFD1FAE5); // soft emerald tint
  static const _tintEnd = Color(0xFFA7F3D0); // richer mint
  static const _border = Color(0xFF6EE7B7); // visible green outline
  static const _track = Color(0xFFFFFFFF); // white track, pops on tint
  static const _bar = Color(0xFF059669); // confident green fill
  static const _accent = Color(0xFF047857); // icon + chevron
  static const _titleText = Color(0xFF064E3B); // deep forest green
  static const _bodyText = Color(0xFF0F5132); // green-tinted labels

  @override
  Widget build(BuildContext context) {
    Widget gridMetric(int index) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _labels[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _bodyText,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${values[index].round()}%',
                textAlign: TextAlign.right,
                maxLines: 1,
                style: const TextStyle(
                  color: _titleText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (values[index] / 100).clamp(0.0, 1.0),
            minHeight: 6,
            borderRadius: BorderRadius.circular(6),
            backgroundColor: _track,
            valueColor: const AlwaysStoppedAnimation<Color>(_bar),
          ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_tintStart, _tintEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border, width: 1),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _border),
                      ),
                      child: const Icon(
                        Icons.trending_up_rounded,
                        color: _accent,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Growth & Impact',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _titleText,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'See how campus life helps you grow',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFF047857),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: _accent,
                      size: 24,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (grid) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: gridMetric(0),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: gridMetric(1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: gridMetric(2),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: gridMetric(3),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  for (int i = 0; i < 4; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    Row(
                      children: [
                        SizedBox(
                          width: 84,
                          child: Text(
                            _labels[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _bodyText,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: (values[i] / 100).clamp(0.0, 1.0),
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(6),
                            backgroundColor: _track,
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(_bar),
                          ),
                        ),
                        SizedBox(
                          width: 42,
                          child: Text(
                            '${values[i].round()}%',
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            style: const TextStyle(
                              color: _titleText,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarZoomOverlay extends StatelessWidget {
  final bool isVisible;
  final ImageProvider? avatarImage;
  final String displayName;
  final VoidCallback onClose;

  const _AvatarZoomOverlay({
    required this.isVisible,
    required this.avatarImage,
    required this.displayName,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final availableHeight = mq.size.height - mq.padding.vertical;
    final heightLimitedSize = math.max(0.0, availableHeight - 110) * 0.70;
    final imgSize = math
        .min(
          mq.size.shortestSide * 0.70,
          math.min(300.0, heightLimitedSize),
        )
        .clamp(0.0, 300.0)
        .toDouble();

    return IgnorePointer(
      ignoring: !isVisible,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: isVisible ? 1.0 : 0.0,
        curve: Curves.easeInOut,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: const Color(0xEB0F172A),
            child: SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: imgSize + 8,
                        height: imgSize + 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.20),
                              width: 4),
                        ),
                        child: ClipOval(
                          child: avatarImage != null
                              ? Image(
                                  image: avatarImage!,
                                  fit: BoxFit.cover,
                                  width: imgSize,
                                  height: imgSize,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: const Color(0xFF1E293B),
                                    child: const Icon(Icons.person_rounded,
                                        color: Colors.white38, size: 80),
                                  ),
                                )
                              : Container(
                                  color: const Color(0xFF1E293B),
                                  child: const Icon(Icons.person_rounded,
                                      color: Colors.white38, size: 80),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (displayName.isNotEmpty)
                        Text(displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('Tap × to close',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.40),
                              fontSize: 12)),
                    ]),
                  ),
                  Positioned(
                    top: 12,
                    right: 16,
                    child: GestureDetector(
                      onTap: onClose,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.20),
                              width: 1),
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditProfilePage extends StatefulWidget {
  final TextEditingController studentIdCtrl;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController contactCtrl;
  final TextEditingController facebookCtrl;
  final ImageProvider? avatarImage;
  final Future<Uint8List?> Function() onUploadAvatar;
  final Future<Uint8List?> Function() onTakePhoto;
  final Future<bool> Function() onSave;

  const _EditProfilePage({
    required this.studentIdCtrl,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.contactCtrl,
    required this.facebookCtrl,
    required this.avatarImage,
    required this.onUploadAvatar,
    required this.onTakePhoto,
    required this.onSave,
  });

  @override
  State<_EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<_EditProfilePage> {
  Uint8List? _localAvatarBytes;
  bool _saving = false;

  Future<void> _showAvatarOptions() async {
    if (_saving) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading:
                    const Icon(Icons.photo_library_rounded, color: _kBwText),
                title: const Text('Choose from gallery',
                    style: TextStyle(
                        color: _kBwText, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _handleUploadAvatar();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: _kBwText),
                title: const Text('Take a photo',
                    style: TextStyle(
                        color: _kBwText, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _handleTakePhoto();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleUploadAvatar() async {
    final bytes = await widget.onUploadAvatar();
    if (!mounted || bytes == null) return;
    setState(() => _localAvatarBytes = bytes);
  }

  Future<void> _handleTakePhoto() async {
    final bytes = await widget.onTakePhoto();
    if (!mounted || bytes == null) return;
    setState(() => _localAvatarBytes = bytes);
  }

  Future<void> _handleSave() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final ok = await widget.onSave();
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
    }
  }

  Widget _topBar() {
    return Row(
      children: [
        IconButton(
          tooltip: 'Back',
          onPressed: _saving ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: _kBwText, size: 26),
        ),
        const SizedBox(width: 4),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Edit Profile',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _kBwText,
                      letterSpacing: -0.3)),
              SizedBox(height: 2),
              Text('Update your personal information',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: _kBwHint)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: Colors.white,
          shape: const StadiumBorder(
              side: BorderSide(color: _kBwBorder, width: 1.2)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: _saving ? null : () => Navigator.pop(context),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close_rounded, color: _kBwText, size: 15),
                  SizedBox(width: 6),
                  Text('Cancel',
                      style: TextStyle(
                          color: _kBwText,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _headerCard(ImageProvider? avatar) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBwBorder, width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _showAvatarOptions,
            child: SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kViolet,
                      border: Border.all(color: _kBwBorder, width: 2),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2)),
                      ],
                    ),
                    child: ClipOval(
                      child: avatar != null
                          ? Image(
                              image: avatar,
                              fit: BoxFit.cover,
                              width: 66,
                              height: 66,
                              gaplessPlayback: true,
                              errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.person_rounded,
                                      color: Colors.white, size: 34)),
                            )
                          : const Center(
                              child: Icon(Icons.person_rounded,
                                  color: Colors.white, size: 34)),
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _kBwText,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_outlined,
                          color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Student Profile',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _kBwText)),
                const SizedBox(height: 3),
                const Text('Manage your account',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, color: _kBwHint)),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kBwIconBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('STUDENT ACCOUNT',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: _kBwText)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ImageProvider? currentAvatar = _localAvatarBytes != null
        ? MemoryImage(_localAvatarBytes!)
        : widget.avatarImage;
    final mq = MediaQuery.of(context);

    return MediaQuery(
      data: mq.copyWith(
        textScaler:
            mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.3),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final breakpoint = _profileBreakpointFor(constraints.maxWidth);
          final maxContentWidth = switch (breakpoint) {
            _ProfileBreakpoint.compact => 540.0,
            _ProfileBreakpoint.medium => 640.0,
            _ProfileBreakpoint.expanded => 860.0,
          };

          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.dark
                .copyWith(statusBarColor: Colors.transparent),
            child: Scaffold(
              backgroundColor: _kBwBg,
              body: SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxContentWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _topBar(),
                          const SizedBox(height: 16),
                          _headerCard(currentAvatar),
                          const SizedBox(height: 22),
                          _EditForm(
                            studentIdCtrl: widget.studentIdCtrl,
                            nameCtrl: widget.nameCtrl,
                            emailCtrl: widget.emailCtrl,
                            contactCtrl: widget.contactCtrl,
                            facebookCtrl: widget.facebookCtrl,
                            isSaving: _saving,
                            onSave: _handleSave,
                            expanded: breakpoint == _ProfileBreakpoint.expanded,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EditForm extends StatelessWidget {
  final TextEditingController studentIdCtrl;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController contactCtrl;
  final TextEditingController facebookCtrl;
  final bool isSaving;
  final VoidCallback onSave;
  final bool expanded;

  const _EditForm({
    required this.studentIdCtrl,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.contactCtrl,
    required this.facebookCtrl,
    required this.isSaving,
    required this.onSave,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final studentIdField = _BwFormField(
      label: 'Student ID',
      controller: studentIdCtrl,
      hint: 'e.g., 202324-1234',
      icon: Icons.badge_outlined,
      enabled: !isSaving,
      textInputAction: TextInputAction.next,
    );
    final nameField = _BwFormField(
      label: 'Full Name',
      controller: nameCtrl,
      hint: 'First Last',
      icon: Icons.person_outline_rounded,
      enabled: !isSaving,
      textInputAction: TextInputAction.next,
    );
    final emailField = _BwFormField(
      label: 'Email',
      controller: emailCtrl,
      hint: 'name@school.edu.ph',
      icon: Icons.mail_outline_rounded,
      enabled: !isSaving,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
    );
    final contactField = _BwFormField(
      label: 'Contact',
      controller: contactCtrl,
      hint: '09123456789',
      icon: Icons.phone_outlined,
      enabled: !isSaving,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
    );
    final facebookField = _BwFormField(
      label: 'Facebook',
      controller: facebookCtrl,
      hint: 'Your Facebook name',
      icon: Icons.facebook_rounded,
      enabled: !isSaving,
      textInputAction: TextInputAction.done,
      isLast: true,
    );

    final fields = expanded
        ? Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: studentIdField),
                  const SizedBox(width: 20),
                  Expanded(child: nameField),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: emailField),
                  const SizedBox(width: 20),
                  Expanded(child: contactField),
                ],
              ),
              facebookField,
            ],
          )
        : Column(
            children: [
              studentIdField,
              nameField,
              emailField,
              contactField,
              facebookField,
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _BwSectionLabel(text: 'Personal Information'),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kBwBorder, width: 1),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: fields,
        ),
        const SizedBox(height: 22),
        _BlackButton(
          label: 'Save Changes',
          icon: Icons.save_outlined,
          isLoading: isSaving,
          onTap: onSave,
        ),
      ],
    );
  }
}

class _BwFormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool isLast, enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  const _BwFormField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
    this.isLast = false,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: _kBwText),
          ),
        ),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          style: const TextStyle(
              fontSize: 14.5, fontWeight: FontWeight.w500, color: _kBwText),
          decoration: _bwFieldDecoration(icon: icon, hint: hint),
        ),
      ]),
    );
  }
}

class _BlackButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isLoading;
  const _BlackButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 54,
          decoration: BoxDecoration(
            color: const Color(0xFF1A9E6B),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                else ...[
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BwSectionLabel extends StatelessWidget {
  final String text;
  const _BwSectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 3,
        height: 14,
        decoration: BoxDecoration(
          color: _kBwText,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 10),
      Text(text.toUpperCase(),
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              color: _kBwHint)),
    ]);
  }
}
