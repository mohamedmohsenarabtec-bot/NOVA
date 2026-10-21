import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config.dart';
import '../../shared/app_controls.dart';
import '../../shared/brand.dart';
import '../../core/strings.dart';
import '../../core/validation.dart';
import '../../shared/repository.dart';
import 'auth_feedback.dart';

class AuthScreen extends StatefulWidget {
  final NovaRepository repo;
  final bool recovery;
  final VoidCallback onRecovered;
  const AuthScreen({
    super.key,
    required this.repo,
    required this.recovery,
    required this.onRecovered,
  });
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  bool register = false, consent = false, busy = false;
  DateTime? birth;
  String Function(Strings)? notice;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit({bool reset = false}) async {
    if (reset && !Config.emailRecoveryEnabled) {
      setState(
        () => notice = (s) => s.t(
          'استعادة كلمة المرور بالبريد غير مفعّلة في هذه التجربة. لن نرسل رسالة. يلزم إعداد إرسال البريد قبل تفعيلها.',
          'Email password recovery is not enabled for this preview. No email was sent. Configure email delivery before enabling recovery.',
        ),
      );
      return;
    }
    if (reset && !Validation.email(email.text)) {
      setState(
        () =>
            notice = (s) =>
                s.t('أدخل بريدًا صالحًا أولًا.', 'Enter a valid email first.'),
      );
      return;
    }
    if (reset
        ? !Validation.email(email.text)
        : !form.currentState!.validate()) {
      return;
    }
    if (register &&
        !reset &&
        (!consent ||
            birth == null ||
            !Validation.adult(birth!, DateTime.now()))) {
      setState(
        () => notice = (s) => s.t(
          'أكّد عمرك وموافقتك على الشروط أولًا.',
          'Confirm your age and consent first.',
        ),
      );
      return;
    }
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      if (reset) {
        await widget.repo.client.auth.resetPasswordForEmail(email.text.trim());
        notice = (s) => s.t(
          'إذا كان الحساب مؤهلًا فقد طُلبت رسالة استعادة. وصولها يعتمد على إعداد البريد.',
          'If eligible, a recovery email was requested. Delivery depends on email configuration.',
        );
      } else if (widget.recovery) {
        await widget.repo.client.auth.updateUser(
          UserAttributes(password: password.text),
        );
        widget.onRecovered();
      } else if (register) {
        final result = await widget.repo.register(
          email: email.text.trim(),
          password: password.text,
          birth: birth!,
        );
        notice = (s) => signupFeedback(s, result);
      } else {
        await widget.repo.client.auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
    } catch (error) {
      notice = (s) => authFeedback(s, error);
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Scaffold(
      appBar: AppBar(title: const NovaLogo(), actions: const [AppControls()]),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(28),
            children: [
              const Center(child: NovaLogo(symbolOnly: true, size: 76)),
              const SizedBox(height: 24),
              Text(
                s.t(
                  'كل حكاية جميلة\nتبدأ بلحظة صدق.',
                  'Every meaningful story\nstarts with being yourself.',
                ),
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 12),
              Text(
                s.t(
                  'تعارف بنية واضحة، وخطوات على راحتك. +١٨',
                  'Clear intentions. Your pace. Adults 18+ only.',
                ),
              ),
              const SizedBox(height: 32),
              Form(
                key: form,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!widget.recovery)
                      TextFormField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: InputDecoration(
                          labelText: s.t('البريد الإلكتروني', 'Email'),
                        ),
                        validator: (v) => Validation.email(v ?? '')
                            ? null
                            : s.t('أدخل بريدًا صالحًا', 'Enter a valid email'),
                      ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: password,
                      obscureText: true,
                      autofillHints: [
                        register
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      decoration: InputDecoration(
                        labelText: s.t('كلمة المرور', 'Password'),
                      ),
                      validator: (v) =>
                          (register || widget.recovery
                              ? Validation.password(v ?? '')
                              : (v ?? '').isNotEmpty)
                          ? null
                          : s.t(
                              'استخدم ١٢ حرفًا على الأقل',
                              'Use at least 12 characters',
                            ),
                    ),
                    if (register && !widget.recovery) ...[
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime(
                                    DateTime.now().year - 20,
                                  ),
                                  firstDate: DateTime(1920),
                                  lastDate: DateTime.now(),
                                );
                                if (date != null) setState(() => birth = date);
                              },
                        icon: const Icon(Icons.cake_outlined),
                        label: Text(
                          birth == null
                              ? s.t(
                                  'تاريخ الميلاد • ١٨ عامًا فأكثر',
                                  'Date of birth • 18 or older',
                                )
                              : birth!.toIso8601String().substring(0, 10),
                        ),
                      ),
                      CheckboxListTile(
                        value: consent,
                        onChanged: (v) => setState(() => consent = v ?? false),
                        title: Text(
                          s.t(
                            'أوافق على الشروط وسياسة الخصوصية',
                            'I agree to the terms and privacy policy',
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(
                              s.t(
                                'الشروط والخصوصية • مسودة',
                                'Terms & privacy • draft',
                              ),
                            ),
                            content: Text(
                              s.t(
                                'للبالغين فقط. نحفظ الملف والرسائل لتقديم الخدمة. المحادثات ليست مشفرة من طرف إلى طرف. يحق لك الحظر والإبلاغ وتصدير بياناتك وحذف الحساب. هذه نسخة تطوير غير متاحة للإطلاق العام قبل المراجعة القانونية. راجع ملفات docs/legal.',
                                'Adults only. Profiles and messages are stored to provide the service. Chats are not end-to-end encrypted. You can block, report, export data and delete your account. Development version; legal review required before public launch. See docs/legal.',
                              ),
                            ),
                          ),
                        ),
                        child: Text(
                          s.t(
                            'قراءة الشروط والخصوصية',
                            'Read terms and privacy',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: busy ? null : submit,
                      child: busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              widget.recovery
                                  ? s.t('تحديث كلمة المرور', 'Update password')
                                  : register
                                  ? s.t('ابدأ حكايتك', 'Begin your story')
                                  : s.t('تسجيل الدخول', 'Sign in'),
                            ),
                    ),
                    if (!widget.recovery) ...[
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                register = !register;
                                notice = null;
                              }),
                        child: Text(
                          register
                              ? s.t(
                                  'لديك حساب؟ سجّل الدخول',
                                  'Already a member? Sign in',
                                )
                              : s.t('حساب جديد', 'Create an account'),
                        ),
                      ),
                      TextButton(
                        onPressed: busy ? null : () => submit(reset: true),
                        child: Text(
                          s.t('نسيت كلمة المرور؟', 'Forgot password?'),
                        ),
                      ),
                    ],
                    if (notice != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(notice!(s)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
