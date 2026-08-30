class GmxAccount {
  const GmxAccount({
    required this.accountId,
    required this.email,
    this.lastSuccessfulScanAt,
    this.credentialAvailable = false,
  });

  static const provider = 'gmx';

  final String accountId;
  final String email;
  final DateTime? lastSuccessfulScanAt;
  final bool credentialAvailable;

  String get scanAccountLabel => 'GMX · $email';

  GmxAccount withLastSuccessfulScanAt(DateTime value) => GmxAccount(
    accountId: accountId,
    email: email,
    lastSuccessfulScanAt: value,
    credentialAvailable: credentialAvailable,
  );

  GmxAccount withCredentialAvailable(bool value) => GmxAccount(
    accountId: accountId,
    email: email,
    lastSuccessfulScanAt: lastSuccessfulScanAt,
    credentialAvailable: value,
  );

  Map<String, dynamic> toJson() => {
    'accountId': accountId,
    'provider': provider,
    'email': email,
    if (lastSuccessfulScanAt != null)
      'lastSuccessfulScanAt': lastSuccessfulScanAt!.toUtc().toIso8601String(),
    'credentialAvailable': credentialAvailable,
  };

  static GmxAccount? tryFromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final accountId = json['accountId'];
    final providerValue = json['provider'];
    final email = json['email'];
    final credentialAvailable = json['credentialAvailable'];
    if (accountId is! String ||
        accountId.isEmpty ||
        providerValue != provider ||
        email is! String ||
        !_looksLikeEmail(email) ||
        credentialAvailable is! bool) {
      return null;
    }
    final scanValue = json['lastSuccessfulScanAt'];
    final lastScan = scanValue == null
        ? null
        : scanValue is String
        ? DateTime.tryParse(scanValue)?.toUtc()
        : null;
    if (scanValue != null && lastScan == null) return null;
    return GmxAccount(
      accountId: accountId,
      email: email.trim().toLowerCase(),
      lastSuccessfulScanAt: lastScan,
      credentialAvailable: credentialAvailable,
    );
  }

  static bool _looksLikeEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
}
