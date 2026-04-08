import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_state.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  // ─── Color tokens ──────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF4F46E5);
  static const Color _secondary = Color(0xFF06B6D4);
  static const Color _success = Color(0xFF22C55E);
  static const Color _background = Color(0xFFF1F5F9);

  // ─── Controllers ───────────────────────────────────────────────────────────
  final TextEditingController studentIdCtrl = TextEditingController();
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController contactCtrl = TextEditingController();
  final TextEditingController facebookCtrl = TextEditingController();

  Uint8List? _avatarBytes;
  bool _isEditing = false;
  bool _isLoading = true;
  bool _showZoom = false;
  Map<String, dynamic>? _profile;

  late final AnimationController _headerAnim;
  late final Animation<double> _headerFade;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _headerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _headerFade = CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut);
    _loadProfile();
  }

  @override
  void dispose() {
    _headerAnim.dispose();
    studentIdCtrl.dispose();
    nameCtrl.dispose();
    emailCtrl.dispose();
    contactCtrl.dispose();
    facebookCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    await AppState.instance.loadStudentProfile();
    final currentProfile = AppState.instance.currentStudent;
    if (currentProfile != null) {
      _profile = {
        'student_id': currentProfile.studentId,
        'name': currentProfile.name,
        'email': currentProfile.email,
        'contact': currentProfile.contact,
        'facebook': currentProfile.facebook,
        'avatar_url': currentProfile.avatarUrl,
      };
      _populateControllers();
    } else {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString('student_profile');
      if (profileJson != null) {
        try {
          final data = jsonDecode(profileJson) as Map<String, dynamic>;
          _profile = {
            'student_id': data['studentId'] ?? '',
            'name': data['name'] ?? '',
            'email': data['email'] ?? '',
            'contact': data['contact'] ?? '',
            'facebook': data['facebook'] ?? '',
            'avatar_url': data['avatarUrl'] ?? '',
          };
          _populateControllers();
        } catch (e) {
          // keep _profile null on parse failure
        }
      }
    }
    setState(() {
      _isEditing = false;
      _isLoading = false;
    });
    _headerAnim.forward();
  }

  @override
  void _populateControllers() {
    if (_profile != null) {
      studentIdCtrl.text = _profile!['student_id'] ?? '';
      nameCtrl.text = _profile!['name'] ?? '';
      emailCtrl.text = _profile!['email'] ?? '';
      contactCtrl.text = _profile!['contact'] ?? '';
      facebookCtrl.text = _profile!['facebook'] ?? '';
    }
  }

  /// Returns 0.0–1.0 based on how many fields are filled
  double get _completeness {
    if (_profile == null) return 0;
    final keys = ['student_id', 'name', 'email', 'contact', 'facebook'];
    final filled = keys.where((k) {
      final v = _profile![k] as String? ?? '';
      return v.isNotEmpty;
    }).length;
    return filled / keys.length;
  }

  Future<void> _pickAvatar() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'heic', 'webp'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() => _avatarBytes = result.files.first.bytes);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (studentIdCtrl.text.trim().isEmpty ||
        nameCtrl.text.trim().isEmpty ||
        emailCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in required fields')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final updatedProfile = StudentProfile(
        id: AppState.instance.currentStudent?.id ?? '',
        name: nameCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        studentId: studentIdCtrl.text.trim(),
        contact: contactCtrl.text.trim(),
        facebook: facebookCtrl.text.trim(),
        avatarUrl: _avatarBytes != null
            ? 'data:image/png;base64,${base64Encode(_avatarBytes!)}'
            : AppState.instance.currentStudent?.avatarUrl ?? '',
        joinedOrgIds: AppState.instance.currentStudent?.joinedOrgIds ?? [],
      );
      await AppState.instance.setStudentProfile(updatedProfile);
      if (mounted) {
        setState(() {
          _isEditing = false;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Profile saved successfully!'),
              ],
            ),
            backgroundColor: _success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openZoom() => setState(() => _showZoom = true);
  void _closeZoom() => setState(() => _showZoom = false);

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _background,
        body: Center(
          child: CircularProgressIndicator(color: _primary, strokeWidth: 2.5),
        ),
      );
    }

    ImageProvider? avatarImage;
    if (_avatarBytes != null) {
      avatarImage = MemoryImage(_avatarBytes!);
    } else if (_profile?['avatar_url'] != null &&
        (_profile!['avatar_url'] as String).isNotEmpty) {
      avatarImage = NetworkImage(_profile!['avatar_url'] as String);
    }

    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── SLIVER APP BAR ─────────────────────────────────────────────
              SliverAppBar(
                pinned: true,
                expandedHeight: MediaQuery.of(context).size.height * 0.33,
                backgroundColor: _primary,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                title: const Text(
                  'Student Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    letterSpacing: 0.3,
                  ),
                ),
                centerTitle: true,
                actions: [
                  _AppBarActionButton(
                    isEditing: _isEditing,
                    onTap: _isEditing
                        ? _saveProfile
                        : () => setState(() => _isEditing = true),
                  ),
                  const SizedBox(width: 8),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: FadeTransition(
                    opacity: _headerFade,
                    child: _ProfileHeroHeader(
                      primary: _primary,
                      secondary: _secondary,
                      avatarBytes: _avatarBytes,
                      avatarUrl: _profile?['avatar_url'],
                      isEditing: _isEditing,
                      onAvatarTap: _isEditing ? _pickAvatar : _openZoom,
                      displayName: _profile?['name'] ?? '',
                      studentId: _profile?['student_id'] ?? '',
                      completeness: _completeness,
                    ),
                  ),
                ),
              ),

              // ── BODY ───────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 540),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.04),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                        child: _isEditing
                            ? _EditForm(
                                key: const ValueKey('edit'),
                                studentIdCtrl: studentIdCtrl,
                                nameCtrl: nameCtrl,
                                emailCtrl: emailCtrl,
                                contactCtrl: contactCtrl,
                                facebookCtrl: facebookCtrl,
                                onSave: _saveProfile,
                              )
                            : _ViewCard(
                                key: const ValueKey('view'),
                                profile: _profile,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── ZOOM OVERLAY ───────────────────────────────────────────────────
          _AvatarZoomOverlay(
            isVisible: _showZoom,
            avatarImage: avatarImage,
            displayName: _profile?['name'] ?? '',
            onClose: _closeZoom,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _ProfileHeroHeader — Polished centered layout with completeness ring
// =============================================================================
class _ProfileHeroHeader extends StatelessWidget {
  final Color primary;
  final Color secondary;
  final Uint8List? avatarBytes;
  final String? avatarUrl;
  final bool isEditing;
  final VoidCallback? onAvatarTap;
  final String displayName;
  final String studentId;
  final double completeness;

  const _ProfileHeroHeader({
    required this.primary,
    required this.secondary,
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

    return Container(
      decoration: BoxDecoration(
        // AFTER — full indigo → cyan, matches the screenshot exactly
        gradient: LinearGradient(
          colors: [
            primary, // #4F46E5 Indigo
            secondary, // #06B6D4 Cyan
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // ── Decorative background orbs ─────────────────────────────────────
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -50,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          Positioned(
            top: 60,
            left: 30,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),

          // ── Main centered content ──────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Avatar with glowing ring
                  GestureDetector(
                    onTap: onAvatarTap,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        // Outer glow ring
                        Container(
                          width: avatarSize + 20,
                          height: avatarSize + 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                              colors: [
                                secondary.withOpacity(0.7),
                                primary.withOpacity(0.3),
                                secondary.withOpacity(0.7),
                              ],
                            ),
                          ),
                        ),
                        // White ring
                        Container(
                          width: avatarSize + 8,
                          height: avatarSize + 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                        // Avatar
                        CircleAvatar(
                          radius: avatarSize / 2,
                          backgroundColor: const Color(0xFFE0E7FF),
                          backgroundImage: avatarBytes != null
                              ? MemoryImage(avatarBytes!) as ImageProvider
                              : null,
                          child: avatarBytes == null
                              ? (avatarUrl != null && avatarUrl!.isNotEmpty
                                  ? ClipOval(
                                      child: Image.network(
                                        avatarUrl!,
                                        fit: BoxFit.cover,
                                        width: avatarSize,
                                        height: avatarSize,
                                        errorBuilder: (_, __, ___) => Icon(
                                          Icons.person_rounded,
                                          size: avatarSize * 0.48,
                                          color: const Color(0xFF4F46E5),
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      Icons.person_rounded,
                                      size: avatarSize * 0.48,
                                      color: const Color(0xFF4F46E5),
                                    ))
                              : null,
                        ),

                        // Camera badge (edit mode)
                        if (isEditing)
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [primary, secondary],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.18),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),

                        // Zoom badge (view mode, avatar exists)
                        if (!isEditing &&
                            (avatarBytes != null ||
                                (avatarUrl != null && avatarUrl!.isNotEmpty)))
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
                                    color: Colors.black.withOpacity(0.12),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.zoom_in_rounded,
                                size: 14,
                                color: Color(0xFF06B6D4),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Name / placeholder
                  if (displayName.isNotEmpty) ...[
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.1,
                      ),
                    ),
                    if (studentId.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            studentId,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.90),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                  ] else
                    Text(
                      isEditing ? 'Tap photo to upload' : 'No profile set',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),

                  const SizedBox(height: 14),

                  // ── Profile completeness bar ───────────────────────────────
                  if (!isEditing)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Profile Completeness',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.70),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${(completeness * 100).toInt()}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: completeness,
                              minHeight: 5,
                              backgroundColor: Colors.white.withOpacity(0.20),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF06B6D4),
                              ),
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
    final size = MediaQuery.of(context).size;
    final imgSize = (size.width * 0.70).clamp(0.0, 300.0);

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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: imgSize + 8,
                          height: imgSize + 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.20),
                              width: 4,
                            ),
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
                          Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          'Tap × to close',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.40),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
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
                            color: Colors.white.withOpacity(0.20),
                            width: 1,
                          ),
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
// _AppBarActionButton — pill with icon + label
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
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
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isEditing ? Icons.check_rounded : Icons.edit_rounded,
              color: isEditing ? const Color(0xFF4F46E5) : Colors.white,
              size: 15,
            ),
            const SizedBox(width: 5),
            Text(
              isEditing ? 'Save' : 'Edit',
              style: TextStyle(
                color: isEditing ? const Color(0xFF4F46E5) : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// _ViewCard — profile details display, polished rows
// =============================================================================
class _ViewCard extends StatelessWidget {
  final Map<String, dynamic>? profile;

  const _ViewCard({super.key, required this.profile});

  static const _fields = [
    _FieldDef(
        Icons.badge_rounded, 'Student ID', 'student_id', Color(0xFF4F46E5)),
    _FieldDef(Icons.person_rounded, 'Full Name', 'name', Color(0xFF0891B2)),
    _FieldDef(Icons.email_rounded, 'Email', 'email', Color(0xFF0D9488)),
    _FieldDef(Icons.phone_rounded, 'Contact', 'contact', Color(0xFF16A34A)),
    _FieldDef(
        Icons.facebook_rounded, 'Facebook', 'facebook', Color(0xFF2563EB)),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel(text: 'Profile Details'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withOpacity(0.07),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: _buildRows(profile)),
        ),
      ],
    );
  }

  static List<Widget> _buildRows(Map<String, dynamic>? profile) {
    final rows = <Widget>[];
    for (int i = 0; i < _fields.length; i++) {
      rows.add(_ProfileInfoRow(
        fieldDef: _fields[i],
        value: profile?[_fields[i].key] ?? '',
        isFirst: i == 0,
        isLast: i == _fields.length - 1,
      ));
      if (i < _fields.length - 1) {
        rows.add(Divider(
          height: 1,
          thickness: 1,
          indent: 70,
          endIndent: 20,
          color: Colors.grey.shade100,
        ));
      }
    }
    return rows;
  }
}

