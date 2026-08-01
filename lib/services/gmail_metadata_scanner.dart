import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../data/scan_data_store.dart';
import '../data/service_catalog.dart';
import '../models/scan_dataset.dart';
import '../models/service_category.dart';
import '../models/service_item.dart';
import 'google_auth_service.dart';

final gmailMetadataScanner = GmailMetadataScanner();

class GmailMetadataScanner {
  static const _maximumMessages = 1000;

  Future<ScanDataset> scanAndSave(
    GoogleSignInAccount user, {
    required void Function(int current, int total) onProgress,
  }) async {
    final headers = await googleAuthService.authorizeGmailMetadata(user);
    final messageIds = await _listMessageIds(headers);
    final account = accountLabelFor(user.email);
    final knownServices = scanDataNotifier.value?.services ?? const [];
    final aggregated = <String, _LiveService>{};

    const chunkSize = 10;
    for (var offset = 0; offset < messageIds.length; offset += chunkSize) {
      final end = (offset + chunkSize).clamp(0, messageIds.length);
      final chunk = messageIds.sublist(offset, end);
      final messages = await Future.wait(
        chunk.map((id) => _getMetadata(id, headers)),
      );

      for (final message in messages) {
        if (message == null) continue;
        _aggregate(message, account, knownServices, aggregated);
      }
      onProgress(end, messageIds.length);
    }

    final services = aggregated.values.map((item) => item.build()).toList()
      ..sort((a, b) => b.totalMailCount.compareTo(a.totalMailCount));
    final incoming = ScanDataset(
      services: services,
      sourceFiles: ['gmail-api:$account'],
    );

    final current = scanDataNotifier.value;
    final labelsToReplace = {
      ...accountLabelsFor(user.email),
      ...?current?.accounts.where(
        (label) => _accountLabelMatchesEmail(label, user.email),
      ),
    };
    final complete = current == null
        ? incoming
        : current.withoutAccounts(labelsToReplace).mergedWith(incoming);
    await scanDataStore.save(complete);
    return scanDataNotifier.value!;
  }

  Future<List<String>> _listMessageIds(Map<String, String> headers) async {
    final ids = <String>[];
    String? pageToken;

    while (ids.length < _maximumMessages) {
      final remaining = _maximumMessages - ids.length;
      final pageSize = remaining > 500 ? 500 : remaining;
      final parameters = <String, String>{
        'labelIds': 'INBOX',
        'maxResults': '$pageSize',
        'pageToken': ?pageToken,
      };
      final uri = Uri.https(
        'gmail.googleapis.com',
        '/gmail/v1/users/me/messages',
        parameters,
      );
      final response = await http.get(uri, headers: headers);
      _ensureSuccess(response, 'Nachrichtenliste');
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final messages = (json['messages'] as List<dynamic>?) ?? const [];
      ids.addAll(
        messages.map(
          (message) => (message as Map<String, dynamic>)['id'] as String,
        ),
      );

      pageToken = json['nextPageToken'] as String?;
      if (pageToken == null || messages.isEmpty) break;
    }

    return ids.take(_maximumMessages).toList(growable: false);
  }

