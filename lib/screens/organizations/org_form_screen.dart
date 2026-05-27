import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/app_state.dart';

class OrgFormScreen extends StatefulWidget {
  final String title;
  final String logoAsset;

  const OrgFormScreen({
    super.key,
    required this.title,
    required this.logoAsset,
  });

  @override
  State<OrgFormScreen> createState() => _OrgFormScreenState();
}

class OrgFormContent extends StatefulWidget {
  final String title;
  final String logoAsset;

  const OrgFormContent({
    super.key,
    required this.title,
    required this.logoAsset,
  });

  @override
  State<OrgFormContent> createState() => _OrgFormContentState();
}

class _OrgFormScreenState extends State<OrgFormScreen> {
  // Design colors
  static const Color mintBg = Color(0xFFEAF6F0);
  static const Color tealHeader = Color(0xFF79CFC4);

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
  final TextEditingController experienceCtrl = TextEditingController();
  final TextEditingController emergencyCtrl = TextEditingController();

  bool agreed = false;
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
    experienceCtrl.dispose();
    emergencyCtrl.dispose();
    super.dispose();
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
  static const Color tealHeader = Color(0xFF79CFC4);
  // Updated: neutral, clean field fill instead of teal/green
  static const Color fieldFill = Color(0xFFF5F6F8);
  static const Color fieldBorder = Color(0xFFDDE1E7);
  static const Color labelColor = Color(0xFF5A6370);
  static const Color buttonGradStart = Color(0xFF3DD13A);
  static const Color buttonGradEnd = Color(0xFF1FB31A);
  static const Color accentViolet = Color(0xFF4A148C);

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
  final TextEditingController experienceCtrl = TextEditingController();
  final TextEditingController emergencyCtrl = TextEditingController();

  bool agreed = false;
  List<PlatformFile> attachments = [];

  // Course quick-select options
  static const List<String> _courseOptions = [
    'BEED',
    'BSIT',
    'BSCRIM',
    'BSHM',
  ];

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
    final horizontalPadding = screenWidth * 0.04;
    final verticalPadding = screenWidth * 0.05;

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
                  color: Colors.white.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Student ID — numbers only, numeric keyboard
                    _pillField(
                      controller: studentIdCtrl,
                      label: 'STUDENT ID NUMBER',
                      hint: 'e.g., 202324-1234',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]')),
                      ],
                    ),

                    _pillField(
                      controller: nameCtrl,
                      label: 'FULL NAME',
                      hint: 'First Last',
                      keyboardType: TextInputType.name,
                    ),

                    // Course field with quick-select chips
                    _courseField(),

                    _pillField(
                      controller: yearSectionCtrl,
                      label: 'YEAR & SECTION',
                      hint: '3rd Year • Section A',
                    ),

                    // Contact — numeric keyboard, digits only
                    _pillField(
                      controller: contactCtrl,
                      label: 'CONTACT NUMBER',
                      hint: '09123456789',
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),

                    _pillField(
                      controller: emailCtrl,
                      label: 'EMAIL',
                      hint: 'youremail@gmail.com',
                      keyboardType: TextInputType.emailAddress,
                    ),

                    _pillField(
                      controller: facebookCtrl,
                      label: 'FACEBOOK ACCOUNT',
                      hint: 'facebook name',
                      keyboardType: TextInputType.url,
                    ),

                    _pillField(
                      controller: reasonCtrl,
                      label: 'REASON FOR JOINING (SHORT)',
                      hint: 'Why do you want to join?',
                      keyboardType: TextInputType.multiline,
                    ),

                    _pillField(
                      controller: skillsCtrl,
                      label: 'SKILLS / TALENTS',
                      hint: 'acting, directing, scriptwriting…',
                    ),

                    _pillField(
                      controller: experienceCtrl,
                      label: 'PREVIOUS EXPERIENCE',
                      hint: 'Past plays, roles, orgs (optional)',
                    ),

                    _pillField(
                      controller: emergencyCtrl,
                      label: 'EMERGENCY CONTACT',
                      hint: 'Name — Phone',
                    ),

                    const SizedBox(height: 4),

                    // Sent Attachments section
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
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
                        color: Colors.white.withValues(alpha: 0.6),
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

                    // Profile picture upload control
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
                                        color:
                                            Colors.black.withValues(alpha: 0.2),
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

                    // Agreement
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
                          color:
                              const Color(0xFF6B5B95).withValues(alpha: 0.10),
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

  /// Course field: text input + quick-select course buttons below
  Widget _courseField() {
    final radius = BorderRadius.circular(40);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 6),
          child: Text(
            'COURSE / PROGRAM',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: labelColor,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextField(
            controller: courseCtrl,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              filled: true,
              fillColor: fieldFill,
              hintText: 'e.g., BSIT, BSHM',
              hintStyle:
                  const TextStyle(color: Color(0xFFADB5BD), fontSize: 13.5),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: radius,
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: radius,
                borderSide: const BorderSide(color: fieldBorder, width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: radius,
                borderSide:
                    const BorderSide(color: Color(0xFF79CFC4), width: 1.8),
              ),
            ),
          ),
        ),
        // Quick-select buttons
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8, top: 2),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _courseOptions.map((course) {
              final isSelected = courseCtrl.text == course;
              return GestureDetector(
                onTap: () {
                  setState(() => courseCtrl.text = course);
                  courseCtrl.selection = TextSelection.fromPosition(
                    TextPosition(offset: courseCtrl.text.length),
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF79CFC4) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF79CFC4)
                          : const Color(0xFFDDE1E7),
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF79CFC4)
                                  .withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : [],
                  ),
                  child: Text(
                    course,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          isSelected ? Colors.white : const Color(0xFF5A6370),
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
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
          ? () async {
              await AppState.instance.submitApplication(
                orgName: widget.title,
                studentId: studentIdCtrl.text.trim(),
                name: nameCtrl.text.trim(),
                contact: contactCtrl.text.trim(),
                email: emailCtrl.text.trim(),
                reason: reasonCtrl.text.trim(),
                skills: skillsCtrl.text.trim(),
                attachments: attachments.map((f) => f.name).toList(),
              );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Application submitted to ${widget.title}!'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
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
                color: Colors.black.withValues(alpha: 0.12),
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
    List<TextInputFormatter>? inputFormatters,
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
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: labelColor,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            maxLines: maxLines,
            minLines: maxLines > 1 ? maxLines : 1,
            textAlignVertical:
                maxLines > 1 ? TextAlignVertical.top : TextAlignVertical.center,
            decoration: InputDecoration(
              filled: true,
              fillColor: fieldFill,
              hintText: hint,
              hintStyle:
                  const TextStyle(color: Color(0xFFADB5BD), fontSize: 13.5),
              contentPadding: EdgeInsets.symmetric(
                  horizontal: 20, vertical: maxLines > 1 ? 18 : 16),
              border: OutlineInputBorder(
                borderRadius: radius,
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: radius,
                borderSide: const BorderSide(color: fieldBorder, width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: radius,
                borderSide:
                    const BorderSide(color: Color(0xFF79CFC4), width: 1.8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
