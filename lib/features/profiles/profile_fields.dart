abstract final class ProfileFields {
  static const details = {
    'education': ['التعليم', 'Education'],
    'occupation': ['العمل', 'Occupation'],
    'lifestyle': ['نمط الحياة', 'Lifestyle'],
    'partner': ['ما أبحث عنه', 'What I am looking for'],
    'relationship_status': [
      'الحالة العاطفية (اختياري)',
      'Relationship status (optional)',
    ],
  };
  static List<String> values(String input) => input
      .replaceAll('،', ',')
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList();
  static String? validateName(String value) =>
      value.trim().length < 2 || value.trim().length > 40 ? 'name' : null;
  static int completion(Map<String, dynamic> p) =>
      ((p['display_name'] ?? '').toString().trim().length >= 2 ? 20 : 0) +
      (p['onboarding_complete'] == true ? 20 : 0) +
      ((p['bio'] ?? '') != '' ? 15 : 0) +
      ((p['city'] ?? '') != '' ? 10 : 0) +
      ((p['interests'] as List? ?? []).isNotEmpty ? 15 : 0) +
      ((p['languages'] as List? ?? []).isNotEmpty ? 10 : 0) +
      ((p['details'] as Map? ?? {}).isNotEmpty ? 10 : 0);
}
