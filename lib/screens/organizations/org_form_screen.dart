import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_state.dart';

class OrgFormScreen extends StatelessWidget {
  final String title;
  final String logoAsset;

  const OrgFormScreen({
    super.key,
    required this.title,
    required this.logoAsset,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _FormColors.background,
      appBar: AppBar(
        backgroundColor: _FormColors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text(
          'Student Application',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: OrgFormContent(title: title, logoAsset: logoAsset),
    );
  }
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

abstract class _FormColors {
  static const background = Color(0xFFF2FAF7);
  static const card = Colors.white;
  static const green = Color(0xFF0F8A61);
  static const darkGreen = Color(0xFF075A42);
  static const brightGreen = Color(0xFF20B77D);
  static const text = Color(0xFF173B30);
  static const muted = Color(0xFF6B8178);
  static const label = Color(0xFF53635D);
  static const border = Color(0xFFD7E6E0);
  static const field = Color(0xFFF7F9FA);
  static const error = Color(0xFFB42318);
}

class _OrgFormContentState extends State<OrgFormContent> {
  final _formKey = GlobalKey<FormState>();

  final studentIdCtrl = TextEditingController();
  final fullNameCtrl = TextEditingController();
  final courseCtrl = TextEditingController();
  final yearCtrl = TextEditingController();
  final sectionCtrl = TextEditingController();
  final contactCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final facebookCtrl = TextEditingController();
  final reasonCtrl = TextEditingController();
  final skillsCtrl = TextEditingController();
  final experienceCtrl = TextEditingController();
  final emergencyContactCtrl = TextEditingController();

  bool _isSubmitting = false;
  bool _isUploading = false;
  final List<String> _attachments = [];
  final List<String> _attachmentNames = [];

  static const List<String> _courseOptions = [
    'BEED',
    'BSED',
    'BSCRIM',
    'BSIT',
    'BSHM',
    'BSTM',
  ];

  static const List<String> _yearOptions = [
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
  ];

  @override
  void initState() {
    super.initState();
    for (final controller in [
      studentIdCtrl,
      fullNameCtrl,
      courseCtrl,
      yearCtrl,
      sectionCtrl,
      contactCtrl,
      emailCtrl,
      facebookCtrl,
      reasonCtrl,
      skillsCtrl,
      experienceCtrl,
      emergencyContactCtrl,
    ]) {
      controller.addListener(_refresh);
    }

    // The account profile is the source of truth for identity information.
    // Prefill the application from the profile created at sign-up so students
    // do not have to type their name, ID, email, contact, and Facebook again.
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillFromProfile());
  }

  Future<void> _prefillFromProfile() async {
    try {
      await AppState.instance.loadStudentProfile();
      final profile = AppState.instance.currentStudent;
      if (!mounted || profile == null) return;

      if (studentIdCtrl.text.trim().isEmpty) studentIdCtrl.text = profile.studentId;
      if (fullNameCtrl.text.trim().isEmpty) fullNameCtrl.text = profile.name;
      if (emailCtrl.text.trim().isEmpty) emailCtrl.text = profile.email;
      if (contactCtrl.text.trim().isEmpty) contactCtrl.text = profile.contact;
      if (facebookCtrl.text.trim().isEmpty) facebookCtrl.text = profile.facebook;
    } catch (_) {
      // The form remains usable if the cached profile is temporarily unavailable.
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final controller in [
      studentIdCtrl,
      fullNameCtrl,
      courseCtrl,
      yearCtrl,
      sectionCtrl,
      contactCtrl,
      emailCtrl,
      facebookCtrl,
      reasonCtrl,
      skillsCtrl,
      experienceCtrl,
      emergencyContactCtrl,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _requiredFieldsComplete =>
      studentIdCtrl.text.trim().isNotEmpty &&
      fullNameCtrl.text.trim().isNotEmpty &&
      courseCtrl.text.trim().isNotEmpty &&
      yearCtrl.text.trim().isNotEmpty &&
      sectionCtrl.text.trim().isNotEmpty &&
      contactCtrl.text.trim().isNotEmpty &&
      emailCtrl.text.trim().isNotEmpty &&
      facebookCtrl.text.trim().isNotEmpty &&
      reasonCtrl.text.trim().isNotEmpty &&
      skillsCtrl.text.trim().isNotEmpty &&
      experienceCtrl.text.trim().isNotEmpty &&
      emergencyContactCtrl.text.trim().isNotEmpty;

  String _yearSection() {
    return '${yearCtrl.text.trim()} • ${sectionCtrl.text.trim()}';
  }

  String _formatReason() => reasonCtrl.text.trim();

  String _formatSkills() => skillsCtrl.text.trim();

  String _formatExperience() => experienceCtrl.text.trim();

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      await AppState.instance.submitApplication(
        orgName: widget.title,
        studentId: studentIdCtrl.text.trim(),
        name: fullNameCtrl.text.trim(),
        course: courseCtrl.text.trim(),
        yearSection: _yearSection(),
        contact: contactCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        facebook: facebookCtrl.text.trim(),
        reason: _formatReason(),
        skills: _formatSkills(),
        experience: _formatExperience(),
        emergencyContact: emergencyContactCtrl.text.trim(),
        attachments: List<String>.from(_attachments),
        // Reuse the student's saved profile picture in the application snapshot.
        profilePicUrl: AppState.instance.currentStudent?.avatarUrl ?? '',
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Your application to ${widget.title} was submitted.'),
          backgroundColor: _FormColors.darkGreen,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not submit the application: $e'),
          backgroundColor: _FormColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final contentWidth = width < 700 ? width : 680.0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        width < 600 ? 16 : 24,
        20,
        width < 600 ? 16 : 24,
        44,
      ),
      child: Center(
        child: SizedBox(
          width: contentWidth,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _organizationHeader(),
                const SizedBox(height: 16),
                _sectionCard(
                  icon: Icons.school_rounded,
                  title: 'Student Information',
                  subtitle: 'Please provide your student information accurately.',
                  children: [
                    _fieldLabel('STUDENT ID NUMBER', required: true),
                    _field(
                      controller: studentIdCtrl,
                      hint: 'e.g. 202324-1234',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
                      ],
                      validator: (value) {
                        final error = _requiredValidator(value);
                        if (error != null) return error;
                        if (!RegExp(r'^\d{6}-\d{4}$').hasMatch(value!.trim())) {
                          return 'Use this format: 202324-1234';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 5),
                    _fieldLabel('FULL NAME', required: true),
                    _field(
                      controller: fullNameCtrl,
                      hint: 'e.g. Gon Castillo',
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 5),
                    _fieldLabel('COURSE / PROGRAM', required: true),
                    _dropdownField(
                      controller: courseCtrl,
                      hint: 'Select your course / program',
                      options: _courseOptions,
                      dialogTitle: 'Select Course / Program',
                    ),
                    const SizedBox(height: 5),
                    _fieldLabel('YEAR & SECTION', required: true),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: _dropdownField(
                            controller: yearCtrl,
                            hint: 'Select year',
                            options: _yearOptions,
                            dialogTitle: 'Select Year Level',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 4,
                          child: _field(
                            controller: sectionCtrl,
                            hint: 'e.g. A',
                            validator: _requiredValidator,
                            textCapitalization: TextCapitalization.characters,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _sectionCard(
                  icon: Icons.contact_phone_rounded,
                  title: 'Contact Information',
                  subtitle: 'Enter the accounts and number you currently use.',
                  children: [
                    _fieldLabel('CONTACT NUMBER', required: true),
                    _field(
                      controller: contactCtrl,
                      hint: 'e.g. 09171234567',
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      validator: (value) {
                        final error = _requiredValidator(value);
                        if (error != null) return error;
                        if (!RegExp(r'^09\d{9}$').hasMatch(value!.trim())) {
                          return 'Enter an 11-digit Philippine mobile number.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 5),
                    _fieldLabel('EMAIL ADDRESS', required: true),
                    _field(
                      controller: emailCtrl,
                      hint: 'e.g. juan.delacruz@gmail.com',
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        final error = _requiredValidator(value);
                        if (error != null) return error;
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value!.trim())) {
                          return 'Enter a valid email address.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 5),
                    _fieldLabel('FACEBOOK ACCOUNT', required: true),
                    _field(
                      controller: facebookCtrl,
                      hint: 'e.g. Gon',
                      keyboardType: TextInputType.url,
                      validator: _requiredValidator,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _sectionCard(
                  icon: Icons.theater_comedy_rounded,
                  title: 'About Your Application',
                  subtitle: 'Tell the organization what you can bring to the group.',
                  children: [
                    _fieldLabel('REASON FOR JOINING', required: true),
                    _field(
                      controller: reasonCtrl,
                      hint: 'e.g. I want to improve my acting skills and be part of EL TIATRO performances.',
                      maxLines: 4,
                      validator: (value) {
                        final error = _requiredValidator(value);
                        if (error != null) return error;
                        if (value!.trim().length < 10) {
                          return 'Please provide a little more detail.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 5),
                    _fieldLabel('SKILLS / TALENTS', required: true),
                    _field(
                      controller: skillsCtrl,
                      hint: 'e.g. Acting, singing, dancing, or scriptwriting',
                      maxLines: 3,
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 5),
                    _fieldLabel('PREVIOUS EXPERIENCE', required: true),
                    _field(
                      controller: experienceCtrl,
                      hint: 'e.g. School play, classroom performance, or None',
                      maxLines: 3,
                      validator: _requiredValidator,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _sectionCard(
                  icon: Icons.health_and_safety_outlined,
                  title: 'Emergency Contact',
                  subtitle: 'Provide a person the organization can contact when necessary.',
                  children: [
                    _fieldLabel('EMERGENCY CONTACT', required: true),
                    _field(
                      controller: emergencyContactCtrl,
                      hint: 'e.g. Maria Santos - 09181234567',
                      keyboardType: TextInputType.phone,
                      validator: _requiredValidator,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _attachmentCard(),
                const SizedBox(height: 18),
                _submitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickAttachments() async {
    if (_isUploading) return;
    try {
      setState(() => _isUploading = true);
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.custom,
        allowedExtensions: [
          'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic',
          'mp4', 'mov', 'm4v', 'avi', 'mkv', 'webm',
        ],
      );
      if (result == null || result.files.isEmpty) return;

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) continue;
        final safeName = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
        final path = 'application_attachments/${user.id}/${DateTime.now().microsecondsSinceEpoch}_$safeName';
        // Application files belong to the application_assets bucket.
        await supabase.storage.from('application_assets').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: false),
        );
        final url = supabase.storage.from('application_assets').getPublicUrl(path);
        _attachments.add(url);
        _attachmentNames.add(file.name);
      }

      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not add attachment: $e'),
          backgroundColor: _FormColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
      _attachmentNames.removeAt(index);
    });
  }

  Widget _attachmentCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 17, 16, 18),
      decoration: BoxDecoration(
        color: _FormColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _FormColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F7F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.attach_file_rounded, color: _FormColors.green, size: 21),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Attachments', style: TextStyle(color: _FormColors.text, fontSize: 15.5, fontWeight: FontWeight.w900)),
                    SizedBox(height: 2),
                    Text('Add photos or videos of your work, performances, drawings, or other supporting materials.', style: TextStyle(color: _FormColors.muted, fontSize: 11.5, height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _isUploading ? null : _pickAttachments,
            icon: _isUploading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.add_photo_alternate_rounded),
            label: Text(_isUploading ? 'Uploading...' : 'Add Photos / Videos'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: _FormColors.green,
              side: const BorderSide(color: _FormColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
            ),
          ),
          if (_attachmentNames.isNotEmpty) ...[
            const SizedBox(height: 10),
            ..._attachmentNames.asMap().entries.map((entry) {
              final i = entry.key;
              final name = entry.value;
              return Container(
                margin: const EdgeInsets.only(top: 7),
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                decoration: BoxDecoration(
                  color: _FormColors.field,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: _FormColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.insert_drive_file_rounded, size: 19, color: _FormColors.green),
                    const SizedBox(width: 8),
                    Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _FormColors.text))),
                    IconButton(
                      tooltip: 'Remove',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _removeAttachment(i),
                      icon: const Icon(Icons.close_rounded, size: 19, color: _FormColors.muted),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _organizationHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            _FormColors.darkGreen,
            _FormColors.green,
            _FormColors.brightGreen,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _FormColors.green.withOpacity(.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _organizationLogo(62),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'STUDENT APPLICATION',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Fill out the form below to apply as a student member.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _organizationLogo(double size) {
    Widget image;
    if (widget.logoAsset.startsWith('http')) {
      image = Image.network(
        widget.logoAsset,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.groups_rounded,
          color: _FormColors.green,
          size: 30,
        ),
      );
    } else if (widget.logoAsset.isNotEmpty) {
      image = Image.asset(
        widget.logoAsset,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.groups_rounded,
          color: _FormColors.green,
          size: 30,
        ),
      );
    } else {
      image = const Icon(
        Icons.groups_rounded,
        color: _FormColors.green,
        size: 30,
      );
    }

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: Colors.white.withOpacity(.55),
          width: 2,
        ),
      ),
      child: ClipOval(child: image),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 17, 16, 18),
      decoration: BoxDecoration(
        color: _FormColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _FormColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F7F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _FormColors.green, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _FormColors.text,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _FormColors.muted,
                        fontSize: 11.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  Widget _fieldLabel(String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 7),
      child: Row(
        children: [
          Text(
            text,
            style: const TextStyle(
              color: _FormColors.label,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: .75,
            ),
          ),
          if (required)
            const Text(
              ' *',
              style: TextStyle(
                color: _FormColors.error,
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    String? Function(String?)? validator,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        minLines: maxLines > 1 ? maxLines : null,
        validator: validator,
        textCapitalization: textCapitalization,
        textInputAction: maxLines > 1
            ? TextInputAction.newline
            : TextInputAction.next,
        style: const TextStyle(
          color: _FormColors.text,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0xFFA6B2AE),
            fontSize: 13,
          ),
          filled: true,
          fillColor: _FormColors.field,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 15,
            vertical: maxLines > 1 ? 14 : 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: _FormColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: _FormColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(
              color: _FormColors.green,
              width: 1.6,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: _FormColors.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(
              color: _FormColors.error,
              width: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _dropdownField({
    required TextEditingController controller,
    required String hint,
    required List<String> options,
    required String dialogTitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DropdownButtonFormField<String>(
        value: controller.text.isEmpty ? null : controller.text,
        isExpanded: true,
        icon: const Icon(Icons.keyboard_arrow_down_rounded),
        dropdownColor: Colors.white,
        menuMaxHeight: 300,
        style: const TextStyle(
          color: _FormColors.text,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0xFFA6B2AE),
            fontSize: 13,
          ),
          filled: true,
          fillColor: _FormColors.field,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: _FormColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: _FormColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(
              color: _FormColors.green,
              width: 1.6,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: _FormColors.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(
              color: _FormColors.error,
              width: 1.4,
            ),
          ),
        ),
        hint: Text(hint),
        items: options
            .map(
              (option) => DropdownMenuItem<String>(
                value: option,
                child: Text(option),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value == null) return;
          controller.text = value;
          setState(() {});
        },
        validator: _requiredValidator,
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }
    return null;
  }

  Widget _submitButton() {
    final enabled = _requiredFieldsComplete && !_isSubmitting;

    return SizedBox(
      height: 56,
      child: FilledButton.icon(
        onPressed: enabled ? _submit : null,
        style: FilledButton.styleFrom(
          backgroundColor: _FormColors.green,
          disabledBackgroundColor: const Color(0xFFB8D6CA),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white70,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: enabled ? 2 : 0,
        ),
        icon: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.send_rounded, size: 20),
        label: Text(
          _isSubmitting ? 'SUBMITTING...' : 'SUBMIT APPLICATION',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: .8,
          ),
        ),
      ),
    );
  }
}
