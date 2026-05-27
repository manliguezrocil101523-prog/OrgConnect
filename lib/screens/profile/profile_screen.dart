import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/unified_login_page.dart';

// ─── Shared constants ────────────────────────────────────────────────────────
const _kPrimary = Color(0xFF4F46E5);
const _kSecondary = Color(0xFF06B6D4);
const _kSuccess = Color(0xFF22C55E);
const _kBg = Color(0xFFF1F5F9);
const _kSlate0F = Color(0xFF0F172A);
const _kSlate94 = Color(0xFF94A3B8);
const _kSlateE2 = Color(0xFFE2E8F0);
const _kSlateF8 = Color(0xFFF8FAFC);
const _kRed = Color(0xFFE11D48);

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
            color: _kPrimary.withOpacity(0.07),
            blurRadius: 24,
            offset: const Offset(0, 8)),
        BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
        padding: const EdgeInsets.all(10),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
              color: iconColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: iconColor, size: 16),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: _kSlateE2, width: 1.2)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: _kPrimary, width: 1.8)),
    );

// ─── Main Screen ─────────────────────────────────────────────────────────────
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final studentIdCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final contactCtrl = TextEditingController();
  final facebookCtrl = TextEditingController();

  Uint8List? _avatarBytes;
  bool _isEditing = false;
  bool _isLoading = true;
  bool _showZoom = false;
  Map<String, dynamic>? _profile;

  late final AnimationController _headerAnim;
  late final Animation<double> _headerFade;

  @override
  void initState() {
    super.initState();
    _headerAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _headerFade = CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut);
    _loadProfile();
  }

  @override
  void dispose() {
    _headerAnim.dispose();
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

  Future<void> _loadProfile() async {
    await AppState.instance.loadStudentProfile();
    final cur = AppState.instance.currentStudent;
    if (cur != null) {
      _profile = {
        'student_id': cur.studentId,
        'name': cur.name,
        'email': cur.email,
        'contact': cur.contact,
        'facebook': cur.facebook,
        'avatar_url': cur.avatarUrl,
      };
      _populateControllers();
    } else {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('student_profile');
      if (json != null) {
        try {
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
        } catch (_) {}
      }
    }

    // FIX Bug 3: guard mounted before touching widget tree after async gap
    if (!mounted) return;
    setState(() {
      _isEditing = false;
      _isLoading = false;
    });
    _headerAnim.forward();
  }

  void _populateControllers() {
    if (_profile == null) return;
    studentIdCtrl.text = _profile!['student_id'] ?? '';
    nameCtrl.text = _profile!['name'] ?? '';
    emailCtrl.text = _profile!['email'] ?? '';
    contactCtrl.text = _profile!['contact'] ?? '';
    facebookCtrl.text = _profile!['facebook'] ?? '';
  }

  double get _completeness {
    if (_profile == null) return 0;
    final keys = ['student_id', 'name', 'email', 'contact', 'facebook'];
    return keys
            .where((k) => (_profile![k] as String? ?? '').isNotEmpty)
            .length /
        keys.length;
  }

  Future<void> _pickAvatar() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'heic', 'webp'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() => _avatarBytes = result.files.first.bytes);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  Future<void> _saveProfile() async {
    if (studentIdCtrl.text.trim().isEmpty ||
        nameCtrl.text.trim().isEmpty ||
        emailCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in required fields')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updated = StudentProfile(
        id: AppState.instance.currentStudent?.id ?? '',
        name: nameCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        studentId: studentIdCtrl.text.trim(),
        contact: contactCtrl.text.trim(),
        facebook: facebookCtrl.text.trim(),
        avatarUrl: _avatarBytes != null
            ? 'data:image/png;base64,${base64Encode(_avatarBytes!)}'
            : AppState.instance.currentStudent?.avatarUrl ?? '',
        joinedOrgIds: AppState.instance.currentStudent?.joinedOrgIds ?? [],
      );
      await AppState.instance.setStudentProfile(updated);

      if (!mounted) return;
      setState(() {
        _isEditing = false;
        _isLoading = false; // FIX Bug 1: moved into the try block, not missing
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
    } catch (e) {
      if (!mounted) return;
      // FIX Bug 1: always reset loading in both success and error paths
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error saving profile: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _showLogoutDialog() => showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 40,
                    offset: const Offset(0, 16)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon badge
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _kRed.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.logout_rounded, color: _kRed, size: 30),
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
                Text(
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
                  // Cancel button
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
                          child: Text('Cancel',
                              style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: _kSlate0F)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Log Out button
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        Navigator.pop(ctx);
                        await Supabase.instance.client.auth.signOut();
                        if (!mounted) return;
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const UnifiedLoginPage()), // 👈 replace with your login widget
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
                                color: _kRed.withOpacity(0.30),
                                blurRadius: 12,
                                offset: const Offset(0, 4)),
                          ],
                        ),
                        child: const Center(
                          child: Text('Log Out',
                              style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _kBg,
        body: Center(
            child:
                CircularProgressIndicator(color: _kPrimary, strokeWidth: 2.5)),
      );
    }

    // FIX Bug 4: data: URIs cannot be loaded by NetworkImage — detect and use
    // MemoryImage instead to avoid crash/blank avatar after save.
    ImageProvider? avatarImage;
    if (_avatarBytes != null) {
      avatarImage = MemoryImage(_avatarBytes!);
    } else {
      final url = _profile?['avatar_url'] as String? ?? '';
      if (url.startsWith('data:')) {
        // Stored as base64 data URI — decode back to bytes
        try {
          final base64Str = url.substring(url.indexOf(',') + 1);
          avatarImage = MemoryImage(base64Decode(base64Str));
        } catch (_) {
          avatarImage = null;
        }
      } else if (url.isNotEmpty) {
        avatarImage = NetworkImage(url);
      }
    }

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: MediaQuery.of(context).size.height * 0.38,
                backgroundColor: _kPrimary,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                title: const Text('Student Profile',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        letterSpacing: 0.3)),
                centerTitle: true,
                actions: [
                  _AppBarActionButton(
                    isEditing: _isEditing,
                    onTap: _isEditing
                        ? _saveProfile
                        : () => setState(() => _isEditing = true),
                  ),
                  const SizedBox(width: 8),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: FadeTransition(
                    opacity: _headerFade,
                    child: _ProfileHeroHeader(
                      avatarBytes: _avatarBytes,
                      avatarUrl: _profile?['avatar_url'],
                      isEditing: _isEditing,
                      onAvatarTap: _isEditing
                          ? _pickAvatar
                          : () => setState(() => _showZoom = true),
                      displayName: _profile?['name'] ?? '',
                      studentId: _profile?['student_id'] ?? '',
                      completeness: _completeness,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 540),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                                    begin: const Offset(0, 0.04),
                                    end: Offset.zero)
                                .animate(anim),
                            child: child,
                          ),
                        ),
                        child: _isEditing
                            ? _EditForm(
                                key: const ValueKey('edit'),
                                studentIdCtrl: studentIdCtrl,
                                nameCtrl: nameCtrl,
                                emailCtrl: emailCtrl,
                                contactCtrl: contactCtrl,
                                facebookCtrl: facebookCtrl,
                                onSave: _saveProfile,
                              )
                            : _ViewCard(
                                key: const ValueKey('view'),
                                profile: _profile,
                                onLogout: _showLogoutDialog,
                                loggedInEmail: Supabase.instance.client.auth
                                        .currentUser?.email ??
                                    (_profile?['email'] as String? ?? ''),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          _AvatarZoomOverlay(
            isVisible: _showZoom,
            avatarImage: avatarImage,
            displayName: _profile?['name'] ?? '',
            onClose: () => setState(() => _showZoom = false),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _ProfileHeroHeader
// =============================================================================
class _ProfileHeroHeader extends StatelessWidget {
  final Uint8List? avatarBytes;
  final String? avatarUrl;
  final bool isEditing;
  final VoidCallback? onAvatarTap;
  final String displayName;
  final String studentId;
  final double completeness;

  const _ProfileHeroHeader({
    required this.avatarBytes,
    required this.avatarUrl,
    required this.isEditing,
    required this.onAvatarTap,
    required this.displayName,
    required this.studentId,
    required this.completeness,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final avatarSize = (size.width * 0.22).clamp(68.0, 96.0);

    // FIX Bug 4 (hero header): same data URI guard for the header avatar
    Widget? avatarChild;
    ImageProvider? bgImage;
    if (avatarBytes != null) {
      bgImage = MemoryImage(avatarBytes!);
    } else {
      final url = avatarUrl ?? '';
      if (url.startsWith('data:')) {
        try {
          final base64Str = url.substring(url.indexOf(',') + 1);
          bgImage = MemoryImage(base64Decode(base64Str));
        } catch (_) {}
      } else if (url.isNotEmpty) {
        // Use a plain Image.network wrapped in ClipOval as child so errors
        // are handled gracefully.
        avatarChild = ClipOval(
          child: Image.network(
            url,
            fit: BoxFit.cover,
            width: avatarSize,
            height: avatarSize,
            errorBuilder: (_, __, ___) => Icon(
              Icons.person_rounded,
              size: avatarSize * 0.48,
              color: _kPrimary,
            ),
          ),
        );
      }
    }

    // If no image at all, show the person icon
    avatarChild ??= (bgImage == null
        ? Icon(Icons.person_rounded, size: avatarSize * 0.48, color: _kPrimary)
        : null);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kPrimary, _kSecondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          _Orb(top: -40, right: -30, size: 200, opacity: 0.06),
          _Orb(bottom: -20, left: -50, size: 160, opacity: 0.04),
          _Orb(top: 60, left: 30, size: 60, opacity: 0.05),
          SafeArea(
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                // Dynamically scale top padding & gaps so content never
                // overflows on any screen height.
                final topPad = (constraints.maxHeight * 0.18).clamp(8.0, 44.0);
                final gap = (constraints.maxHeight * 0.04).clamp(4.0, 14.0);
                return SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: topPad),
                        GestureDetector(
                          onTap: onAvatarTap,
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: avatarSize + 20,
                                height: avatarSize + 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: SweepGradient(colors: [
                                    _kSecondary.withOpacity(0.7),
                                    _kPrimary.withOpacity(0.3),
                                    _kSecondary.withOpacity(0.7),
                                  ]),
                                ),
                              ),
                              Container(
                                width: avatarSize + 8,
                                height: avatarSize + 8,
                                decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white),
                              ),
                              CircleAvatar(
                                radius: avatarSize / 2,
                                backgroundColor: const Color(0xFFE0E7FF),
                                backgroundImage: bgImage,
                                child: bgImage == null ? avatarChild : null,
                              ),
                              if (isEditing)
                                Positioned(
                                  bottom: 2,
                                  right: 2,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                          colors: [_kPrimary, _kSecondary],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.18),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2))
                                      ],
                                    ),
                                    child: const Icon(Icons.camera_alt_rounded,
                                        size: 14, color: Colors.white),
                                  ),
                                )
                              else if (avatarBytes != null ||
                                  (avatarUrl ?? '').isNotEmpty)
                                Positioned(
                                  bottom: 2,
                                  right: 2,
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.12),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2))
                                      ],
                                    ),
                                    child: const Icon(Icons.zoom_in_rounded,
                                        size: 14, color: _kSecondary),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(height: gap),
                        if (displayName.isNotEmpty) ...[
                          Text(displayName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.1)),
                          if (studentId.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20)),
                                child: Text(studentId,
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.90),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.3)),
                              ),
                            ),
                        ] else
                          Text(
                            isEditing
                                ? 'Tap photo to upload'
                                : 'No profile set',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
                                fontSize: 13,
                                fontStyle: FontStyle.italic),
                          ),
                        SizedBox(height: gap),
                        if (!isEditing)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 48),
                            child: Column(children: [
                              Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Profile Completeness',
                                        style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.70),
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w500)),
                                    Text('${(completeness * 100).toInt()}%',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700)),
                                  ]),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: completeness,
                                  minHeight: 5,
                                  backgroundColor:
                                      Colors.white.withOpacity(0.20),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                          _kSecondary),
                                ),
                              ),
                            ]),
                          ),
                        SizedBox(height: gap / 2),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Simple decorative circle helper
