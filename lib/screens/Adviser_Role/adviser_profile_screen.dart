import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/unified_login_page.dart';

class AdviserProfileScreen extends StatefulWidget {
  const AdviserProfileScreen({super.key});

  @override
  State<AdviserProfileScreen> createState() => _AdviserProfileScreenState();
}

class _AdviserProfileScreenState extends State<AdviserProfileScreen> {
  static const _primary = Color(0xFF16A34A);
  static const _secondary = Color(0xFF128058);
  static const _bg = Color(0xFFF3FAF5);
  static const _slate0F = Color(0xFF0F2D22);
  static const _slate94 = Color(0xFF64748B);
  static const _red = Color(0xFFDC2626);

  final _db = Supabase.instance.client;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _contact = TextEditingController();
  final _facebook = TextEditingController();

  Uint8List? _avatarBytes;
  String _avatarUrl = '';
  bool _loading = true;
  bool _saving = false;
  bool _editing = false;
  bool _showZoom = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _contact.dispose();
    _facebook.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = _db.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final profile = await _db
          .from('profiles')
          .select('name,email,contact,facebook,avatar_url')
          .eq('id', user.id)
          .maybeSingle();
      if (profile != null) {
        _name.text = '${profile['name'] ?? ''}';
        _email.text = '${profile['email'] ?? user.email ?? ''}';
        _contact.text = '${profile['contact'] ?? ''}';
        _facebook.text = '${profile['facebook'] ?? ''}';
        _avatarUrl = '${profile['avatar_url'] ?? ''}';
      } else {
        _email.text = user.email ?? '';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes != null && mounted) {
      setState(() => _avatarBytes = bytes);
    }
  }

  Future<String?> _uploadAvatar() async {
    if (_avatarBytes == null) return null;
    final user = _db.auth.currentUser;
    if (user == null) return null;

    final path =
        'adviser_profiles/${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _db.storage.from('avatar').uploadBinary(
          path,
          _avatarBytes!,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    return _db.storage.from('avatar').getPublicUrl(path);
  }

  Future<void> _save() async {
    final user = _db.auth.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      final uploaded = await _uploadAvatar();
      final values = <String, dynamic>{
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'contact': _contact.text.trim(),
        'facebook': _facebook.text.trim(),
      };
      if (uploaded != null) {
        values['avatar_url'] = uploaded;
      }
      await _db.from('profiles').update(values).eq('id', user.id);
      if (uploaded != null) _avatarUrl = uploaded;
      if (!mounted) return;
      setState(() {
        _saving = false;
        _editing = false;
        _avatarBytes = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully.'),
          backgroundColor: _primary,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not update profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _changePassword() async {
    final password = TextEditingController();
    final confirm = TextEditingController();
    bool obscurePassword = true;
    bool obscureConfirm = true;
    bool changing = false;

    final changed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Row(
            children: [
              _IconBox(icon: Icons.lock_reset_rounded, color: _primary),
              SizedBox(width: 10),
              Text('Change Password'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: password,
                obscureText: obscurePassword,
                enabled: !changing,
                decoration: InputDecoration(
                  labelText: 'New password',
                  hintText: 'At least 6 characters',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () => setDialogState(
                      () => obscurePassword = !obscurePassword,
                    ),
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: confirm,
                obscureText: obscureConfirm,
                enabled: !changing,
                decoration: InputDecoration(
                  labelText: 'Confirm password',
                  prefixIcon: const Icon(Icons.verified_user_outlined),
                  suffixIcon: IconButton(
                    onPressed: () => setDialogState(
                      () => obscureConfirm = !obscureConfirm,
                    ),
                    icon: Icon(
                      obscureConfirm
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed:
                  changing ? null : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _primary),
              onPressed: changing
                  ? null
                  : () async {
                      final newPassword = password.text.trim();
                      final confirmPassword = confirm.text.trim();
                      if (newPassword.length < 6) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Password must be at least 6 characters.'),
                          ),
                        );
                        return;
                      }
                      if (newPassword != confirmPassword) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text('Passwords do not match.'),
                          ),
                        );
                        return;
                      }
                      setDialogState(() => changing = true);
                      try {
                        await _db.auth.updateUser(
                          UserAttributes(password: newPassword),
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (e) {
                        if (dialogContext.mounted) {
                          setDialogState(() => changing = false);
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text('Could not change password: $e'),
                            ),
                          );
                        }
                      }
                    },
              child: changing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Update Password'),
            ),
          ],
        ),
      ),
    );

    password.dispose();
    confirm.dispose();
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated successfully.'),
          backgroundColor: _primary,
        ),
      );
    }
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log out?'),
        content: const Text(
          'You will need to sign in again to access the adviser dashboard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (shouldLogout != true || !mounted) return;

    try {
      await _db.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const UnifiedLoginPage()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not log out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  ImageProvider? _imageProvider() {
    if (_avatarBytes != null) return MemoryImage(_avatarBytes!);
    if (_avatarUrl.trim().isNotEmpty) return NetworkImage(_avatarUrl);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: CircularProgressIndicator(color: _primary),
        ),
      );
    }

    final avatar = _imageProvider();
    final displayName = _name.text.trim().isEmpty ? 'Adviser' : _name.text.trim();

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          Column(
            children: [
              SizedBox(
                height: 150,
                width: double.infinity,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_secondary, _primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -30,
                        top: -50,
                        child: _orb(150, Colors.white.withValues(alpha: .07)),
                      ),
                      Positioned(
                        left: -35,
                        bottom: -55,
                        child: _orb(115, Colors.white.withValues(alpha: .05)),
                      ),
                      SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 14, 0),
                          child: Row(
                            children: [
                              const Text(
                                'Profile',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () => setState(() {
                                  _editing = !_editing;
                                  if (!_editing) _avatarBytes = null;
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: .15),
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: .30),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _editing
                                            ? Icons.close_rounded
                                            : Icons.edit_rounded,
                                        color: Colors.white,
                                        size: 15,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        _editing ? 'Cancel' : 'Edit',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 12,
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (_editing) {
                                  _pickAvatar();
                                } else if (avatar != null) {
                                  setState(() => _showZoom = true);
                                }
                              },
                              child: Stack(
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
                                      backgroundColor: const Color(0xFFE8F5EC),
                                      backgroundImage: avatar,
                                      child: avatar == null
                                          ? const Icon(
                                              Icons.person_rounded,
                                              color: _primary,
                                              size: 38,
                                            )
                                          : null,
                                    ),
                                  ),
                                  if (_editing)
                                    Positioned(
                                      right: -2,
                                      bottom: -2,
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        decoration: const BoxDecoration(
                                          color: _primary,
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
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Organization Adviser',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: .82),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
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
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 48),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 540),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _sectionLabel('Profile Details'),
                            const SizedBox(height: 12),
                            if (_editing) ...[
                              _editCard(
                                'Full Name',
                                _name,
                                Icons.person_rounded,
                                _primary,
                              ),
                              _editCard(
                                'Email',
                                _email,
                                Icons.email_rounded,
                                const Color(0xFF0D9488),
                              ),
                              _editCard(
                                'Contact',
                                _contact,
                                Icons.phone_rounded,
                                _primary,
                              ),
                              _editCard(
                                'Facebook / Social link',
                                _facebook,
                                Icons.facebook_rounded,
                                const Color(0xFF2563EB),
                              ),
                              const SizedBox(height: 8),
                              FilledButton.icon(
                                onPressed: _saving ? null : _save,
                                icon: _saving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.check_rounded),
                                label: Text(
                                  _saving ? 'Saving...' : 'Save Profile',
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _primary,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 52),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ] else ...[
                              _infoCard(
                                Icons.person_rounded,
                                'FULL NAME',
                                _name.text,
                                _primary,
                              ),
                              _infoCard(
                                Icons.email_rounded,
                                'EMAIL',
                                _email.text,
                                const Color(0xFF0D9488),
                              ),
                              _infoCard(
                                Icons.phone_rounded,
                                'CONTACT',
                                _contact.text,
                                _primary,
                              ),
                              _infoCard(
                                Icons.facebook_rounded,
                                'FACEBOOK',
                                _facebook.text,
                                const Color(0xFF2563EB),
                              ),
                            ],
                            const SizedBox(height: 20),
                            _sectionLabel('Account & Security'),
                            const SizedBox(height: 12),
                            Container(
                              decoration: _cardDecoration(),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Column(
                                  children: [
                                    ListTile(
                                      onTap: _changePassword,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 8,
                                      ),
                                      leading: const _IconBox(
                                        icon: Icons.lock_reset_rounded,
                                        color: _primary,
                                      ),
                                      title: const Text(
                                        'Change Password',
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                          color: _slate0F,
                                        ),
                                      ),
                                      subtitle: const Text(
                                        'Update your account password securely',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: _slate94,
                                        ),
                                      ),
                                      trailing: const Icon(
                                        Icons.chevron_right_rounded,
                                        color: _primary,
                                      ),
                                    ),
                                    Divider(
                                      height: 1,
                                      indent: 76,
                                      endIndent: 20,
                                      color: Colors.grey.shade100,
                                    ),
                                    ListTile(
                                      onTap: _logout,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 8,
                                      ),
                                      leading: const _IconBox(
                                        icon: Icons.logout_rounded,
                                        color: _red,
                                      ),
                                      title: const Text(
                                        'Log Out',
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                          color: _red,
                                        ),
                                      ),
                                      subtitle: Text(
                                        _email.text.trim().isNotEmpty
                                            ? 'Logged in as: ${_email.text.trim()}'
                                            : 'Tap to sign out',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: _slate94,
                                        ),
                                      ),
                                      trailing: Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: _red.withValues(alpha: .08),
                                          borderRadius:
                                              BorderRadius.circular(9),
                                        ),
                                        child: const Icon(
                                          Icons.chevron_right_rounded,
                                          color: _red,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Center(
                              child: Text(
                                'OrgConnect Adviser • Profile',
                                style: TextStyle(
                                  color: Color(0xFF94A3A8),
                                  fontSize: 11,
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
            ],
          ),
          if (_showZoom)
            Positioned.fill(
              child: Material(
                color: Colors.black.withValues(alpha: .72),
                child: SafeArea(
                  child: Stack(
                    children: [
                      Center(
                        child: GestureDetector(
                          onTap: () => setState(() => _showZoom = false),
                          child: Container(
                            width: 270,
                            height: 270,
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              backgroundColor: Color(0xFFE8F5EC),
                              backgroundImage: avatar,
                              child: avatar == null
                                  ? const Icon(
                                      Icons.person_rounded,
                                      color: _primary,
                                      size: 100,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 16,
                        child: IconButton(
                          onPressed: () => setState(() => _showZoom = false),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _orb(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  Widget _sectionLabel(String text) => Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: _primary,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            text.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF087F5B),
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ],
      );

  Widget _infoCard(IconData icon, String label, String value, Color color) {
    final empty = value.trim().isEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: .14),
                  color.withValues(alpha: .06),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _slate94,
                    letterSpacing: .9,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  empty ? 'Not added yet' : value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.25,
                    fontWeight: empty ? FontWeight.w400 : FontWeight.w700,
                    color: empty ? const Color(0xFFCBD5E1) : _slate0F,
                    fontStyle: empty ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            empty ? Icons.add_circle_outline_rounded : Icons.check_circle_rounded,
            color: empty ? const Color(0xFFE2E8F0) : color.withValues(alpha: .65),
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _editCard(
    String label,
    TextEditingController controller,
    IconData icon,
    Color color,
  ) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: _cardDecoration(),
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: color),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: color.withValues(alpha: .10)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: _primary, width: 1.5),
            ),
          ),
        ),
      );

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: .055),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      );
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconBox({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: color, size: 19),
      );
}
