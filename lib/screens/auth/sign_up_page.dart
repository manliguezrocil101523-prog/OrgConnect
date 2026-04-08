import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_state.dart';

// ── Design Tokens ─────────────────────────────────────────────
abstract final class _C {
  static const accent       = Color(0xFF12B896);
  static const accentDark   = Color(0xFF0D9278);
  static const pageBg       = Color(0xFFF8F9FA);
  static const card         = Color(0xFFFFFFFF);
  static const inputRest    = Color(0xFFF2F4F6);
  static const inputStroke  = Color(0xFFE2E6EA);
  static const textPrimary  = Color(0xFF111827);
  static const textSub      = Color(0xFF6B7280);
  static const textHint     = Color(0xFFADB5BD);
  static const error        = Color(0xFFDC2626);
  static const success      = Color(0xFF059669);

  static const r12 = 12.0;  static const r14 = 14.0;
  static const r18 = 18.0;  static const r24 = 24.0;

  static const s8  =  8.0;  static const s12 = 12.0;
  static const s14 = 14.0;  static const s16 = 16.0;
  static const s20 = 20.0;  static const s24 = 24.0;
  static const s28 = 28.0;  static const s32 = 32.0;

  static final cardShadow = [
    BoxShadow(color: Colors.black.withOpacity(0.06),
        blurRadius: 32, spreadRadius: -4, offset: const Offset(0, 12)),
    BoxShadow(color: Colors.black.withOpacity(0.04),
        blurRadius: 8, offset: const Offset(0, 2)),
  ];
  static final btnShadow = [
    BoxShadow(color: accent.withOpacity(0.30),
        blurRadius: 20, offset: const Offset(0, 8)),
    BoxShadow(color: Colors.black.withOpacity(0.10),
        blurRadius: 4, offset: const Offset(0, 2)),
  ];
}

// ── Input Decoration ──────────────────────────────────────────
InputDecoration _deco(String hint, {IconData? icon, bool focused = false}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _C.textHint, fontSize: 14),
      fillColor: focused ? Colors.white : _C.inputRest,
      filled: true,
      prefixIcon: icon != null
          ? Icon(icon, size: 18, color: focused ? _C.accent : _C.textHint)
          : null,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: _C.s16, vertical: 15),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_C.r12),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_C.r12),
          borderSide: const BorderSide(color: _C.inputStroke)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_C.r12),
          borderSide: const BorderSide(color: _C.accent, width: 1.6)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_C.r12),
          borderSide: const BorderSide(color: _C.error)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_C.r12),
          borderSide: const BorderSide(color: _C.error, width: 1.6)),
      errorStyle:
          const TextStyle(fontSize: 11.5, height: 1.4, color: _C.error),
    );

// ── Reusable Focused Field ────────────────────────────────────
class _Field extends StatefulWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.validator,
    this.icon,
    this.obscure      = false,
    this.keyboardType = TextInputType.text,
    this.action       = TextInputAction.next,
    this.formatters,
    this.onToggle,       // non-null = password field
  });

  final TextEditingController      controller;
  final String                     hint;
  final String? Function(String?)? validator;
  final IconData?                  icon;
  final bool                       obscure;
  final TextInputType              keyboardType;
  final TextInputAction            action;
  final List<TextInputFormatter>?  formatters;
  final VoidCallback?              onToggle;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() { _focus.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => TextFormField(
    controller:      widget.controller,
    focusNode:       _focus,
    obscureText:     widget.obscure,
    keyboardType:    widget.keyboardType,
    textInputAction: widget.action,
    inputFormatters: widget.formatters,
    validator:       widget.validator,
    style: const TextStyle(
        fontSize: 14.5, fontWeight: FontWeight.w500, color: _C.textPrimary),
    decoration: _deco(widget.hint, icon: widget.icon, focused: _focused)
        .copyWith(
      suffixIcon: widget.onToggle != null
          ? IconButton(
              icon: Icon(
                widget.obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 18,
                color: _focused ? _C.accent : _C.textHint,
              ),
              onPressed: widget.onToggle,
              splashRadius: 18,
            )
          : null,
    ),
  );
}