class _Orb extends StatelessWidget {
  final double? top, bottom, left, right, size, opacity;
  const _Orb(
      {this.top,
      this.bottom,
      this.left,
      this.right,
      required this.size,
      required this.opacity});

  @override
  Widget build(BuildContext context) => Positioned(
        top: top,
        bottom: bottom,
        left: left,
        right: right,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(opacity!)),
        ),
      );
}

// =============================================================================
// _AvatarZoomOverlay
// =============================================================================
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
    final imgSize =
        (MediaQuery.of(context).size.width * 0.70).clamp(0.0, 300.0);

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
                              color: Colors.white.withOpacity(0.20), width: 4),
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
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('Tap × to close',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.40),
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
                          color: Colors.white.withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withOpacity(0.20), width: 1),
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

// =============================================================================
// _AppBarActionButton
// =============================================================================
class _AppBarActionButton extends StatelessWidget {
  final bool isEditing;
  final VoidCallback onTap;
  const _AppBarActionButton({required this.isEditing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isEditing ? Colors.white : Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
          border: isEditing
              ? null
              : Border.all(color: Colors.white.withOpacity(0.35), width: 1),
          boxShadow: isEditing
              ? [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ]
              : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(isEditing ? Icons.check_rounded : Icons.edit_rounded,
              color: isEditing ? _kPrimary : Colors.white, size: 15),
          const SizedBox(width: 5),
          Text(isEditing ? 'Save' : 'Edit',
              style: TextStyle(
                  color: isEditing ? _kPrimary : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

// =============================================================================
// _ViewCard
// =============================================================================
class _FieldDef {
  final IconData icon;
  final String label, key;
  final Color color;
  const _FieldDef(this.icon, this.label, this.key, this.color);
}

class _ViewCard extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final VoidCallback? onLogout;
  final String loggedInEmail;
  const _ViewCard({
    super.key,
    required this.profile,
    this.onLogout,
    this.loggedInEmail = '',
  });

  static const _fields = [
    _FieldDef(
        Icons.badge_rounded, 'Student ID', 'student_id', Color(0xFF4F46E5)),
    _FieldDef(Icons.person_rounded, 'Full Name', 'name', Color(0xFF0891B2)),
    _FieldDef(Icons.email_rounded, 'Email', 'email', Color(0xFF0D9488)),
    _FieldDef(Icons.phone_rounded, 'Contact', 'contact', Color(0xFF16A34A)),
    _FieldDef(
        Icons.facebook_rounded, 'Facebook', 'facebook', Color(0xFF2563EB)),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _SectionLabel(text: 'Profile Details'),
      const SizedBox(height: 12),
      Container(
        decoration: _cardDecoration(),
        child: Column(children: [
          for (int i = 0; i < _fields.length; i++) ...[
            _ProfileInfoRow(
                fieldDef: _fields[i],
                value: profile?[_fields[i].key] ?? '',
                isFirst: i == 0,
                isLast: i == _fields.length - 1),
            if (i < _fields.length - 1)
              Divider(
                  height: 1,
                  thickness: 1,
                  indent: 70,
                  endIndent: 20,
                  color: Colors.grey.shade100),
          ],
        ]),
      ),
      const SizedBox(height: 28),
      const _SectionLabel(text: 'Account'),
      const SizedBox(height: 12),
      Container(
        decoration: _cardDecoration(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              onTap: onLogout,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              leading: _IconBox(icon: Icons.logout_rounded, color: _kRed),
              title: const Text('Log Out',
                  style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: _kRed)),
              subtitle: Text(
                loggedInEmail.isNotEmpty
                    ? 'Logged in as: $loggedInEmail'
                    : 'Tap to sign out',
                style: const TextStyle(
                    fontSize: 11.5,
                    color: _kSlate94,
                    fontWeight: FontWeight.w400),
              ),
              trailing: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                    color: _kRed.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.chevron_right_rounded,
                    color: _kRed, size: 18),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

// Reusable tinted icon box
class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const _IconBox({required this.icon, required this.color, this.size = 40});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(11)),
        child: Icon(icon, color: color, size: 19),
      );
}

class _ProfileInfoRow extends StatelessWidget {
  final _FieldDef fieldDef;
  final String value;
  final bool isFirst, isLast;
  const _ProfileInfoRow(
      {required this.fieldDef,
      required this.value,
      this.isFirst = false,
      this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final isEmpty = value.isEmpty || value == 'Not set';
    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(20) : Radius.zero,
        bottom: isLast ? const Radius.circular(20) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: fieldDef.color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(11)),
            child: Icon(fieldDef.icon, color: fieldDef.color, size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(fieldDef.label.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _kSlate94,
                          letterSpacing: 0.8)),
                  const SizedBox(height: 3),
                  Text(
                    isEmpty ? 'Not added yet' : value,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: isEmpty ? FontWeight.w400 : FontWeight.w600,
                      color: isEmpty ? const Color(0xFFCBD5E1) : _kSlate0F,
                      fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ]),
          ),
          if (!isEmpty)
            Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                    color: fieldDef.color.withOpacity(0.6),
                    shape: BoxShape.circle)),
        ]),
      ),
    );
  }
}

