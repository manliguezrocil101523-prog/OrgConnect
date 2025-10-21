import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/app_state.dart';

class OrgFormScreen extends StatefulWidget {
  final String title;
  final String logoAsset;

  const OrgFormScreen({
    Key? key,
    required this.title,
    required this.logoAsset,
  }) : super(key: key);

  @override
  State<OrgFormScreen> createState() => _OrgFormScreenState();
}

class OrgFormContent extends StatefulWidget {
  final String title;
  final String logoAsset;

  const OrgFormContent({
    Key? key,
    required this.title,
    required this.logoAsset,
  }) : super(key: key);

  @override
  State<OrgFormContent> createState() => _OrgFormContentState();
}

class _OrgFormScreenState extends State<OrgFormScreen> {
  // Design colors
  static const Color mintBg = Color(0xFFEAF6F0); // very light mint
  static const Color tealHeader = Color(0xFF79CFC4); // header band
  static const Color pillFill = Color(0xFF8FD4CC); // text field fill
  static const Color buttonGradStart = Color(0xFF3DD13A);
  static const Color buttonGradEnd = Color(0xFF1FB31A);
  static const Color accentViolet = Color(0xFF4A148C); // for APPLY label

  // Controllers
  final TextEditingController studentIdCtrl = TextEditingController();
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController courseCtrl = TextEditingController();
  final TextEditingController yearSectionCtrl = TextEditingController();
  final TextEditingController contactCtrl = TextEditingController();
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController facebookCtrl = TextEditingController();
  final TextEditingController reasonCtrl = TextEditingController();
  final TextEditingController skillsCtrl = TextEditingController();
  final TextEditingController availabilityCtrl = TextEditingController();
  final TextEditingController experienceCtrl = TextEditingController();
  final TextEditingController emergencyCtrl = TextEditingController();

  bool agreed = false;

  // Attachments (images/videos)
  List<PlatformFile> attachments = [];

  @override
  void dispose() {
    studentIdCtrl.dispose();
    nameCtrl.dispose();
    courseCtrl.dispose();
    yearSectionCtrl.dispose();
    contactCtrl.dispose();
    emailCtrl.dispose();
    facebookCtrl.dispose();
    reasonCtrl.dispose();
    skillsCtrl.dispose();
    availabilityCtrl.dispose();
    experienceCtrl.dispose();
    emergencyCtrl.dispose();
    super.dispose();
  }

  bool get _isEnabled =>
      agreed &&
      studentIdCtrl.text.trim().isNotEmpty &&
      nameCtrl.text.trim().isNotEmpty &&
      contactCtrl.text.trim().isNotEmpty;

  String _formatToday() {
    final now = DateTime.now();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  Future<void> _pickAttachments() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'gif',
          'heic',
          'webp',
          'mp4',
          'mov',
          'm4v',
          'avi',
          'mkv',
          'webm'
        ],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() => attachments.addAll(result.files));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attachment pick failed: $e')),
      );
    }
  }

  IconData _iconForExt(String? ext) {
    final e = (ext ?? '').toLowerCase();
    const imgExts = {'jpg', 'jpeg', 'png', 'gif', 'heic', 'webp'};
    const vidExts = {'mp4', 'mov', 'm4v', 'avi', 'mkv', 'webm'};
    if (imgExts.contains(e)) return Icons.image;
    if (vidExts.contains(e)) return Icons.movie_creation_outlined;
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mintBg,
      appBar: AppBar(
        backgroundColor: tealHeader,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(
          widget.title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
      ),
      body: OrgFormContent(
        title: widget.title,
        logoAsset: widget.logoAsset,
      ),
    );
  }
}

class _OrgFormContentState extends State<OrgFormContent> {
  // Design colors
  static const Color mintBg = Color(0xFFEAF6F0); // very light mint
  static const Color tealHeader = Color(0xFF79CFC4); // header band
  static const Color pillFill = Color(0xFF8FD4CC); // text field fill
  static const Color buttonGradStart = Color(0xFF3DD13A);
  static const Color buttonGradEnd = Color(0xFF1FB31A);
  static const Color accentViolet = Color(0xFF4A148C); // for APPLY label

