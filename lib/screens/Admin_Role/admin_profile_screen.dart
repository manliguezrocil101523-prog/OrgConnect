import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/unified_login_page.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});
  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  static const green = Color(0xFF16A34A);
  static const bg = Color(0xFFF3FAF5);
  final db = Supabase.instance.client;
  final name = TextEditingController();
  final email = TextEditingController();
  final contact = TextEditingController();
  Uint8List? bytes;
  String avatar = '';
  bool loading = true, saving = false, editing = false;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { name.dispose(); email.dispose(); contact.dispose(); super.dispose(); }

  Future<void> _load() async {
    final u = db.auth.currentUser;
    if (u == null) return;
    try {
      final p = await db.from('profiles').select('name,email,contact,avatar_url').eq('id', u.id).maybeSingle();
      name.text = p?['name']?.toString() ?? 'Administrator';
      email.text = p?['email']?.toString() ?? u.email ?? '';
      contact.text = p?['contact']?.toString() ?? '';
      avatar = p?['avatar_url']?.toString() ?? '';
    } finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> _pick() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (r?.files.single.bytes != null) setState(() => bytes = r!.files.single.bytes);
  }

  Future<String?> _upload() async {
    if (bytes == null) return null;
    final path = 'admin_profiles/${db.auth.currentUser!.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await db.storage.from('avatar').uploadBinary(path, bytes!, fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true));
    return db.storage.from('avatar').getPublicUrl(path);
  }

  Future<void> _save() async {
    final u = db.auth.currentUser;
    if (u == null) return;
    setState(() => saving = true);
    try {
      final uploaded = await _upload();
      await db.from('profiles').update({'name': name.text.trim(), 'email': email.text.trim(), 'contact': contact.text.trim(), if (uploaded != null) 'avatar_url': uploaded}).eq('id', u.id);
      if (uploaded != null) avatar = uploaded;
      if (mounted) setState(() { saving = false; editing = false; bytes = null; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admin profile updated.'), backgroundColor: green));
    } catch (e) {
      if (mounted) setState(() => saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update profile: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _password() async {
    final a = TextEditingController(), b = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Row(children: [Icon(Icons.lock_reset_rounded, color: green), SizedBox(width: 10), Text('Change Password')]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: a, obscureText: true, decoration: const InputDecoration(labelText: 'New password', prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: b, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm password', prefixIcon: Icon(Icons.verified_user_outlined), border: OutlineInputBorder())),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(style: FilledButton.styleFrom(backgroundColor: green), onPressed: () async {
        if (a.text.trim().length < 6 || a.text.trim() != b.text.trim()) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Use at least 6 characters and make both passwords match.'))); return;
        }
        try { await db.auth.updateUser(UserAttributes(password: a.text.trim())); if (ctx.mounted) Navigator.pop(ctx, true); }
        catch (e) { if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Could not change password: $e'))); }
      }, child: const Text('Update'))],
    ));
    a.dispose(); b.dispose();
    if (ok == true && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed successfully.'), backgroundColor: green));
  }

  Future<void> _logout() async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Log out?'), content: const Text('You will need to sign in again to access the Admin / CSO dashboard.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(style: FilledButton.styleFrom(backgroundColor: green), onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out'))],
    ));
    if (yes != true || !mounted) return;
    await db.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const UnifiedLoginPage()), (_) => false);
  }

  Widget _avatar() {
    final image = bytes != null ? MemoryImage(bytes!) : (avatar.isNotEmpty ? NetworkImage(avatar) : null);
    return Stack(children: [
      CircleAvatar(radius: 54, backgroundColor: Colors.white.withOpacity(.18), backgroundImage: image as ImageProvider?, child: image == null ? const Icon(Icons.admin_panel_settings_rounded, size: 48, color: Colors.white) : null),
      if (editing) Positioned(right: 0, bottom: 0, child: InkWell(onTap: _pick, child: Container(padding: const EdgeInsets.all(9), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.camera_alt_rounded, color: green, size: 18))))
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(title: const Text('Admin Profile', style: TextStyle(fontWeight: FontWeight.w800)), backgroundColor: green, foregroundColor: Colors.white, elevation: 0, automaticallyImplyLeading: false),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF14532D), green]), borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: green.withOpacity(.18), blurRadius: 22, offset: const Offset(0, 10))]),
                  child: Column(children: [
                    _avatar(),
                    const SizedBox(height: 14),
                    Text(name.text.isEmpty ? 'Administrator' : name.text, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text('Admin / CSO', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: green), onPressed: () => setState(() => editing = !editing), icon: Icon(editing ? Icons.close_rounded : Icons.edit_rounded), label: Text(editing ? 'Cancel Editing' : 'Edit Profile')),
                  ]),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFDDEDE2))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Account Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 14),
                    TextField(controller: name, enabled: editing, decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: email, enabled: editing, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: contact, enabled: editing, decoration: const InputDecoration(labelText: 'Contact', prefixIcon: Icon(Icons.phone_outlined), border: OutlineInputBorder())),
                    if (editing) ...[
                      const SizedBox(height: 14),
                      SizedBox(width: double.infinity, child: FilledButton.icon(style: ButtonStyle(backgroundColor: MaterialStatePropertyAll(green)), onPressed: saving ? null : _save, icon: const Icon(Icons.save_rounded), label: Text(saving ? 'Saving...' : 'Save Changes'))),
                    ],
                  ]),
                ),
                const SizedBox(height: 14),
                _action(Icons.lock_reset_rounded, 'Change Password', 'Update your Supabase account password', _password),
                const SizedBox(height: 10),
                _action(Icons.logout_rounded, 'Log Out', 'Sign out of the Admin / CSO account', _logout, danger: true),
              ],
            ),
    );
  }

  Widget _action(IconData icon, String title, String subtitle, VoidCallback tap, {bool danger = false}) => Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: danger ? Colors.red.shade100 : const Color(0xFFDDEDE2))), child: ListTile(onTap: tap, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: (danger ? Colors.red : green).withOpacity(.10), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: danger ? Colors.red : green)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right_rounded)));
}
