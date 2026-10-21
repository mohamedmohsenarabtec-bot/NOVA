abstract final class Validation {
  static bool email(String value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());
  static bool password(String value) => value.length >= 12;
  static int age(DateTime birth, DateTime now) =>
      now.year -
      birth.year -
      ((now.month < birth.month ||
              (now.month == birth.month && now.day < birth.day))
          ? 1
          : 0);
  static bool adult(DateTime birth, DateTime now) =>
      !birth.isAfter(now) && age(birth, now) >= 18;
}
