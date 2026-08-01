import 'service_item.dart';

class ScanDataset {
  const ScanDataset({required this.services, required this.sourceFiles});

  final List<ServiceItem> services;
  final List<String> sourceFiles;

  List<String> get accounts {
    final result =
        services.expand((service) => service.accounts).toSet().toList()..sort();
    return result;
  }

  List<ServiceItem> servicesFor(String account) {
    if (account == 'Alle E-Mail-Konten') return services;
    return services
        .where((service) => service.accounts.contains(account))
        .toList();
  }

  ScanDataset mergedWith(ScanDataset other) {
    final merged = <String, ServiceItem>{
      for (final service in services) service.id: service,
    };

    for (final incoming in other.services) {
      final existing = merged[incoming.id];
      if (existing == null) {
        merged[incoming.id] = incoming;
        continue;
      }

      merged[incoming.id] = ServiceItem(
        id: existing.id,
        name: existing.name,
        categoryId: existing.categoryId,
        mailCounts: {...existing.mailCounts, ...incoming.mailCounts},
        color: existing.color,
        monogram: existing.monogram,
        domains: {...existing.domains, ...incoming.domains}.toList(),
        newsletterCounts: {
          ...existing.newsletterCounts,
          ...incoming.newsletterCounts,
        },
        securityCounts: {
          ...existing.securityCounts,
          ...incoming.securityCounts,
        },
        unsubscribeByAccount: {
          ...existing.unsubscribeByAccount,
          ...incoming.unsubscribeByAccount,
        },
        unsubscribeUrlsByAccount: {
          ...existing.unsubscribeUrlsByAccount,
          ...incoming.unsubscribeUrlsByAccount,
        },
        unsubscribeRequiresPostByAccount: {
          ...existing.unsubscribeRequiresPostByAccount,
          ...incoming.unsubscribeRequiresPostByAccount,
        },
      );
    }

    final mergedServices = merged.values.toList()
      ..sort((a, b) => b.totalMailCount.compareTo(a.totalMailCount));

    return ScanDataset(
      services: mergedServices,
      sourceFiles: {...sourceFiles, ...other.sourceFiles}.toList(),
    );
  }

  ScanDataset replacingAccountsWith(ScanDataset other) {
    return withoutAccounts(other.accounts.toSet()).mergedWith(other);
  }

  ScanDataset withoutAccounts(Set<String> removedAccounts) {
    final retainedServices = <ServiceItem>[];

    for (final service in services) {
      final mailCounts = Map<String, int>.from(service.mailCounts)
        ..removeWhere((account, _) => removedAccounts.contains(account));
      if (mailCounts.isEmpty) continue;

      final newsletterCounts = Map<String, int>.from(service.newsletterCounts)
        ..removeWhere((account, _) => removedAccounts.contains(account));
      final securityCounts = Map<String, int>.from(service.securityCounts)
        ..removeWhere((account, _) => removedAccounts.contains(account));
      final unsubscribeByAccount = Map<String, bool>.from(
        service.unsubscribeByAccount,
      )..removeWhere((account, _) => removedAccounts.contains(account));
      final unsubscribeUrlsByAccount = Map<String, String>.from(
        service.unsubscribeUrlsByAccount,
      )..removeWhere((account, _) => removedAccounts.contains(account));
      final unsubscribeRequiresPostByAccount = Map<String, bool>.from(
        service.unsubscribeRequiresPostByAccount,
      )..removeWhere((account, _) => removedAccounts.contains(account));

      retainedServices.add(
        ServiceItem(
          id: service.id,
          name: service.name,
          categoryId: service.categoryId,
          mailCounts: mailCounts,
          color: service.color,
          monogram: service.monogram,
          domains: service.domains,
          newsletterCounts: newsletterCounts,
          securityCounts: securityCounts,
          unsubscribeByAccount: unsubscribeByAccount,
          unsubscribeUrlsByAccount: unsubscribeUrlsByAccount,
          unsubscribeRequiresPostByAccount: unsubscribeRequiresPostByAccount,
        ),
      );
    }

    final retainedSources = sourceFiles
        .where((source) {
          final normalized = source.toLowerCase();
          return !removedAccounts.any(
            (account) => normalized.contains(account.toLowerCase()),
          );
        })
        .toList(growable: false);
    return ScanDataset(
      services: retainedServices,
      sourceFiles: retainedSources,
    );
  }

  Map<String, Object> toJson() => {
    'services': services.map((service) => service.toJson()).toList(),
    'sourceFiles': sourceFiles,
  };

  factory ScanDataset.fromJson(Map<String, dynamic> json) => ScanDataset(
    services: (json['services'] as List)
        .map(
          (service) =>
              ServiceItem.fromJson(Map<String, dynamic>.from(service as Map)),
        )
        .toList(),
    sourceFiles: List<String>.from(json['sourceFiles'] as List),
  );
}