  // Controllers
  final TextEditingController studentIdCtrl = TextEditingController();
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController courseCtrl = TextEditingController();
  final TextEditingController yearSectionCtrl = TextEditingController();
  final TextEditingController contactCtrl = TextEditingController();
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController facebookCtrl = TextEditingController();
  final TextEditingController reasonCtrl = TextEditingController();
  final TextEditingController skillsCtrl = TextEditingController();
  final TextEditingController availabilityCtrl = TextEditingController();
  final TextEditingController experienceCtrl = TextEditingController();
  final TextEditingController emergencyCtrl = TextEditingController();

  bool agreed = false;

  // Attachments (images/videos)
  List<PlatformFile> attachments = [];

  @override
  void dispose() {
    studentIdCtrl.dispose();
    nameCtrl.dispose();
    courseCtrl.dispose();
    yearSectionCtrl.dispose();
    contactCtrl.dispose();
    emailCtrl.dispose();
    facebookCtrl.dispose();
    reasonCtrl.dispose();
    skillsCtrl.dispose();
    availabilityCtrl.dispose();
    experienceCtrl.dispose();
    emergencyCtrl.dispose();
    super.dispose();
  }

  bool get _isEnabled =>
      agreed &&
      studentIdCtrl.text.trim().isNotEmpty &&
      nameCtrl.text.trim().isNotEmpty &&
      contactCtrl.text.trim().isNotEmpty;

