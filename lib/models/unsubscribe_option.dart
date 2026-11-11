/// Metadata only. These methods are never executed by the parser.
enum UnsubscribeMethod { httpGet, oneClickPost, mailto, unknown }

class UnsubscribeOption {
  const UnsubscribeOption({
    required this.account,
    required this.uri,
    required this.method,
  });

  final String account;
  final Uri uri;
  final UnsubscribeMethod method;

  bool get isWebLink => uri.scheme == 'http' || uri.scheme == 'https';

  Map<String, Object> toJson() => {
    'account': account,
    'url': uri.toString(),
    'method': method.name,
  };

  static UnsubscribeOption? tryFromJson(Object? value) {
    if (value is! Map) return null;
    final account = value['account'];
    final url = value['url'];
    if (account is! String || account.isEmpty || url is! String) return null;
    final uri = validatedUri(url);
    if (uri == null) return null;
    var method = UnsubscribeMethod.unknown;
    for (final candidate in UnsubscribeMethod.values) {
      if (candidate.name == value['method']) method = candidate;
    }
    // Do not silently change the meaning of inconsistent persisted metadata.
    if ((method == UnsubscribeMethod.oneClickPost && uri.scheme != 'https') ||
        (method == UnsubscribeMethod.httpGet && uri.scheme == 'mailto') ||
        (method == UnsubscribeMethod.mailto && uri.scheme != 'mailto')) {
      method = UnsubscribeMethod.unknown;
    }
    return UnsubscribeOption(account: account, uri: uri, method: method);
  }

  /// Accept supported absolute URIs without repairing malformed input.
  static Uri? validatedUri(String value) {
    if (value.isEmpty ||
        RegExp(r'[\x00-\x20\x7f<>\\]').hasMatch(value) ||
        RegExp(r'%(?![0-9a-fA-F]{2})').hasMatch(value) ||
        RegExp(
          r'%(?:0[0-9a-f]|1[0-9a-f]|7f)',
          caseSensitive: false,
        ).hasMatch(value)) {
      return null;
    }
    try {
      final uri = Uri.tryParse(value);
      if (uri == null) return null;
      if (uri.scheme == 'http' || uri.scheme == 'https') {
        if (!uri.hasAuthority ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty ||
            uri.host.contains('%') ||
            uri.port < 1 ||
            uri.port > 65535) {
          return null;
        }
        return uri;
      }
      if (uri.scheme == 'mailto' && !uri.hasAuthority && !uri.hasFragment) {
        final recipients = Uri.decodeComponent(uri.path).split(',');
        if (recipients.every(
          (address) => RegExp(r'^[^@\s<>]+@[^@\s<>]+$').hasMatch(address),
        )) {
          return uri;
        }
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is UnsubscribeOption &&
      account == other.account &&
      uri == other.uri &&
      method == other.method;

  @override
  int get hashCode => Object.hash(account, uri, method);
}
