import 'package:flutter/material.dart';

import 'service_category.dart';

class ServiceItem {
  const ServiceItem({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.mailCounts,
    required this.color,
    required this.monogram,
    required this.domains,
    this.newsletterCounts = const {},
    this.securityCounts = const {},
    this.unsubscribeByAccount = const {},
    this.unsubscribeUrlsByAccount = const {},
    this.unsubscribeRequiresPostByAccount = const {},
  });

  final String id;
  final String name;
  final ServiceCategory categoryId;
  final Map<String, int> mailCounts;
  final Color color;
  final String monogram;
  final List<String> domains;
  final Map<String, int> newsletterCounts;
  final Map<String, int> securityCounts;
  final Map<String, bool> unsubscribeByAccount;
  final Map<String, String> unsubscribeUrlsByAccount;
  final Map<String, bool> unsubscribeRequiresPostByAccount;

  String get category => categoryId.germanLabel;
  List<String> get accounts => mailCounts.keys.toList();

  int get totalMailCount =>
      mailCounts.values.fold(0, (total, count) => total + count);

  bool get isDuplicateRegistration => accounts.length > 1;

  int newsletterCountFor(String selectedAccount) =>
      _countFor(newsletterCounts, selectedAccount);

  int securityCountFor(String selectedAccount) =>
      _countFor(securityCounts, selectedAccount);

  bool hasUnsubscribeLinkFor(String selectedAccount) {
    if (selectedAccount == 'Alle E-Mail-Konten') {
      return unsubscribeByAccount.values.any((found) => found);
    }
    return unsubscribeByAccount[selectedAccount] ?? false;
  }

  String? unsubscribeUrlFor(String selectedAccount) {
    if (selectedAccount == 'Alle E-Mail-Konten') {
      return unsubscribeUrlsByAccount.values.firstOrNull;
    }
    return unsubscribeUrlsByAccount[selectedAccount];
  }

  bool unsubscribeRequiresPostFor(String selectedAccount) {
    if (selectedAccount == 'Alle E-Mail-Konten') {
      return unsubscribeRequiresPostByAccount.values.any((value) => value);
    }
    return unsubscribeRequiresPostByAccount[selectedAccount] ?? false;
  }

  int mailCountFor(String selectedAccount) {
    if (selectedAccount == 'Alle E-Mail-Konten') return totalMailCount;
    return mailCounts[selectedAccount] ?? 0;
  }

  int _countFor(Map<String, int> counts, String selectedAccount) {
    if (selectedAccount == 'Alle E-Mail-Konten') {
      return counts.values.fold(0, (total, count) => total + count);
    }
    return counts[selectedAccount] ?? 0;
  }

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'categoryId': categoryId.id,
    'mailCounts': mailCounts,
    'color': color.toARGB32(),
    'monogram': monogram,
    'domains': domains,
    'newsletterCounts': newsletterCounts,
    'securityCounts': securityCounts,
    'unsubscribeByAccount': unsubscribeByAccount,
    'unsubscribeUrlsByAccount': unsubscribeUrlsByAccount,
    'unsubscribeRequiresPostByAccount': unsubscribeRequiresPostByAccount,
  };

  factory ServiceItem.fromJson(Map<String, dynamic> json) => ServiceItem(
    id: json['id'] as String,
    name: json['name'] as String,
    categoryId: serviceCategoryFromId(json['categoryId'] as String),
    mailCounts: _intMap(json['mailCounts']),
    color: Color(json['color'] as int),
    monogram: json['monogram'] as String,
    domains: List<String>.from(json['domains'] as List),
    newsletterCounts: _intMap(json['newsletterCounts']),
    securityCounts: _intMap(json['securityCounts']),
    unsubscribeByAccount: _boolMap(json['unsubscribeByAccount']),
    unsubscribeUrlsByAccount: _stringMap(json['unsubscribeUrlsByAccount']),
    unsubscribeRequiresPostByAccount:
        json.containsKey('unsubscribeRequiresPostByAccount')
        ? _boolMap(json['unsubscribeRequiresPostByAccount'])
        : {
            for (final account in _stringMap(
              json['unsubscribeUrlsByAccount'],
            ).keys)
              account: true,
          },
  );

  static Map<String, int> _intMap(Object? value) =>
      (value as Map<String, dynamic>).map(
        (key, item) => MapEntry(key, item as int),
      );

  static Map<String, bool> _boolMap(Object? value) =>
      (value as Map<String, dynamic>? ?? const {}).map(
        (key, item) => MapEntry(key, item as bool),
      );

  static Map<String, String> _stringMap(Object? value) =>
      (value as Map<String, dynamic>? ?? const {}).map(
        (key, item) => MapEntry(key, item as String),
      );
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
