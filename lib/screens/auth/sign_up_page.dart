import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_state.dart';
import 'email_verification_page.dart';

const _kBlue = Color(0xFF2563EB);
const _kBg = Color(0xFFF8FAFF);
const _kText = Color(0xFF1E293B);
const _kSubText = Color(0xFF94A3B8);
const _kWhite = Colors.white;
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
  final _password = TextEditingController();

  bool _loading = false;
  bool _obscure = true;

  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();

  late final Animation<double> _fade =
      CurvedAnimation(parent: _ac, curve: Curves.easeOut);

  late final Animation<Offset> _slide = Tween(
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

    for (final c in [_fName, _lName, _studId, _email, _password]) {
      c.dispose();
    }

    super.dispose();
  }

// ============================================================
// PATCH for sign_up_page.dart
// Only ONE method changes — _signUp()
// Replace the entire _signUp() method with this:
// ============================================================

  Future<void> _signUp() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final name = "${_fName.text.trim()} ${_lName.text.trim()}";
    final email = _email.text.trim();

    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: _password.text,
        data: {
          'name': name,
          'student_id': _studId.text.trim(),
        },
      );

      final user = res.user;

      if (user != null) {
        AppState.instance.setStudentProfile(
          StudentProfile(
            id: user.id,
            name: name,
            email: email,
            studentId: _studId.text.trim(),
            contact: '',
            facebook: '',
            avatarUrl: '',
          ),
        );

        if (!mounted) return;

        // If email confirmation is required → go to OTP verification page
        if (res.session == null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => EmailVerificationPage(email: email),
            ),
          );
        } else {
          // Auto-confirmed (email confirm is OFF) → go straight to login
          _snack('Account created successfully!', ok: true);
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    } on AuthException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack(e.toString());
    }

    if (mounted) setState(() => _loading = false);
  }

// ============================================================
// Also add this import at the TOP of sign_up_page.dart
// (with the other imports):
// ============================================================
// import 'email_verification_page.dart';

  void _snack(
    String msg, {
    bool ok = false,
  }) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: ok ? _kSuccess : _kError,
        ),
      );
  }

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
                          "Create an account to get started with OrgConnect. Join your campus organizations and never miss out on events again!",
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
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'First name required'
                              : null,
                        ),
                        const SizedBox(height: 22),
                        _LineFormField(
                          controller: _lName,
                          hint: 'Last Name',
                          icon: Icons.person_outline,
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Last name required'
                              : null,
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
                            )
                          ],
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Student ID required'
                              : null,
                        ),
                        const SizedBox(height: 22),
                        _LineFormField(
                          controller: _email,
                          hint: 'Email',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return "Email required";
                            }

                            final clean = v.trim();

                            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(clean)) {
                              return "Enter valid email";
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
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return "Password required";
                            }

                            if (v.length < 6) {
                              return "Minimum 6 characters";
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 45),
                        SizedBox(
                          width: 200,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _signUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kBlue,
                              elevation: 8,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: _loading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text(
                                    "CREATE",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      letterSpacing: .8,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Already have an account? ",
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
                                "Login here",
                                style: TextStyle(
                                  color: _kBlue,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          ],
                        )
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
  State<_LineFormField> createState() => _LineFormFieldState();
}

class _LineFormFieldState extends State<_LineFormField> {
  final _focus = FocusNode();

  bool focused = false;

  @override
  void initState() {
    super.initState();

    _focus.addListener(() {
      setState(() {
        focused = _focus.hasFocus;
      });
    });
  }

  @override
  void dispose() {
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
        contentPadding: const EdgeInsets.symmetric(
          vertical: 22,
        ),
        prefixIcon: Icon(
          widget.icon,
          color: focused ? _kBlue : Colors.grey.shade400,
          size: 20,
        ),
        suffixIcon: widget.onToggle != null
            ? IconButton(
                onPressed: widget.onToggle,
                icon: Icon(
                  widget.obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _kBlue,
                ),
              )
            : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
            width: 1.2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(
            color: _kBlue,
            width: 2,
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