// =============================================================================
// _EditForm
// =============================================================================
class _EditForm extends StatelessWidget {
  final TextEditingController studentIdCtrl,
      nameCtrl,
      emailCtrl,
      contactCtrl,
      facebookCtrl;
  final VoidCallback onSave;
  const _EditForm(
      {super.key,
      required this.studentIdCtrl,
      required this.nameCtrl,
      required this.emailCtrl,
      required this.contactCtrl,
      required this.facebookCtrl,
      required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _SectionLabel(text: 'Edit Information'),
      const SizedBox(height: 16),
      Container(
        decoration: _cardDecoration(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
        child: Column(children: [
          _FormField(
              label: 'Student ID',
              controller: studentIdCtrl,
              hint: 'e.g., 202324-1234',
              icon: Icons.badge_rounded,
              iconColor: _kPrimary,
              isRequired: true),
          _FormField(
              label: 'Full Name',
              controller: nameCtrl,
              hint: 'First Last',
              icon: Icons.person_rounded,
              iconColor: const Color(0xFF0891B2),
              isRequired: true),
          _FormField(
              label: 'Email',
              controller: emailCtrl,
              hint: 'name@school.edu.ph',
              icon: Icons.email_rounded,
              iconColor: const Color(0xFF0D9488),
              isRequired: true,
              keyboardType: TextInputType.emailAddress),
          _FormField(
              label: 'Contact',
              controller: contactCtrl,
              hint: '09123456789',
              icon: Icons.phone_rounded,
              iconColor: const Color(0xFF16A34A),
              keyboardType: TextInputType.phone),
          _FormField(
              label: 'Facebook',
              controller: facebookCtrl,
              hint: 'Your Facebook name',
              icon: Icons.facebook_rounded,
              iconColor: const Color(0xFF2563EB),
              isLast: true),
        ]),
      ),
      const SizedBox(height: 24),
      _GradientButton(
          label: 'Save Profile',
          icon: Icons.check_circle_rounded,
          onTap: onSave),
      const SizedBox(height: 10),
      const Center(
        child: Text('* Required fields',
            style: TextStyle(
                fontSize: 11, color: _kSlate94, fontStyle: FontStyle.italic)),
      ),
    ]);
  }
}

