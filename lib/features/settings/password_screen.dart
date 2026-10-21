import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/strings.dart';
import '../../shared/app_controls.dart';
import '../../shared/brand.dart';
import '../../shared/repository.dart';
import '../auth/auth_feedback.dart';

class PasswordScreen extends StatefulWidget {
  final NovaRepository repo;
  const PasswordScreen({super.key, required this.repo});
  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final form = GlobalKey<FormState>();
  final current = TextEditingController();
  final next = TextEditingController();
  final confirm = TextEditingController();
  bool busy = false, saved = false;
  Object? error;

  @override
  void dispose() {
    current.dispose();
    next.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      saved = false;
      error = null;
    });
    try {
      final email = widget.repo.client.auth.currentUser?.email;
      if (email == null) throw StateError('Email session required');
      await widget.repo.client.auth.signInWithPassword(
        email: email,
        password: current.text,
      );
      await widget.repo.client.auth.updateUser(
        UserAttributes(password: next.text),
      );
      current.clear();
      next.clear();
      confirm.clear();
      if (mounted) setState(() => saved = true);
    } catch (failure) {
      if (mounted) setState(() => error = failure);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const NovaLogo(symbolOnly: true),
        leading: BackButton(onPressed: () => context.go('/')),
        actions: const [AppControls()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                s.t('تغيير كلمة المرور', 'Change password'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: current,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: s.t(
                          'كلمة المرور الحالية',
                          'Current password',
                        ),
                      ),
                      validator: (v) => (v ?? '').isEmpty
                          ? s.t(
                              'أدخل كلمة المرور الحالية',
                              'Enter current password',
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: next,
                      obscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: s.t('كلمة المرور الجديدة', 'New password'),
                      ),
                      validator: (v) => (v ?? '').length < 12
                          ? s.t(
                              'استخدم 12 حرفًا على الأقل',
                              'Use at least 12 characters',
                            )
                          : v == current.text
                          ? s.t(
                              'اختر كلمة مرور مختلفة',
                              'Choose a different password',
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirm,
                      obscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: s.t(
                          'تأكيد كلمة المرور الجديدة',
                          'Confirm new password',
                        ),
                      ),
                      validator: (v) => v != next.text
                          ? s.t(
                              'كلمتا المرور غير متطابقتين',
                              'Passwords do not match',
                            )
                          : null,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: busy ? null : save,
                      child: Text(
                        busy
                            ? s.t('جارٍ الحفظ…', 'Saving…')
                            : s.t('حفظ كلمة المرور', 'Save password'),
                      ),
                    ),
                  ],
                ),
              ),
              if (saved)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      s.t(
                        'تم تغيير كلمة المرور. استخدم الجديدة عند الدخول القادم.',
                        'Password changed. Use the new password next time you sign in.',
                      ),
                    ),
                  ),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(authFeedback(s, error!)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
