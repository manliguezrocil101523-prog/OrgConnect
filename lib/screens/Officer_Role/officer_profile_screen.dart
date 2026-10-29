import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/unified_login_page.dart';
import '../analytics/student_impact_screen.dart';
import '../../widgets/app_header.dart';

class OfficerProfileScreen extends StatefulWidget {
  final String initialName;
  final String initialAvatarUrl;
  final bool embedded;
  final String organizationId;
  final String organizationName;

  const OfficerProfileScreen({
    super.key,
    this.initialName = '',
    this.initialAvatarUrl = '',
    this.embedded = false,
    this.organizationId = '',
    this.organizationName = '',
  });

  @override
  State<OfficerProfileScreen> createState() => _OfficerProfileScreenState();
}

class _OfficerProfileScreenState extends State<OfficerProfileScreen> {
  static const _primary = Color(0xFF16A34A);
  // Matches the dark-to-green gradient used by the profile header.
  static const _headerStart = Color(0xFF064E3B);
  static const _secondary = Color(0xFF128058);
  static const _bg = Color(0xFFE6F7EE);
  static const _slate0F = Color(0xFF0F2D22);
  static const _slate94 = Color(0xFF64748B);
  static const _red = Color(0xFFDC2626);
  static const _teal = Color(0xFF0D9488);
  static const _blue = Color(0xFF2563EB);

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

  // Baseline values to restore on cancel
  String _origName = '';
  String _origEmail = '';
  String _origContact = '';
  String _origFacebook = '';
  String _origAvatarUrl = '';

