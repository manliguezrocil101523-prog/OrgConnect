import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/unified_login_page.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  // ───────────────────────── Design tokens ─────────────────────────
  static const _primary = Color(0xFF059669); // emerald (text / buttons)
  static const _primaryLight = Color(0xFF10B981); // emerald (badges / checks)
  static const _primarySoft = Color(0xFFECFDF5); // emerald tint
  static const _primaryBorder = Color(0xFFA7F3D0);
  static const _bg = Color(0xFFF9FAFB);
  static const _border = Color(0xFFE5E7EB);
  static const _text = Color(0xFF111827);
  static const _muted = Color(0xFF6B7280);
  static const _hint = Color(0xFF9CA3AF);
  static const _red = Color(0xFFEF4444);
  static const _redSoft = Color(0xFFFEE2E2);

  static const double _desktopBreakpoint = 1024;

  // ───────────────────────── State / logic (unchanged) ─────────────────────────
  final _db = Supabase.instance.client;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _contact = TextEditingController();
  final _facebook = TextEditingController();
  final _scroll = ScrollController();

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
    _scroll.dispose();
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

  Future<String?> _uploadAvatar() async {
    if (_avatarBytes == null) return null;
    final user = _db.auth.currentUser;
    if (user == null) return null;

    final path =
        'admin_profiles/${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
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
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
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
                      obscureConfirm ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log out?'),
        content: const Text(
          'You will need to sign in again to access the admin dashboard.',
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

  // Same behaviour as the old header "Edit / Cancel" button.
  void _toggleEditing() {
    setState(() {
      _editing = !_editing;
      if (!_editing) _avatarBytes = null;
    });
  }

  // Used by the avatar camera badge: opens edit mode (never closes it).
  void _startEditing() {
    if (!_editing) setState(() => _editing = true);
  }

  // ───────────────────────── Build ─────────────────────────
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

    final isDesktop = MediaQuery.of(context).size.width > _desktopBreakpoint;
    final avatar = _imageProvider();
    final displayName = _name.text.trim().isEmpty ? 'Admin' : _name.text.trim();
    final hPad = isDesktop ? 32.0 : 16.0;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          Column(
            children: [
              if (!isDesktop) _buildMobileTopBar(displayName, avatar),
              Expanded(
                child: Scrollbar(
                  controller: _scroll,
                  thumbVisibility: isDesktop,
                  child: SingleChildScrollView(
                    controller: _scroll,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      hPad,
                      isDesktop ? 32 : 16,
                      hPad,
                      40,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child: _buildBody(
                          isDesktop: isDesktop,
                          displayName: displayName,
                          avatar: avatar,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_showZoom) _buildZoomOverlay(avatar),
        ],
      ),
    );
  }

  Widget _buildBody({
    required bool isDesktop,
    required String displayName,
    required ImageProvider? avatar,
  }) {
    final details = _buildProfileDetailsCard();
    final security = _buildSecurityCard();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isDesktop) ...[
          _buildPageTitle(),
          const SizedBox(height: 20),
        ],
        _buildHeader(
          isDesktop: isDesktop,
          displayName: displayName,
          avatar: avatar,
        ),
        const SizedBox(height: 20),
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: details),
              const SizedBox(width: 24),
              Expanded(flex: 5, child: security),
            ],
          )
        else ...[
          details,
          const SizedBox(height: 16),
          security,
        ],
        const SizedBox(height: 28),
        _buildFooter(),
      ],
    );
  }

  // ───────────────────────── Top bars ─────────────────────────
  Widget _buildMobileTopBar(String displayName, ImageProvider? avatar) {
    final initial = displayName.substring(0, 1).toUpperCase();
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _text,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Manage your account',
                      style: TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _showZoom = true),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: _primarySoft,
                  backgroundImage: avatar,
                  child: avatar == null
                      ? Text(
                          initial,
                          style: const TextStyle(
                            color: _primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageTitle() => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profile',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: _text,
              letterSpacing: -.3,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Manage your personal information and account security.',
            style: TextStyle(fontSize: 14, color: _muted),
          ),
        ],
      );

  // ───────────────────────── Header card ─────────────────────────
  Widget _buildHeader({
    required bool isDesktop,
    required String displayName,
    required ImageProvider? avatar,
  }) {
    final email = _email.text.trim();

    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: isDesktop ? 22 : 18,
            fontWeight: FontWeight.w700,
            color: _text,
            letterSpacing: -.2,
          ),
        ),
        if (email.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13.5, color: _muted),
          ),
        ],
        const SizedBox(height: 10),
        _buildRoleBadge(),
      ],
    );

    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 18),
      decoration: _cardDecoration(),
      child: isDesktop
          ? Row(
              children: [
                _buildAvatar(avatar, displayName, 88),
                const SizedBox(width: 20),
                Expanded(child: summary),
                const SizedBox(width: 16),
                _buildEditButton(),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _buildAvatar(avatar, displayName, 68),
                    const SizedBox(width: 14),
                    Expanded(child: summary),
                  ],
                ),
                const SizedBox(height: 16),
                _buildEditButton(),
              ],
            ),
    );
  }

  Widget _buildAvatar(ImageProvider? avatar, String displayName, double size) {
    final initial = displayName.substring(0, 1).toUpperCase();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: () => setState(() => _showZoom = true),
            child: Container(
              width: size,
              height: size,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _primaryBorder, width: 2),
              ),
              child: CircleAvatar(
                backgroundColor: _primarySoft,
                backgroundImage: avatar,
                child: avatar == null
                    ? Text(
                        initial,
                        style: TextStyle(
                          color: _primary,
                          fontWeight: FontWeight.w700,
                          fontSize: size * .34,
                        ),
                      )
                    : null,
              ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: GestureDetector(
              onTap: _startEditing,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _primaryLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _primarySoft,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _primaryBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: _primaryLight,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'ORGANIZATION ADMIN',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _primary,
                letterSpacing: .6,
              ),
            ),
          ],
        ),
      );

  Widget _buildEditButton() => OutlinedButton.icon(
        onPressed: _toggleEditing,
        icon: Icon(
          _editing ? Icons.close_rounded : Icons.edit_outlined,
          size: 18,
        ),
        label: Text(_editing ? 'Cancel' : 'Edit Profile'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _text,
          side: const BorderSide(color: _border),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

  // ───────────────────────── Profile details ─────────────────────────
  Widget _buildProfileDetailsCard() => _buildSectionCard(
        title: 'Profile Details',
        subtitle: _editing
            ? 'Update your information, then save your changes.'
            : 'Your personal information and contact details.',
        child: _editing ? _buildEditForm() : _buildInfoList(),
      );

  Widget _buildInfoList() => Column(
        children: [
          _buildInfoTile(
            icon: Icons.person_outline_rounded,
            label: 'FULL NAME',
            value: _name.text,
            color: _primary,
          ),
          const SizedBox(height: 10),
          _buildInfoTile(
            icon: Icons.mail_outline_rounded,
            label: 'EMAIL',
            value: _email.text,
            color: const Color(0xFF0D9488),
          ),
          const SizedBox(height: 10),
          _buildInfoTile(
            icon: Icons.phone_outlined,
            label: 'CONTACT NUMBER',
            value: _contact.text,
            color: const Color(0xFF0284C7),
          ),
          const SizedBox(height: 10),
          _buildInfoTile(
            icon: Icons.facebook_rounded,
            label: 'FACEBOOK',
            value: _facebook.text,
            color: const Color(0xFF2563EB),
          ),
        ],
      );

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final empty = value.trim().isEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          _IconBox(icon: icon, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: _muted,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  empty ? 'Not added yet' : value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.25,
                    fontWeight: empty ? FontWeight.w400 : FontWeight.w600,
                    color: empty ? _hint : _text,
                    fontStyle: empty ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            empty
                ? Icons.add_circle_outline_rounded
                : Icons.check_circle_rounded,
            color: empty ? const Color(0xFFD1D5DB) : _primaryLight,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildEditField(
            label: 'Full Name',
            controller: _name,
            icon: Icons.person_outline_rounded,
          ),
          _buildEditField(
            label: 'Email',
            controller: _email,
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
          _buildEditField(
            label: 'Contact Number',
            controller: _contact,
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          _buildEditField(
            label: 'Facebook / Social link',
            controller: _facebook,
            icon: Icons.facebook_rounded,
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : _toggleEditing,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _text,
                    side: const BorderSide(color: _border),
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
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
                      : const Icon(Icons.check_rounded, size: 20),
                  label: Text(_saving ? 'Saving...' : 'Save Profile'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );

  Widget _buildEditField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14.5, color: _text),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: _muted, fontSize: 14),
            floatingLabelStyle: const TextStyle(color: _primary),
            prefixIcon: Icon(icon, color: _muted, size: 20),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _primaryLight, width: 1.5),
            ),
          ),
        ),
      );

  // ───────────────────────── Account & security ─────────────────────────
  Widget _buildSecurityCard() {
    final email = _email.text.trim();
    return _buildSectionCard(
      title: 'Account & Security',
      subtitle: 'Manage your password and active session.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildGroupLabel('PASSWORD'),
          _buildActionTile(
            icon: Icons.vpn_key_outlined,
            color: _primary,
            title: 'Change Password',
            subtitle: 'Update your account password securely',
            onTap: _changePassword,
          ),
          const SizedBox(height: 22),
          _buildGroupLabel('SESSION'),
          _buildActionTile(
            icon: Icons.logout_rounded,
            color: _red,
            title: 'Log Out',
            titleColor: _red,
            subtitle:
                email.isNotEmpty ? 'Logged in as: $email' : 'Tap to sign out',
            background: _red.withValues(alpha: .04),
            borderColor: _redSoft,
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Widget _buildGroupLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: _hint,
            letterSpacing: 1,
          ),
        ),
      );

  Widget _buildActionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color titleColor = _text,
    Color background = _bg,
    Color borderColor = _border,
  }) =>
      Material(
        color: background,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                _IconBox(icon: icon, color: color),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: _muted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: color == _red ? _red : _hint,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      );

  // ───────────────────────── Shared pieces ─────────────────────────
  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) =>
      Container(
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _text,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 13, color: _muted, height: 1.35),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: _border),
            const SizedBox(height: 16),
            child,
          ],
        ),
      );

  Widget _buildFooter() => const Center(
        child: Text(
          'OrgConnect Admin • CSO Workspace v1.0',
          textAlign: TextAlign.center,
          style: TextStyle(color: _hint, fontSize: 12),
        ),
      );

  Widget _buildZoomOverlay(ImageProvider? avatar) => Positioned.fill(
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
                        backgroundColor: _primarySoft,
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
      );

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _text.withValues(alpha: .04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _IconBox({
    required this.icon,
    required this.color,
    this.size = 40.0, // Added default value here
  });

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: color,
          size: size * 0.48,
        ),
      );
}
