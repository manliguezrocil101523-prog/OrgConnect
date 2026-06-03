import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_state.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';

class OfficerOrgProfileScreen extends StatefulWidget {
  final String orgId;

  const OfficerOrgProfileScreen({super.key, required this.orgId});

  @override
  State<OfficerOrgProfileScreen> createState() =>
      _OfficerOrgProfileScreenState();
}

class _OfficerOrgProfileScreenState extends State<OfficerOrgProfileScreen> {
  // ── Colors (matches officer dashboard palette) ────────────────────────────
  static const Color _primary = Color(0xFF4F46E5);
  static const Color _secondary = Color(0xFF06B6D4);
  static const Color _background = Color(0xFFF8FAFC);
  static const Color _cardSurface = Colors.white;
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF94A3B8);
  static const Color _fieldFill = Color(0xFFF1F5F9);
  static const Color _fieldBorder = Color(0xFFE2E8F0);

  // ── Form controllers ──────────────────────────────────────────────────────
  late final TextEditingController _nameCtrl;
  late final TextEditingController _acronymCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _shortDescCtrl;
  late final TextEditingController _aboutCtrl;
  late final TextEditingController _missionVisionCtrl;
  late final TextEditingController _adviserCtrl;
  late final TextEditingController _contactEmailCtrl;
  late final TextEditingController _contactPhoneCtrl;
  late final TextEditingController _socialLinkCtrl;

  // ── Officers & highlights lists (editable) ────────────────────────────────
  late List<String> _officers;
  late List<OrgMediaItem> _highlights;

  Uint8List? _pickedImageBytes;
  String? _pickedImageExt;
  String _logoUrl = '';
  String _logoAsset = '';

  bool _isSaving = false;
  late Organization _org;

  @override
  void initState() {
    super.initState();

    // Find org from AppState
    _org = AppState.instance.organizations.firstWhere(
      (o) => o.id == widget.orgId,
    );

    // Pre-fill all controllers
    _nameCtrl = TextEditingController(text: _org.name);
    _acronymCtrl = TextEditingController(text: _org.acronym);
    _categoryCtrl = TextEditingController(text: _org.category);
    _shortDescCtrl = TextEditingController(text: _org.shortDesc);
    _aboutCtrl = TextEditingController(text: _org.about);
    _missionVisionCtrl = TextEditingController(text: _org.missionVision);
    _adviserCtrl = TextEditingController(text: _org.adviser);
    _contactEmailCtrl = TextEditingController(text: _org.contactEmail);
    _contactPhoneCtrl = TextEditingController(text: _org.contactPhone);
    _socialLinkCtrl = TextEditingController(text: _org.socialLink);

    _officers = List<String>.from(_org.officers);
    _highlights = List<OrgMediaItem>.from(_org.activitiesHighlights);
    _logoAsset = _org.logoAsset;

    // Check if logoAsset is already a network URL
    if (_org.logoAsset.startsWith('http')) {
      _logoUrl = _org.logoAsset;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _acronymCtrl.dispose();
    _categoryCtrl.dispose();
    _shortDescCtrl.dispose();
    _aboutCtrl.dispose();
    _missionVisionCtrl.dispose();
    _adviserCtrl.dispose();
    _contactEmailCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _socialLinkCtrl.dispose();
    super.dispose();
  }

  // ── Pick image from gallery ───────────────────────────────────────────────
  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _pickedImageBytes = result.files.single.bytes;
        _pickedImageExt = result.files.single.extension ?? 'png';
      });
    }
  }

  // ── Upload logo to Supabase Storage, returns public URL ──────────────────
  Future<String?> _uploadLogo() async {
    if (_pickedImageBytes == null) return null;

    try {
      final fileBytes = _pickedImageBytes!;
      final fileExt = _pickedImageExt ?? 'png';
      final fileName =
          'org_logos/${widget.orgId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await Supabase.instance.client.storage.from('org-assets').uploadBinary(
            fileName,
            fileBytes,
            fileOptions: FileOptions(
              contentType: 'image/$fileExt',
              upsert: true,
            ),
          );

      final publicUrl = Supabase.instance.client.storage
          .from('org-assets')
          .getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      debugPrint('Logo upload error: $e');
      return null;
    }
  }

  // ── Save all changes ──────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_isSaving) return;

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Organization name cannot be empty.', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Upload new logo if one was picked
      // Upload new logo if one was picked
      String finalLogoAsset = _logoAsset;
      if (_pickedImageBytes != null) {
        final uploadedUrl = await _uploadLogo();
        if (uploadedUrl != null) {
          // Evict old cached image so the new logo shows immediately everywhere
          await CachedNetworkImage.evictFromCache(_logoAsset);
          finalLogoAsset = uploadedUrl;
        } else {
          _snack('Logo upload failed. Other changes will still be saved.',
              isError: false);
        }
      }

      // Build updated org object
      final updated = _org.copyWith(
        name: name,
        acronym: _acronymCtrl.text.trim(),
        category: _categoryCtrl.text.trim(),
        shortDesc: _shortDescCtrl.text.trim(),
        about: _aboutCtrl.text.trim(),
        missionVision: _missionVisionCtrl.text.trim(),
        adviser: _adviserCtrl.text.trim(),
        contactEmail: _contactEmailCtrl.text.trim(),
        contactPhone: _contactPhoneCtrl.text.trim(),
        socialLink: _socialLinkCtrl.text.trim(),
        officers: _officers,
        activitiesHighlights: _highlights,
        logoAsset: finalLogoAsset,
      );

      // This already handles Supabase + AppState update
      await AppState.instance.updateOrganization(updated);

      if (!mounted) return;
      _snack('Organization profile updated!');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) _snack('Failed to save changes.', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isError ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Add item to a string list (officers / highlights) ────────────────────
  Future<void> _addListItem(List<String> list, String label) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Add $label'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter $label',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => list.add(result));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Edit Org Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _isSaving
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    ),
                  )
                : TextButton(
                    onPressed: _save,
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Logo picker ─────────────────────────────────────────────
                _LogoPicker(
                  pickedFile: _pickedImageBytes,
                  logoUrl: _logoUrl,
                  logoAsset: _logoAsset,
                  onTap: _pickLogo,
                  primary: _primary,
                ),

                const SizedBox(height: 28),

                // ── Basic Info ──────────────────────────────────────────────
                _sectionLabel('Basic Info'),
                const SizedBox(height: 12),
                _field(
                  controller: _nameCtrl,
                  label: 'Organization Name',
                  icon: Icons.groups_rounded,
                ),
                _field(
                  controller: _acronymCtrl,
                  label: 'Acronym',
                  icon: Icons.short_text_rounded,
                ),
                _field(
                  controller: _categoryCtrl,
                  label: 'Category',
                  icon: Icons.category_rounded,
                ),
                _field(
                  controller: _shortDescCtrl,
                  label: 'Short Description',
                  icon: Icons.notes_rounded,
                  maxLines: 2,
                ),

                const SizedBox(height: 24),

                // ── Details ─────────────────────────────────────────────────
                _sectionLabel('Details'),
                const SizedBox(height: 12),
                _field(
                  controller: _aboutCtrl,
                  label: 'About',
                  icon: Icons.info_rounded,
                  maxLines: 4,
                ),
                _field(
                  controller: _missionVisionCtrl,
                  label: 'Mission & Vision',
                  icon: Icons.flag_rounded,
                  maxLines: 4,
                ),
                _field(
                  controller: _adviserCtrl,
                  label: 'Adviser',
                  icon: Icons.person_rounded,
                ),

                const SizedBox(height: 24),

                // ── Contact ─────────────────────────────────────────────────
                _sectionLabel('Contact'),
                const SizedBox(height: 12),
                _field(
                  controller: _contactEmailCtrl,
                  label: 'Contact Email',
                  icon: Icons.email_rounded,
                  keyboardType: TextInputType.emailAddress,
                ),
                _field(
                  controller: _contactPhoneCtrl,
                  label: 'Contact Phone',
                  icon: Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                ),
                _field(
                  controller: _socialLinkCtrl,
                  label: 'Social / Facebook Link',
                  icon: Icons.link_rounded,
                  keyboardType: TextInputType.url,
                ),

                const SizedBox(height: 24),

                // ── Officers list ───────────────────────────────────────────
                _sectionLabel('Officers'),
                const SizedBox(height: 12),
                _EditableListCard(
                  items: _officers,
                  accentColor: _primary,
                  onAdd: () => _addListItem(_officers, 'Officer'),
                  onRemove: (i) => setState(() => _officers.removeAt(i)),
                ),

                const SizedBox(height: 24),

                // ── Activities / Highlights list ────────────────────────────
                // ── Activities / Highlights media ───────────────────────────
                _sectionLabel('Activities & Events'),
                const SizedBox(height: 12),
                _MediaEditCard(
                  items: _highlights,
                  accentColor: _secondary,
                  orgId: widget.orgId,
                  onChanged: (updated) => setState(() => _highlights = updated),
                ),

                const SizedBox(height: 36),

                // ── Save button ─────────────────────────────────────────────
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      disabledBackgroundColor: _primary.withOpacity(0.45),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Section label widget ──────────────────────────────────────────────────
  Widget _sectionLabel(String text) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_primary, _secondary],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  // ── Reusable text field ───────────────────────────────────────────────────
  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardSurface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        minLines: 1,
        keyboardType: keyboardType,
        style: const TextStyle(
          fontSize: 14,
          color: _textDark,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: _cardSurface,
          labelText: label,
          labelStyle: const TextStyle(
            fontSize: 13,
            color: _textMuted,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(icon, color: _primary, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _fieldBorder, width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _primary, width: 1.8),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: maxLines > 1 ? 14 : 0,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _LogoPicker — shows current logo and a camera button to change it
// =============================================================================
class _LogoPicker extends StatelessWidget {
  final Uint8List? pickedFile;
  final String logoUrl;
  final String logoAsset;
  final VoidCallback onTap;
  final Color primary;

  const _LogoPicker({
    required this.pickedFile,
    required this.logoUrl,
    required this.logoAsset,
    required this.onTap,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Logo circle ────────────────────────────────────────────────
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: primary.withOpacity(0.25), width: 2),
              boxShadow: [
                BoxShadow(
                  color: primary.withOpacity(0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipOval(child: _logoWidget()),
          ),

          // ── Camera edit button ─────────────────────────────────────────
          Positioned(
            bottom: 0,
            right: -4,
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoWidget() {
    // Priority: newly picked file > network URL > asset
    if (pickedFile != null) {
      return Image.memory(pickedFile!,
          fit: BoxFit.cover, width: 110, height: 110);
    }
    if (logoUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: logoUrl,
        fit: BoxFit.cover,
        width: 110,
        height: 110,
        placeholder: (_, __) => _fallbackIcon(),
        errorWidget: (_, __, ___) => _fallbackIcon(),
      );
    }
    if (logoAsset.isNotEmpty) {
      return Image.asset(
        logoAsset,
        fit: BoxFit.cover,
        width: 110,
        height: 110,
        errorBuilder: (_, __, ___) => _fallbackIcon(),
      );
    }
    return _fallbackIcon();
  }

  Widget _fallbackIcon() => Container(
        color: const Color(0xFFE0E7FF),
        child: Icon(Icons.groups_rounded, color: primary, size: 40),
      );
}

// =============================================================================
// _EditableListCard — for Officers and Activities lists
// =============================================================================
class _EditableListCard extends StatelessWidget {
  final List<String> items;
  final Color accentColor;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  const _EditableListCard({
    required this.items,
    required this.accentColor,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No items yet. Tap + to add.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade400,
                ),
              ),
            )
          else
            ...items.asMap().entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: accentColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            e.value,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => onRemove(e.key),
                          child: Icon(
                            Icons.remove_circle_outline_rounded,
                            size: 20,
                            color: Colors.red.shade300,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: Icon(Icons.add_rounded, color: accentColor, size: 18),
            label: Text(
              'Add Item',
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: accentColor.withOpacity(0.4)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _MediaEditCard — rich media editor for Activities & Events
// =============================================================================
class _MediaEditCard extends StatefulWidget {
  final List<OrgMediaItem> items;
  final Color accentColor;
  final String orgId;
  final ValueChanged<List<OrgMediaItem>> onChanged;

  const _MediaEditCard({
    required this.items,
    required this.accentColor,
    required this.orgId,
    required this.onChanged,
  });

  @override
  State<_MediaEditCard> createState() => _MediaEditCardState();
}

class _MediaEditCardState extends State<_MediaEditCard> {
  bool _isUploading = false;

  Future<String?> _uploadFile(Uint8List bytes, String ext, String mime) async {
    try {
      final fileName =
          'org_activities/${widget.orgId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await Supabase.instance.client.storage.from('org-assets').uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(contentType: mime, upsert: true),
          );
      return Supabase.instance.client.storage
          .from('org-assets')
          .getPublicUrl(fileName);
    } catch (e) {
      debugPrint('Media upload error: $e');
      return null;
    }
  }

  Future<void> _addText() async {
    final ctrl = TextEditingController();
    final captionCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Add Text'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Write something...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Add')),
        ],
      ),
    );
    if (result == true && ctrl.text.trim().isNotEmpty) {
      final updated = [
        ...widget.items,
        OrgMediaItem(
            type: 'text',
            content: ctrl.text.trim(),
            caption: captionCtrl.text.trim())
      ];
      widget.onChanged(updated);
    }
  }

  Future<void> _addImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _isUploading = true);
    try {
      final newItems = <OrgMediaItem>[];
      for (final f in result.files) {
        if (f.bytes == null) continue;
        final ext = f.extension ?? 'jpg';
        final url = await _uploadFile(f.bytes!, ext, 'image/$ext');
        if (url != null) {
          // Ask for optional caption
          String caption = '';
          if (mounted) {
            final captionCtrl = TextEditingController();
            final cap = await showDialog<String>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                title: Text(f.name, style: const TextStyle(fontSize: 14)),
                content: TextField(
                  controller: captionCtrl,
                  decoration: InputDecoration(
                    hintText: 'Add a caption (optional)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(ctx).pop(''),
                      child: const Text('Skip')),
                  FilledButton(
                      onPressed: () =>
                          Navigator.of(ctx).pop(captionCtrl.text.trim()),
                      child: const Text('Done')),
                ],
              ),
            );
            caption = cap ?? '';
          }
          newItems
              .add(OrgMediaItem(type: 'image', content: url, caption: caption));
        }
      }
      widget.onChanged([...widget.items, ...newItems]);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _addVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    setState(() => _isUploading = true);
    try {
      final f = result.files.single;
      final ext = f.extension ?? 'mp4';
      final url = await _uploadFile(f.bytes!, ext, 'video/$ext');
      if (url != null) {
        String caption = '';
        if (mounted) {
          final captionCtrl = TextEditingController();
          final cap = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              title: const Text('Video uploaded!'),
              content: TextField(
                controller: captionCtrl,
                decoration: InputDecoration(
                  hintText: 'Add a caption (optional)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(''),
                    child: const Text('Skip')),
                FilledButton(
                    onPressed: () =>
                        Navigator.of(ctx).pop(captionCtrl.text.trim()),
                    child: const Text('Done')),
              ],
            ),
          );
          caption = cap ?? '';
        }
        widget.onChanged([
          ...widget.items,
          OrgMediaItem(type: 'video', content: url, caption: caption)
        ]);
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (widget.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('No items yet. Add text, images, or videos.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
            )
          else
            ...widget.items.asMap().entries.map((e) {
              final item = e.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Preview
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: item.type == 'image'
                          ? CachedNetworkImage(
                              imageUrl: item.content,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                  width: 56,
                                  height: 56,
                                  color: Colors.grey.shade200),
                              errorWidget: (_, __, ___) => Container(
                                  width: 56,
                                  height: 56,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.broken_image)),
                            )
                          : item.type == 'video'
                              ? Container(
                                  width: 56,
                                  height: 56,
                                  color: Colors.black87,
                                  child: const Icon(
                                      Icons.play_circle_fill_rounded,
                                      color: Colors.white,
                                      size: 28),
                                )
                              : Container(
                                  width: 56,
                                  height: 56,
                                  color: widget.accentColor.withOpacity(0.08),
                                  child: Icon(Icons.text_snippet_rounded,
                                      color: widget.accentColor, size: 26),
                                ),
                    ),
                    const SizedBox(width: 10),
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.type == 'text'
                                ? item.content
                                : item.type == 'image'
                                    ? 'Image'
                                    : 'Video',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          if (item.caption.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(item.caption,
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.grey.shade500)),
                          ],
                        ],
                      ),
                    ),
                    // Delete
                    GestureDetector(
                      onTap: () {
                        final updated = [...widget.items]..removeAt(e.key);
                        widget.onChanged(updated);
                      },
                      child: Icon(Icons.remove_circle_outline_rounded,
                          size: 20, color: Colors.red.shade300),
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 6),

          // Action buttons row
          Row(
            children: [
              Expanded(
                child: _addBtn(
                  icon: Icons.text_fields_rounded,
                  label: 'Text',
                  onTap: _isUploading ? null : _addText,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _addBtn(
                  icon: Icons.image_rounded,
                  label: 'Image',
                  onTap: _isUploading ? null : _addImage,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _addBtn(
                  icon: Icons.videocam_rounded,
                  label: 'Video',
                  onTap: _isUploading ? null : _addVideo,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _addBtn({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: widget.accentColor),
      label: Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: widget.accentColor)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: widget.accentColor.withOpacity(0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
    );
  }
}
