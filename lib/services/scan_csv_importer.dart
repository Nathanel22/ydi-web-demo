import 'package:csv/csv.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../models/scan_dataset.dart';
import '../models/service_category.dart';
import '../models/service_item.dart';
import '../data/service_catalog.dart';

class ScanCsvImporter {
  const ScanCsvImporter();

  Future<ScanDataset?> pickAndImport() async {
    const typeGroup = XTypeGroup(
      label: 'YDI scan results',
      extensions: ['csv'],
      mimeTypes: ['text/csv'],
      uniformTypeIdentifiers: ['public.comma-separated-values-text'],
      webWildCards: ['text/csv'],
    );

    final files = await openFiles(acceptedTypeGroups: [typeGroup]);
    if (files.isEmpty) return null;

    final contents = <String, String>{};
    for (final file in files) {
      contents[file.name] = await file.readAsString();
    }
    return parseContents(contents);
  }

  ScanDataset parseContents(Map<String, String> files) {
    final merged = <String, _MutableService>{};

    for (final entry in files.entries) {
      final account = _accountFromFilename(entry.key);
      final rows = Csv(fieldDelimiter: ';').decode(entry.value);

      if (rows.isEmpty) continue;
      final headers = rows.first
          .map((value) => value.toString().replaceFirst('\ufeff', '').trim())
          .toList();
      final indexes = <String, int>{
        for (var index = 0; index < headers.length; index++)
          headers[index]: index,
      };
      _validateHeaders(indexes, entry.key);

      for (final row in rows.skip(1)) {
        final name = _value(row, indexes, 'Dienst');
        if (name.isEmpty) continue;

        final domain = _value(row, indexes, 'Domain').toLowerCase();
        final catalog = ServiceCatalog.findByDomain(domain);
        final resolvedName = catalog?.name ?? name;
        final key = catalog?.id ?? _serviceKey(name, domain);
        final service = merged.putIfAbsent(
          key,
          () => _MutableService(
            id: catalog?.id ?? _idFor(name),
            name: resolvedName,
            category:
                catalog?.category ??
                _categoryFrom(_value(row, indexes, 'Kategorie')),
            color: _colorFor(resolvedName),
            monogram: _monogramFor(resolvedName),
          ),
        );

        if (domain.isNotEmpty && !service.domains.contains(domain)) {
          service.domains.add(domain);
        }
        service.mailCounts[account] = _number(row, indexes, 'Mails gesamt');
        service.newsletterCounts[account] = _number(row, indexes, 'Newsletter');
        service.securityCounts[account] = _number(row, indexes, 'Sicherheit');
        service.unsubscribeByAccount[account] =
            _value(row, indexes, 'Abmeldelink gefunden').toLowerCase() == 'ja';
      }
    }

    final services = merged.values.map((service) => service.build()).toList()
      ..sort((a, b) => b.totalMailCount.compareTo(a.totalMailCount));

    if (services.isEmpty) {
      throw const FormatException('Keine gültigen YDI-Scandaten gefunden.');
    }

    return ScanDataset(
      services: services,
      sourceFiles: files.keys.toList(growable: false),
    );
  }

  void _validateHeaders(Map<String, int> indexes, String filename) {
    const required = [
      'Dienst',
      'Domain',
      'Kategorie',
      'Mails gesamt',
      'Newsletter',
      'Sicherheit',
      'Abmeldelink gefunden',
    ];
    final missing = required.where((header) => !indexes.containsKey(header));
    if (missing.isNotEmpty) {
      throw FormatException(
        '$filename ist keine gültige YDI-Scandatei. Fehlend: ${missing.join(', ')}',
      );
    }
  }

  String _value(List<dynamic> row, Map<String, int> indexes, String header) {
    final index = indexes[header];
    if (index == null || index >= row.length) return '';
    return row[index].toString().trim();
  }

  int _number(List<dynamic> row, Map<String, int> indexes, String header) =>
      int.tryParse(_value(row, indexes, header)) ?? 0;

  String _accountFromFilename(String filename) {
    final lower = filename.toLowerCase();
    if (lower.contains('gmail')) return 'Gmail';
    if (lower.contains('gmx')) return 'GMX';
    throw FormatException(
      'Der Dateiname muss GMX oder Gmail enthalten: $filename',
    );
  }

  String _serviceKey(String name, String domain) {
    if (domain.isNotEmpty) return domain;
    return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _idFor(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

  String _monogramFor(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length > 1) {
      return '${words.first[0]}${words.last[0]}'.toUpperCase();
    }
    final end = name.length < 2 ? name.length : 2;
    return name.substring(0, end).toUpperCase();
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

  ServiceCategory _categoryFrom(String value) => switch (value.toLowerCase()) {
    'streaming' => ServiceCategory.streaming,
    'immobilien' => ServiceCategory.realEstate,
    'karriere' => ServiceCategory.career,
    'technologie' => ServiceCategory.technology,
    'gaming' ||
    'gaming / shopping' ||
    'gaming / streaming' => ServiceCategory.gaming,
    'shopping' || 'shopping / food' => ServiceCategory.shopping,
    'essen & lieferung' || 'essen bestellen' => ServiceCategory.foodDelivery,
    'news & medien' || 'zeitung' || 'news' => ServiceCategory.news,
    'social media' => ServiceCategory.socialMedia,
    'finanzen' => ServiceCategory.finance,
    'versicherung' || 'versicherungen' => ServiceCategory.insurance,
    'reisen' => ServiceCategory.travel,
    'fahrzeuge' => ServiceCategory.vehicles,
    'vergleich' => ServiceCategory.comparison,
    'e-mail' => ServiceCategory.email,
    'versand' => ServiceCategory.shipping,
    'sportwetten' => ServiceCategory.betting,
    'tickets' => ServiceCategory.tickets,
    'cloud' => ServiceCategory.cloud,
    'smart home' => ServiceCategory.smartHome,
    'newsletter-system' => ServiceCategory.newsletterSystem,
    'gesundheit' => ServiceCategory.health,
    'telekommunikation' => ServiceCategory.telecommunications,
    'marktplatz' => ServiceCategory.marketplace,
    'produktivität' => ServiceCategory.productivity,
    'bürobedarf' => ServiceCategory.officeSupplies,
    'umfragen' => ServiceCategory.surveys,
    'unbekannt' => ServiceCategory.unknown,
    _ => ServiceCategory.other,
  };
}

class _MutableService {
  _MutableService({
    required this.id,
    required this.name,
    required this.category,
    required this.color,
    required this.monogram,
  });

  final String id;
  final String name;
  final ServiceCategory category;
  final Color color;
  final String monogram;
  final List<String> domains = [];
  final Map<String, int> mailCounts = {};
  final Map<String, int> newsletterCounts = {};
  final Map<String, int> securityCounts = {};
  final Map<String, bool> unsubscribeByAccount = {};

  ServiceItem build() => ServiceItem(
    id: id,
    name: name,
    categoryId: category,
    mailCounts: Map.unmodifiable(mailCounts),
    color: color,
    monogram: monogram,
    domains: List.unmodifiable(domains),
    newsletterCounts: Map.unmodifiable(newsletterCounts),
    securityCounts: Map.unmodifiable(securityCounts),
    unsubscribeByAccount: Map.unmodifiable(unsubscribeByAccount),
  );
}