// ── Social Button ─────────────────────────────────────────────
class _SocialBtn extends StatelessWidget {
  const _SocialBtn({required this.label, required this.logo, required this.onTap});
  final String   label;
  final Widget   logo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: _C.textPrimary,
        side: const BorderSide(color: _C.inputStroke),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_C.r14)),
        padding: const EdgeInsets.symmetric(horizontal: _C.s16),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 20, height: 20, child: logo),
          const SizedBox(width: _C.s12),
          Text(label,
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: _C.textPrimary)),
        ],
      ),
    ),
  );
}

// ── Google Logo ───────────────────────────────────────────────
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _GooglePainter());
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    final r = s.width / 2;
    final p = Paint()..style = PaintingStyle.fill;
    final rect = Rect.fromCircle(center: c, radius: r);

    for (final seg in [
      (a: -1.5708, sw: 1.5708, col: const Color(0xFF4285F4)),
      (a: -3.1416, sw: 1.5708, col: const Color(0xFFEA4335)),
      (a:  3.1416, sw: 0.8727, col: const Color(0xFFFBBC05)),
      (a:  3.1416 + 0.8727, sw: 0.6981, col: const Color(0xFF34A853)),
    ]) { canvas.drawArc(rect, seg.a, seg.sw, true, p..color = seg.col); }

    canvas.drawCircle(c, r * 0.58, p..color = Colors.white);
    canvas.drawRect(
        Rect.fromLTWH(c.dx - r * 0.02, c.dy - r * 0.20, r * 1.04, r * 0.40),
        p..color = Colors.white);
    canvas.drawRect(
        Rect.fromLTWH(c.dx, c.dy - r * 0.20, r, r * 0.40),
        p..color = const Color(0xFF4285F4));
    canvas.drawCircle(c, r * 0.57, p..color = Colors.white);
  }
  @override bool shouldRepaint(_) => false;
}

// ── Facebook Logo ─────────────────────────────────────────────
class _FacebookLogo extends StatelessWidget {
  const _FacebookLogo();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _FbPainter());
}

class _FbPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawCircle(Offset(s.width / 2, s.height / 2), s.width / 2,
        Paint()..color = const Color(0xFF1877F2));
    (TextPainter(
      text: const TextSpan(
          text: 'f',
          style: TextStyle(color: Colors.white, fontSize: 15,
              fontWeight: FontWeight.w800, fontFamily: 'Georgia')),
      textDirection: TextDirection.ltr,
    )..layout())
      .paint(canvas, Offset((s.width - 8) / 2, (s.height - 16) / 2));
  }
  @override bool shouldRepaint(_) => false;
}

