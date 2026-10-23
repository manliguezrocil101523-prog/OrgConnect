import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Notification;
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_state.dart';
import 'package:cached_network_image/cached_network_image.dart';

class OfficerOrgProfileScreen extends StatefulWidget {
  final String orgId;

  const OfficerOrgProfileScreen({super.key, required this.orgId});

  @override
  State<OfficerOrgProfileScreen> createState() =>
      _OfficerOrgProfileScreenState();
}

class _OfficerOrgProfileScreenState extends State<OfficerOrgProfileScreen> {
  // ── Colors (matches officer dashboard palette) ────────────────────────────
  static const Color _primary = Color(0xFF16A34A);
  static const Color _secondary = Color(0xFF0F766E);
  static const Color _background = Color(0xFFF0FDF4);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF94A3B8);
  static const Color _fieldBorder = Color(0xFFE2E8F0);

  // ── Form controllers ──────────────────────────────────────────────────────
  late final TextEditingController _nameCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _aboutCtrl;
  late final TextEditingController _missionCtrl;
  late final TextEditingController _visionCtrl;
  late final TextEditingController _goalsCtrl;
  late final TextEditingController _adviserCtrl;
  late final TextEditingController _socialLinkCtrl;

  // ── Officers & highlights lists (editable) ────────────────────────────────
  late List<String> _officers;
  late List<OrgOfficerProfile> _officerProfiles;
  late List<OrgMediaItem> _highlights;

  Uint8List? _pickedImageBytes;
  String? _pickedImageExt;
  String _logoUrl = '';
  String _logoAsset = '';

  bool _isSaving = false;
  late Organization _org;
  bool _orgLoaded = true;
  List<Map<String, dynamic>> _orgPeople = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();

    // Find org from AppState
    final foundOrgs =
        AppState.instance.organizations.where((o) => o.id == widget.orgId);
    _orgLoaded = foundOrgs.isNotEmpty;
    _org = _orgLoaded
        ? foundOrgs.first
        : Organization(
            id: widget.orgId,
            name: '',
            logoAsset: '',
            shortDesc: '',
          );

    // Pre-fill all controllers
    _nameCtrl = TextEditingController(text: _org.name);
    _categoryCtrl = TextEditingController(text: _org.category);
    _aboutCtrl = TextEditingController(text: _org.about);
    _missionCtrl = TextEditingController(text: _org.mission);
    _visionCtrl = TextEditingController(text: _org.vision);
    _goalsCtrl = TextEditingController(text: _org.goals);
    _adviserCtrl = TextEditingController(text: _org.adviser);
    _socialLinkCtrl = TextEditingController(
        text: _facebookNameFromStoredValue(_org.socialLink));

    _officers = List<String>.from(_org.officers);
    _officerProfiles = List<OrgOfficerProfile>.from(_org.officerProfiles);
    _highlights = List<OrgMediaItem>.from(_org.activitiesHighlights)
        .where((item) => item.type == 'image' || item.type == 'video')
        .toList();
    _logoAsset = _org.logoAsset;

    // Check if logoAsset is already a network URL
    if (_org.logoAsset.startsWith('http')) {
      _logoUrl = _org.logoAsset;
    }

    _loadOrganizationPeople();
  }

  Future<void> _loadOrganizationPeople() async {
    try {
      final rows = await Supabase.instance.client
          .from('profiles')
          .select('id,name,role,avatar_url,assigned_org_id,org_id')
          .or('assigned_org_id.eq.${widget.orgId},org_id.eq.${widget.orgId}')
          .order('name');
      if (!mounted) return;
      setState(() {
        _orgPeople = List<Map<String, dynamic>>.from(rows);
      });
    } catch (e) {
      debugPrint('Organization people load error: $e');
    }
  }

  Map<String, dynamic>? _personByRole(String role) {
    final target = role.toLowerCase();
    for (final person in _orgPeople) {
      if (person['role']?.toString().toLowerCase() == target) return person;
    }
    return null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _aboutCtrl.dispose();
    _missionCtrl.dispose();
    _visionCtrl.dispose();
    _goalsCtrl.dispose();
    _adviserCtrl.dispose();
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

  Future<String?> _uploadOfficerPhoto(Uint8List bytes, String ext) async {
    try {
      final fileName =
          'org_officers/${widget.orgId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await Supabase.instance.client.storage.from('org-assets').uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(
              contentType: 'image/$ext',
              upsert: true,
            ),
          );
      return Supabase.instance.client.storage
          .from('org-assets')
          .getPublicUrl(fileName);
    } catch (e) {
      debugPrint('Officer photo upload error: $e');
      return null;
    }
  }

  String _existingOfficerAvatar(String name) {
    final target = name.trim().toLowerCase();
    for (final profile in _officerProfiles) {
      if (profile.name.trim().toLowerCase() == target &&
          profile.avatarUrl.trim().isNotEmpty) {
        return profile.avatarUrl.trim();
      }
    }
    for (final person in _orgPeople) {
      if ((person['name']?.toString().trim().toLowerCase() ?? '') == target) {
        return person['avatar_url']?.toString() ?? '';
      }
    }
    return '';
  }

  Future<void> _editAdviserProfile() async {
    final adviser = _personByRole('adviser');
    if (adviser == null || adviser['id'] == null) {
      _snack('The adviser account could not be found for this organization.',
          isError: true);
      return;
    }
    final nameCtrl = TextEditingController(
        text: adviser['name']?.toString() ?? _adviserCtrl.text);
    Uint8List? pickedBytes;
    String? pickedExt;
    final currentAvatar = adviser['avatar_url']?.toString() ?? '';
    final save = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit Adviser'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 360,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                GestureDetector(
                  onTap: () async {
                    final pick = await FilePicker.platform
                        .pickFiles(type: FileType.image, withData: true);
                    if (pick?.files.single.bytes == null) return;
                    setDialogState(() {
                      pickedBytes = pick!.files.single.bytes;
                      pickedExt = pick.files.single.extension ?? 'jpg';
                    });
                  },
                  child: Container(
                    width: 118,
                    height: 118,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F7EF),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: _primary.withValues(alpha: .35), width: 2),
                    ),
                    child: pickedBytes != null
                        ? Image.memory(pickedBytes!, fit: BoxFit.cover)
                        : currentAvatar.trim().isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: currentAvatar,
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                                errorWidget: (_, __, ___) => const Icon(
                                    Icons.person_rounded,
                                    size: 42,
                                    color: _primary))
                            : const Icon(Icons.add_a_photo_rounded,
                                size: 38, color: _primary),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Tap the picture to choose a new adviser photo.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  maxLines: 2,
                  decoration: InputDecoration(
                      labelText: 'Adviser full name',
                      prefixIcon: const Icon(Icons.person_rounded),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12))),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isNotEmpty) {
                    Navigator.pop(dialogContext,
                        {'name': name, 'bytes': pickedBytes, 'ext': pickedExt});
                  }
                },
                child: const Text('Save Adviser')),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    if (save == null) return;
    try {
      var avatarUrl = currentAvatar;
      final bytes = save['bytes'] as Uint8List?;
      if (bytes != null) {
        avatarUrl = await _uploadOfficerPhoto(
                bytes, save['ext']?.toString() ?? 'jpg') ??
            avatarUrl;
      }
      final changes = <String, dynamic>{
        'name': save['name'],
        'avatar_url': avatarUrl
      };
      await Supabase.instance.client
          .from('profiles')
          .update(changes)
          .eq('id', adviser['id'].toString());
      await Supabase.instance.client
          .from('organizations')
          .update({'adviser': save['name'].toString()}).eq('id', widget.orgId);
      if (!mounted) return;
      setState(() {
        adviser.addAll(changes);
        _adviserCtrl.text = save['name'].toString();
        _org = _org.copyWith(adviser: save['name'].toString());
      });
      await AppState.instance.fetchOrganizations();
      _snack('Adviser details updated.');
    } catch (e) {
      _snack('Could not save adviser details: $e', isError: true);
    }
  }

  Future<OrgOfficerProfile?> _showOfficerEditor({
    OrgOfficerProfile? existing,
  }) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final roleCtrl = TextEditingController(text: existing?.role ?? 'Officer');
    Uint8List? pickedBytes;
    String? pickedExt;
    var currentAvatar = existing?.avatarUrl ??
        (existing == null ? '' : _existingOfficerAvatar(existing.name));

    final result = await showDialog<OrgOfficerProfile>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(existing == null ? 'Add Officer' : 'Edit Officer'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 360,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () async {
                      final pick = await FilePicker.platform.pickFiles(
                        type: FileType.image,
                        withData: true,
                      );
                      if (pick?.files.single.bytes == null) return;
                      setDialogState(() {
                        pickedBytes = pick!.files.single.bytes;
                        pickedExt = pick.files.single.extension ?? 'jpg';
                      });
                    },
                    child: Container(
                      width: 118,
                      height: 118,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7F7EF),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: _primary.withValues(alpha: .35), width: 2),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: pickedBytes != null
                          ? Image.memory(pickedBytes!, fit: BoxFit.cover)
                          : currentAvatar.trim().isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: currentAvatar,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => const Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                  errorWidget: (_, __, ___) => const Icon(
                                    Icons.person_rounded,
                                    size: 42,
                                    color: _primary,
                                  ),
                                )
                              : const Center(
                                  child: Icon(
                                    Icons.add_a_photo_rounded,
                                    size: 38,
                                    color: _primary,
                                  ),
                                ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the square to add or change the officer picture.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Officer name',
                      prefixIcon: const Icon(Icons.person_rounded),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: roleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Designation',
                      hintText: 'e.g. President',
                      prefixIcon: const Icon(Icons.badge_rounded),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final role = roleCtrl.text.trim().isEmpty
                    ? 'Officer'
                    : roleCtrl.text.trim();
                if (name.isEmpty) return;
                var avatarUrl = currentAvatar;
                if (pickedBytes != null) {
                  final uploaded = await _uploadOfficerPhoto(
                    pickedBytes!,
                    pickedExt ?? 'jpg',
                  );
                  if (uploaded != null) {
                    avatarUrl = uploaded;
                  }
                }
                currentAvatar = avatarUrl;
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(
                    OrgOfficerProfile(
                      name: name,
                      role: role,
                      avatarUrl: avatarUrl,
                    ),
                  );
                }
              },
              child: const Text('Save Officer'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    roleCtrl.dispose();
    return result;
  }

  Future<void> _addOfficer() async {
    final profile = await _showOfficerEditor();
    if (profile == null) return;
    setState(() {
      _officers.add('${profile.role}: ${profile.name}');
      _officerProfiles.removeWhere(
        (item) =>
            item.name.trim().toLowerCase() == profile.name.trim().toLowerCase(),
      );
      _officerProfiles.add(profile);
    });
  }

  Future<void> _editOfficer(int index) async {
    final raw = _officers[index];
    final split = raw.indexOf(':');
    final currentName =
        split == -1 ? raw.trim() : raw.substring(split + 1).trim();
    final currentRole =
        split == -1 ? 'Officer' : raw.substring(0, split).trim();
    final existing = _officerProfiles.cast<OrgOfficerProfile?>().firstWhere(
          (p) => p?.name.trim().toLowerCase() == currentName.toLowerCase(),
          orElse: () => OrgOfficerProfile(
            name: currentName,
            role: currentRole,
            avatarUrl: _existingOfficerAvatar(currentName),
          ),
        );
    final updated = await _showOfficerEditor(existing: existing);
    if (updated == null) return;
    setState(() {
      _officers[index] = '${updated.role}: ${updated.name}';
      _officerProfiles.removeWhere(
        (item) => item.name.trim().toLowerCase() == currentName.toLowerCase(),
      );
      _officerProfiles.removeWhere(
        (item) =>
            item.name.trim().toLowerCase() == updated.name.trim().toLowerCase(),
      );
      _officerProfiles.add(updated);
    });
  }

  String _facebookNameFromStoredValue(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    final uri = Uri.tryParse(value.contains('://') ? value : 'https://$value');
    final host = uri?.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    if (uri != null && host == 'facebook.com') {
      final query = uri.queryParameters['q'];
      if (query != null && query.trim().isNotEmpty) return query.trim();
      final path = uri.pathSegments.where((part) => part.isNotEmpty).join(' ');
      if (path.isNotEmpty) return path.replaceAll(RegExp(r'[-_]'), ' ');
    }
    return value;
  }

  // ── Save all changes ──────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_isSaving) return;
    if (!_orgLoaded) {
      _snack(
          'Organization data is still loading. Go back and reopen this page.',
          isError: true);
      return;
    }

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Organization name cannot be empty.', isError: true);
      return;
    }
    final facebookName = _socialLinkCtrl.text.trim();
    if (facebookName.contains('://') &&
        !facebookName.toLowerCase().contains('facebook.com')) {
      _snack(
          'Please enter the organization Facebook name or a Facebook page URL.',
          isError: true);
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
        acronym: _org.acronym,
        category: _categoryCtrl.text.trim(),
        about: _aboutCtrl.text.trim(),
        mission: _missionCtrl.text.trim(),
        vision: _visionCtrl.text.trim(),
        goals: _goalsCtrl.text.trim(),
        adviser: _adviserCtrl.text.trim(),
        socialLink: facebookName,
        officers: _officers,
        officerProfiles: _officerProfiles,
        activitiesHighlights: [
          ..._highlights,
          ..._org.activitiesHighlights
              .where((i) => i.type != 'image' && i.type != 'video'),
        ],
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

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Fixed organization header. The form below is the only scrollable
            // area, so the scrollbar starts exactly at Basic Info.
            Container(
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.20,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF064E3B),
                    Color(0xFF0F7A57),
                    Color(0xFF22C55E),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 10,
                    left: 8,
                    child: IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    top: 42,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 8, 22, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _LogoPicker(
                            pickedFile: _pickedImageBytes,
                            logoUrl: _logoUrl,
                            logoAsset: _logoAsset,
                            onTap: _pickLogo,
                            primary: _primary,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ORGANIZATION PROFILE',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Color(0xFFD9F7E7),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _nameCtrl.text.isEmpty
                                      ? 'Your Organization'
                                      : _nameCtrl.text,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 23,
                                    fontWeight: FontWeight.w900,
                                    height: 1.12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 48),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ── Basic Info ──────────────────────────────
                              _sectionLabel('Basic Info'),
                              const SizedBox(height: 12),
                              _field(
                                controller: _nameCtrl,
                                label: 'Organization Name',
                                icon: Icons.groups_rounded,
                              ),
                              _field(
                                controller: _categoryCtrl,
                                label: 'Category',
                                icon: Icons.category_rounded,
                              ),
                              const SizedBox(height: 24),

                              // ── Details ─────────────────────────────────
                              _sectionLabel('Details'),
                              const SizedBox(height: 12),
                              _field(
                                controller: _aboutCtrl,
                                label: 'About',
                                icon: Icons.info_rounded,
                                maxLines: 4,
                              ),
                              _field(
                                controller: _missionCtrl,
                                label: 'Mission',
                                icon: Icons.flag_rounded,
                                maxLines: 4,
                              ),
                              _field(
                                controller: _visionCtrl,
                                label: 'Vision',
                                icon: Icons.visibility_rounded,
                                maxLines: 4,
                              ),
                              _field(
                                controller: _goalsCtrl,
                                label: 'Goals',
                                icon: Icons.flag_circle_rounded,
                                maxLines: 4,
                              ),

                              const SizedBox(height: 24),

                              // ── Facebook ─────────────────────────────────
                              _sectionLabel('Organization Facebook Page'),
                              const SizedBox(height: 12),
                              _field(
                                controller: _socialLinkCtrl,
                                label: 'Organization Facebook Name',
                                icon: Icons.facebook_rounded,
                                keyboardType: TextInputType.text,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Enter the Facebook page name or username. You can also paste the page URL if you have it.',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),

                              const SizedBox(height: 24),

                              // ── Adviser & officers ─────────────────────
                              _sectionLabel('Adviser & Officers'),
                              const SizedBox(height: 8),
                              Text(
                                'Edit the adviser name and picture here. Officer names, designations, and pictures can be edited below.',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Center(
                                  child: _ProfilePersonEditorCard(
                                label: 'Adviser',
                                name: _personByRole('adviser')?['name']
                                            ?.toString()
                                            .trim()
                                            .isNotEmpty ==
                                        true
                                    ? _personByRole('adviser')!['name']
                                        .toString()
                                    : _adviserCtrl.text.trim(),
                                avatarUrl:
                                    _personByRole('adviser')?['avatar_url']
                                            ?.toString() ??
                                        '',
                                width: 172,
                                onEdit: _editAdviserProfile,
                              )),
                              const SizedBox(height: 14),
                              _OfficerPeopleEditor(
                                officers: _officers,
                                profiles: _officerProfiles,
                                people: _orgPeople,
                                onAdd: _addOfficer,
                                onEdit: _editOfficer,
                                onRemove: (i) => setState(() {
                                  final raw = _officers.removeAt(i);
                                  final split = raw.indexOf(':');
                                  final name = (split == -1
                                          ? raw
                                          : raw.substring(split + 1))
                                      .trim();
                                  _officerProfiles.removeWhere((p) =>
                                      p.name.trim().toLowerCase() ==
                                      name.toLowerCase());
                                }),
                              ),

                              const SizedBox(height: 24),

                              // ── Highlights & activities ────────────────
                              _sectionLabel('Highlights & Activities'),
                              const SizedBox(height: 12),
                              _MediaEditCard(
                                items: _highlights,
                                accentColor: _secondary,
                                orgId: widget.orgId,
                                onChanged: (updated) =>
                                    setState(() => _highlights = updated),
                              ),

                              const SizedBox(height: 36),

                              // ── Save button ─────────────────────────────
                              SizedBox(
                                height: 54,
                                child: ElevatedButton(
                                  onPressed: _isSaving ? null : _save,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _primary,
                                    disabledBackgroundColor:
                                        _primary.withValues(alpha: 0.45),
                                    elevation: 5,
                                    shadowColor:
                                        _primary.withValues(alpha: .22),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  child: _isSaving
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
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
                  ),
                ],
              ),
            ),
          ],
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
            color: _secondary,
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE9FFF2), Color(0xFFBDF3D0)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFB9E4CF)),
        boxShadow: [
          BoxShadow(
              color: _primary.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6))
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
          fillColor: const Color(0xFFF8FFFB),
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
    const double size = 88;
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Compact logo for the member-style horizontal organization card.
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
              border:
                  Border.all(color: primary.withValues(alpha: 0.28), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipOval(child: _logoWidget()),
          ),
          Positioned(
            right: -1,
            bottom: 1,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 7,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 18,
                ),
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
      return Image.memory(
        pickedFile!,
        fit: BoxFit.contain,
        width: 88,
        height: 88,
      );
    }
    if (logoUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: logoUrl,
        fit: BoxFit.contain,
        width: 88,
        height: 88,
        placeholder: (_, __) => _fallbackIcon(),
        errorWidget: (_, __, ___) => _fallbackIcon(),
      );
    }
    if (logoAsset.isNotEmpty) {
      return Image.asset(
        logoAsset,
        fit: BoxFit.contain,
        width: 88,
        height: 88,
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
// _EditablePeopleCard — visual officer/adviser profile editor
// =============================================================================
class _ProfilePersonEditorCard extends StatelessWidget {
  final String label;
  final String name;
  final String avatarUrl;
  final double width;
  final VoidCallback? onEdit;

  const _ProfilePersonEditorCard({
    required this.label,
    required this.name,
    required this.avatarUrl,
    this.width = 172,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = name.trim().isEmpty ? 'No name added yet' : name.trim();
    final displayRole = label.trim().isEmpty ? 'Officer' : label.trim();
    return SizedBox(
      width: width,
      child: Stack(
        children: [
          Container(
            width: width,
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFFFFF), Color(0xFFF3FCF6)]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFB9E4CF), width: 1.2),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x0D0F8A61),
                    blurRadius: 14,
                    offset: Offset(0, 6))
              ],
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 122,
                      child: avatarUrl.trim().isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: avatarUrl.trim(),
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                              placeholder: (_, __) => _personFallback(),
                              errorWidget: (_, __, ___) => _personFallback())
                          : _personFallback(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                        color: const Color(0xFFE3F7EA),
                        borderRadius: BorderRadius.circular(999)),
                    child: Text(displayRole,
                        softWrap: true,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Color(0xFF15803D),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .5)),
                  ),
                  const SizedBox(height: 7),
                  Text(displayName,
                      softWrap: true,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 14.5,
                          height: 1.15,
                          fontWeight: FontWeight.w900)),
                ]),
          ),
          if (onEdit != null)
            Positioned(
                top: 6,
                right: 6,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: IconButton(
                      tooltip: 'Edit adviser',
                      onPressed: onEdit,
                      padding: const EdgeInsets.all(7),
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.edit_rounded,
                          size: 16, color: Color(0xFF16A34A))),
                )),
        ],
      ),
    );
  }

  Widget _personFallback() => Container(
      color: const Color(0xFFE7F7EF),
      child: const Center(
          child:
              Icon(Icons.person_rounded, color: Color(0xFF16A34A), size: 42)));
}