class _FormField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final Color iconColor;
  final bool isRequired, isLast;
  final TextInputType? keyboardType;

  const _FormField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
    required this.iconColor,
    this.isRequired = false,
    this.isLast = false,
    this.keyboardType,
  });

  @override
  State<_FormField> createState() => _FormFieldState();
}

class _FormFieldState extends State<_FormField> {
  late final FocusNode _focus = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    // FIX Bug 5: guard mounted before calling setState from focus listener
    if (mounted) setState(() => _isFocused = _focus.hasFocus);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: widget.isLast ? 0 : 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 7),
          child: RichText(
            text: TextSpan(
              text: widget.label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF374151),
                  letterSpacing: 0.2),
              children: widget.isRequired
                  ? const [
                      TextSpan(
                          text: ' *',
                          style: TextStyle(
                              color: _kRed, fontWeight: FontWeight.w700))
                    ]
                  : [],
            ),
          ),
        ),
        TextField(
          controller: widget.controller,
          focusNode: _focus,
          keyboardType: widget.keyboardType,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500, color: _kSlate0F),
          // FIX Bug 5: always pass the hint — clearing it on focus hides the
          // placeholder but it never comes back on unfocus; just keep it always.
          decoration: _fieldDecoration(
            icon: widget.icon,
            iconColor: widget.iconColor,
            hint: widget.hint,
          ),
        ),
      ]),
    );
  }
}

// Shared gradient button used in edit form and password sheet
class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isLoading;
  const _GradientButton(
      {required this.label,
      required this.icon,
      this.onTap,
      this.isLoading = false});

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
            gradient: _kGrad,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: _kPrimary.withOpacity(0.32),
                  blurRadius: 16,
                  offset: const Offset(0, 6))
            ],
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon, color: Colors.white, size: 19),
                    const SizedBox(width: 8),
                    Text(label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3)),
                  ]),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _SectionLabel
// =============================================================================
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 3,
        height: 14,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_kPrimary, _kSecondary],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 10),
      Text(text.toUpperCase(),
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              color: _kSlate94)),
    ]);
  }
}

// =============================================================================
// _ChangePasswordSheet
// =============================================================================
