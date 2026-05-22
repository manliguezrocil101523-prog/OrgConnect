import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_state.dart';

const _kBlue = Color(0xFF2563EB);
const _kBg = Color(0xFFF8FAFF);
const _kText = Color(0xFF1E293B);
const _kSubText = Color(0xFF94A3B8);
const _kBorder = Color(0xFFCBD5E1);
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
      vsync: this, duration: const Duration(milliseconds: 600))
    ..forward();
  late final Animation<double> _fade =
      CurvedAnimation(parent: _ac, curve: Curves.easeOut);
  late final Animation<Offset> _slide =
      Tween(begin: const Offset(0, 0.05), end: Offset.zero)
          .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));

  @override
  void dispose() {
    _ac.dispose();
    for (final c in [_fName, _lName, _studId, _email, _password]) c.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final name = '${_fName.text.trim()} ${_lName.text.trim()}';

    try {
      final res = await Supabase.instance.client.auth
          .signUp(email: _email.text.trim(), password: _password.text);

      final user = res.user;

      if (user != null &&
          (user.confirmedAt != null || user.emailConfirmedAt != null)) {
        await Supabase.instance.client.from('profiles').upsert({
          'id': user.id,
          'name': name,
          'student_id': _studId.text.trim(),
          'email': _email.text.trim(),
        }, onConflict: 'id');

        AppState.instance.setStudentProfile(StudentProfile(
          id: user.id,
          name: name,
          email: _email.text.trim(),
          studentId: _studId.text.trim(),
          contact: '',
          facebook: '',
          avatarUrl: '',
        ));

        if (!mounted) return;
        _snack('Account created successfully! Welcome!', ok: true);
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        if (!mounted) return;
        _snack(
          'A confirmation link has been sent to ${_email.text.trim()}. '
          'Please check your inbox and confirm before signing in.',
          ok: true,
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
    } on AuthException catch (e) {
      _snack('Sign up failed: ${e.message}');
    } catch (e) {
      _snack('Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool ok = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(
            ok
                ? Icons.check_circle_outline_rounded
                : Icons.error_outline_rounded,
            color: _kWhite,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 13.5)),
          ),
        ]),
        backgroundColor: ok ? _kSuccess : _kError,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Main content ─────────────────────────────────────
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Title block ────────────────────────
                            const SizedBox(height: 32),
                            const Text(
                              'Sign Up',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: _kBlue,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Create your account to get started',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: _kSubText,
                              ),
                            ),

                            // ── Fields ─────────────────────────────
                            const SizedBox(height: 44),
                            _LineFormField(
                              controller: _fName,
                              hint: 'First Name',
                              action: TextInputAction.next,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'First name is required'
                                  : null,
                            ),
                            const SizedBox(height: 28),
                            _LineFormField(
                              controller: _lName,
                              hint: 'Last Name',
                              action: TextInputAction.next,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Last name is required'
                                  : null,
                            ),
                            const SizedBox(height: 28),
                            _LineFormField(
                              controller: _studId,
                              hint: 'Student ID',
                              keyboardType: TextInputType.number,
                              action: TextInputAction.next,
                              formatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Student ID is required'
                                  : null,
                            ),
                            const SizedBox(height: 28),
                            _LineFormField(
                              controller: _email,
                              hint: 'Email Address',
                              keyboardType: TextInputType.emailAddress,
                              action: TextInputAction.next,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty)
                                  return 'Email is required';
                                final clean = v.trim().toLowerCase();
                                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                    .hasMatch(clean)) {
                                  return 'Enter a valid email address';
                                }
                                if (!clean.endsWith('@gmail.com')) {
                                  return 'Only Gmail addresses are accepted';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 28),
                            _LineFormField(
                              controller: _password,
                              hint: 'Password',
                              obscure: _obscure,
                              action: TextInputAction.done,
                              onToggle: () =>
                                  setState(() => _obscure = !_obscure),
                              validator: (v) {
                                if (v == null || v.isEmpty)
                                  return 'Password is required';
                                if (v.length < 6) return 'Minimum 6 characters';
                                return null;
                              },
                            ),

                            // ── Sign Up button ──────────────────────
                            const SizedBox(height: 44),
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _signUp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _kBlue,
                                  disabledBackgroundColor:
                                      _kBlue.withOpacity(0.45),
                                  foregroundColor: _kWhite,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30)),
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2.2, color: _kWhite),
                                      )
                                    : const Text(
                                        'Sign Up',
                                        style: TextStyle(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                              ),
                            ),

                            // ── Already have account ────────────────
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Already have an account?  ',
                                  style: TextStyle(
                                      fontSize: 13.5, color: _kSubText),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.pushReplacementNamed(
                                      context, '/login'),
                                  child: const Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: _kBlue,
                                      decoration: TextDecoration.underline,
                                      decorationColor: _kBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Underline-style validated field ──────────────────────────────────────────
class _LineFormField extends StatefulWidget {
  const _LineFormField({
    required this.controller,
    required this.hint,
    this.validator,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.action = TextInputAction.next,
    this.formatters,
    this.onToggle,
  });

  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;
  final bool obscure;
  final TextInputType keyboardType;
  final TextInputAction action;
  final List<TextInputFormatter>? formatters;
  final VoidCallback? onToggle;

  @override
  State<_LineFormField> createState() => _LineFormFieldState();
}

class _LineFormFieldState extends State<_LineFormField> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
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
      keyboardType: widget.keyboardType,
      textInputAction: widget.action,
      inputFormatters: widget.formatters,
      validator: widget.validator,
      style: const TextStyle(
          fontSize: 15, color: _kText, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: const TextStyle(
            color: _kSubText, fontSize: 14.5, fontWeight: FontWeight.w400),
        contentPadding: const EdgeInsets.only(bottom: 10),
        isDense: true,
        border:
            const UnderlineInputBorder(borderSide: BorderSide(color: _kBorder)),
        enabledBorder:
            const UnderlineInputBorder(borderSide: BorderSide(color: _kBorder)),
        focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: _kBlue, width: 1.8)),
        errorBorder:
            const UnderlineInputBorder(borderSide: BorderSide(color: _kError)),
        focusedErrorBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: _kError, width: 1.8)),
        errorStyle:
            const TextStyle(fontSize: 11.5, height: 1.4, color: _kError),
        suffixIcon: widget.onToggle != null
            ? GestureDetector(
                onTap: widget.onToggle,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Icon(
                    widget.obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 19,
                    color: _focused ? _kBlue : _kSubText,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
