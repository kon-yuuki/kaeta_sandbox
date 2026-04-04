class EmailValidator {
  static final RegExp _emailPattern = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$",
  );

  static bool isValid(String input) {
    final email = input.trim();
    if (email.isEmpty) return false;
    return _emailPattern.hasMatch(email);
  }

  static String? validate(String input) {
    final email = input.trim();
    if (email.isEmpty) return 'メールアドレスを入力してください';
    if (!isValid(email)) return 'メールアドレスの形式を確認してください';
    return null;
  }
}
