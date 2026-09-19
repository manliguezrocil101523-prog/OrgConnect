import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_state.dart' hide User;
import 'email_verification_page.dart';

const _kBlue = Color(0xFF2563EB);
const _kBg = Color(0xFFF8FAFF);
const _kText = Color(0xFF1E293B);
const _kSubText = Color(0xFF94A3B8);
const _kError = Color(0xFFDC2626);
const _kSuccess = Color(0xFF059669);

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
      final response =
          await Supabase.instance.client.auth.signUp(
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
          backgroundColor:
              ok ? _kSuccess : _kError,
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
    final screen = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 20,
            ),
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 380,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        SizedBox(
                          height: screen.height * .05,
                        ),

                        const Text(
                          "Let's Get Started!",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: _kText,
                            letterSpacing: -.7,
                          ),
                        ),

                        const SizedBox(height: 10),

                        const Text(
                          "Create an account to get started with "
                          "OrgConnect. Join your campus organizations "
                          "and never miss out on events again!",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: _kSubText,
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 45),

                        _LineFormField(
                          controller: _fName,
                          hint: 'First Name',
                          icon: Icons.person_outline,
                          validator: (value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'First name required';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 22),

                        _LineFormField(
                          controller: _lName,
                          hint: 'Last Name',
                          icon: Icons.person_outline,
                          validator: (value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Last name required';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 22),

                        _LineFormField(
                          controller: _studId,
                          hint: 'Student ID',
                          icon: Icons.badge_outlined,
                          keyboardType: TextInputType.text,
                          formatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9a-zA-Z-]'),
                            ),
                          ],
                          validator: (value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Student ID required';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 22),

                        _LineFormField(
                          controller: _email,
                          hint: 'Email',
                          icon: Icons.email_outlined,
                          keyboardType:
                              TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Email required';
                            }

                            final clean =
                                value.trim();

                            if (!RegExp(
                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                            ).hasMatch(clean)) {
                              return 'Enter valid email';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 22),

                        _LineFormField(
                          controller: _contact,
                          hint: 'Contact Number (e.g. 09171234567)',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
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

                        const SizedBox(height: 22),

                        _LineFormField(
                          controller: _facebook,
                          hint: 'Facebook Account (e.g. Gon)',
                          icon: Icons.facebook_rounded,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Facebook account required';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 22),

                        _LineFormField(
                          controller: _password,
                          hint: 'Password',
                          icon: Icons.lock_outline,
                          obscure: _obscure,
                          onToggle: () {
                            setState(() {
                              _obscure = !_obscure;
                            });
                          },
                          validator: (value) {
                            if (value == null ||
                                value.isEmpty) {
                              return 'Password required';
                            }

                            if (value.length < 6) {
                              return 'Minimum 6 characters';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 45),

                        SizedBox(
                          width: 200,
                          height: 55,
                          child: ElevatedButton(
                            onPressed:
                                _loading
                                    ? null
                                    : _signUp,
                            style:
                                ElevatedButton
                                    .styleFrom(
                              backgroundColor:
                                  const Color(0xFF16A34A),
                              disabledBackgroundColor:
                                  const Color(0xFF16A34A).withOpacity(
                                0.5,
                              ),
                              elevation: 8,
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  30,
                                ),
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth:
                                          2.5,
                                      color:
                                          Colors
                                              .white,
                                    ),
                                  )
                                : const Text(
                                    'CREATE',
                                    style:
                                        TextStyle(
                                      color:
                                          Colors
                                              .white,
                                      fontSize: 15,
                                      letterSpacing:
                                          .8,
                                      fontWeight:
                                          FontWeight
                                              .w800,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .center,
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
                                Navigator
                                    .pushReplacementNamed(
                                  context,
                                  '/login',
                                );
                              },
                              child: const Text(
                                'Login here',
                                style:
                                    TextStyle(
                                  color: const Color(0xFF16A34A),
                                  fontWeight:
                                      FontWeight
                                          .w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
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
  });

  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;
  final bool obscure;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? formatters;
  final VoidCallback? onToggle;
  final IconData? icon;

  @override
  State<_LineFormField> createState() =>
      _LineFormFieldState();
}

class _LineFormFieldState
    extends State<_LineFormField> {
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
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: widget.hint,
        hintStyle: const TextStyle(
          color: _kSubText,
          fontSize: 14,
        ),
        contentPadding:
            const EdgeInsets.symmetric(
          vertical: 22,
        ),
        prefixIcon: Icon(
          widget.icon,
          color: focused
              ? _kBlue
              : Colors.grey.shade400,
          size: 20,
        ),
        suffixIcon:
            widget.onToggle != null
                ? IconButton(
                    onPressed:
                        widget.onToggle,
                    icon: Icon(
                      widget.obscure
                          ? Icons
                              .visibility_off_outlined
                          : Icons
                              .visibility_outlined,
                      color: _kBlue,
                    ),
                  )
                : null,
        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(30),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
            width: 1.2,
          ),
        ),
        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(30),
          borderSide:
              const BorderSide(
            color: _kBlue,
            width: 2,
          ),
        ),
        errorBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(30),
          borderSide:
              const BorderSide(
            color: _kError,
          ),
        ),
        focusedErrorBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(30),
          borderSide:
              const BorderSide(
            color: _kError,
            width: 2,
          ),
        ),
      ),
    );
  }
}