  String _formatToday() {
    final now = DateTime.now();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  Future<void> _pickAttachments() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'gif',
          'heic',
          'webp',
          'mp4',
          'mov',
          'm4v',
          'avi',
          'mkv',
          'webm'
        ],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() => attachments.addAll(result.files));
      }
    } catch (e) {
      if (!mounted) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Attachment pick failed: $e')),
        );
      }
    }
  }

  IconData _iconForExt(String? ext) {
    final e = (ext ?? '').toLowerCase();
    const imgExts = {'jpg', 'jpeg', 'png', 'gif', 'heic', 'webp'};
    const vidExts = {'mp4', 'mov', 'm4v', 'avi', 'mkv', 'webm'};
    if (imgExts.contains(e)) return Icons.image;
    if (vidExts.contains(e)) return Icons.movie_creation_outlined;
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.04; // 4% of screen width
    final verticalPadding = screenWidth * 0.05; // 5% of screen width

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding, vertical: verticalPadding),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: screenWidth < 600 ? screenWidth * 0.95 : 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth < 600 ? horizontalPadding : 16,
                  vertical: screenWidth < 600 ? verticalPadding * 0.8 : 18,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _pillField(
                        controller: studentIdCtrl,
                        label: 'STUDENT ID NUMBER',
                        hint: 'e.g., 2023-01234'),
                    _pillField(
                        controller: nameCtrl,
                        label: 'FULL NAME',
                        hint: 'First Last',
                        keyboardType: TextInputType.name),
                    _pillField(
                        controller: courseCtrl,
                        label: 'COURSE / PROGRAM',
                        hint: 'e.g., BSIT, BSHM'),
                    _pillField(
                        controller: yearSectionCtrl,
                        label: 'YEAR & SECTION',
                        hint: '3rd Year • Section A'),
                    _pillField(
                        controller: contactCtrl,
                        label: 'CONTACT NUMBER',
                        hint: '+63 912 345 6789',
                        keyboardType: TextInputType.phone),
                    _pillField(
                        controller: emailCtrl,
                        label: 'EMAIL ADDRESS',
                        hint: 'name@school.edu.ph',
                        keyboardType: TextInputType.emailAddress),
                    _pillField(
                        controller: facebookCtrl,
                        label: 'FACEBOOK ACCOUNT',
                        hint: 'facebook.com/your.profile',
                        keyboardType: TextInputType.url),
                    _pillField(
                        controller: reasonCtrl,
                        label: 'REASON FOR JOINING (SHORT)',
                        hint: 'Why do you want to join? (1–2 sentences)',
                        maxLines: 3,
                        keyboardType: TextInputType.multiline),
                    _pillField(
                        controller: skillsCtrl,
                        label: 'SKILLS / TALENTS',
                        hint: 'acting, directing, scriptwriting…'),
                    _pillField(
                        controller: availabilityCtrl,
                        label: 'AVAILABILITY / PREFERRED SCHEDULE',
                        hint: 'Weekdays evenings / Weekends'),
                    _pillField(
                        controller: experienceCtrl,
                        label: 'PREVIOUS EXPERIENCE',
                        hint: 'Past plays, roles, orgs (optional)'),
                    _pillField(
                        controller: emergencyCtrl,
                        label: 'EMERGENCY CONTACT',
                        hint: 'Name — Phone'),

                    const SizedBox(height: 4),

                    // Sent Attachments section
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: const [
                          Icon(Icons.attach_file,
                              size: 16, color: Colors.black87),
                          SizedBox(width: 6),
                          Text(
                            'SENT ATTACHMENTS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (int i = 0; i < attachments.length; i++)
                                InputChip(
                                  avatar: Icon(
                                      _iconForExt(attachments[i].extension),
                                      size: 18),
                                  label: Text(attachments[i].name,
                                      overflow: TextOverflow.ellipsis),
                                  onDeleted: () =>
                                      setState(() => attachments.removeAt(i)),
                                ),
                              if (attachments.isEmpty)
                                const Text(
                                  'No attachments yet. You can add images or videos.',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.black54),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ElevatedButton.icon(
                              onPressed: _pickAttachments,
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text('Add Attachment'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: tealHeader,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Profile picture upload control (placeholder)
                    Row(
                      children: [
                        const Text(
                          'PROFILE PICTURE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.1,
                            color: Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Profile picture upload is a visual placeholder. Integrate image_picker to enable uploads.'),
                                duration: Duration(seconds: 3),
                              ),
                            );
                          },
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundImage: AssetImage(widget.logoAsset),
                                backgroundColor: Colors.white,
                              ),
                              Positioned(
                                bottom: -2,
                                right: -2,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: tealHeader,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      )
                                    ],
                                  ),
                                  child: const Icon(Icons.camera_alt,
                                      size: 14, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Date of application
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today,
                              size: 14, color: Colors.grey.shade700),
                          const SizedBox(width: 6),
                          Text(
                            'Date of Application: ${_formatToday()}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Agreement with link-style policy
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Transform.translate(
                          offset: const Offset(-6, -2),
                          child: Checkbox(
                            value: agreed,
                            onChanged: (v) =>
                                setState(() => agreed = v ?? false),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            side: BorderSide(
                                color: Colors.grey.shade700, width: 1.4),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4)),
                            activeColor: tealHeader,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.black87),
                              children: [
                                const TextSpan(
                                    text: 'I agree to follow org rules & '),
                                TextSpan(
                                  text: 'privacy policy',
                                  style: const TextStyle(
                                      color: Colors.blueAccent,
                                      decoration: TextDecoration.underline),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'Open rules & privacy policy'),
                                              duration: Duration(seconds: 2)),
                                        );
                                      }
                                    },
                                ),
                                const TextSpan(text: '.'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Status badge
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6B5B95).withOpacity(0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Status: Pending',
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B5B95),
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // APPLY button
                    _applyButton(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _applyButton(BuildContext context) {
    final bool enabled = _isEnabled;
    final Gradient gradient = LinearGradient(
      colors: enabled
          ? const [buttonGradStart, buttonGradEnd]
          : const [Color(0xFF9BEA98), Color(0xFF79D976)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return GestureDetector(
      onTap: enabled
          ? () {
              // Persist application in in-memory AppState (minimalist, non-destructive)
              AppState.instance.submitApplication(
                orgName: widget.title,
                studentId: studentIdCtrl.text.trim(),
                name: nameCtrl.text.trim(),
                contact: contactCtrl.text.trim(),
                email: emailCtrl.text.trim(),
                reason: reasonCtrl.text.trim(),
                skills: skillsCtrl.text.trim(),
                attachments: attachments.map((f) => f.name).toList(),
              );

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Application submitted.')),
              );

              // Keep the navigation as-is to avoid altering your current flow
            }
          : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: enabled ? 1.0 : 0.85,
        child: Container(
          height: 56,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'APPLY',
              style: TextStyle(
                letterSpacing: 2.0,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: accentViolet,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pillField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    final radius = BorderRadius.circular(40);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: Colors.black87,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            minLines: maxLines > 1 ? maxLines : 1,
            textAlignVertical:
                maxLines > 1 ? TextAlignVertical.top : TextAlignVertical.center,
            decoration: InputDecoration(
              filled: true,
              fillColor: pillFill,
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.black87, fontSize: 13.5),
              contentPadding: EdgeInsets.symmetric(
                  horizontal: 20, vertical: maxLines > 1 ? 18 : 16),
              border: OutlineInputBorder(
                borderRadius: radius,
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