class _OfficerPeopleEditor extends StatelessWidget {
  final List<String> officers;
  final List<OrgOfficerProfile> profiles;
  final List<Map<String, dynamic>> people;
  final VoidCallback onAdd;
  final void Function(int index) onEdit;
  final void Function(int index) onRemove;

  const _OfficerPeopleEditor({
    required this.officers,
    required this.profiles,
    required this.people,
    required this.onAdd,
    required this.onEdit,
    required this.onRemove,
  });

  String _nameOnly(String raw) {
    final text = raw.trim();
    final split = text.indexOf(':');
    return split == -1 ? text : text.substring(split + 1).trim();
  }

  String _roleOnly(String raw) {
    final text = raw.trim();
    final split = text.indexOf(':');
    return split == -1 ? 'Officer' : text.substring(0, split).trim();
  }

  String _avatarFor(String name) {
    final target = name.toLowerCase();
    for (final person in people) {
      if ((person['name']?.toString().trim().toLowerCase() ?? '') == target) {
        return person['avatar_url']?.toString() ?? '';
      }
    }
    return '';
  }

  String _profileAvatar(String name) {
    final target = name.trim().toLowerCase();
    for (final profile in profiles) {
      if (profile.name.trim().toLowerCase() == target &&
          profile.avatarUrl.trim().isNotEmpty) {
        return profile.avatarUrl.trim();
      }
    }
    return _avatarFor(name);
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FFFB), Color(0xFFDDF4E8)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFB9E4CF)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF16A34A).withValues(alpha: .07),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (officers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No officers added yet. Add an officer below.',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var index = 0; index < officers.length; index++) ...[
                      if (index > 0) const SizedBox(width: 10),
                      Builder(
                        builder: (context) {
                          final raw = officers[index];
                          final name = _nameOnly(raw);
                          final role = _roleOnly(raw);
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              _ProfilePersonEditorCard(
                                label: role,
                                name: name,
                                avatarUrl: _profileAvatar(name),
                                width: 172,
                              ),
                              Positioned(
                                top: -5,
                                right: -4,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      onTap: () => onEdit(index),
                                      child: Container(
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: const Color(0xFFB9E4CF)),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x12000000),
                                              blurRadius: 6,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.edit_rounded,
                                          size: 14,
                                          color: Color(0xFF16A34A),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () => onRemove(index),
                                      child: Container(
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.red.shade100),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x12000000),
                                              blurRadius: 6,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 16,
                                          color: Colors.red.shade400,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
              label: const Text('Add Officer'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF16A34A),
                side: BorderSide(
                    color: const Color(0xFF16A34A).withValues(alpha: .4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ],
        ),
      );
}

