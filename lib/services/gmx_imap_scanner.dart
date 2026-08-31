import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';

import '../config/public_demo.dart';
import '../data/scan_data_store.dart';
import '../data/service_catalog.dart';
import '../models/scan_dataset.dart';
import '../models/gmx_sync_state.dart';
import '../models/service_category.dart';
import '../models/service_item.dart';

final gmxImapScanner = GmxImapScanner();

class GmxImapScanner {
  GmxImapScanner({
    RealGmxAccessPolicy accessPolicy = realGmxAccessPolicy,
    ImapClient Function()? clientFactory,
    GmxImapSession Function()? sessionFactory,
    this.dataStore,
  }) : _accessPolicy = accessPolicy,
       _sessionFactory =
           sessionFactory ??
           (() => EnoughMailGmxImapSession(
             clientFactory?.call() ?? _createClient(),
           ));

  static const maximumMessages = 5000;
  static const chunkSize = 250;
  static const headerFetchCriteria =
      '(UID BODY.PEEK[HEADER.FIELDS (FROM SUBJECT LIST-UNSUBSCRIBE '
      'LIST-UNSUBSCRIBE-POST LIST-ID)])';

  final RealGmxAccessPolicy _accessPolicy;
  final GmxImapSession Function() _sessionFactory;
  final ScanDataStore? dataStore;

  ScanDataStore get _store => dataStore ?? scanDataStore;

  Future<void> testConnection(String email, String password) async {
    _accessPolicy.ensureAllowed();
    final session = _sessionFactory();
    try {
      await session.connect(email.trim(), password);
      await session.selectInbox();
    } finally {
      await session.close();
    }
  }

  Future<ScanDataset> scanAndSave(
    String email,
    String password, {
    required void Function(int current, int total) onProgress,
    bool Function()? isCancelled,
  }) async {
    _accessPolicy.ensureAllowed();
    final normalizedEmail = email.trim().toLowerCase();
    final account = 'GMX · $normalizedEmail';
    final session = _sessionFactory();
    try {
      await session.connect(normalizedEmail, password);
      final mailbox = await session.selectInbox();
      _throwIfCancelled(isCancelled);

      final previousState = await _store.loadGmxSyncState(account);
      final canIncrement =
          previousState != null &&
          mailbox.uidValidity != null &&
          previousState.uidValidity == mailbox.uidValidity;
      final eligibleUids = canIncrement
          ? ((await session.searchUids(
                  afterUid: previousState.lastProcessedUid,
                )).toSet().toList()..sort())
                .where((uid) => uid > previousState.lastProcessedUid)
                .take(maximumMessages)
                .toList(growable: false)
          : const <int>[];
      final total = canIncrement
          ? eligibleUids.length
          : mailbox.messagesExists > maximumMessages
          ? maximumMessages
          : mailbox.messagesExists;
      if (total == 0) {
        onProgress(0, 0);
        if (canIncrement) {
          return _store.notifier.value ??
              const ScanDataset(services: [], sourceFiles: []);
        }
        return _commitAccount(
          account,
          const [],
          mailbox.uidValidity == null
              ? null
              : GmxSyncState(
                  uidValidity: mailbox.uidValidity!,
                  lastProcessedUid: 0,
                ),
        );
      }

      final knownServices = _store.notifier.value?.services ?? const [];
      final aggregated = <String, _GmxService>{};
      if (canIncrement) {
        for (final service in knownServices) {
          if (service.accounts.contains(account)) {
            aggregated[service.id] = _GmxService.fromService(service, account);
          }
        }
      }
      var processed = 0;
      int? highestFetchedUid;
      for (var offset = 0; offset < total; offset += chunkSize) {
        _throwIfCancelled(isCancelled);
        final end = offset + chunkSize < total ? offset + chunkSize : total;
        final messages = canIncrement
            ? await session.fetchUids(
                eligibleUids.sublist(offset, end),
                criteria: headerFetchCriteria,
              )
            : await session.fetchSequenceRange(
                mailbox.messagesExists - total + offset + 1,
                mailbox.messagesExists - total + end,
                criteria: headerFetchCriteria,
              );
        _throwIfCancelled(isCancelled);
        var messagesInChunk = 0;
        for (final message in messages) {
          _aggregate(message, account, knownServices, aggregated);
          final uid = message.uid;
          if (uid != null &&
              (highestFetchedUid == null || uid > highestFetchedUid)) {
            highestFetchedUid = uid;
          }
          messagesInChunk++;
          if (messagesInChunk % 20 == 0) {
            onProgress(offset + messagesInChunk, total);
          }
        }
        processed = end;
        onProgress(processed, total);
      }

      return _commitAccount(
        account,
        aggregated.values.map((value) => value.build()).toList(),
        mailbox.uidValidity == null ||
                (!canIncrement && highestFetchedUid == null)
            ? null
            : GmxSyncState(
                uidValidity: mailbox.uidValidity!,
                lastProcessedUid: canIncrement
                    ? eligibleUids.last
                    : highestFetchedUid!,
              ),
      );
    } finally {
      await session.close();
    }
  }

