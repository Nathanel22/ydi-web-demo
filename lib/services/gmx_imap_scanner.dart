import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';

import '../data/scan_data_store.dart';
import '../data/account_scan_store.dart';
import '../data/service_catalog.dart';
import '../models/scan_dataset.dart';
import '../models/service_category.dart';
import '../models/service_item.dart';

final gmxImapScanner = GmxImapScanner();

class GmxImapScanner {
  static const maximumMessages = 1000;

  Future<void> testConnection(String email, String password) async {
    final client = _client();
    try {
      await client.connectToServer('imap.gmx.net', 993, isSecure: true);
      await client.login(email.trim(), password);
      await client.selectInbox();
    } finally {
      await _close(client);
    }
  }

  Future<ScanDataset> scanAndSave(
    String email,
    String password, {
    required void Function(int current, int total) onProgress,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final account = 'GMX · $normalizedEmail';
    final client = _client();
    try {
      await client.connectToServer('imap.gmx.net', 993, isSecure: true);
      await client.login(normalizedEmail, password);
      final mailbox = await client.selectInbox();
      final total = mailbox.messagesExists;
      final count = total > maximumMessages ? maximumMessages : total;
      if (count == 0) {
        onProgress(0, 0);
        return _replaceAccount(account, const []);
      }

      final result = await client.fetchRecentMessages(
        messageCount: count,
        criteria:
            'BODY.PEEK[HEADER.FIELDS (FROM SUBJECT LIST-UNSUBSCRIBE LIST-UNSUBSCRIBE-POST LIST-ID)]',
      );
      final knownServices = scanDataNotifier.value?.services ?? const [];
      final aggregated = <String, _GmxService>{};
      var processed = 0;
      for (final message in result.messages) {
        _aggregate(message, account, knownServices, aggregated);
        processed++;
        if (processed % 20 == 0 || processed == result.messages.length) {
          onProgress(processed, count);
        }
      }
      return _replaceAccount(
        account,
        aggregated.values.map((value) => value.build()).toList(),
      );
    } finally {
      await _close(client);
    }
  }

  ImapClient _client() => ImapClient(
    isLogEnabled: false,
    defaultWriteTimeout: const Duration(seconds: 20),
    defaultResponseTimeout: const Duration(seconds: 30),
  );

  Future<void> _close(ImapClient client) async {
    try {
      if (client.isLoggedIn) await client.logout();
    } catch (_) {
      // The socket may already be closed after a failed login.
    }
  }

  Future<ScanDataset> _replaceAccount(
    String account,
    List<ServiceItem> services,
  ) async {
    final incoming = ScanDataset(
      services: services,
      sourceFiles: ['gmx-imap:$account'],
    );
    final current = scanDataNotifier.value;
    final labelsToReplace = {
      account,
      ...?current?.accounts.where(
        (label) =>
            label.toLowerCase() == 'gmx' ||
            label.toLowerCase().endsWith(account.substring(3).toLowerCase()),
      ),
    };
    final complete = current == null
        ? incoming
        : current.withoutAccounts(labelsToReplace).mergedWith(incoming);
    await scanDataStore.save(complete);
    await accountScanStore.markScanned(account);
    return scanDataNotifier.value!;
  }

  void _aggregate(
    MimeMessage message,
    String account,
    List<ServiceItem> knownServices,
    Map<String, _GmxService> aggregated,
  ) {
    final from = message.from?.isNotEmpty == true
        ? message.from!.first.email
        : message.getHeaderValue('from') ?? '';
    final domain = _senderDomain(from);
    if (domain.isEmpty) return;
    final catalog = ServiceCatalog.findByDomain(domain);
    final known = catalog == null ? _knownService(domain, knownServices) : null;
    final root = _rootDomain(domain);
    final id =
        catalog?.id ?? known?.id ?? root.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final name = catalog?.name ?? known?.name ?? root;
    final item = aggregated.putIfAbsent(
      id,
      () => _GmxService(
        id: id,
        name: name,
        category:
            catalog?.category ?? known?.categoryId ?? ServiceCategory.unknown,
        color: known?.color ?? _colorFor(name),
        monogram: known?.monogram ?? _monogramFor(name),
        domain: catalog?.domains.first ?? known?.domains.firstOrNull ?? root,
        account: account,
      ),
    );
    item.total++;
    final subject = (message.decodeSubject() ?? '').toLowerCase();
    final unsubscribe = message.getHeaderValue('list-unsubscribe') ?? '';
    final unsubscribePost =
        message.getHeaderValue('list-unsubscribe-post') ?? '';
    final listId = message.getHeaderValue('list-id') ?? '';
    if (unsubscribe.isNotEmpty ||
        listId.isNotEmpty ||
        _containsAny(subject, _newsletterWords)) {
      item.newsletters++;
    }
    if (_containsAny(subject, _securityWords)) item.security++;
    if (unsubscribe.isNotEmpty) item.hasUnsubscribe = true;
    item.unsubscribeUrl ??= _httpsUrlFrom(unsubscribe);
    if (unsubscribePost.toLowerCase().contains('list-unsubscribe=one-click')) {
      item.unsubscribeRequiresPost = true;
    }
  }

  String? _httpsUrlFrom(String header) {
    final match = RegExp(
      r'https?://[^>\s,]+',
      caseSensitive: false,
    ).firstMatch(header);
    return match?.group(0);
  }

  ServiceItem? _knownService(String domain, List<ServiceItem> services) {
    for (final service in services) {
      for (final knownDomain in service.domains) {
        if (domain == knownDomain || domain.endsWith('.$knownDomain')) {
          return service;
        }
      }
    }
    return null;
  }

  String _senderDomain(String from) {
    final matches = RegExp(r'@([a-zA-Z0-9.-]+)').allMatches(from).toList();
    return matches.isEmpty ? '' : matches.last.group(1)!.toLowerCase();
  }

  String _rootDomain(String domain) {
    final parts = domain.split('.');
    if (parts.length <= 2) return domain;
    const compoundSuffixes = {'co.uk', 'com.au', 'com.br', 'co.jp'};
    final lastTwo = parts.sublist(parts.length - 2).join('.');
    return compoundSuffixes.contains(lastTwo)
        ? parts.sublist(parts.length - 3).join('.')
        : lastTwo;
  }

  bool _containsAny(String value, List<String> words) =>
      words.any(value.contains);

  Color _colorFor(String name) {
    const colors = [
      Color(0xFF526DFF),
      Color(0xFF9B62E8),
      Color(0xFF29A583),
      Color(0xFFEF7E5B),
      Color(0xFF2777BD),
      Color(0xFFF39B28),
    ];
    final sum = name.codeUnits.fold(0, (total, value) => total + value);
    return colors[sum % colors.length];
  }

  String _monogramFor(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length > 1) {
      return '${words.first[0]}${words.last[0]}'.toUpperCase();
    }
    return name.substring(0, name.length < 2 ? name.length : 2).toUpperCase();
  }

