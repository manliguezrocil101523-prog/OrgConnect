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
  static const green = Color(0xFF16A34A);
  static const bg = Color(0xFFF3FAF5);
  final _db = Supabase.instance.client;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _contact = TextEditingController();
  final _facebook = TextEditingController();
  Uint8List? _bytes;
  String _avatar = '';
  bool _loading = true, _saving = false, _editing = false;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { for (final c in [_name,_email,_contact,_facebook]) c.dispose(); super.dispose(); }

  Future<void> _load() async {
    final u = _db.auth.currentUser;
    if (u == null) return;
    try {
      final p = await _db.from('profiles').select('name,email,contact,facebook,avatar_url').eq('id', u.id).maybeSingle();
      if (p != null) {
        _name.text = p['name'] ?? ''; _email.text = p['email'] ?? u.email ?? '';
        _contact.text = p['contact'] ?? ''; _facebook.text = p['facebook'] ?? ''; _avatar = p['avatar_url'] ?? '';
      } else { _email.text = u.email ?? ''; }
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _pick() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (r?.files.single.bytes != null) setState(() => _bytes = r!.files.single.bytes);
  }

  Future<String?> _upload() async {
    if (_bytes == null) return null;
    final path = 'adviser_profiles/${_db.auth.currentUser!.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _db.storage.from('avatar').uploadBinary(path, _bytes!, fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true));
    return _db.storage.from('avatar').getPublicUrl(path);
  }

  Future<void> _changePassword() async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscurePassword = true;
    bool obscureConfirm = true;
    bool changing = false;

    final changed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Row(
            children: [
              Icon(Icons.lock_reset_rounded, color: green),
              SizedBox(width: 10),
              Text('Change Password'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                enabled: !changing,
                decoration: InputDecoration(
                  labelText: 'New password',
                  hintText: 'At least 6 characters',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                    icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: confirmController,
                obscureText: obscureConfirm,
                enabled: !changing,
                decoration: InputDecoration(
                  labelText: 'Confirm password',
                  prefixIcon: const Icon(Icons.verified_user_outlined),
                  suffixIcon: IconButton(
                    onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                    icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: changing ? null : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: green),
              onPressed: changing
                  ? null
                  : () async {
                      final password = passwordController.text.trim();
                      final confirm = confirmController.text.trim();
                      if (password.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password must be at least 6 characters.')),
                        );
                        return;
                      }
                      if (password != confirm) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Passwords do not match.')),
                        );
                        return;
                      }

                      setDialogState(() => changing = true);
                      try {
                        await _db.auth.updateUser(UserAttributes(password: password));
                        if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                      } catch (e) {
                        setDialogState(() => changing = false);
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(content: Text('Could not change password: $e')),
                          );
                        }
                      }
                    },
              child: changing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Update Password'),
            ),
          ],
        ),
      ),
    );

    passwordController.dispose();
    confirmController.dispose();

    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully.'), backgroundColor: green),
      );
    }
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to access the adviser dashboard.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: green),
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
          SnackBar(content: Text('Could not log out: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _save() async {
    final u = _db.auth.currentUser; if (u == null) return;
    setState(() => _saving = true);
    try {
      final uploaded = await _upload();
      await _db.from('profiles').update({'name':_name.text.trim(),'email':_email.text.trim(),'contact':_contact.text.trim(),'facebook':_facebook.text.trim(), if (uploaded != null) 'avatar_url':uploaded}).eq('id',u.id);
      if (uploaded != null) _avatar = uploaded;
      if (mounted) { setState(() { _saving=false; _editing=false; }); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated.'), backgroundColor: green)); }
    } catch (e) { if (mounted) { setState(() => _saving=false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update profile: $e'), backgroundColor: Colors.red)); } }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: bg,
    appBar: AppBar(title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.w800)), backgroundColor: green, foregroundColor: Colors.white, elevation: 0, automaticallyImplyLeading: false),
    body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 30), children: [
      Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF14532D), green], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: green.withOpacity(.18), blurRadius: 20, offset: const Offset(0, 8))]),
        child: Column(children: [
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.white.withOpacity(.14), borderRadius: BorderRadius.circular(30)), child: const Row(children: [Icon(Icons.verified_user_outlined, size: 14, color: Colors.white), SizedBox(width: 5), Text('ADVISER ACCOUNT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .8))])),
            const Spacer(),
            if (_editing) IconButton(onPressed: _pick, icon: const Icon(Icons.camera_alt_outlined, color: Colors.white), tooltip: 'Change photo'),
          ]),
          const SizedBox(height: 18),
          GestureDetector(onTap: _editing ? _pick : null, child: Stack(alignment: Alignment.bottomRight, children: [CircleAvatar(radius: 50, backgroundColor: Colors.white.withOpacity(.2), backgroundImage: _bytes != null ? MemoryImage(_bytes!) : (_avatar.isNotEmpty ? NetworkImage(_avatar) : null) as ImageProvider?, child: (_bytes == null && _avatar.isEmpty) ? const Icon(Icons.person_rounded, size: 50, color: Colors.white) : null), if (_editing) Container(padding: const EdgeInsets.all(7), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.edit_rounded, color: green, size: 17))])),
          const SizedBox(height: 13),
          Text(_name.text.isEmpty ? 'Adviser' : _name.text, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4), const Text('Organization Adviser', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
          if (_email.text.isNotEmpty) ...[const SizedBox(height: 8), Text(_email.text, style: const TextStyle(color: Colors.white70, fontSize: 12))],
        ]),
      ),
      const SizedBox(height: 18),
      Row(children: [Expanded(child: _profileQuickCard(Icons.edit_outlined, _editing ? 'Editing mode' : 'Profile', _editing ? 'Make your changes below' : 'Keep details current', _editing ? green : const Color(0xFF2563EB))), const SizedBox(width: 10), Expanded(child: _profileQuickCard(Icons.lock_outline_rounded, 'Security', 'Password protected', const Color(0xFF7C3AED)))]),
      const SizedBox(height: 20),
      _profileSection('Personal information', Icons.person_outline_rounded, [_field('Full name', _name, Icons.person_outline), _field('Email', _email, Icons.email_outlined), _field('Contact number', _contact, Icons.phone_outlined), _field('Facebook / Social link', _facebook, Icons.link)]),
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: _saving ? null : (_editing ? _save : () => setState(() => _editing = true)), icon: Icon(_editing ? Icons.check_rounded : Icons.edit_outlined), label: Text(_saving ? 'Saving…' : (_editing ? 'Save Profile' : 'Edit Profile')), style: FilledButton.styleFrom(backgroundColor: green, minimumSize: const Size(double.infinity, 54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
      if (_editing) Padding(padding: const EdgeInsets.only(top: 5), child: TextButton(onPressed: () { setState(() { _editing = false; _bytes = null; }); _load(); }, child: const Text('Cancel changes'))),
      const SizedBox(height: 22),
      _profileSection('Account & security', Icons.shield_outlined, [
        _actionTile(Icons.lock_reset_rounded, 'Change Password', 'Update your adviser account password', green, _changePassword),
        const Divider(height: 1),
        _actionTile(Icons.logout_rounded, 'Log Out', 'Sign out of your adviser account', Colors.red, _logout),
      ]),
      const SizedBox(height: 10),
      const Center(child: Text('OrgConnect Adviser • Profile', style: TextStyle(color: Color(0xFF94A3A8), fontSize: 11))),
    ]),
  );

  Widget _profileQuickCard(IconData icon, String title, String subtitle, Color color) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.035), blurRadius: 12, offset: const Offset(0, 4))]),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: color.withOpacity(.1), borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: color, size: 20)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF12352A))),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF6B8178), height: 1.25)),
      ])),
    ]),
  );

  Widget _profileSection(String title, IconData icon, List<Widget> children) => Container(padding: const EdgeInsets.fromLTRB(16, 15, 16, 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.035), blurRadius: 14, offset: const Offset(0, 5))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: green.withOpacity(.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: green, size: 19)), const SizedBox(width: 10), Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF12352A)))]), const SizedBox(height: 14), ...children]));

  Widget _actionTile(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) => ListTile(contentPadding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2), leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(.09), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color)), title: Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: color == Colors.red ? Colors.red : const Color(0xFF12352A))), subtitle: Text(subtitle, style: const TextStyle(color: Color(0xFF6B8178), fontSize: 11)), trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3A8)), onTap: onTap);

  Widget _field(String label, TextEditingController c, IconData icon) => Padding(padding:const EdgeInsets.only(bottom:12), child: TextField(controller:c, enabled:_editing, decoration:InputDecoration(labelText:label,prefixIcon:Icon(icon,color:green),filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.circular(14),borderSide:BorderSide.none),disabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(14),borderSide:BorderSide(color:Colors.grey.shade200)))));
}