  static ImapClient _createClient() => ImapClient(
    isLogEnabled: false,
    defaultWriteTimeout: const Duration(seconds: 20),
    defaultResponseTimeout: const Duration(seconds: 30),
  );

  Future<ScanDataset> _commitAccount(
    String account,
    List<ServiceItem> services,
    GmxSyncState? syncState,
  ) async {
    final incoming = ScanDataset(
      services: services,
      sourceFiles: ['gmx-imap:$account'],
    );
    final current = _store.notifier.value;
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
    return _store.saveGmxDataset(account, complete, syncState: syncState);
  }

  void _throwIfCancelled(bool Function()? isCancelled) {
    if (isCancelled?.call() == true) throw const GmxScanCancelledException();
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

class GmxMailboxSnapshot {
  const GmxMailboxSnapshot({
    required this.messagesExists,
    required this.uidValidity,
  });

  final int messagesExists;
  final int? uidValidity;
}

abstract interface class GmxImapSession {
  Future<void> connect(String email, String password);

  Future<GmxMailboxSnapshot> selectInbox();

  Future<List<int>> searchUids({int? afterUid});

  Future<List<MimeMessage>> fetchSequenceRange(
    int firstSequenceId,
    int lastSequenceId, {
    required String criteria,
  });

  Future<List<MimeMessage>> fetchUids(
    List<int> uids, {
    required String criteria,
  });

  Future<void> close();
}

class EnoughMailGmxImapSession implements GmxImapSession {
  EnoughMailGmxImapSession(this._client);

  final ImapClient _client;

  @override
  Future<void> connect(String email, String password) async {
    await _client.connectToServer('imap.gmx.net', 993, isSecure: true);
    await _client.login(email, password);
  }

  @override
  Future<GmxMailboxSnapshot> selectInbox() async {
    final mailbox = await _client.selectInbox();
    return GmxMailboxSnapshot(
      messagesExists: mailbox.messagesExists,
      uidValidity: mailbox.uidValidity,
    );
  }

  @override
  Future<List<int>> searchUids({int? afterUid}) async {
    final result = await _client.uidSearchMessages(
      searchCriteria: afterUid == null ? 'ALL' : 'UID ${afterUid + 1}:*',
    );
    return result.matchingSequence?.toList() ?? const [];
  }

  @override
  Future<List<MimeMessage>> fetchSequenceRange(
    int firstSequenceId,
    int lastSequenceId, {
    required String criteria,
  }) async {
    final result = await _client.fetchMessages(
      MessageSequence.fromRange(firstSequenceId, lastSequenceId),
      criteria,
    );
    return result.messages;
  }

  @override
  Future<List<MimeMessage>> fetchUids(
    List<int> uids, {
    required String criteria,
  }) async {
    if (uids.isEmpty) return const [];
    final result = await _client.uidFetchMessages(
      MessageSequence.fromIds(uids, isUid: true),
      criteria,
    );
    return result.messages;
  }

  @override
  Future<void> close() async {
    try {
      if (_client.isLoggedIn) await _client.logout();
    } catch (_) {
      // The socket may already be closed after a failed login or scan.
    }
  }
}

class GmxScanCancelledException implements Exception {
  const GmxScanCancelledException();
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

  factory _GmxService.fromService(ServiceItem service, String account) =>
      _GmxService(
          id: service.id,
          name: service.name,
          category: service.categoryId,
          color: service.color,
          monogram: service.monogram,
          domain: service.domains.firstOrNull ?? '',
          account: account,
        )
        ..total = service.mailCountFor(account)
        ..newsletters = service.newsletterCountFor(account)
        ..security = service.securityCountFor(account)
        ..hasUnsubscribe = service.hasUnsubscribeLinkFor(account)
        ..unsubscribeUrl = service.unsubscribeUrlFor(account)
        ..unsubscribeRequiresPost = service.unsubscribeRequiresPostFor(account);
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
