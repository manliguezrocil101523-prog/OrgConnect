import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/unified_login_page.dart';
import '../analytics/student_impact_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../widgets/app_header.dart';

// ─── Shared constants ────────────────────────────────────────────────────────
const _kPrimary = Color(0xFF16A34A);
const _kSecondary = Color(0xFF0F766E);
const _kSuccess = Color(0xFF22C55E);
const _kBg = Color(0xFFE6F7EE);
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
        padding: const EdgeInsets.all(10),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
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
  bool _isLoading = true;
  bool _showZoom = false;
  Map<String, dynamic>? _profile;

  late final AnimationController _headerAnim;

  @override
  void initState() {
    super.initState();
    _headerAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
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
                    color: Colors.black.withValues(alpha: 0.12),
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
                    color: _kRed.withValues(alpha: 0.08),
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
                                color: _kRed.withValues(alpha: 0.30),
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

            // 1) Verify the current password
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

            // 2) Only now set the new password
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
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: const Row(
              children: [
                Icon(Icons.lock_reset_rounded, color: _kPrimary),
                SizedBox(width: 10),
                Text('Change Password'),
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
                    decoration: InputDecoration(
                      labelText: 'Current password',
                      hintText: 'Enter your current password',
                      prefixIcon: const Icon(Icons.lock_clock_outlined),
                      suffixIcon: IconButton(
                        onPressed: () => setDialogState(
                            () => currentObscure = !currentObscure),
                        icon: Icon(currentObscure
                            ? Icons.visibility_off
                            : Icons.visibility),
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    obscureText: obscure,
                    enabled: !isSaving,
                    decoration: InputDecoration(
                      labelText: 'New password',
                      hintText: 'Enter a new password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setDialogState(() => obscure = !obscure),
                        icon: Icon(
                            obscure ? Icons.visibility_off : Icons.visibility),
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: confirmController,
                    obscureText: confirmObscure,
                    enabled: !isSaving,
                    decoration: InputDecoration(
                      labelText: 'Confirm new password',
                      hintText: 'Re-enter your new password',
                      prefixIcon: const Icon(Icons.verified_user_outlined),
                      suffixIcon: IconButton(
                        onPressed: () => setDialogState(
                            () => confirmObscure = !confirmObscure),
                        icon: Icon(confirmObscure
                            ? Icons.visibility_off
                            : Icons.visibility),
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
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
                  child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _kPrimary),
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

    currentController.dispose();
    controller.dispose();
    confirmController.dispose();
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully.')));
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

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          Column(
            children: [
              AppHeader(
                title: (_profile?['name'] ?? '').toString().isEmpty
                    ? 'Your Profile'
                    : (_profile?['name'] ?? '').toString(),
                subtitle: (_profile?['student_id'] ?? '').toString().isEmpty
                    ? 'Manage your account'
                    : (_profile?['student_id'] ?? '').toString(),
                status: 'STUDENT PROFILE',
                avatarImage: avatarImage,
                onAvatarTap: () => setState(() => _showZoom = true),
                trailing: _AppBarActionButton(
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
              ),
              Expanded(
                child: ScrollConfiguration(
                  behavior: const MaterialScrollBehavior()
                      .copyWith(scrollbars: false),
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
                          loggedInEmail: Supabase
                                  .instance.client.auth.currentUser?.email ??
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
          color:
              isEditing ? Colors.white : Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: isEditing
              ? null
              : Border.all(
                  color: Colors.white.withValues(alpha: 0.35), width: 1),
          boxShadow: isEditing
              ? [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
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
      const _SectionLabel(text: 'Growth & Impact'),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StudentImpactScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 17, 14, 17),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kPrimary, _kSecondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _kPrimary.withValues(alpha: .16),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: .25)),
                ),
                child: const Icon(Icons.insights_rounded,
                    color: Colors.white, size: 23),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Organization Impact',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Record how your organizations support your growth.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white, size: 23),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                leading:
                    _IconBox(icon: Icons.lock_reset_rounded, color: _kPrimary),
                title: const Text('Change Password',
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: _kSlate0F)),
                subtitle: const Text('Update your account password securely',
                    style: TextStyle(fontSize: 11.5, color: _kSlate94)),
                trailing:
                    const Icon(Icons.chevron_right_rounded, color: _kPrimary),
              ),
              Divider(
                  height: 1,
                  indent: 76,
                  endIndent: 20,
                  color: Colors.grey.shade100),
              ListTile(
                onTap: onLogout,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                leading: _IconBox(icon: Icons.logout_rounded, color: _kRed),
                title: const Text('Log Out',
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: _kRed)),
                subtitle: Text(
                  loggedInEmail.isNotEmpty
                      ? 'Logged in as: $loggedInEmail'
                      : 'Tap to sign out',
                  style: const TextStyle(fontSize: 11.5, color: _kSlate94),
                ),
                trailing: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                      color: _kRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(9)),
                  child: const Icon(Icons.chevron_right_rounded,
                      color: _kRed, size: 18),
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
  const _IconBox({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
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
                colors: [
                  fieldDef.color.withValues(alpha: .14),
                  fieldDef.color.withValues(alpha: .06)
                ],
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
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _kSlate94,
                      letterSpacing: .9),
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
            isEmpty
                ? Icons.add_circle_outline_rounded
                : Icons.check_circle_rounded,
            color: isEmpty ? _kSlateE2 : fieldDef.color.withValues(alpha: .65),
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

  Future<void> _showAvatarOptions() async {
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
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _handleUploadAvatar();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: const Text('Take a photo'),
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

  @override
  Widget build(BuildContext context) {
    final ImageProvider? currentAvatar = _localAvatarBytes != null
        ? MemoryImage(_localAvatarBytes!)
        : widget.avatarImage;

    return Scaffold(
      backgroundColor: const Color(0xFFE6F7EE),
      body: Column(
        children: [
          AppHeader(
            title: 'Edit Profile',
            subtitle: 'Manage your account',
            status: 'STUDENT PROFILE',
            avatarImage: currentAvatar,
            avatarEditing: true,
            onAvatarTap: _showAvatarOptions,
            trailing: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withValues(alpha: .30)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close_rounded, color: Colors.white, size: 15),
                    SizedBox(width: 5),
                    Text('Cancel', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 48),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: _EditForm(
                      studentIdCtrl: widget.studentIdCtrl,
                      nameCtrl: widget.nameCtrl,
                      emailCtrl: widget.emailCtrl,
                      contactCtrl: widget.contactCtrl,
                      facebookCtrl: widget.facebookCtrl,
                      onSave: () async {
                        final ok = await widget.onSave();
                        if (ok && context.mounted) Navigator.pop(context);
                      },
                    ),
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

// =============================================================================
// _EditForm
// =============================================================================
class _EditForm extends StatelessWidget {
  final TextEditingController studentIdCtrl;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController contactCtrl;
  final TextEditingController facebookCtrl;
  final VoidCallback onSave;

  const _EditForm({
    required this.studentIdCtrl,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.contactCtrl,
    required this.facebookCtrl,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
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
  const _GradientButton({
    required this.label,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 54,
          decoration: BoxDecoration(
            gradient: _kGrad,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: _kPrimary.withValues(alpha: 0.32),
                  blurRadius: 16,
                  offset: const Offset(0, 6))
            ],
          ),
          child: Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
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
