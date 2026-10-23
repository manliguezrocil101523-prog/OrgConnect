import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_state.dart' hide User;
import 'email_verification_page.dart';

const _kGreen = Color(0xFF16A34A);
const _kBg = Color(0xFFF8FAFF);
const _kText = Color(0xFF1E293B);
const _kSubText = Color(0xFF94A3B8);
const _kError = Color(0xFFDC2626);
const _kSuccess = Color(0xFF059669);
const _kLogo = 'assets/icon/login_logo.png';

enum _DeviceType { mobile, tablet, desktop }

_DeviceType _getDeviceType(double width) {
  if (width >= 1024) return _DeviceType.desktop;
  if (width >= 600) return _DeviceType.tablet;
  return _DeviceType.mobile;
}

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _fName = TextEditingController();
  final _lName = TextEditingController();
  final _studId = TextEditingController();
  final _email = TextEditingController();
  final _contact = TextEditingController();
  final _facebook = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  bool _obscure = true;

  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();

  late final Animation<double> _fade =
      CurvedAnimation(parent: _ac, curve: Curves.easeOut);

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, .05),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(
      parent: _ac,
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  void dispose() {
    _ac.dispose();

    _fName.dispose();
    _lName.dispose();
    _studId.dispose();
    _email.dispose();
    _contact.dispose();
    _facebook.dispose();
    _password.dispose();

    super.dispose();
  }

  // ============================================================
  // CREATE PROFILE
  // ============================================================

  Future<void> _createProfile(User user) async {
    final firstName = _fName.text.trim();
    final lastName = _lName.text.trim();

    final name = '$firstName $lastName'.trim();
    final studentId = _studId.text.trim();
    final email = _email.text.trim();
    final contact = _contact.text.trim();
    final facebook = _facebook.text.trim();

    await Supabase.instance.client.from('profiles').upsert(
      {
        'id': user.id,
        'name': name,
        'email': email,
        'student_id': studentId,
        'role': 'student',
        'active': true,
        'contact': contact,
        'facebook': facebook,
        'avatar_url': '',
        'joined_org_ids': <String>[],
      },
      onConflict: 'id',
    );

    await AppState.instance.setStudentProfile(
      StudentProfile(
        id: user.id,
        name: name,
        email: email,
        studentId: studentId,
        contact: contact,
        facebook: facebook,
        avatarUrl: '',
        joinedOrgIds: const [],
      ),
    );

    AppState.instance.setRole(UserRole.student);
  }

  // ============================================================
  // SIGN UP
  // ============================================================

  Future<void> _signUp() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_loading) {
      return;
    }

    setState(() {
      _loading = true;
    });

    final firstName = _fName.text.trim();
    final lastName = _lName.text.trim();
    final name = '$firstName $lastName'.trim();
    final studentId = _studId.text.trim();
    final email = _email.text.trim();
    final contact = _contact.text.trim();
    final facebook = _facebook.text.trim();
    final password = _password.text;

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'first_name': firstName,
          'last_name': lastName,
          'student_id': studentId,
          'contact': contact,
          'facebook': facebook,
        },
      );

      final user = response.user;

      if (user == null) {
        _snack(
          'Account could not be created. Please try again.',
        );
        return;
      }

      // ==========================================================
      // EMAIL VERIFICATION ENABLED
      //
      // Supabase does not give us an authenticated session yet.
      // Therefore, the profile will be created AFTER OTP
      // verification inside EmailVerificationPage.
      // ==========================================================

      if (response.session == null) {
        if (!mounted) {
          return;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => EmailVerificationPage(
              email: email,
            ),
          ),
        );

        return;
      }

      // ==========================================================
      // EMAIL VERIFICATION DISABLED
      //
      // We already have an authenticated session, so create
      // the profile immediately.
      // ==========================================================

      try {
        await _createProfile(user);
      } on PostgrestException catch (e) {
        debugPrint(
          'PROFILE CREATION ERROR: ${e.message}',
        );

        debugPrint(
          'PROFILE CREATION DETAILS: ${e.details}',
        );

        debugPrint(
          'PROFILE CREATION CODE: ${e.code}',
        );

        if (!mounted) {
          return;
        }

        _snack(
          'Account created, but profile creation failed: '
          '${e.message}',
        );

        return;
      }

      if (!mounted) {
        return;
      }

      _snack(
        'Account created successfully!',
        ok: true,
      );

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/home',
        (_) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) {
        return;
      }

      _snack(e.message);
    } on PostgrestException catch (e) {
      debugPrint(
        'DATABASE ERROR: ${e.message}',
      );

      debugPrint(
        'DATABASE DETAILS: ${e.details}',
      );

      debugPrint(
        'DATABASE CODE: ${e.code}',
      );

      if (!mounted) {
        return;
      }

      _snack(
        'Database error: ${e.message}',
      );
    } catch (e) {
      debugPrint(
        'SIGN UP ERROR: $e',
      );

      if (!mounted) {
        return;
      }

      _snack(
        'Something went wrong: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _snack(
    String msg, {
    bool ok = false,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: ok ? _kSuccess : _kError,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final device = _getDeviceType(constraints.maxWidth);
            final isDesktop = device == _DeviceType.desktop;
            final isMobile = device == _DeviceType.mobile;

            return SingleChildScrollView(
              padding: isDesktop
                  ? EdgeInsets.zero
                  : EdgeInsets.symmetric(
                      horizontal: isMobile ? 20 : 24,
                      vertical: isMobile ? 16 : 28,
                    ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: isDesktop
                      ? constraints.maxHeight
                      : constraints.maxHeight - (isMobile ? 32 : 56),
                ),
                child: Center(
                  child: FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      child: AutofillGroup(
                        child: Form(
                          key: _formKey,
                          child: _buildBody(device),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(_DeviceType device) {
    if (device == _DeviceType.desktop) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(child: _BrandPanel()),
            Expanded(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 36,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: _buildFormContent(device),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (device == _DeviceType.tablet) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _kGreen.withValues(alpha: 0.08),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: _buildFormContent(device),
        ),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: _buildFormContent(device),
    );
  }

  Widget _buildFormContent(_DeviceType device) {
    final isDesktop = device == _DeviceType.desktop;
    final isMobile = device == _DeviceType.mobile;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        if (!isDesktop) ...[
          Image.asset(
            _kLogo,
            height: isMobile ? 64 : 72,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
          const SizedBox(height: 8),
          const Text(
            'OrgConnect',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _kText,
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          "Let's Get Started!",
          textAlign: isDesktop ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            fontSize: isDesktop ? 30 : 26,
            fontWeight: FontWeight.w900,
            color: _kText,
            letterSpacing: -.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Create an account to get started with OrgConnect. Join your campus organizations and never miss out on events again!",
          textAlign: isDesktop ? TextAlign.left : TextAlign.center,
          style: const TextStyle(
            fontSize: 13.5,
            color: _kSubText,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        _buildNameFields(isMobile),
        const SizedBox(height: 14),
        _LineFormField(
          controller: _studId,
          hint: 'Student ID',
          icon: Icons.badge_outlined,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.next,
          formatters: [
            FilteringTextInputFormatter.allow(
              RegExp(r'[0-9a-zA-Z-]'),
            ),
          ],
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Student ID required';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        _LineFormField(
          controller: _email,
          hint: 'Email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Email required';
            }
            final clean = value.trim();
            if (!RegExp(
              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
            ).hasMatch(clean)) {
              return 'Enter valid email';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        _LineFormField(
          controller: _contact,
          hint: 'Contact Number (e.g. 09171234567)',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.telephoneNumber],
          formatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Contact number required';
            }
            if (value.trim().length < 10) {
              return 'Enter a valid contact number';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        _LineFormField(
          controller: _facebook,
          hint: 'Facebook Account (e.g. Gon)',
          icon: Icons.facebook_rounded,
          textInputAction: TextInputAction.next,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Facebook account required';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        _LineFormField(
          controller: _password,
          hint: 'Password',
          icon: Icons.lock_outline,
          obscure: _obscure,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          onSubmitted: (_) => _signUp(),
          onToggle: () {
            setState(() {
              _obscure = !_obscure;
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Password required';
            }
            if (value.length < 6) {
              return 'Minimum 6 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _loading ? null : _signUp,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kGreen,
              disabledBackgroundColor: _kGreen.withValues(alpha: 0.4),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'CREATE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      letterSpacing: .8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Already have an account? ',
              style: TextStyle(
                color: _kText,
                fontSize: 13,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.pushReplacementNamed(
                  context,
                  '/login',
                );
              },
              child: const Text(
                'Login here',
                style: TextStyle(
                  color: _kGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNameFields(bool isMobile) {
    final firstName = _LineFormField(
      controller: _fName,
      hint: 'First Name',
      icon: Icons.person_outline,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.givenName],
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'First name required';
        }
        return null;
      },
    );

    final lastName = _LineFormField(
      controller: _lName,
      hint: 'Last Name',
      icon: Icons.person_outline,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.familyName],
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Last name required';
        }
        return null;
      },
    );

    if (isMobile) {
      return Column(
        children: [
          firstName,
          const SizedBox(height: 14),
          lastName,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: firstName),
        const SizedBox(width: 12),
        Expanded(child: lastName),
      ],
    );
  }
}

// ============================================================
// BRAND PANEL (DESKTOP)
// ============================================================

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBg,
      padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                _kLogo,
                height: 76,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
              const SizedBox(height: 20),
              const Text(
                'OrgConnect',
                style: TextStyle(
                  color: _kText,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'One place to manage student organizations, events, and members.',
                style: TextStyle(
                  color: _kSubText,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 36),
              const _FeatureItem(
                icon: Icons.groups_outlined,
                label: 'Join campus organizations',
              ),
              const SizedBox(height: 16),
              const _FeatureItem(
                icon: Icons.event_available_outlined,
                label: 'Never miss events',
              ),
              const SizedBox(height: 16),
              const _FeatureItem(
                icon: Icons.campaign_outlined,
                label: 'Stay connected with student leaders',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: _kGreen,
            size: 20,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: _kText,
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// LINE FORM FIELD
// ============================================================

class _LineFormField extends StatefulWidget {
  const _LineFormField({
    required this.controller,
    required this.hint,
    this.validator,
    this.obscure = false,
    this.keyboardType,
    this.formatters,
    this.onToggle,
    this.icon,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;
  final bool obscure;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? formatters;
  final VoidCallback? onToggle;
  final IconData? icon;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_LineFormField> createState() => _LineFormFieldState();
}

class _LineFormFieldState extends State<_LineFormField> {
  final _focus = FocusNode();

  bool focused = false;

  @override
  void initState() {
    super.initState();

    _focus.addListener(
      _handleFocusChange,
    );
  }

  void _handleFocusChange() {
    if (!mounted) {
      return;
    }

    setState(() {
      focused = _focus.hasFocus;
    });
  }

  @override
  void dispose() {
    _focus.removeListener(
      _handleFocusChange,
    );
    _focus.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: _focus,
      obscureText: widget.obscure,
      validator: widget.validator,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.formatters,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onFieldSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hoverColor: Colors.transparent,
        hintText: widget.hint,
        hintStyle: const TextStyle(
          color: _kSubText,
          fontSize: 14,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 22,
        ),
        prefixIcon: Icon(
          widget.icon,
          color: focused ? _kGreen : _kSubText,
          size: 20,
        ),
        suffixIcon: widget.onToggle != null
            ? IconButton(
                onPressed: widget.onToggle,
                icon: Icon(
                  widget.obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _kGreen,
                ),
              )
            : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(
            color: _kGreen,
            width: 1.8,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(
            color: _kError,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(
            color: _kError,
            width: 2,
          ),
        ),
      ),
    );
  }
}
