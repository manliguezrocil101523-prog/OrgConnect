import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OfficerProfileScreen extends StatefulWidget {
  const OfficerProfileScreen({super.key});
  @override State<OfficerProfileScreen> createState() => _OfficerProfileScreenState();
}

class _OfficerProfileScreenState extends State<OfficerProfileScreen> {
  static const green = Color(0xFF16A34A);
  static const bg = Color(0xFFF0FDF4);
  final db = Supabase.instance.client;
  final name = TextEditingController();
  final contact = TextEditingController();
  final course = TextEditingController();
  String? avatarUrl;
  Uint8List? _avatarBytes;
  bool loading = true;
  bool uploading = false;
  bool saving = false;

  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final user = db.auth.currentUser;
    if (user == null) return;
    try {
      final p = await db.from('profiles').select('name,contact,course,avatar_url,email').eq('id', user.id).maybeSingle();
      if (p != null) {
        name.text = p['name']?.toString() ?? '';
        contact.text = p['contact']?.toString() ?? '';
        course.text = p['course']?.toString() ?? '';
        avatarUrl = p['avatar_url']?.toString();
      }
    } catch (_) {} finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> _pickProfilePicture() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      final bytes = result?.files.isNotEmpty == true
          ? result!.files.first.bytes
          : null;
      if (bytes == null || !mounted) return;
      setState(() => _avatarBytes = bytes);

      final user = db.auth.currentUser;
      if (user == null) return;
      setState(() => uploading = true);
      final path = 'officer_profiles/${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await db.storage.from('avatar').uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );
      final url = db.storage.from('avatar').getPublicUrl(path);
      await db.from('profiles').update({'avatar_url': url}).eq('id', user.id);
      if (!mounted) return;
      setState(() {
        avatarUrl = url;
        _avatarBytes = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _avatarBytes = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not upload profile picture: $e')),
      );
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> _save() async {
    final user = db.auth.currentUser; if (user == null) return;
    setState(() => saving = true);
    try {
      await db.from('profiles').update({'name': name.text.trim(), 'contact': contact.text.trim(), 'course': course.text.trim(), 'avatar_url': avatarUrl}).eq('id', user.id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated.')));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update profile: $e'))); }
    finally { if (mounted) setState(() => saving = false); }
  }
  Future<void> _changePassword() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Change password'),
      content: TextField(controller: c, obscureText: true, decoration: const InputDecoration(labelText: 'New password', prefixIcon: Icon(Icons.lock_outline))),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, c.text.trim().length >= 6), child: const Text('Change'))],
    ));
    if (ok != true) return;
    try { await db.auth.updateUser(UserAttributes(password: c.text.trim())); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed successfully.'))); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not change password: $e'))); }
  }
  ImageProvider? _avatarImage() {
    if (_avatarBytes != null) return MemoryImage(_avatarBytes!);
    final url = avatarUrl?.trim() ?? '';
    if (url.isNotEmpty) return NetworkImage(url);
    return null;
  }

  @override void dispose() { name.dispose(); contact.dispose(); course.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: bg,
    appBar: AppBar(backgroundColor: green, foregroundColor: Colors.white, title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.w800))),
    body: loading ? const Center(child: CircularProgressIndicator(color: green)) : ListView(padding: const EdgeInsets.all(20), children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [green, Color(0xFF0F766E)]), borderRadius: BorderRadius.circular(24)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Stack(children: [
            CircleAvatar(
              radius: 42,
              backgroundColor: Colors.white24,
              backgroundImage: _avatarImage(),
              child: (_avatarImage() == null)
                  ? const Icon(Icons.person, color: Colors.white, size: 42)
                  : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: uploading ? null : _pickProfilePicture,
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: uploading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: green))
                        : const Icon(Icons.camera_alt_rounded, color: green, size: 18),
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Officer Account', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)), Text(db.auth.currentUser?.email ?? '', style: const TextStyle(color: Colors.white70))])),
        ]),
        const SizedBox(height: 12),
        TextButton.icon(onPressed: uploading ? null : _pickProfilePicture, icon: const Icon(Icons.upload_rounded, color: Colors.white), label: Text(uploading ? 'Uploading...' : 'Upload Profile Picture', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
      ])),
      const SizedBox(height: 18),
      _field(name, 'Full name', Icons.person_outline), _field(contact, 'Contact number', Icons.phone_outlined), _field(course, 'Course / program', Icons.school_outlined),
      const SizedBox(height: 8), FilledButton.icon(onPressed: saving ? null : _save, icon: const Icon(Icons.save_rounded), label: Text(saving ? 'Saving...' : 'Save Profile'), style: FilledButton.styleFrom(backgroundColor: green, minimumSize: const Size.fromHeight(52))),
      const SizedBox(height: 12), OutlinedButton.icon(onPressed: _changePassword, icon: const Icon(Icons.lock_reset_rounded), label: const Text('Change Password'), style: OutlinedButton.styleFrom(foregroundColor: green, minimumSize: const Size.fromHeight(52))),
    ]),
  );
  Widget _field(TextEditingController c, String label, IconData icon) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: c, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: green), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))));
}