  @override
  void initState() {
    super.initState();
    _name.text = widget.initialName.trim();
    _avatarUrl = widget.initialAvatarUrl.trim();
    _origName = _name.text;
    _origAvatarUrl = _avatarUrl;
    if (_name.text.isNotEmpty || _avatarUrl.isNotEmpty) {
      _loading = false;
    }
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
      if (mounted && _loading) setState(() => _loading = false);
      return;
    }
    try {
      final profile = await _db
          .from('profiles')
          .select('name,email,contact,facebook,avatar_url')
          .eq('id', user.id)
          .maybeSingle();
      if (profile != null) {
        final databaseName = '${profile['name'] ?? ''}'.trim();
        final databaseAvatar = '${profile['avatar_url'] ?? ''}'.trim();
        if (databaseName.isNotEmpty || _name.text.isEmpty) {
          _name.text = databaseName;
        }
        _email.text = '${profile['email'] ?? user.email ?? ''}';
        _contact.text = '${profile['contact'] ?? ''}';
        _facebook.text = '${profile['facebook'] ?? ''}';
        if (databaseAvatar.isNotEmpty || _avatarUrl.isEmpty) {
          _avatarUrl = databaseAvatar;
        }
        _origName = _name.text;
        _origEmail = _email.text;
        _origContact = _contact.text;
        _origFacebook = _facebook.text;
        _origAvatarUrl = _avatarUrl;
      } else {
        _email.text = user.email ?? '';
        _origEmail = _email.text;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load profile: $e')),
        );
      }
    } finally {
      if (mounted && _loading) setState(() => _loading = false);
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
        'officer_profiles/${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
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

      // Update baseline tracking
      _origName = _name.text;
      _origEmail = _email.text;
      _origContact = _contact.text;
      _origFacebook = _facebook.text;
      _origAvatarUrl = _avatarUrl;

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
    final currentPassword = TextEditingController();
    final password = TextEditingController();
    final confirm = TextEditingController();
    bool obscureCurrentPassword = true;
    bool obscurePassword = true;
    bool obscureConfirm = true;
    bool changing = false;

    final changed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          scrollable: true,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Row(
            children: [
              _IconBox(icon: Icons.lock_reset_rounded, color: _primary),
              SizedBox(width: 10),
              Flexible(child: Text('Change Password')),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPassword,
                  obscureText: obscureCurrentPassword,
                  enabled: !changing,
                  decoration: InputDecoration(
                    labelText: 'Current password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => setDialogState(
                        () => obscureCurrentPassword = !obscureCurrentPassword,
                      ),
                      icon: Icon(
                        obscureCurrentPassword
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
                      final oldPassword = currentPassword.text;
                      final newPassword = password.text.trim();
                      final confirmPassword = confirm.text.trim();
                      if (oldPassword.isEmpty) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter your current password.'),
                          ),
                        );
                        return;
                      }
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
                        final user = _db.auth.currentUser;
                        final email = user?.email;
                        if (user == null || email == null || email.isEmpty) {
                          throw Exception('Unable to verify the current account.');
                        }
                        await _db.auth.signInWithPassword(
                          email: email,
                          password: oldPassword,
                        );
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

    currentPassword.dispose();
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
          'You will need to sign in again to access the officer dashboard.',
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
      if (widget.embedded) {
        return const ColoredBox(
          color: _bg,
          child: Center(child: CircularProgressIndicator(color: _primary)),
        );
      }
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: CircularProgressIndicator(color: _primary),
        ),
      );
    }

    final avatar = _imageProvider();
    final displayName =
        _name.text.trim().isEmpty ? 'Officer' : _name.text.trim();
    final zoomSize =
        (MediaQuery.sizeOf(context).shortestSide * .75).clamp(200.0, 340.0);

    final profileBody = Stack(
      children: [
        Column(
          children: [
            AppHeader(
              title: displayName,
              subtitle: 'Organization Officer',
              status: 'OFFICER PROFILE',
              avatarImage: avatar,
              avatarEditing: _editing,
              squareBottom: true,
              onAvatarTap: () {
                if (_editing) {
                  _pickAvatar();
                } else if (avatar != null) {
                  setState(() => _showZoom = true);
                }
              },
              trailing: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => setState(() {
                    _editing = !_editing;
                    if (!_editing) {
                      _avatarBytes = null;
                      _name.text = _origName;
                      _email.text = _origEmail;
                      _contact.text = _origContact;
                      _facebook.text = _origFacebook;
                      _avatarUrl = _origAvatarUrl;
                    }
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
                          _editing ? Icons.close_rounded : Icons.edit_rounded,
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
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  final w = box.maxWidth;
                  final twoPane = w >= 1000;
                  final cols = !twoPane && w >= 720 ? 2 : 1;
                  final maxW = twoPane ? 1100.0 : (w >= 720 ? 760.0 : 540.0);
                  final pad = w < 360 ? 14.0 : (w < 720 ? 20.0 : 32.0);

                  final details = _detailsSection(cols);
                  final growth = _growthSection();
                  final account = _accountSection();

                  return Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding:
                          EdgeInsets.fromLTRB(pad, w >= 720 ? 32 : 22, pad, 48),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxW),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (twoPane)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 11,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: details,
                                      ),
                                    ),
                                    const SizedBox(width: 32),
                                    Expanded(
                                      flex: 9,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          ...growth,
                                          const SizedBox(height: 20),
                                          ...account,
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              else ...[
                                ...details,
                                const SizedBox(height: 18),
                                ...growth,
                                const SizedBox(height: 20),
                                ...account,
                              ],
                              const SizedBox(height: 16),
                              const Center(
                                child: Text(
                                  'OrgConnect Officer • Profile',
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
                  );
                },
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
                          width: zoomSize.toDouble(),
                          height: zoomSize.toDouble(),
                          padding: const EdgeInsets.all(5),
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
    );

    if (widget.embedded) return profileBody;
    return Scaffold(
      backgroundColor: _bg,
      body: profileBody,
    );
  }

  List<Widget> _detailsSection(int cols) {
    final fields = [
      (Icons.person_rounded, 'FULL NAME', 'Full Name', _name, _primary),
      (Icons.email_rounded, 'EMAIL', 'Email', _email, _teal),
      (Icons.phone_rounded, 'CONTACT', 'Contact', _contact, _primary),
      (
        Icons.facebook_rounded,
        'FACEBOOK',
        'Facebook / Social link',
        _facebook,
        _blue
      ),
    ];
    return [
      _sectionLabel('Profile Details'),
      const SizedBox(height: 12),
      ..._grid([
        for (final (icon, view, edit, ctrl, color) in fields)
          _editing
              ? _editCard(edit, ctrl, icon, color)
              : _infoCard(icon, view, ctrl.text, color),
      ], cols),
      if (_editing) ...[
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
          label: Text(_saving ? 'Saving...' : 'Save Profile'),
          style: FilledButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    ];
  }

  List<Widget> _growthSection() => [
        _sectionLabel('Growth & Impact'),
        const SizedBox(height: 12),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StudentImpactScreen(
                  organizationId: widget.organizationId.isEmpty
                      ? null
                      : widget.organizationId,
                  organizationName: widget.organizationName.isEmpty
                      ? null
                      : widget.organizationName,
                ),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 17, 14, 17),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_headerStart, _secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _primary.withValues(alpha: .16),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  _IconBox(icon: Icons.insights_rounded, color: Colors.white),
                  SizedBox(width: 13),
                  Expanded(
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
                          'Record how your organization supports your growth.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Icon(
  Icons.chevron_right_rounded,
  color: Colors.white,
),
                ],
              ),
            ),
          ),
        ),
      ];

  List<Widget> _accountSection() => [
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
                  contentPadding: const EdgeInsets.symmetric(
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
                    style: TextStyle(fontSize: 11.5, color: _slate94),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.black,
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
                  contentPadding: const EdgeInsets.symmetric(
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
                    style: const TextStyle(fontSize: 11.5, color: _slate94),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.black,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ];

  List<Widget> _grid(List<Widget> items, int cols) => [
        for (var i = 0; i < items.length; i += cols)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: cols == 1
                ? items[i]
                : IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var j = i; j < i + cols; j++) ...[
                          if (j > i) const SizedBox(width: 12),
                          Expanded(
                            child: j < items.length
                                ? items[j]
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
      ];

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
          Flexible(
            child: Text(
              text.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF087F5B),
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ],
      );

  Widget _infoCard(IconData icon, String label, String value, Color color) {
    final empty = value.trim().isEmpty;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            height: 46,
            child: Center(
              child: Icon(icon, color: color, size: 21),
            ),
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
        ],
      ),
    );
  }

  Widget _editCard(
    String label,
    TextEditingController controller,
    IconData icon,
    Color color,
  ) =>
      Container(
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
  Widget build(BuildContext context) => SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: Icon(icon, color: color, size: 19),
        ),
      );
}
