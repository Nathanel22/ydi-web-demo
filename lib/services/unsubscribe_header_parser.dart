import '../models/unsubscribe_option.dart';

/// Parses RFC 2369/8058 metadata only; performs no network or mail operations.
class UnsubscribeHeaderParser {
  const UnsubscribeHeaderParser();

  List<UnsubscribeOption> parse({
    required String account,
    required Iterable<String> listUnsubscribe,
    Iterable<String> listUnsubscribePost = const [],
  }) {
    if (account.trim().isEmpty) return const [];
    final postValues = listUnsubscribePost.map(_unfold).toList();
    final oneClick =
        postValues.isNotEmpty &&
        postValues.every(
          (value) => RegExp(
            r'^list-unsubscribe[ \t]*=[ \t]*one-click$',
            caseSensitive: false,
          ).hasMatch(value),
        );
    final options = <UnsubscribeOption>{};
    for (final header in listUnsubscribe) {
      for (final value in _uris(_unfold(header))) {
        final uri = UnsubscribeOption.validatedUri(value);
        if (uri == null) continue;
        final method = uri.scheme == 'mailto'
            ? UnsubscribeMethod.mailto
            : postValues.isEmpty
            ? UnsubscribeMethod.httpGet
            : oneClick && uri.scheme == 'https'
            ? UnsubscribeMethod.oneClickPost
            : UnsubscribeMethod.unknown;
        options.add(
          UnsubscribeOption(account: account, uri: uri, method: method),
        );
      }
    }
    return List.unmodifiable(options);
  }

  String _unfold(String value) =>
      value.replaceAll(RegExp(r'\r?\n[ \t]+'), ' ').trim();

  Iterable<String> _uris(String header) sync* {
    if (header.contains('\r') || header.contains('\n')) return;
    if (!header.contains('<') && !header.contains('>')) {
      // Tolerate one bare URI. Do not guess at comma separators: commas are
      // valid URI characters (including in mailto recipient lists).
      yield header;
      return;
    }
    var start = -1;
    var nested = false;
    for (var index = 0; index < header.length; index++) {
      if (header[index] == '<') {
        if (start >= 0) {
          nested = true;
        } else {
          start = index + 1;
          nested = false;
        }
      } else if (header[index] == '>' && start >= 0) {
        if (!nested) yield header.substring(start, index).trim();
        start = -1;
      }
    }
  }
}