class _FieldDef {
  final IconData icon;
  final String label;
  final String key;
  final Color color;
  const _FieldDef(this.icon, this.label, this.key, this.color);
}

class _ProfileInfoRow extends StatelessWidget {
  final _FieldDef fieldDef;
  final String value;
  final bool isFirst;
  final bool isLast;

  const _ProfileInfoRow({
    required this.fieldDef,
    required this.value,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = value.isEmpty || value == 'Not set';

    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(20) : Radius.zero,
        bottom: isLast ? const Radius.circular(20) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon container — rounded square with tinted bg
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: fieldDef.color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(fieldDef.icon, color: fieldDef.color, size: 19),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fieldDef.label.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isEmpty ? 'Not added yet' : value,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: isEmpty ? FontWeight.w400 : FontWeight.w600,
                      color: isEmpty
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF0F172A),
                      fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ),

            // Filled indicator dot
            if (!isEmpty)
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: fieldDef.color.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// _EditForm — polished edit layout
// =============================================================================
class _EditForm extends StatelessWidget {
  final TextEditingController studentIdCtrl;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController contactCtrl;
  final TextEditingController facebookCtrl;
  final VoidCallback onSave;

  const _EditForm({
    super.key,
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
        const _SectionLabel(text: 'Edit Information'),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withOpacity(0.07),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
          child: Column(
            children: [
              _FormField(
                label: 'Student ID',
                controller: studentIdCtrl,
                hint: 'e.g., 202324-1234',
                icon: Icons.badge_rounded,
                iconColor: const Color(0xFF4F46E5),
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
        _GradientSaveButton(onTap: onSave),
        const SizedBox(height: 10),
        const Center(
          child: Text(
            '* Required fields',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF94A3B8),
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
  final bool isRequired;
  final bool isLast;
  final TextInputType? keyboardType;

  const _FormField({
    super.key,
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
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();

    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: widget.isLast ? 0 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LABEL
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 7),
            child: RichText(
              text: TextSpan(
                text: widget.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF374151),
                  letterSpacing: 0.2,
                ),
                children: widget.isRequired
                    ? const [
                        TextSpan(
                          text: ' *',
                          style: TextStyle(
                            color: Color(0xFFE11D48),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ]
                    : [],
              ),
            ),
          ),

          // TEXT FIELD
          TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            keyboardType: widget.keyboardType,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: _isFocused ? '' : widget.hint, // ✨ fade trigger
              hintStyle: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),

              prefixIcon: Padding(
                padding: const EdgeInsets.all(10),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: widget.iconColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(widget.icon, color: widget.iconColor, size: 16),
                ),
              ),

              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 15),

              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide.none,
              ),

              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide:
                    const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
              ),

              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide:
                    const BorderSide(color: Color(0xFF4F46E5), width: 1.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientSaveButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GradientSaveButton({required this.onTap});

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
            gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withOpacity(0.32),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 19),
                SizedBox(width: 8),
                Text(
                  'Save Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _SectionLabel — unified with Dashboard
// =============================================================================
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
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
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
            color: Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}