  Future<_MessageMetadata?> _getMetadata(
    String id,
    Map<String, String> headers,
  ) async {
    final uri = Uri.parse(
      'https://gmail.googleapis.com/gmail/v1/users/me/messages/$id'
      '?format=metadata'
      '&metadataHeaders=From'
      '&metadataHeaders=Subject'
      '&metadataHeaders=List-Unsubscribe'
      '&metadataHeaders=List-ID',
    );
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 404) return null;
    _ensureSuccess(response, 'Nachrichtenmetadaten');
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final payload = json['payload'] as Map<String, dynamic>?;
    final rawHeaders = (payload?['headers'] as List<dynamic>?) ?? const [];
    final values = <String, String>{};
    for (final raw in rawHeaders) {
      final header = raw as Map<String, dynamic>;
      values[(header['name'] as String).toLowerCase()] =
          header['value'] as String? ?? '';
    }
    return _MessageMetadata(
      from: values['from'] ?? '',
      subject: values['subject'] ?? '',
      listUnsubscribe: values['list-unsubscribe'] ?? '',
      listId: values['list-id'] ?? '',
    );
  }

  void _aggregate(
    _MessageMetadata message,
    String account,
    List<ServiceItem> knownServices,
    Map<String, _LiveService> aggregated,
  ) {
    final domain = _senderDomain(message.from);
    if (domain.isEmpty) return;
    final catalog = ServiceCatalog.findByDomain(domain);
    final known = catalog == null ? _knownService(domain, knownServices) : null;
    final root = _rootDomain(domain);
    final id =
        catalog?.id ?? known?.id ?? root.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final name = catalog?.name ?? known?.name ?? root;
    final item = aggregated.putIfAbsent(
      id,
      () => _LiveService(
        id: id,
        name: name,
        category:
            catalog?.category ?? known?.categoryId ?? ServiceCategory.unknown,
        color: known?.color ?? _colorFor(name),
        monogram: known?.monogram ?? _monogramFor(name),
        domain: catalog != null
            ? catalog.domains.first
            : known == null || known.domains.isEmpty
            ? root
            : known.domains.first,
        account: account,
      ),
    );
    item.total++;

    final subject = message.subject.toLowerCase();
    if (message.listUnsubscribe.isNotEmpty ||
        message.listId.isNotEmpty ||
        _containsAny(subject, _newsletterWords)) {
      item.newsletters++;
    }
    if (_containsAny(subject, _securityWords)) item.security++;
    if (message.listUnsubscribe.isNotEmpty) item.hasUnsubscribe = true;
  }

  ServiceItem? _knownService(String domain, List<ServiceItem> services) {
    for (final service in services) {
      for (final knownDomain in service.domains) {
        final normalized = knownDomain.toLowerCase();
        if (domain == normalized || domain.endsWith('.$normalized')) {
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
    if (compoundSuffixes.contains(lastTwo) && parts.length >= 3) {
      return parts.sublist(parts.length - 3).join('.');
    }
    return lastTwo;
  }

  String accountLabelFor(String email) => 'Gmail · $email';

  Set<String> accountLabelsFor(String email) => {
    'Gmail',
    accountLabelFor(email),
    _legacyAccountLabelFor(email),
  };

  bool _accountLabelMatchesEmail(String label, String email) {
    if (!label.toLowerCase().startsWith('gmail')) return false;

    final emailParts = email.toLowerCase().split('@');
    if (emailParts.length != 2) return false;

    final atIndex = label.lastIndexOf('@');
    if (atIndex < 0) return label.toLowerCase() == 'gmail';

    final domain = label.substring(atIndex + 1).toLowerCase();
    if (domain != emailParts.last) return false;

    final beforeAt = label.substring(0, atIndex);
    final withoutProvider = beforeAt.length > 5
        ? beforeAt.substring(5)
        : beforeAt;
    final visibleParts = RegExp(
      r'[a-zA-Z0-9._+\-]+',
    ).allMatches(withoutProvider).map((match) => match.group(0)!).toList();
    if (visibleParts.isEmpty) return false;

    final local = emailParts.first;
    if (visibleParts.length == 1) {
      return visibleParts.first.toLowerCase() == local;
    }
    return local.startsWith(visibleParts.first.toLowerCase()) &&
        local.endsWith(visibleParts.last.toLowerCase());
  }

  String _legacyAccountLabelFor(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return 'Gmail';
    final local = parts.first;
    final startLength = local.length < 2 ? local.length : 2;
    final visibleStart = local.substring(0, startLength);
    final visibleEnd = local.length > 4
        ? local.substring(local.length - 2)
        : '';
    return 'Gmail · $visibleStart…$visibleEnd@${parts.last}';
  }

  bool _containsAny(String value, List<String> words) =>
      words.any(value.contains);

  void _ensureSuccess(http.Response response, String operation) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw StateError('$operation fehlgeschlagen (${response.statusCode}).');
  }

  Color _colorFor(String name) {
    const colors = [
      Color(0xFF526DFF),
      Color(0xFF9B62E8),
      Color(0xFF29A583),
      Color(0xFFEF7E5B),
      Color(0xFF2777BD),
      Color(0xFFF39B28),
      Color(0xFF00A88F),
    ];
    final sum = name.codeUnits.fold(0, (total, value) => total + value);
    return colors[sum % colors.length];
  }

  String _monogramFor(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length > 1) {
      return '${words.first[0]}${words.last[0]}'.toUpperCase();
    }
    final end = name.length < 2 ? name.length : 2;
    return name.substring(0, end).toUpperCase();
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
    'zwei-faktor',
    '2fa',
    'warnung',
  ];
}

class _MessageMetadata {
  const _MessageMetadata({
    required this.from,
    required this.subject,
    required this.listUnsubscribe,
    required this.listId,
  });

  final String from;
  final String subject;
  final String listUnsubscribe;
  final String listId;
}

class _LiveService {
  _LiveService({
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
  );
}