  static const _newsletterWords = [
    'newsletter',
    'angebot',
    'angebote',
    'sale',
    'deal',
    'rabatt',
    'gutschein',
    'promotion',
  ];
  static const _securityWords = [
    'security',
    'sicherheit',
    'login',
    'log-in',
    'sign-in',
    'anmeldung',
    'verification',
    'bestätigungscode',
    'passwort',
    'password',
    '2fa',
    'warnung',
  ];
}

class _GmxService {
  _GmxService({
    required this.id,
    required this.name,
    required this.category,
    required this.color,
    required this.monogram,
    required this.domain,
    required this.account,
  });
  final String id;
  final String name;
  final ServiceCategory category;
  final Color color;
  final String monogram;
  final String domain;
  final String account;
  int total = 0;
  int newsletters = 0;
  int security = 0;
  bool hasUnsubscribe = false;
  String? unsubscribeUrl;
  bool unsubscribeRequiresPost = false;

  ServiceItem build() => ServiceItem(
    id: id,
    name: name,
    categoryId: category,
    mailCounts: {account: total},
    color: color,
    monogram: monogram,
    domains: [domain],
    newsletterCounts: {account: newsletters},
    securityCounts: {account: security},
    unsubscribeByAccount: {account: hasUnsubscribe},
    unsubscribeUrlsByAccount: {
      if (unsubscribeUrl != null) account: unsubscribeUrl!,
    },
    unsubscribeRequiresPostByAccount: {account: unsubscribeRequiresPost},
  );
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
