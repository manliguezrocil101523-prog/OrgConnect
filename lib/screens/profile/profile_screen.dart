import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/unified_login_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';

// ─── Shared constants ────────────────────────────────────────────────────────
const _kPrimary = Color(0xFF16A34A);
const _kSecondary = Color(0xFF0F766E);
const _kSuccess = Color(0xFF22C55E);
const _kBg = Color(0xFFF1F5F9);
const _kSlate0F = Color(0xFF0F172A);
const _kSlate94 = Color(0xFF94A3B8);
const _kSlateE2 = Color(0xFFE2E8F0);
const _kSlateF8 = Color(0xFFF0FDF4);
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

  Future<Uint8List?> _pickAvatar() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'heic', 'webp'],
        withData: true,
      );
      final bytes = result?.files.isNotEmpty == true
          ? result!.files.first.bytes
          : null;
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
        _isEditing = false;
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
      // FIX Bug 1: always reset loading in both success and error paths
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error saving profile: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
      return false;
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

  Future<void> _changePassword() async {
    final controller = TextEditingController();
    final confirmController = TextEditingController();
    bool obscure = true;
    bool confirmObscure = true;

    final changed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Row(
            children: [
              Icon(Icons.lock_reset_rounded, color: _kPrimary),
              SizedBox(width: 10),
              Text('Change Password'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'New password',
                  hintText: 'Enter a new password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: () => setDialogState(() => obscure = !obscure),
                    icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: confirmController,
                obscureText: confirmObscure,
                decoration: InputDecoration(
                  labelText: 'Confirm password',
                  hintText: 'Re-enter your new password',
                  prefixIcon: const Icon(Icons.verified_user_outlined),
                  suffixIcon: IconButton(
                    onPressed: () => setDialogState(() => confirmObscure = !confirmObscure),
                    icon: Icon(confirmObscure ? Icons.visibility_off : Icons.visibility),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _kPrimary),
              onPressed: () async {
                final password = controller.text.trim();
                final confirm = confirmController.text.trim();
                if (password.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be at least 6 characters.')));
                  return;
                }
                if (password != confirm) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match.')));
                  return;
                }
                try {
                  await Supabase.instance.client.auth.updateUser(
                    UserAttributes(password: password),
                  );
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Could not change password: $e')));
                  }
                }
              },
              child: const Text('Update Password'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    confirmController.dispose();
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully.')));
    }
  }

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

    ImageProvider? avatarImage;
    if (_avatarBytes != null) {
      avatarImage = MemoryImage(_avatarBytes!);
    } else {
      final url = _profile?['avatar_url'] as String? ?? '';
      if (url.startsWith('data:')) {
        try {
          avatarImage = MemoryImage(
            base64Decode(url.substring(url.indexOf(',') + 1)),
          );
        } catch (_) {}
      } else if (url.isNotEmpty) {
        avatarImage = CachedNetworkImageProvider(url);
      }
    }

    const headerHeight = 138.0;

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          Column(
            children: [
              SizedBox(
                height: headerHeight,
                width: double.infinity,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_kPrimary, _kSecondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    children: [
                      _Orb(top: -45, right: -30, size: 150, opacity: 0.07),
                      _Orb(bottom: -55, left: -35, size: 115, opacity: 0.05),
                      SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 14, 0),
                          child: Row(
                            children: [
                              const Text('Profile', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
                              const Spacer(),
                              _AppBarActionButton(
                                isEditing: false,
                                onTap: () async {
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
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 13,
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => setState(() => _showZoom = true),
                              child: _CompactAvatar(image: avatarImage, showCamera: false),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    (_profile?['name'] ?? '').toString().isEmpty ? 'Your Profile' : (_profile?['name'] ?? '').toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 3),
                                  if ((_profile?['student_id'] ?? '').toString().isNotEmpty)
                                    Text(
                                      (_profile?['student_id'] ?? '').toString(),
                                      style: TextStyle(color: Colors.white.withOpacity(.82), fontSize: 12.5, fontWeight: FontWeight.w600),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ScrollConfiguration(
                  behavior: const MaterialScrollBehavior().copyWith(scrollbars: false),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 48),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 540),
                        child: _ViewCard(
                          profile: _profile,
                          onLogout: _showLogoutDialog,
                          onChangePassword: _changePassword,
                          loggedInEmail: Supabase.instance.client.auth.currentUser?.email ?? (_profile?['email'] as String? ?? ''),
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

// Compact identity avatar used by the fixed Profile header.
class _CompactAvatar extends StatelessWidget {
  final ImageProvider? image;
  final bool showCamera;

  const _CompactAvatar({required this.image, required this.showCamera});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 78,
          height: 78,
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: CircleAvatar(
            backgroundColor: const Color(0xFFE0E7FF),
            backgroundImage: image,
            child: image == null
                ? const Icon(Icons.person_rounded, color: _kPrimary, size: 38)
                : null,
          ),
        ),
        if (showCamera)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 27,
              height: 27,
              decoration: const BoxDecoration(
                color: _kPrimary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
      ],
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
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            width: avatarSize,
            height: avatarSize,
            errorWidget: (_, __, ___) => Icon(
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
  final VoidCallback? onChangePassword;
  final String loggedInEmail;
  const _ViewCard({
    super.key,
    required this.profile,
    this.onLogout,
    this.onChangePassword,
    this.loggedInEmail = '',
  });

  static const _fields = [
    _FieldDef(
        Icons.badge_rounded, 'Student ID', 'student_id', Color(0xFF16A34A)),
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
      for (final field in _fields) ...[
        _ProfileInfoCard(
          fieldDef: field,
          value: profile?[field.key] ?? '',
        ),
        const SizedBox(height: 10),
      ],
      const SizedBox(height: 18),
      const _SectionLabel(text: 'Account & Security'),
      const SizedBox(height: 12),
      Container(
        decoration: _cardDecoration(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              ListTile(
                onTap: onChangePassword,
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                leading: _IconBox(icon: Icons.lock_reset_rounded, color: _kPrimary),
                title: const Text('Change Password', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _kSlate0F)),
                subtitle: const Text('Update your account password securely', style: TextStyle(fontSize: 11.5, color: _kSlate94)),
                trailing: const Icon(Icons.chevron_right_rounded, color: _kPrimary),
              ),
              Divider(height: 1, indent: 76, endIndent: 20, color: Colors.grey.shade100),
              ListTile(
                onTap: onLogout,
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                leading: _IconBox(icon: Icons.logout_rounded, color: _kRed),
                title: const Text('Log Out', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _kRed)),
                subtitle: Text(
                  loggedInEmail.isNotEmpty ? 'Logged in as: $loggedInEmail' : 'Tap to sign out',
                  style: const TextStyle(fontSize: 11.5, color: _kSlate94),
                ),
                trailing: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: _kRed.withOpacity(0.08), borderRadius: BorderRadius.circular(9)),
                  child: const Icon(Icons.chevron_right_rounded, color: _kRed, size: 18),
                ),
              ),
            ],
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

class _ProfileInfoCard extends StatelessWidget {
  final _FieldDef fieldDef;
  final String value;

  const _ProfileInfoCard({required this.fieldDef, required this.value});

  @override
  Widget build(BuildContext context) {
    final isEmpty = value.trim().isEmpty || value == 'Not set';
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [fieldDef.color.withOpacity(.14), fieldDef.color.withOpacity(.06)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(fieldDef.icon, color: fieldDef.color, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fieldDef.label.toUpperCase(),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _kSlate94, letterSpacing: .9),
                ),
                const SizedBox(height: 4),
                Text(
                  isEmpty ? 'Not added yet' : value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.25,
                    fontWeight: isEmpty ? FontWeight.w400 : FontWeight.w700,
                    color: isEmpty ? const Color(0xFFCBD5E1) : _kSlate0F,
                    fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            isEmpty ? Icons.add_circle_outline_rounded : Icons.check_circle_rounded,
            color: isEmpty ? _kSlateE2 : fieldDef.color.withOpacity(.65),
            size: 18,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Dedicated edit screen
// =============================================================================
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

  @override
  Widget build(BuildContext context) {
    final ImageProvider? currentAvatar = _localAvatarBytes != null
        ? MemoryImage(_localAvatarBytes!)
        : widget.avatarImage;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: _EditForm(
              studentIdCtrl: widget.studentIdCtrl,
              nameCtrl: widget.nameCtrl,
              emailCtrl: widget.emailCtrl,
              contactCtrl: widget.contactCtrl,
              facebookCtrl: widget.facebookCtrl,
              avatarImage: currentAvatar,
              onUploadAvatar: _handleUploadAvatar,
              onTakePhoto: _handleTakePhoto,
              onSave: () async {
                final ok = await widget.onSave();
                if (ok && context.mounted) Navigator.pop(context);
              },
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _EditForm
// =============================================================================
class _EditForm extends StatelessWidget {
  final TextEditingController studentIdCtrl;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController contactCtrl;
  final TextEditingController facebookCtrl;
  final ImageProvider? avatarImage;
  final VoidCallback onUploadAvatar;
  final VoidCallback onTakePhoto;
  final VoidCallback onSave;

  const _EditForm({
    super.key,
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
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          decoration: _cardDecoration(),
          child: Column(
            children: [
              const Text(
                'Profile Photo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _kSlate0F,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Add a photo so your profile is easy to recognize.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _kSlate94, fontSize: 12.5),
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: onUploadAvatar,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 118,
                      height: 118,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _kGrad,
                        boxShadow: [
                          BoxShadow(
                            color: _kPrimary.withOpacity(0.18),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        backgroundColor: const Color(0xFFE0E7FF),
                        backgroundImage: avatarImage,
                        child: avatarImage == null
                            ? const Icon(
                                Icons.person_rounded,
                                size: 54,
                                color: _kPrimary,
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 2,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: _kGrad,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 17,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: onUploadAvatar,
                    icon: const Icon(Icons.upload_rounded, size: 17),
                    label: const Text('Upload'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kPrimary,
                      side: const BorderSide(color: _kPrimary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: onTakePhoto,
                    icon: const Icon(Icons.camera_alt_rounded, size: 17),
                    label: const Text('Camera'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const _SectionLabel(text: 'Edit Information'),
        const SizedBox(height: 16),
        Container(
          decoration: _cardDecoration(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
          child: Column(
            children: [
              _FormField(
                label: 'Student ID',
                controller: studentIdCtrl,
                hint: 'e.g., 202324-1234',
                icon: Icons.badge_rounded,
                iconColor: _kPrimary,
                isRequired: true,
              ),
              _FormField(
                label: 'Full Name',
                controller: nameCtrl,
                hint: 'First Last',
                icon: Icons.person_rounded,
                iconColor: const Color(0xFF0891B2),
                isRequired: true,
              ),
              _FormField(
                label: 'Email',
                controller: emailCtrl,
                hint: 'name@school.edu.ph',
                icon: Icons.email_rounded,
                iconColor: const Color(0xFF0D9488),
                isRequired: true,
                keyboardType: TextInputType.emailAddress,
              ),
              _FormField(
                label: 'Contact',
                controller: contactCtrl,
                hint: '09123456789',
                icon: Icons.phone_rounded,
                iconColor: const Color(0xFF16A34A),
                keyboardType: TextInputType.phone,
              ),
              _FormField(
                label: 'Facebook',
                controller: facebookCtrl,
                hint: 'Your Facebook name',
                icon: Icons.facebook_rounded,
                iconColor: const Color(0xFF2563EB),
                isLast: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _GradientButton(
          label: 'Save Profile',
          icon: Icons.check_circle_rounded,
          onTap: onSave,
        ),
        const SizedBox(height: 10),
        const Center(
          child: Text(
            '* Required fields',
            style: TextStyle(
              fontSize: 11,
              color: _kSlate94,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
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
