import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_state.dart';

class OrgFormScreen extends StatelessWidget {
  final String title;
  final String logoAsset;
  final String? orgId;
  final String category;

  const OrgFormScreen({
    super.key,
    required this.title,
    required this.logoAsset,
    this.orgId,
    this.category = '',
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
      body: OrgFormContent(
          title: title, logoAsset: logoAsset, orgId: orgId, category: category),
    );
  }
}

class OrgFormContent extends StatefulWidget {
  final String title;
  final String logoAsset;
  final String? orgId;
  final String category;
  final bool embedded;

  const OrgFormContent({
    super.key,
    required this.title,
    required this.logoAsset,
    this.orgId,
    this.category = '',
    this.embedded = false,
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

  final studentIdFocus = FocusNode();
  final fullNameFocus = FocusNode();
  final courseFocus = FocusNode();
  final yearFocus = FocusNode();
  final sectionFocus = FocusNode();
  final contactFocus = FocusNode();
  final emailFocus = FocusNode();
  final facebookFocus = FocusNode();
  final reasonFocus = FocusNode();
  final skillsFocus = FocusNode();
  final experienceFocus = FocusNode();
  final emergencyContactFocus = FocusNode();

  bool _isSubmitting = false;
  bool _isUploading = false;
  int _resetCount = 0;
  final List<String> _attachments = [];
  final List<String> _attachmentPaths = [];
  final List<String> _attachmentNames = [];

  static const int _maxFileSize = 25 * 1024 * 1024;
  static const int _maxFiles = 6;

  String get _orgLower => widget.title.trim().toLowerCase();
  bool get _isTheater =>
      _orgLower.contains('teatro') ||
      _orgLower.contains('theater') ||
      widget.category.toLowerCase().contains('performing');
  bool get _isCatholic =>
      _orgLower.contains('catholic') ||
      _orgLower.contains('scap') ||
      widget.category.toLowerCase().contains('faith');
  bool get _isSports =>
      widget.category.toLowerCase().contains('sports') ||
      widget.category.toLowerCase().contains('athletic');
  bool get _isAcademic =>
      widget.category.toLowerCase().contains('academic') ||
      widget.category.toLowerCase().contains('education');

  String get _reasonHint {
    if (_isTheater) {
      return 'e.g. I want to develop my acting, stage performance, and teamwork skills through ${widget.title} productions.';
    }
    if (_isCatholic) {
      return 'e.g. I want to grow in faith, service, and community involvement through ${widget.title}.';
    }
    if (_isSports) {
      return 'e.g. I want to improve my skills, discipline, teamwork, and fitness through ${widget.title}.';
    }
    if (_isAcademic) {
      return 'e.g. I want to strengthen my academic skills and contribute to ${widget.title} learning activities.';
    }
    return 'e.g. I want to develop my skills and actively contribute to ${widget.title} activities.';
  }

  String get _skillsHint {
    if (_isTheater) {
      return 'e.g. Acting, stage performance, voice projection, dancing, directing, or scriptwriting';
    }
    if (_isCatholic) {
      return 'e.g. Community service, organizing, public speaking, music, outreach, or teamwork';
    }
    if (_isSports) {
      return 'e.g. Basketball, volleyball, athletics, coaching, event support, or team leadership';
    }
    if (_isAcademic) {
      return 'e.g. Research, tutoring, writing, organizing, presentation, or peer mentoring';
    }
    return 'e.g. Communication, organizing, leadership, creativity, teamwork, or skills related to ${widget.title}';
  }

  String get _experienceHint {
    if (_isTheater) {
      return 'e.g. School play, stage performance, theater workshop, production crew, or None';
    }
    if (_isCatholic) {
      return 'e.g. Outreach activity, parish service, campus ministry, volunteer work, or None';
    }
    if (_isSports) {
      return 'e.g. School team, intramurals, sports club, coaching, or None';
    }
    if (_isAcademic) {
      return 'e.g. Academic club, research project, tutoring, seminar, or None';
    }
    return 'e.g. School organization, volunteer activity, event project, or None';
  }

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

    AppState.instance.addListener(_onAppStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillFromProfile());
  }

  void _onAppStateChanged() {
    if (mounted) setState(() {});
  }

  String? get _blockingNoticeText {
    final orgId = widget.orgId;
    if (orgId == null || orgId.isEmpty) return null;
    if (AppState.instance.isMemberOfOrg(orgId)) {
      return 'You are already a member of ${widget.title}.';
    }
    final app = AppState.instance.applicationForOrg(orgId);
    if (app == null) return null;
    final orgName = widget.title;
    switch (app.status) {
      case ApplicationStatus.pending:
        return 'Your application to $orgName is pending review.';
      case ApplicationStatus.interviewed:
      case ApplicationStatus.interviewScheduled:
        return 'Your application to $orgName is in the interview stage.';
      case ApplicationStatus.forApproval:
        return 'Your application to $orgName is waiting for final approval.';
      case ApplicationStatus.approved:
      case ApplicationStatus.accepted:
        return 'You are already a member of $orgName.';
      case ApplicationStatus.declined:
        return 'Your application to $orgName was not approved. You cannot apply again to this organization. Please contact its officers.';
    }
  }

  bool get _isDeclinedNotice {
    final orgId = widget.orgId;
    if (orgId == null || orgId.isEmpty) return false;
    final app = AppState.instance.applicationForOrg(orgId);
    return app?.status == ApplicationStatus.declined;
  }

  String _normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('63')) {
      return '0${digits.substring(2)}';
    }
    if (digits.length == 10 && digits.startsWith('9')) {
      return '0$digits';
    }
    return digits;
  }

  Future<void> _prefillFromProfile() async {
    try {
      var profile = AppState.instance.currentStudent;
      if (profile == null) {
        await AppState.instance.loadStudentProfile();
        if (!mounted) return;
        profile = AppState.instance.currentStudent;
      }
      if (profile == null) return;

      if (studentIdCtrl.text.trim().isEmpty) {
        final formatter = _StudentIdFormatter();
        final formattedId = formatter
            .formatEditUpdate(
              TextEditingValue.empty,
              TextEditingValue(text: profile.studentId),
            )
            .text;
        studentIdCtrl.text = formattedId;
      }
      if (fullNameCtrl.text.trim().isEmpty) {
        fullNameCtrl.text = profile.name;
      }
      if (emailCtrl.text.trim().isEmpty) {
        emailCtrl.text = profile.email;
      }
      if (contactCtrl.text.trim().isEmpty && profile.contact.isNotEmpty) {
        contactCtrl.text = _normalizePhone(profile.contact);
      }
      if (facebookCtrl.text.trim().isEmpty) {
        facebookCtrl.text = profile.facebook;
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onAppStateChanged);
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
    for (final node in [
      studentIdFocus,
      fullNameFocus,
      courseFocus,
      yearFocus,
      sectionFocus,
      contactFocus,
      emailFocus,
      facebookFocus,
      reasonFocus,
      skillsFocus,
      experienceFocus,
      emergencyContactFocus,
    ]) {
      node.dispose();
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

    final notice = _blockingNoticeText;
    if (notice != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(notice),
          backgroundColor:
              _isDeclinedNotice ? _FormColors.error : _FormColors.darkGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (studentIdCtrl.text.trim().isEmpty ||
        !RegExp(r'^\d{6}-\d{4}$').hasMatch(studentIdCtrl.text.trim())) {
      studentIdFocus.requestFocus();
    } else if (fullNameCtrl.text.trim().isEmpty) {
      fullNameFocus.requestFocus();
    } else if (courseCtrl.text.trim().isEmpty) {
      courseFocus.requestFocus();
    } else if (yearCtrl.text.trim().isEmpty) {
      yearFocus.requestFocus();
    } else if (sectionCtrl.text.trim().isEmpty) {
      sectionFocus.requestFocus();
    } else if (contactCtrl.text.trim().isEmpty ||
        !RegExp(r'^09\d{9}$').hasMatch(contactCtrl.text.trim())) {
      contactFocus.requestFocus();
    } else if (emailCtrl.text.trim().isEmpty ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
            .hasMatch(emailCtrl.text.trim())) {
      emailFocus.requestFocus();
    } else if (facebookCtrl.text.trim().isEmpty) {
      facebookFocus.requestFocus();
    } else if (reasonCtrl.text.trim().isEmpty ||
        reasonCtrl.text.trim().length < 10) {
      reasonFocus.requestFocus();
    } else if (skillsCtrl.text.trim().isEmpty) {
      skillsFocus.requestFocus();
    } else if (experienceCtrl.text.trim().isEmpty) {
      experienceFocus.requestFocus();
    } else if (emergencyContactCtrl.text.trim().isEmpty) {
      emergencyContactFocus.requestFocus();
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isSubmitting || _isUploading) return;

    setState(() => _isSubmitting = true);

    try {
      await AppState.instance.submitApplication(
        orgName: widget.title,
        orgId: widget.orgId,
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
        profilePicUrl: AppState.instance.currentStudent?.avatarUrl ?? '',
      );

      if (!mounted) return;

      studentIdCtrl.clear();
      fullNameCtrl.clear();
      courseCtrl.clear();
      yearCtrl.clear();
      sectionCtrl.clear();
      contactCtrl.clear();
      emailCtrl.clear();
      facebookCtrl.clear();
      reasonCtrl.clear();
      skillsCtrl.clear();
      experienceCtrl.clear();
      emergencyContactCtrl.clear();
      _attachments.clear();
      _attachmentPaths.clear();
      _attachmentNames.clear();
      _formKey.currentState?.reset();
      _resetCount++;

      setState(() => _isSubmitting = false);
      await _prefillFromProfile();

      if (!mounted) return;
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
      final message = e is ApplicationSubmitException
          ? e.message
          : 'Could not submit your application. Please check your connection and try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: _FormColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final formWidget = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.embedded) ...[
            _organizationHeader(),
            const SizedBox(height: 16),
          ],
          if (_blockingNoticeText != null) ...[
            _blockingNoticeCard(),
            const SizedBox(height: 16),
          ],
          _sectionCard(
            icon: Icons.school_rounded,
            title: 'Student Information',
            subtitle: 'Please provide your student information accurately.',
            children: [
              _fieldLabel('STUDENT ID NUMBER', controller: studentIdCtrl),
              _field(
                controller: studentIdCtrl,
                focusNode: studentIdFocus,
                hint: 'e.g. 202324-1234',
                keyboardType: TextInputType.number,
                inputFormatters: [_StudentIdFormatter()],
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
              _fieldLabel('FULL NAME', controller: fullNameCtrl),
              _field(
                controller: fullNameCtrl,
                focusNode: fullNameFocus,
                hint: 'e.g. Gon Castillo',
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                validator: _requiredValidator,
              ),
              const SizedBox(height: 5),
              _fieldLabel('COURSE / PROGRAM', controller: courseCtrl),
              _dropdownField(
                controller: courseCtrl,
                focusNode: courseFocus,
                hint: 'Select your course / program',
                options: _courseOptions,
                dialogTitle: 'Select Course / Program',
              ),
              const SizedBox(height: 5),
              _fieldLabel('YEAR & SECTION',
                  controller: yearCtrl, secondaryController: sectionCtrl),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: _dropdownField(
                      controller: yearCtrl,
                      focusNode: yearFocus,
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
                      focusNode: sectionFocus,
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
              _fieldLabel('CONTACT NUMBER', controller: contactCtrl),
              _field(
                controller: contactCtrl,
                focusNode: contactFocus,
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
              _fieldLabel('EMAIL ADDRESS', controller: emailCtrl),
              _field(
                controller: emailCtrl,
                focusNode: emailFocus,
                hint: 'e.g. juan.delacruz@gmail.com',
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  final error = _requiredValidator(value);
                  if (error != null) return error;
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                      .hasMatch(value!.trim())) {
                    return 'Enter a valid email address.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 5),
              _fieldLabel('FACEBOOK ACCOUNT', controller: facebookCtrl),
              _field(
                controller: facebookCtrl,
                focusNode: facebookFocus,
                hint: 'e.g. Gon Castillo or facebook.com/yourname',
                keyboardType: TextInputType.text,
                validator: _requiredValidator,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _sectionCard(
            icon: Icons.edit_note_rounded,
            title: 'About Your Application',
            subtitle: 'Tell the organization what you can bring to the group.',
            children: [
              _fieldLabel('REASON FOR JOINING', controller: reasonCtrl),
              _field(
                controller: reasonCtrl,
                focusNode: reasonFocus,
                hint: _reasonHint,
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
              _fieldLabel('SKILLS / TALENTS', controller: skillsCtrl),
              _field(
                controller: skillsCtrl,
                focusNode: skillsFocus,
                hint: _skillsHint,
                maxLines: 3,
                validator: _requiredValidator,
              ),
              const SizedBox(height: 5),
              _fieldLabel('PREVIOUS EXPERIENCE', controller: experienceCtrl),
              _field(
                controller: experienceCtrl,
                focusNode: experienceFocus,
                hint: _experienceHint,
                maxLines: 3,
                validator: _requiredValidator,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _sectionCard(
            icon: Icons.health_and_safety_outlined,
            title: 'Emergency Contact',
            subtitle:
                'Provide a person the organization can contact when necessary.',
            children: [
              _fieldLabel('EMERGENCY CONTACT',
                  controller: emergencyContactCtrl),
              _field(
                controller: emergencyContactCtrl,
                focusNode: emergencyContactFocus,
                hint: 'e.g. Maria Santos - 09181234567',
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.words,
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
    );

    if (widget.embedded) {
      return formWidget;
    }

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
          child: formWidget,
        ),
      ),
    );
  }

  String _mimeFor(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'mp4':
      case 'm4v':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'mkv':
        return 'video/x-matroska';
      case 'webm':
        return 'video/webm';
      default:
        return 'application/octet-stream';
    }
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
          'jpg',
          'jpeg',
          'png',
          'gif',
          'webp',
          'heic',
          'mp4',
          'mov',
          'm4v',
          'avi',
          'mkv',
          'webm',
        ],
      );
      if (result == null || result.files.isEmpty) return;

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please log in again to add attachments.'),
              backgroundColor: _FormColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final List<String> skipped = [];

      for (final file in result.files) {
        if (_attachments.length >= _maxFiles) {
          skipped.add('${file.name} (limit of 6 files reached)');
          continue;
        }
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) {
          skipped.add('${file.name} (file is empty)');
          continue;
        }
        if (bytes.length > _maxFileSize) {
          skipped.add('${file.name} (exceeds 25 MB limit)');
          continue;
        }

        try {
          final safeName =
              file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
          final path =
              'application_attachments/${user.id}/${DateTime.now().microsecondsSinceEpoch}_$safeName';
          await supabase.storage.from('application_assets').uploadBinary(
                path,
                bytes,
                fileOptions: FileOptions(
                  contentType: _mimeFor(file.name),
                  upsert: false,
                ),
              );
          final url =
              supabase.storage.from('application_assets').getPublicUrl(path);
          _attachments.add(url);
          _attachmentPaths.add(path);
          _attachmentNames.add(file.name);
        } catch (_) {
          skipped.add('${file.name} (upload failed)');
        }
      }

      if (skipped.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Skipped: ${skipped.join(', ')}'),
            backgroundColor: _FormColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Could not add attachments. Please check your connection and try again.'),
          backgroundColor: _FormColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _removeAttachment(int index) {
    if (index < 0 ||
        index >= _attachments.length ||
        index >= _attachmentNames.length) {
      return;
    }
    final path =
        index < _attachmentPaths.length ? _attachmentPaths[index] : null;
    setState(() {
      _attachments.removeAt(index);
      _attachmentNames.removeAt(index);
      if (index < _attachmentPaths.length) {
        _attachmentPaths.removeAt(index);
      }
    });
    if (path != null) {
      Supabase.instance.client.storage
          .from('application_assets')
          .remove([path]).then((_) {}, onError: (Object _) {});
    }
  }

  Widget _blockingNoticeCard() {
    final notice = _blockingNoticeText;
    if (notice == null) return const SizedBox.shrink();
    final isDeclined = _isDeclinedNotice;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _FormColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDeclined ? _FormColors.error : _FormColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .035),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            isDeclined
                ? Icons.error_outline_rounded
                : Icons.info_outline_rounded,
            color: isDeclined ? _FormColors.error : _FormColors.green,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              notice,
              style: TextStyle(
                color: isDeclined ? _FormColors.error : _FormColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
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
            color: Colors.black.withValues(alpha: .035),
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
              const Icon(Icons.attach_file_rounded,
                  color: _FormColors.green, size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Attachments',
                        style: TextStyle(
                            color: _FormColors.text,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900)),
                    SizedBox(height: 2),
                    Text(
                        'Add photos or videos of your work, performances, drawings, or other supporting materials.',
                        style: TextStyle(
                            color: _FormColors.muted,
                            fontSize: 11.5,
                            height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: (_isUploading || _blockingNoticeText != null)
                ? null
                : _pickAttachments,
            icon: _isUploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.add_photo_alternate_rounded),
            label: Text(_isUploading ? 'Uploading...' : 'Add Photos / Videos'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: _FormColors.green,
              side: const BorderSide(color: _FormColors.border),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13)),
            ),
          ),
          if (_attachmentNames.isNotEmpty) ...[
            const SizedBox(height: 10),
            ..._attachmentNames.asMap().entries.map((entry) {
              final i = entry.key;
              final name = entry.value;
              return Container(
                margin: const EdgeInsets.only(top: 7),
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                decoration: BoxDecoration(
                  color: _FormColors.field,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: _FormColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.insert_drive_file_rounded,
                        size: 19, color: _FormColors.green),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _FormColors.text))),
                    IconButton(
                      tooltip: 'Remove',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _removeAttachment(i),
                      icon: const Icon(Icons.close_rounded,
                          size: 19, color: _FormColors.muted),
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
            color: _FormColors.green.withValues(alpha: .18),
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
          color: Colors.white.withValues(alpha: .55),
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
            color: Colors.black.withValues(alpha: .035),
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
              Icon(icon, color: _FormColors.green, size: 22),
              const SizedBox(width: 10),
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

  Widget _fieldLabel(String text,
      {TextEditingController? controller,
      TextEditingController? secondaryController}) {
    final bool isEmpty = controller != null && controller.text.trim().isEmpty ||
        (secondaryController != null &&
            secondaryController.text.trim().isEmpty);

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
          if (isEmpty)
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
    required FocusNode focusNode,
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
        focusNode: focusNode,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        minLines: maxLines > 1 ? maxLines : null,
        validator: validator,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        textCapitalization: textCapitalization,
        textInputAction:
            maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
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
    required FocusNode focusNode,
    required String hint,
    required List<String> options,
    required String dialogTitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DropdownButtonFormField<String>(
        key: ValueKey('${dialogTitle}_$_resetCount'),
        focusNode: focusNode,
        // ignore: deprecated_member_use
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
        autovalidateMode: AutovalidateMode.onUserInteraction,
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
    final notice = _blockingNoticeText;
    final isBlocked = notice != null;
    final enabled = _requiredFieldsComplete &&
        !_isSubmitting &&
        !_isUploading &&
        !isBlocked;

    String label = 'SUBMIT APPLICATION';
    if (isBlocked) {
      final orgId = widget.orgId ?? '';
      final isMember = AppState.instance.isMemberOfOrg(orgId);
      final app = AppState.instance.applicationForOrg(orgId);
      final isApprovedMember = app?.status == ApplicationStatus.approved ||
          app?.status == ApplicationStatus.accepted;
      if (isMember || isApprovedMember) {
        label = 'ALREADY A MEMBER';
      } else {
        label = 'ALREADY APPLIED';
      }
    } else if (_isSubmitting) {
      label = 'SUBMITTING...';
    }

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
          label,
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

class _StudentIdFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 10 ? digits.substring(0, 10) : digits;
    final buffer = StringBuffer();
    for (int i = 0; i < limited.length; i++) {
      if (i == 6) {
        buffer.write('-');
      }
      buffer.write(limited[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
