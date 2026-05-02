import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/w_lang_toggle.dart';
import '../../app_state/app_state.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _registerMode = false;
  bool _submitting = false;
  bool _googleSubmitting = false;
  String? _errorMessage;
  String? _successMessage;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLanguage language = ref.watch(
      appStateProvider.select((WaveMedAppState state) => state.language),
    );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            Row(
              children: <Widget>[
                const Text(
                  'WaveMed',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                LanguageToggle(
                  language: language,
                  onChanged: ref.read(appStateProvider).setLanguage,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(32),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _registerMode
                        ? tr(
                            language,
                            'Create your care workspace',
                            'أنشئ مساحة الرعاية',
                          )
                        : tr(
                            language,
                            'Sign in to continue monitoring',
                            'سجل الدخول للمتابعة',
                          ),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr(
                      language,
                      'Email and password are backed by Firebase Auth. Use your account credentials to continue.',
                      'يعتمد تسجيل الدخول على Firebase Auth. استخدم بيانات حسابك للمتابعة.',
                    ),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SegmentedButton<bool>(
                    segments: <ButtonSegment<bool>>[
                      ButtonSegment<bool>(
                        value: false,
                        label: Text(tr(language, 'Sign in', 'دخول')),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        label: Text(tr(language, 'Register', 'حساب جديد')),
                      ),
                    ],
                    selected: <bool>{_registerMode},
                    onSelectionChanged: (Set<bool> value) {
                      setState(() {
                        _registerMode = value.first;
                        _errorMessage = null;
                        _successMessage = null;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: tr(language, 'Email', 'البريد الإلكتروني'),
                      prefixIcon: const Icon(Icons.mail_outline),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: tr(language, 'Password', 'كلمة المرور'),
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                  ),
                  if (_errorMessage != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ],
                  if (_successMessage != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      _successMessage!,
                      style: const TextStyle(color: AppColors.success),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      backgroundColor: AppColors.primary,
                    ),
                    child: Text(
                      _submitting
                          ? tr(language, 'Connecting...', 'جارٍ الاتصال...')
                          : _registerMode
                          ? tr(language, 'Create account', 'إنشاء الحساب')
                          : tr(language, 'Open dashboard', 'افتح لوحة المتابعة'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _googleSubmitting ? null : _signInWithGoogle,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                    ),
                    icon: _googleSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.g_mobiledata_rounded),
                    label: Text(
                      tr(
                        language,
                        'Continue with Google',
                        'المتابعة عبر Google',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _submitting ? null : _resetPassword,
                    child: Text(
                      tr(
                        language,
                        'Forgot password?',
                        'نسيت كلمة المرور؟',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final AppLanguage language = ref.read(appStateProvider).language;
    setState(() {
      _submitting = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      await ref.read(appStateProvider).signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        registerMode: _registerMode,
      );
    } catch (error) {
      String message = tr(
        language,
        'Authentication failed. Verify Firebase Auth configuration or use an anonymous developer session.',
        'فشلت المصادقة. تحقق من إعداد Firebase Auth أو استخدم جلسة تطوير مجهولة.',
      );

      // Show the actual Firebase reason to make debugging possible.
      if (error is FirebaseAuthException) {
        message = '${message}\n${error.code}${error.message == null ? '' : ': ${error.message}'}';
      } else {
        message = '$message\n$error';
      }

      setState(() {
        _errorMessage = message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    final AppLanguage language = ref.read(appStateProvider).language;
    setState(() {
      _googleSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      await ref.read(appStateProvider).signInWithGoogle();
    } catch (error) {
      if (!mounted) {
        return;
      }
      String message = tr(
        language,
        'Google sign-in failed. Enable Google provider in Firebase Auth and verify authorized web domains.',
        'فشل تسجيل الدخول عبر Google. فعّل مزود Google في Firebase Auth وتأكد من النطاقات المصرح بها للويب.',
      );
      if (error is FirebaseAuthException) {
        message =
            '$message\n${error.code}${error.message == null ? '' : ': ${error.message}'}';
      } else {
        message = '$message\n$error';
      }
      setState(() {
        _errorMessage = message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _googleSubmitting = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    final AppLanguage language = ref.read(appStateProvider).language;
    setState(() {
      _submitting = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      await ref
          .read(appStateProvider)
          .sendPasswordResetEmail(_emailController.text.trim());
      if (!mounted) {
        return;
      }
      setState(() {
        _successMessage = tr(
          language,
          'Password reset email sent.',
          'تم إرسال رسالة إعادة تعيين كلمة المرور.',
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = tr(
          language,
          'Enter a valid email before requesting a reset.',
          'أدخل بريداً إلكترونياً صالحاً قبل طلب إعادة التعيين.',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }
}
