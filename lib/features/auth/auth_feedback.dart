import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/strings.dart';

enum SignupResult { signedIn, confirmationRequired, alreadyRegistered }

String signupFeedback(Strings s, SignupResult result) => switch (result) {
  SignupResult.signedIn => s.t(
    'تم إنشاء حسابك وتسجيل الدخول.',
    'Account created. You are signed in.',
  ),
  SignupResult.confirmationRequired => s.t(
    'الخادم يطلب تأكيد البريد. للتجربة دون بريد عطّل Confirm email في إعدادات مزود Email بمشروع التطوير.',
    'This server requires email confirmation. For testing without email, disable Confirm email in the development project Email provider settings.',
  ),
  SignupResult.alreadyRegistered => s.t(
    'الحساب موجود بالفعل. استخدم تسجيل الدخول.',
    'An account already exists. Please sign in.',
  ),
};

String authFeedback(Strings s, Object error) {
  if (error is TimeoutException || error is AuthRetryableFetchException) {
    return s.t(
      'تعذر الاتصال. تحقق من الإنترنت وحاول مجددًا.',
      'Could not connect. Check your network and try again.',
    );
  }
  if (error is AuthException) {
    return switch (error.code) {
      'user_already_exists' ||
      'email_exists' => signupFeedback(s, SignupResult.alreadyRegistered),
      'invalid_credentials' => s.t(
        'البريد أو كلمة المرور غير صحيحة.',
        'Email or password is incorrect.',
      ),
      'email_not_confirmed' => signupFeedback(
        s,
        SignupResult.confirmationRequired,
      ),
      'weak_password' => s.t(
        'اختر كلمة مرور أقوى من ١٢ حرفًا على الأقل.',
        'Choose a stronger password with at least 12 characters.',
      ),
      'over_request_rate_limit' ||
      'over_email_send_rate_limit' ||
      'over_sms_send_rate_limit' => s.t(
        'طلبات كثيرة. انتظر قليلًا ثم حاول مجددًا.',
        'Too many requests. Wait a little and try again.',
      ),
      'captcha_failed' => s.t(
        'أكمل التحقق الأمني ثم أعد المحاولة.',
        'Complete the security check, then retry.',
      ),
      'signup_disabled' => s.t(
        'إنشاء الحسابات غير مفعّل على الخادم.',
        'Registration is disabled on the server.',
      ),
      'session_not_found' ||
      'refresh_token_not_found' ||
      'refresh_token_already_used' => s.t(
        'انتهت الجلسة. سجّل الدخول مجددًا.',
        'Your session expired. Please sign in again.',
      ),
      'unexpected_failure' => s.t(
        'تعذر إنشاء الحساب على الخادم. يلزم فحص إعدادات قاعدة البيانات.',
        'The server could not create the account. Database setup needs checking.',
      ),
      _ => s.t(
        'تعذر إتمام الطلب. تحقق من البيانات والاتصال ثم حاول مجددًا.',
        'Could not complete the request. Check your details and connection, then retry.',
      ),
    };
  }
  return s.error;
}