// =============================================================================
// _MediaEditCard — rich media editor for Highlights & Activities
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
        if (url != null && mounted) {
          final activityNameCtrl = TextEditingController();
          final descriptionCtrl = TextEditingController();
          final details = await showDialog<Map<String, String>>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              title: const Text('Add activity picture'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      f.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: activityNameCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Activity name',
                        hintText: 'e.g. Attending Mass',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descriptionCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Short description (optional)',
                        hintText: 'Add a brief note about the activity',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Skip'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop({
                    'title': activityNameCtrl.text.trim(),
                    'description': descriptionCtrl.text.trim(),
                  }),
                  child: const Text('Save'),
                ),
              ],
            ),
          );
          newItems.add(
            OrgMediaItem(
              type: 'image',
              content: url,
              title: details?['title'] ?? '',
              description: details?['description'] ?? '',
            ),
          );
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
        String activityName = '';
        String description = '';
        if (mounted) {
          final activityNameCtrl = TextEditingController();
          final descriptionCtrl = TextEditingController();
          final details = await showDialog<Map<String, String>>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text('Add activity video'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      f.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: activityNameCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Activity name',
                        hintText: 'e.g. Attending Mass',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descriptionCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Short description (optional)',
                        hintText: 'Add a brief note about the activity',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Skip'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop({
                    'title': activityNameCtrl.text.trim(),
                    'description': descriptionCtrl.text.trim(),
                  }),
                  child: const Text('Save'),
                ),
              ],
            ),
          );
          activityName = details?['title'] ?? '';
          description = details?['description'] ?? '';
        }
        widget.onChanged([
          ...widget.items,
          OrgMediaItem(
            type: 'video',
            content: url,
            title: activityName,
            description: description,
          ),
        ]);
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = widget.items
        .where((item) => item.type == 'image' || item.type == 'video')
        .toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FFFB), Color(0xFFDDF4E8)]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFB9E4CF)),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF16A34A).withValues(alpha: 0.07),
              blurRadius: 14,
              offset: const Offset(0, 5))
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
          else if (visibleItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                  'No highlights yet. Add an activity picture or video.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
            )
          else
            ...visibleItems.asMap().entries.map((e) {
              final item = e.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
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
                                  color: widget.accentColor
                                      .withValues(alpha: 0.08),
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
                                    ? 'Pictures'
                                    : 'Video',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: item.type == 'image'
                                  ? widget.accentColor
                                  : Colors.grey.shade700,
                            ),
                          ),
                          if (item.title.trim().isNotEmpty ||
                              item.caption.trim().isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              item.title.trim().isNotEmpty
                                  ? item.title.trim()
                                  : item.caption.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          if (item.description.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              item.description.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Delete
                    GestureDetector(
                      onTap: () {
                        final target = item;
                        final updated = [...widget.items]..removeWhere(
                            (candidate) => identical(candidate, target));
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
                  icon: Icons.image_rounded,
                  label: 'Activity Picture',
                  onTap: _isUploading ? null : _addImage,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _addBtn(
                  icon: Icons.videocam_rounded,
                  label: 'Activity Video',
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
        side: BorderSide(color: widget.accentColor.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
    );
  }
}
