abstract final class Validators {
  static String? required(String? v) => (v == null || v.trim().isEmpty) ? 'This field is required' : null;

  static String? phone(String? v) =>
      RegExp(r'^[6-9]\d{9}$').hasMatch(v?.trim() ?? '') ? null : 'Enter a valid 10-digit mobile number';

  static String? pincode(String? v) =>
      RegExp(r'^[1-9]\d{5}$').hasMatch(v?.trim() ?? '') ? null : 'Enter a valid 6-digit PIN code';

  static String? gstin(String? v) =>
      RegExp(r'^\d{2}[A-Z]{5}\d{4}[A-Z][1-9A-Z]Z[0-9A-Z]$').hasMatch(v?.trim().toUpperCase() ?? '')
      ? null
      : 'Enter a valid 15-character GSTIN';

  static String? pan(String? v) =>
      RegExp(r'^[A-Z]{5}\d{4}[A-Z]$').hasMatch(v?.trim().toUpperCase() ?? '') ? null : 'Enter a valid 10-character PAN';

  static String? fssai(String? v) =>
      RegExp(r'^\d{14}$').hasMatch(v?.trim() ?? '') ? null : 'Enter a valid 14-digit FSSAI number';

  static String? password(String? v) {
    final value = v ?? '';
    if (value.length < 8) return 'Use at least 8 characters';
    if (!value.contains(RegExp(r'[A-Za-z]')) || !value.contains(RegExp(r'\d'))) {
      return 'Use both letters and numbers';
    }
    return null;
  }

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return null; // email is optional
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()) ? null : 'Enter a valid email';
  }

  static String? positiveAmount(String? v) {
    final amount = double.tryParse(v?.trim() ?? '');
    return (amount == null || amount <= 0) ? 'Enter a valid amount' : null;
  }
}
