class Validators {
  /// Validates email format (used as username)
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Validates password strength:
  /// min 8 chars, at least 1 upper, 1 lower, 1 digit, 1 special char
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    final hasUpper = RegExp(r'[A-Z]').hasMatch(value);
    final hasLower = RegExp(r'[a-z]').hasMatch(value);
    final hasDigit = RegExp(r'\d').hasMatch(value);
    final hasSpecial = RegExp(r'[!@#\$&*~%^()_\-+=]').hasMatch(value);
    if (!hasUpper || !hasLower || !hasDigit || !hasSpecial) {
      return 'Include upper, lower, number & special character';
    }
    return null;
  }

  /// Validates a 10-digit mobile number (adjust regex for your country)
  static String? validateMobile(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Mobile number is required';
    }
    final mobileRegex = RegExp(r'^[6-9]\d{9}$');
    if (!mobileRegex.hasMatch(value.trim())) {
      return 'Enter a valid 10-digit mobile number';
    }
    return null;
  }
}