// ═══════════════════════════════════════════════════════════════
//  SIGN-UP PAGE
// ═══════════════════════════════════════════════════════════════
class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});
  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage>
    with SingleTickerProviderStateMixin {

  final _formKey  = GlobalKey<FormState>();
  final _fName    = TextEditingController();
  final _lName    = TextEditingController();
  final _studId   = TextEditingController();
  final _email    = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  bool _obscure = true;

  late final AnimationController _ac =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
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

  // ── Supabase Logic (unchanged) ────────────────────────────────
  Future<void> _signUp() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final name = '${_fName.text.trim()} ${_lName.text.trim()}';

    try {
      final res = await Supabase.instance.client.auth.signUp(
          email: _email.text.trim(), password: _password.text);
      final user = res.user;
      if (user != null) {
        await Supabase.instance.client.from('profiles').insert({
          'id': user.id, 'name': name,
          'student_id': _studId.text.trim(), 'email': _email.text.trim(),
        });
        AppState.instance.setStudentProfile(StudentProfile(
          id: user.id, name: name, email: _email.text.trim(),
          studentId: _studId.text.trim(),
          contact: '', facebook: '', avatarUrl: '',
        ));
        if (!mounted) return;
        _snack('Account created successfully! Welcome!', ok: true);
        Navigator.pushReplacementNamed(context, '/signin');
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
          Icon(ok ? Icons.check_circle_outline_rounded
                  : Icons.error_outline_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: _C.s8),
          Expanded(child: Text(msg,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5))),
        ]),
        backgroundColor: ok ? _C.success : _C.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(_C.s16),
      ));
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: _C.pageBg,
        body: FadeTransition(opacity: _fade,
          child: SlideTransition(position: _slide,
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: _C.s24, vertical: _C.s32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: _C.s28),
                        _buildCard(),
                        const SizedBox(height: _C.s24),
                        _buildFooter(),
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

  // ── Header ────────────────────────────────────────────────────
  Widget _buildHeader() => Column(children: [
    Container(
      width: 72, height: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_C.r18),
        border: Border.all(color: const Color(0xFFE8EAED)),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 4)),
          BoxShadow(color: Color(0x08000000), blurRadius: 4,  offset: Offset(0, 1)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_C.r18 - 1),
        child: Image.asset('assets/orgconnectLogo.jpg', fit: BoxFit.cover),
      ),
    ),
    const SizedBox(height: _C.s20),
    const Text('Create your account',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800,
            color: _C.textPrimary, letterSpacing: -0.6, height: 1.15)),
    const SizedBox(height: _C.s8),
    const Text('Join your campus community',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14.5, color: _C.textSub, height: 1.5)),
  ]);

  // ── Form Card ─────────────────────────────────────────────────
  Widget _buildCard() => Container(
    decoration: BoxDecoration(color: _C.card,
        borderRadius: BorderRadius.circular(_C.r24),
        boxShadow: _C.cardShadow),
    padding: const EdgeInsets.all(_C.s24),
    child: Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

        // Name row
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _Field(
            controller: _fName, hint: 'First name',
            icon: Icons.person_outline_rounded,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          )),
          const SizedBox(width: _C.s12),
          Expanded(child: _Field(
            controller: _lName, hint: 'Last name',
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          )),
        ]),
        const SizedBox(height: _C.s14),

        _Field(
          controller: _studId, hint: 'Student ID',
          icon: Icons.badge_outlined,
          keyboardType: TextInputType.number,
          formatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: _C.s14),

        _Field(
          controller: _email, hint: 'Email address',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Email is required';
            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim()))
              return 'Enter a valid email';
            return null;
          },
        ),
        const SizedBox(height: _C.s14),

        _Field(
          controller: _password, hint: 'Password',
          icon: Icons.lock_outline_rounded,
          obscure: _obscure,
          action: TextInputAction.done,
          onToggle: () => setState(() => _obscure = !_obscure),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Password is required';
            if (v.length < 6) return 'Minimum 6 characters';
            return null;
          },
        ),
        const SizedBox(height: _C.s24),

        // CTA Button
        _buildButton(),
        const SizedBox(height: _C.s20),

        // Divider
        Row(children: [
          Expanded(child: Divider(color: _C.inputStroke, endIndent: _C.s12)),
          const Text('or', style: TextStyle(color: _C.textHint,
              fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.3)),
          Expanded(child: Divider(color: _C.inputStroke, indent: _C.s12)),
        ]),
        const SizedBox(height: _C.s20),

        _SocialBtn(label: 'Continue with Google',
            logo: const _GoogleLogo(), onTap: () {}),
        const SizedBox(height: _C.s12),
        _SocialBtn(label: 'Continue with Facebook',
            logo: const _FacebookLogo(), onTap: () {}),
      ]),
    ),
  );

  // ── CTA Button ────────────────────────────────────────────────
  Widget _buildButton() => SizedBox(
    height: 52,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: _loading ? _C.accent.withOpacity(0.55) : _C.accent,
        borderRadius: BorderRadius.circular(_C.r14),
        boxShadow: _loading ? null : _C.btnShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(_C.r14),
        child: InkWell(
          borderRadius: BorderRadius.circular(_C.r14),
          onTap: _loading ? null : _signUp,
          splashColor:    Colors.white.withOpacity(0.15),
          highlightColor: Colors.white.withOpacity(0.08),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _loading
                  ? const SizedBox(key: ValueKey('s'), width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: Colors.white))
                  : const Text('Create Account', key: ValueKey('l'),
                      style: TextStyle(color: Colors.white, fontSize: 15,
                          fontWeight: FontWeight.w700, letterSpacing: 0.2)),
            ),
          ),
        ),
      ),
    ),
  );

  // ── Footer ────────────────────────────────────────────────────
  Widget _buildFooter() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Text('Already have an account?  ',
          style: TextStyle(color: _C.textSub, fontSize: 13.5)),
      GestureDetector(
        onTap: () => Navigator.pushReplacementNamed(context, '/signin'),
        child: const Text('Sign In',
            style: TextStyle(color: _C.accent, fontSize: 13.5,
                fontWeight: FontWeight.w700)),
      ),
    ],
  );
}