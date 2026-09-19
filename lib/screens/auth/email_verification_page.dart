import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _kBlue = Color(0xFF2563EB);
const _kBg = Color(0xFFF8FAFF);
const _kText = Color(0xFF1E293B);
const _kSubText = Color(0xFF94A3B8);
const _kBorder = Color(0xFFE5E7EB);
const _kError = Color(0xFFDC2626);
const _kSuccess = Color(0xFF059669);

class EmailVerificationPage extends StatefulWidget {
  final String email;

  const EmailVerificationPage({
    super.key,
    required this.email,
  });

  @override
  State<EmailVerificationPage> createState() =>
      _EmailVerificationPageState();
}

class _EmailVerificationPageState
    extends State<EmailVerificationPage>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _otpControllers =
      List.generate(
    6,
    (_) => TextEditingController(),
  );

  final List<FocusNode> _otpFocusNodes =
      List.generate(
    6,
    (_) => FocusNode(),
  );

  bool _loading = false;
  bool _resending = false;

  late final AnimationController _animationController =
      AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  )..forward();

  late final Animation<double> _fadeAnimation =
      CurvedAnimation(
    parent: _animationController,
    curve: Curves.easeOut,
  );

  late final Animation<Offset> _slideAnimation =
      Tween<Offset>(
    begin: const Offset(0, .05),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  void dispose() {
    _animationController.dispose();

    for (final controller in _otpControllers) {
      controller.dispose();
    }

    for (final focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }

    super.dispose();
  }

  // ============================================================
  // CREATE PROFILE AFTER EMAIL VERIFICATION
  // ============================================================

  Future<void> _createProfile(User user) async {
    final metadata = user.userMetadata ?? {};

    final name =
        metadata['name']?.toString().trim() ?? '';

    final studentId =
        metadata['student_id']?.toString().trim() ?? '';

    final contact =
        metadata['contact']?.toString().trim() ?? '';

    final facebook =
        metadata['facebook']?.toString().trim() ?? '';

    final email =
        user.email?.trim() ?? widget.email.trim();

    if (name.isEmpty) {
      throw Exception(
        'Your name could not be found. Please register again.',
      );
    }

    if (studentId.isEmpty) {
      throw Exception(
        'Your Student ID could not be found. Please register again.',
      );
    }

    await Supabase.instance.client
        .from('profiles')
        .upsert(
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
  }

  // ============================================================
  // VERIFY OTP
  // ============================================================

  Future<void> _verifyCode() async {
    if (_loading) {
      return;
    }

    final code = _otpControllers
        .map((controller) => controller.text.trim())
        .join();

    if (code.length != 6) {
      _showMessage(
        'Please enter the complete 6-digit verification code.',
        error: true,
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final response =
          await Supabase.instance.client.auth.verifyOTP(
        email: widget.email.trim(),
        token: code,
        type: OtpType.signup,
      );

      final user = response.user;
      final session = response.session;

      // ==========================================================
      // VERIFY THAT SUPABASE ACTUALLY AUTHENTICATED THE USER
      // ==========================================================

      if (user == null || session == null) {
        _showMessage(
          'Verification was unsuccessful. Please try again.',
          error: true,
        );
        return;
      }

      // ==========================================================
      // CREATE THE PROFILE WHILE THE USER IS AUTHENTICATED
      //
      // This is the important fix.
      //
      // Your Supabase INSERT policy allows authenticated users
      // to insert profiles. After verifyOTP(), the user has an
      // authenticated session.
      // ==========================================================

      try {
        await _createProfile(user);
      } on PostgrestException catch (e) {
        debugPrint(
          'PROFILE INSERT ERROR: ${e.message}',
        );

        debugPrint(
          'PROFILE INSERT DETAILS: ${e.details}',
        );

        debugPrint(
          'PROFILE INSERT CODE: ${e.code}',
        );

        _showMessage(
          'Email verified, but your profile could not be created.\n'
          '${e.message}',
          error: true,
        );

        return;
      }

      // ==========================================================
      // SUCCESS
      // ==========================================================

      if (!mounted) {
        return;
      }

      _showMessage(
        'Email verified! Your OrgConnect account is ready.',
        error: false,
      );

      /*
       * We now have:
       *
       * auth.users
       *      ↓
       * profiles
       *
       * The profile was successfully created.
       *
       * Sign out so the user can go through the normal login
       * flow.
       */

      await Supabase.instance.client.auth.signOut();

      if (!mounted) {
        return;
      }

      await Future.delayed(
        const Duration(milliseconds: 700),
      );

      if (!mounted) {
        return;
      }

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
        (_) => false,
      );
    } on AuthException catch (e) {
      debugPrint(
        'OTP AUTH ERROR: ${e.message}',
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        e.message,
        error: true,
      );
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

      _showMessage(
        'Database error: ${e.message}',
        error: true,
      );
    } catch (e) {
      debugPrint(
        'VERIFICATION ERROR: $e',
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        'Something went wrong while verifying your email.',
        error: true,
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
  // RESEND CODE
  // ============================================================

  Future<void> _resendCode() async {
    if (_resending || _loading) {
      return;
    }

    setState(() {
      _resending = true;
    });

    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: widget.email.trim(),
      );

      for (final controller in _otpControllers) {
        controller.clear();
      }

      if (!mounted) {
        return;
      }

      _showMessage(
        'A new verification code has been sent to ${widget.email}.',
        error: false,
      );

      FocusScope.of(context).requestFocus(
        _otpFocusNodes.first,
      );
    } on AuthException catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        e.message,
        error: true,
      );
    } catch (e) {
      debugPrint(
        'RESEND ERROR: $e',
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        'Unable to resend the verification code.',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _resending = false;
        });
      }
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              error ? _kError : _kSuccess,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  // ============================================================
  // OTP FIELD
  // ============================================================

  Widget _otpField(int index) {
    final hasFocus =
        _otpFocusNodes[index].hasFocus;

    return SizedBox(
      width: 48,
      height: 58,
      child: AnimatedContainer(
        duration:
            const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(14),
          border: Border.all(
            color: hasFocus
                ? _kBlue
                : _kBorder,
            width: hasFocus ? 2 : 1.2,
          ),
          boxShadow: hasFocus
              ? [
                  BoxShadow(
                    color:
                        _kBlue.withOpacity(.12),
                    blurRadius: 8,
                    offset:
                        const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: TextField(
          controller:
              _otpControllers[index],
          focusNode:
              _otpFocusNodes[index],
          textAlign: TextAlign.center,
          keyboardType:
              TextInputType.number,
          maxLength: 1,
          inputFormatters: [
            FilteringTextInputFormatter
                .digitsOnly,
          ],
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: _kText,
          ),
          decoration:
              const InputDecoration(
            border: InputBorder.none,
            counterText: '',
            contentPadding:
                EdgeInsets.zero,
          ),
          onChanged: (value) {
            if (value.isNotEmpty &&
                index < 5) {
              FocusScope.of(context)
                  .requestFocus(
                _otpFocusNodes[index + 1],
              );
            } else if (value.isEmpty &&
                index > 0) {
              FocusScope.of(context)
                  .requestFocus(
                _otpFocusNodes[index - 1],
              );
            }

            if (_otpControllers.every(
              (controller) =>
                  controller.text.isNotEmpty,
            )) {
              _verifyCode();
            }

            if (mounted) {
              setState(() {});
            }
          },
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
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: _kText,
          ),
          onPressed: _loading
              ? null
              : () {
                  Navigator.pop(context);
                },
        ),
        title: const Text(
          'Verify Email',
          style: TextStyle(
            color: _kText,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 20,
            ),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 400,
              ),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      // ======================================================
                      // ICON
                      // ======================================================

                      Center(
                        child: Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(
                            color: _kBlue
                                .withOpacity(.08),
                            borderRadius:
                                BorderRadius.circular(
                              24,
                            ),
                          ),
                          child: const Icon(
                            Icons
                                .mark_email_unread_outlined,
                            color: _kBlue,
                            size: 40,
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ======================================================
                      // TITLE
                      // ======================================================

                      const Center(
                        child: Text(
                          'Check your email',
                          textAlign:
                              TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight:
                                FontWeight.w800,
                            color: _kText,
                            letterSpacing: -.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ======================================================
                      // DESCRIPTION
                      // ======================================================

                      Center(
                        child: RichText(
                          textAlign:
                              TextAlign.center,
                          text: TextSpan(
                            style:
                                const TextStyle(
                              fontSize: 14,
                              color:
                                  _kSubText,
                              height: 1.6,
                            ),
                            children: [
                              const TextSpan(
                                text:
                                    'We sent a 6-digit verification code to ',
                              ),
                              TextSpan(
                                text:
                                    widget.email,
                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight.w700,
                                  color:
                                      _kText,
                                ),
                              ),
                              const TextSpan(
                                text:
                                    '.',
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // ======================================================
                      // OTP
                      // ======================================================

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .spaceBetween,
                        children:
                            List.generate(
                          6,
                          (index) =>
                              _otpField(index),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ======================================================
                      // RESEND
                      // ======================================================

                      Center(
                        child: TextButton(
                          onPressed:
                              (_loading ||
                                      _resending)
                                  ? null
                                  : _resendCode,
                          child: _resending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth:
                                        2,
                                    color:
                                        _kBlue,
                                  ),
                                )
                              : const Text(
                                  "Didn't receive a code? Resend",
                                  style:
                                      TextStyle(
                                    color:
                                        _kBlue,
                                    fontSize:
                                        13,
                                    fontWeight:
                                        FontWeight
                                            .w600,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ======================================================
                      // VERIFY BUTTON
                      // ======================================================

                      SizedBox(
                        width:
                            double.infinity,
                        height: 54,
                        child:
                            ElevatedButton(
                          onPressed:
                              _loading
                                  ? null
                                  : _verifyCode,
                          style:
                              ElevatedButton
                                  .styleFrom(
                            backgroundColor:
                                _kBlue,
                            disabledBackgroundColor:
                                _kBlue.withOpacity(
                              .45,
                            ),
                            elevation: 0,
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
                                  width: 22,
                                  height: 22,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth:
                                        2.5,
                                    color:
                                        Colors.white,
                                  ),
                                )
                              : const Text(
                                  'VERIFY ACCOUNT',
                                  style:
                                      TextStyle(
                                    fontSize:
                                        15,
                                    fontWeight:
                                        FontWeight
                                            .w800,
                                    color:
                                        Colors
                                            .white,
                                    letterSpacing:
                                        .5,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ======================================================
                      // EMAIL
                      // ======================================================

                      Center(
                        child: Text(
                          widget.email,
                          style:
                              const TextStyle(
                            color:
                                _kSubText,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
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