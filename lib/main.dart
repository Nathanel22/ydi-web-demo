import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config/public_demo.dart';
import 'data/app_entitlements.dart';
import 'data/account_scan_store.dart';
import 'data/gmx_account_store.dart';
import 'data/scan_data_store.dart';
import 'localization/app_language.dart';
import 'models/gmx_account.dart';
import 'models/service_category.dart';
import 'models/service_item.dart';
import 'services/scan_refresh_service.dart';
import 'services/google_auth_service.dart';
import 'services/google_sign_in_button.dart';
import 'services/gmail_metadata_scanner.dart';
import 'services/gmx_credential_manager.dart';
import 'services/gmx_imap_scanner.dart';

String _providerLabel(String account) {
  final normalized = account.toLowerCase();
  if (normalized.startsWith('gmail')) return 'Gmail';
  if (normalized.startsWith('gmx')) return 'GMX';
  if (normalized.startsWith('hotmail')) return 'Hotmail';
  if (normalized.startsWith('outlook')) return 'Outlook';
  if (normalized.startsWith('web.de')) return 'WEB.DE';
  if (normalized.startsWith('yahoo')) return 'Yahoo';
  return account.split(' ·').first;
}

String _providerLabels(Iterable<String> accounts) =>
    accounts.map(_providerLabel).toSet().join(' + ');

String _accountPickerLabel(String account) {
  if (!account.toLowerCase().startsWith('gmail')) return account;
  for (final separator in const [' · ', ' Â· ']) {
    final index = account.indexOf(separator);
    if (index >= 0) return account.substring(index + separator.length);
  }
  return 'Gmail';
}

String? _emailAddressFromAccount(String account) {
  final match = RegExp(
    r'[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}',
    caseSensitive: false,
  ).firstMatch(account);
  return match?.group(0);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (isPublicDemo) {
    scanDataNotifier.value = publicDemoDataset;
  } else {
    await scanDataStore.load();
    await accountScanStore.load();
    await gmxAccountStore.load();
    await gmxCredentialManager.discardExpiredCredentials();
    await googleAuthService.initialize();
  }
  runApp(const YdiApp());
}

class YdiApp extends StatelessWidget {
  const YdiApp({super.key});

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF17233B);
    const blue = Color(0xFF526DFF);

    return ValueListenableBuilder<AppLanguage>(
      valueListenable: languageNotifier,
      builder: (context, language, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'YDI – Your Digital Identity',
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF5F7FB),
            colorScheme: ColorScheme.fromSeed(
              seedColor: blue,
              primary: blue,
              surface: Colors.white,
            ),
            textTheme: ThemeData.light().textTheme.apply(
              bodyColor: navy,
              displayColor: navy,
              fontFamily: 'Segoe UI',
            ),
          ),
          home: DashboardPage(key: ValueKey(language)),
        );
      },
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String selectedAccount = 'Alle E-Mail-Konten';

  List<ServiceItem> get allServices =>
      scanDataNotifier.value?.services ?? const <ServiceItem>[];

  List<DashboardMetric> get metrics {
    final text = AppText(languageNotifier.value);
    final values = [
      '${filteredServices.length}',
      '${filteredServices.where((service) => service.newsletterCountFor(selectedAccount) > 0).length}',
      '${filteredServices.where((service) => service.hasUnsubscribeLinkFor(selectedAccount)).length}',
    ];

    return [
      DashboardMetric(
        values[0],
        text.digitalServices,
        Icons.grid_view_rounded,
        const Color(0xFF526DFF),
      ),
      DashboardMetric(
        values[1],
        text.newsletters,
        Icons.mark_email_unread_rounded,
        const Color(0xFF9B62E8),
      ),
      DashboardMetric(
        values[2],
        text.unsubscribeLinks,
        Icons.unsubscribe_rounded,
        const Color(0xFF29A583),
      ),
    ];
  }

  List<ServiceItem> get filteredServices {
    if (selectedAccount == 'Alle E-Mail-Konten') {
      return allServices;
    }
    return allServices
        .where((service) => service.accounts.contains(selectedAccount))
        .toList();
  }

  List<ServiceItem> get duplicateServices =>
      allServices.where((service) => service.isDuplicateRegistration).toList();

  Map<String, int> get accountServiceCounts {
    final importedAccounts = scanDataNotifier.value?.accounts;
    final accounts = importedAccounts ?? const <String>[];
    return {
      for (final account in accounts)
        account: allServices
            .where((service) => service.accounts.contains(account))
            .length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<GmxAccount>>(
      valueListenable: gmxAccountsNotifier,
      builder: (context, accounts, _) => ValueListenableBuilder(
        valueListenable: scanDataNotifier,
        builder: (context, importedData, _) => _buildDashboard(context),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                  sliver: SliverList.list(
                    children: [
                      _Header(
                        onRefresh: isPublicDemo
                            ? null
                            : () => _refreshScan(context),
                      ),
                      if (allServices.isEmpty) ...[
                        const SizedBox(height: 64),
                        if (!isPublicDemo &&
                            gmxAccountsNotifier.value.isNotEmpty)
                          _ConnectedEmptyDashboard(
                            accounts: gmxAccountsNotifier.value,
                            onSync: () => _refreshScan(context),
                          )
                        else
                          _EmptyDashboard(
                            onConnect: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const EmailAccountsPage(),
                              ),
                            ),
                          ),
                      ] else ...[
                        const SizedBox(height: 28),
                        _AccountSelector(
                          selectedAccount: selectedAccount,
                          accountServiceCounts: accountServiceCounts,
                          onChanged: (account) {
                            setState(() => selectedAccount = account);
                          },
                        ),
                        const SizedBox(height: 22),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth > 760 ? 3 : 2;
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: metrics.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    crossAxisSpacing: 14,
                                    mainAxisSpacing: 14,
                                    childAspectRatio: columns == 4
                                        ? 1.12
                                        : 1.18,
                                  ),
                              itemBuilder: (_, index) => _MetricCard(
                                metric: metrics[index],
                                onTap: () => _openMetric(context, index),
                              ),
                            );
                          },
                        ),
                        if (selectedAccount == 'Alle E-Mail-Konten') ...[
                          const SizedBox(height: 14),
                          _DuplicateRegistrationsCard(
                            count: duplicateServices.length,
                            onTap: () => _openDuplicateRegistrations(context),
                          ),
                        ],
                        const SizedBox(height: 30),
                        _SectionTitle(onShowAll: () => _openServices(context)),
                        const SizedBox(height: 12),
                        ...filteredServices
                            .take(5)
                            .map(
                              (service) => _ServiceRow(
                                service: service,
                                selectedAccount: selectedAccount,
                              ),
                            ),
                        const SizedBox(height: 28),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _BottomNavigation(
        onServicesSelected: () => _openServices(context),
        onNewsletterSelected: () => _openNewsletter(context),
        onSettingsSelected: () => _openSettings(context),
      ),
    );
  }

  void _openServices(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ServicesPage(
          services: filteredServices,
          selectedAccount: selectedAccount,
        ),
      ),
    );
  }

  void _openDuplicateRegistrations(BuildContext context) {
    final text = AppText(languageNotifier.value);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ServicesPage(
          services: duplicateServices,
          selectedAccount: 'Alle E-Mail-Konten',
          pageTitle: text.duplicateRegistrations,
          description: text.duplicateServicesFound(duplicateServices.length),
          showAccountCount: true,
        ),
      ),
    );
  }

  void _openMetric(BuildContext context, int index) {
    switch (index) {
      case 0:
        _openServices(context);
      case 1:
        _openNewsletter(context);
      case 99:
        if (scanDataNotifier.value != null) {
          final services = filteredServices
              .where((service) => service.securityCountFor(selectedAccount) > 0)
              .toList();
          _openFeature(
            context,
            title: AppText(languageNotifier.value).securityActivities,
            subtitle: '${services.length} Dienste mit Sicherheitshinweisen',
            icon: Icons.shield_rounded,
            color: const Color(0xFFEF7E5B),
            items: services
                .map(
                  (service) => FeatureItem(
                    service.name,
                    '${service.securityCountFor(selectedAccount)} Sicherheitshinweise · ${_providerLabels(service.accounts)}',
                    service.monogram,
                  ),
                )
                .toList(),
          );
          return;
        }
        _openFeature(
          context,
          title: 'Sicherheitsaktivitäten',
          subtitle: '18 Dienste mit erkannten Sicherheitshinweisen',
          icon: Icons.shield_rounded,
          color: const Color(0xFFEF7E5B),
          items: const [
            FeatureItem('Google', '7 Sicherheitshinweise', 'G'),
            FeatureItem('Microsoft', '6 Sicherheitshinweise', 'M'),
            FeatureItem('Klarna', '3 Sicherheitshinweise', 'K'),
            FeatureItem('Ubisoft', '2 Sicherheitshinweise', 'U'),
          ],
        );
      case 2:
        if (scanDataNotifier.value != null) {
          final services = filteredServices
              .where(
                (service) => service.hasUnsubscribeLinkFor(selectedAccount),
              )
              .toList();
          _openFeature(
            context,
            title: AppText(languageNotifier.value).unsubscribeLinks,
            subtitle: '${services.length} Dienste mit Abmeldemöglichkeit',
            icon: Icons.unsubscribe_rounded,
            color: const Color(0xFF29A583),
            items: services
                .map(
                  (service) => FeatureItem(
                    service.name,
                    'Abmeldelink gefunden · ${_providerLabels(service.accounts)}',
                    service.monogram,
                  ),
                )
                .toList(),
          );
          return;
        }
        _openFeature(
          context,
          title: 'Abmeldelinks',
          subtitle: '33 Dienste bieten eine Abmeldemöglichkeit',
          icon: Icons.unsubscribe_rounded,
          color: const Color(0xFF29A583),
          items: const [
            FeatureItem('Netflix', 'Abmeldelink gefunden', 'N'),
            FeatureItem('ImmoScout24', 'Abmeldelink gefunden', 'I'),
            FeatureItem('Kununu', 'Abmeldelink gefunden', 'K'),
            FeatureItem('Joyn', 'Abmeldelink gefunden', 'J'),
          ],
        );
    }
  }

  void _openNewsletter(BuildContext context) {
    if (allServices.isEmpty) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const EmailAccountsPage()));
      return;
    }
    if (scanDataNotifier.value != null) {
      final services = filteredServices
          .where((service) => service.newsletterCountFor(selectedAccount) > 0)
          .toList();
      _openFeature(
        context,
        title: AppText(languageNotifier.value).newsletters,
        subtitle: '${services.length} Newsletter-Dienste erkannt',
        icon: Icons.mark_email_unread_rounded,
        color: const Color(0xFF9B62E8),
        items: services
            .map(
              (service) => FeatureItem(
                service.name,
                '${service.newsletterCountFor(selectedAccount)} Newsletter · ${_providerLabels(service.accounts)}',
                service.monogram,
                service: service,
              ),
            )
            .toList(),
      );
      return;
    }
    _openFeature(
      context,
      title: 'Newsletter',
      subtitle: '41 Newsletter-Dienste erkannt',
      icon: Icons.mark_email_unread_rounded,
      color: const Color(0xFF9B62E8),
      items: const [
        FeatureItem('Netflix', '68 Newsletter · GMX', 'N'),
        FeatureItem('ImmoScout24', '37 Newsletter · GMX', 'I'),
        FeatureItem('Kununu', '31 Newsletter · GMX', 'K'),
        FeatureItem('LinkedIn', '166 Newsletter · Gmail', 'L'),
      ],
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
  }

  Future<void> _refreshScan(BuildContext context) async {
    final accounts = {
      ...?scanDataNotifier.value?.accounts,
      ...gmxAccountsNotifier.value.map((account) => account.scanAccountLabel),
    }.toList();
    if (accounts.isEmpty) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const EmailAccountsPage()));
      return;
    }

    final account = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          children: [
            const Text(
              'Welches Konto aktualisieren?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'YDI ersetzt nur die bisherigen Ergebnisse dieses Kontos.',
              style: TextStyle(color: Color(0xFF657086)),
            ),
            const SizedBox(height: 12),
            for (final item in accounts)
              Card(
                color: Colors.white,
                child: ListTile(
                  leading: const Icon(Icons.mail_outline_rounded),
                  title: Text(_providerLabel(item)),
                  subtitle: Text(_emailAddressFromAccount(item) ?? item),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pop(context, item),
                ),
              ),
          ],
        ),
      ),
    );
    if (account == null || !context.mounted) return;

    final provider = _providerLabel(account);
    if (provider == 'GMX') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              GmxSetupPage(initialEmail: _emailAddressFromAccount(account)),
        ),
      );
    } else if (provider == 'Gmail') {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const GoogleAccountsPage()));
    }
  }

  void _openFeature(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<FeatureItem> items,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FeaturePage(
          title: title,
          subtitle: subtitle,
          icon: icon,
          color: color,
          items: items,
        ),
      ),
    );
  }
}

class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard({required this.onConnect});

  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: Color(0xFFE9EDFF),
                foregroundColor: Color(0xFF526DFF),
                child: Icon(Icons.alternate_email_rounded, size: 32),
              ),
              const SizedBox(height: 20),
              const Text(
                'Noch keine E-Mail-Konten verbunden',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              const Text(
                'Verbinde dein erstes E-Mail-Konto. Erst danach zeigt YDI '
                'erkannte Dienste, Newsletter und weitere Ergebnisse an.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF788399), height: 1.45),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: onConnect,
                icon: const Icon(Icons.add_rounded),
                label: const Text('E-Mail-Konto verbinden'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectedEmptyDashboard extends StatelessWidget {
  const _ConnectedEmptyDashboard({
    required this.accounts,
    required this.onSync,
  });

  final List<GmxAccount> accounts;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final title = accounts.length == 1
        ? 'GMX verbunden'
        : '${accounts.length} GMX-Konten verbunden';
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: Color(0xFFE2F4EF),
                foregroundColor: Color(0xFF16866C),
                child: Icon(Icons.mark_email_read_outlined, size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Für dieses Konto liegen aktuell keine Analyseergebnisse vor. '
                'Synchronisiere dein Konto, um die Übersicht zu aktualisieren.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF788399), height: 1.45),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: onSync,
                icon: const Icon(Icons.sync_rounded),
                label: const Text('Jetzt synchronisieren'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onRefresh});

  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final text = AppText(languageNotifier.value);
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF526DFF), Color(0xFF8B63E6)],
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          alignment: Alignment.center,
          child: const Text(
            'Y',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Digital Identity',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                text.digitalOverview,
                style: const TextStyle(color: Color(0xFF788399), fontSize: 14),
              ),
            ],
          ),
        ),
        if (onRefresh != null)
          IconButton(
            tooltip: text.refreshScan,
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        const SizedBox(width: 4),
        IconButton.filledTonal(
          onPressed: () {},
          icon: const Icon(Icons.person_outline_rounded),
        ),
      ],
    );
  }
}

class _AccountSelector extends StatefulWidget {
  const _AccountSelector({
    required this.selectedAccount,
    required this.accountServiceCounts,
    required this.onChanged,
  });

  final String selectedAccount;
  final Map<String, int> accountServiceCounts;
  final ValueChanged<String> onChanged;

  @override
  State<_AccountSelector> createState() => _AccountSelectorState();
}

class _AccountSelectorState extends State<_AccountSelector> {
  @override
  Widget build(BuildContext context) {
    final text = AppText(languageNotifier.value);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: _showAccountPicker,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              const Icon(
                Icons.alternate_email_rounded,
                color: Color(0xFF526DFF),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text.accountLabel(widget.selectedAccount),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                widget.selectedAccount == 'Alle E-Mail-Konten'
                    ? _providerLabels(widget.accountServiceCounts.keys)
                    : _providerLabel(widget.selectedAccount),
                style: const TextStyle(color: Color(0xFF788399), fontSize: 13),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.keyboard_arrow_down_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAccountPicker() async {
    final text = AppText(languageNotifier.value);
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF5F7FB),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 12),
                child: Text(
                  text.chooseEmailAccount,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _AccountOption(
                title: 'Alle E-Mail-Konten',
                displayTitle: text.allEmailAccounts,
                subtitle:
                    '${_providerLabels(widget.accountServiceCounts.keys).replaceAll(' + ', ' und ')} zusammen',
                icon: Icons.all_inbox_rounded,
                selected: widget.selectedAccount == 'Alle E-Mail-Konten',
              ),
              ...widget.accountServiceCounts.entries.map(
                (entry) => _AccountOption(
                  title: entry.key,
                  displayTitle: _accountPickerLabel(entry.key),
                  subtitle: '${entry.value} erkannte Dienste',
                  icon: entry.key == 'Gmail'
                      ? Icons.mail_outline_rounded
                      : Icons.email_outlined,
                  selected: widget.selectedAccount == entry.key,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null && mounted) widget.onChanged(result);
  }
}

class _AccountOption extends StatelessWidget {
  const _AccountOption({
    required this.title,
    this.displayTitle,
    required this.subtitle,
    required this.icon,
    required this.selected,
  });

  final String title;
  final String? displayTitle;
  final String subtitle;
  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          onTap: () => Navigator.pop(context, title),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: Icon(icon, color: const Color(0xFF526DFF)),
          title: Text(
            displayTitle ?? title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(subtitle),
          trailing: Icon(
            selected ? Icons.check_circle_rounded : Icons.circle_outlined,
            color: selected ? const Color(0xFF526DFF) : const Color(0xFFB4BBCA),
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric, this.onTap});
  final DashboardMetric metric;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: metric.color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(metric.icon, color: metric.color, size: 21),
              ),
              const Spacer(),
              Text(
                metric.value,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                metric.label,
                maxLines: 2,
                style: const TextStyle(
                  color: Color(0xFF657086),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DuplicateRegistrationsCard extends StatelessWidget {
  const _DuplicateRegistrationsCard({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppText(languageNotifier.value);
    const color = Color(0xFFDA7A25);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.copy_all_rounded, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text.duplicateRegistrations,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      text.detectedAcrossAccounts,
                      style: const TextStyle(
                        color: Color(0xFF788399),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$count',
                style: const TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF9AA3B4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.onShowAll});
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final text = AppText(languageNotifier.value);
    return Row(
      children: [
        Expanded(
          child: Text(
            text.mostFrequentServices,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
        ),
        TextButton(onPressed: onShowAll, child: Text(text.showAll)),
      ],
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.service,
    this.selectedAccount = 'Alle E-Mail-Konten',
    this.showAccountCount = false,
  });
  final ServiceItem service;
  final String selectedAccount;
  final bool showAccountCount;

  @override
  Widget build(BuildContext context) {
    final text = AppText(languageNotifier.value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: ListTile(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ServiceDetailPage(service: service),
              ),
            );
          },
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 7,
          ),
          leading: Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: service.color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              service.monogram,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          title: Text(
            service.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            text.categoryLabel(service.categoryId.id),
            style: const TextStyle(color: Color(0xFF788399)),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selectedAccount == 'Alle E-Mail-Konten') ...[
                Text(
                  showAccountCount
                      ? '${service.accounts.length} Konten'
                      : _providerLabels(service.accounts),
                  style: const TextStyle(
                    color: Color(0xFF657086),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                text.mails(service.mailCountFor(selectedAccount)),
                style: const TextStyle(color: Color(0xFF657086), fontSize: 13),
              ),
              const SizedBox(width: 5),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF9AA3B4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({
    required this.onServicesSelected,
    required this.onNewsletterSelected,
    required this.onSettingsSelected,
  });
  final VoidCallback onServicesSelected;
  final VoidCallback onNewsletterSelected;
  final VoidCallback onSettingsSelected;

  @override
  Widget build(BuildContext context) {
    final text = AppText(languageNotifier.value);
    return NavigationBar(
      selectedIndex: 0,
      onDestinationSelected: (index) {
        if (index == 1) onServicesSelected();
        if (index == 2) onNewsletterSelected();
        if (index == 3) onSettingsSelected();
      },
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(Icons.home_rounded),
          label: text.overview,
        ),
        NavigationDestination(
          icon: const Icon(Icons.grid_view_outlined),
          selectedIcon: const Icon(Icons.grid_view_rounded),
          label: text.services,
        ),
        NavigationDestination(
          icon: const Icon(Icons.mark_email_unread_outlined),
          selectedIcon: const Icon(Icons.mark_email_unread_rounded),
          label: text.newsletters,
        ),
        NavigationDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings_rounded),
          label: text.settings,
        ),
      ],
    );
  }
}

enum _ServiceSort { alphabetical, category }

class ServicesPage extends StatefulWidget {
  const ServicesPage({
    super.key,
    required this.services,
    required this.selectedAccount,
    this.pageTitle,
    this.description,
    this.showAccountCount = false,
  });

  final List<ServiceItem> services;
  final String selectedAccount;
  final String? pageTitle;
  final String? description;
  final bool showAccountCount;

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  String _selectedCategoryId = 'all';
  _ServiceSort _sort = _ServiceSort.alphabetical;

  @override
  Widget build(BuildContext context) {
    final text = AppText(languageNotifier.value);
    final availableCategories =
        widget.services.map((service) => service.categoryId).toSet().toList()
          ..sort(
            (a, b) =>
                text.categoryLabel(a.id).compareTo(text.categoryLabel(b.id)),
          );
    final visibleServices =
        widget.services
            .where(
              (service) =>
                  _selectedCategoryId == 'all' ||
                  service.categoryId.id == _selectedCategoryId,
            )
            .toList()
          ..sort((a, b) {
            if (_sort == _ServiceSort.category) {
              final categoryComparison = text
                  .categoryLabel(a.categoryId.id)
                  .compareTo(text.categoryLabel(b.categoryId.id));
              if (categoryComparison != 0) return categoryComparison;
            }
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.pageTitle ?? text.digitalServices,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: const Color(0xFFF5F7FB),
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Text(
                widget.description ??
                    text.servicesFound(visibleServices.length),
                style: const TextStyle(
                  color: Color(0xFF788399),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: 230,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedCategoryId,
                      decoration: InputDecoration(
                        labelText: text.category,
                        prefixIcon: const Icon(Icons.category_outlined),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: [
                        DropdownMenuItem<String>(
                          value: 'all',
                          child: Text(text.allCategories),
                        ),
                        ...availableCategories.map(
                          (category) => DropdownMenuItem<String>(
                            value: category.id,
                            child: Text(text.categoryLabel(category.id)),
                          ),
                        ),
                      ],
                      onChanged: (categoryId) {
                        if (categoryId != null) {
                          setState(() => _selectedCategoryId = categoryId);
                        }
                      },
                    ),
                  ),
                  SizedBox(
                    width: 230,
                    child: DropdownButtonFormField<_ServiceSort>(
                      isExpanded: true,
                      initialValue: _sort,
                      decoration: InputDecoration(
                        labelText: text.sortBy,
                        prefixIcon: const Icon(Icons.sort_rounded),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: _ServiceSort.alphabetical,
                          child: Text(text.alphabetical),
                        ),
                        DropdownMenuItem(
                          value: _ServiceSort.category,
                          child: Text(text.byCategory),
                        ),
                      ],
                      onChanged: (sort) {
                        if (sort != null) setState(() => _sort = sort);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                text.servicesFound(visibleServices.length),
                style: const TextStyle(color: Color(0xFF788399)),
              ),
              const SizedBox(height: 14),
              ...visibleServices.map(
                (service) => _ServiceRow(
                  service: service,
                  selectedAccount: widget.selectedAccount,
                  showAccountCount: widget.showAccountCount,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final text = AppText(languageNotifier.value);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          text.settings,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: const Color(0xFFF5F7FB),
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
            children: [
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                child: ListTile(
                  onTap: () => _openLanguagePicker(context),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  leading: const Icon(
                    Icons.language_rounded,
                    color: Color(0xFF526DFF),
                  ),
                  title: Text(
                    text.languageSetting,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(languageNotifier.value.label),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ),
              const SizedBox(height: 10),
              _SettingsTile(
                icon: Icons.upload_file_rounded,
                title: text.importScanResults,
                subtitle: text.importScanDescription,
                onTap: () => _importScanResults(context),
              ),
              const SizedBox(height: 10),
              ValueListenableBuilder(
                valueListenable: scanDataNotifier,
                builder: (context, dataset, _) => _SettingsTile(
                  icon: Icons.delete_outline_rounded,
                  title: text.deleteLocalScanData,
                  subtitle: dataset == null
                      ? text.noLocalScanData
                      : text.localScanDataSummary(
                          dataset.accounts.length,
                          dataset.services.length,
                        ),
                  onTap: dataset == null
                      ? null
                      : () => _clearLocalScanData(context),
                ),
              ),
              const SizedBox(height: 10),
              _SettingsTile(
                icon: Icons.alternate_email_rounded,
                title: text.emailAccounts,
                subtitle: 'Konten hinzufügen, aktualisieren oder entfernen',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EmailAccountsPage()),
                ),
              ),
              const SizedBox(height: 10),
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: text.privacy,
                subtitle: text.localAnalysis,
              ),
              const SizedBox(height: 10),
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                title: text.aboutYdi,
                subtitle: isPublicDemo ? 'Web Prototype 0.2' : 'Prototyp 0.1',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _importScanResults(BuildContext context) async {
    if (isPublicDemo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dateiimport ist in der Web-Demo deaktiviert.'),
        ),
      );
      return;
    }
    try {
      final dataset = await scanRefreshService.pickRefreshAndSave();
      if (dataset == null || !context.mounted) return;

      final text = AppText(languageNotifier.value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            text.importSuccessful(
              dataset.accounts.length,
              dataset.services.length,
            ),
          ),
        ),
      );
    } on FormatException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message.toString())));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Die Scandateien konnten nicht gelesen werden.'),
        ),
      );
    }
  }

  Future<void> _clearLocalScanData(BuildContext context) async {
    if (isPublicDemo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Die Web-Demo verwendet feste Beispieldaten.'),
        ),
      );
      return;
    }
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alle lokalen Scandaten löschen?'),
        content: const Text(
          'Alle gespeicherten Scanergebnisse und Kontozuordnungen werden nur '
          'von diesem Gerät entfernt. Deine E-Mail-Postfächer werden nicht '
          'verändert. Einzelne Konten kannst du unter „E-Mail-Konten“ entfernen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Alle lokalen Daten löschen'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;
    await scanDataStore.clear();
  }

  Future<void> _openLanguagePicker(BuildContext context) async {
    final selected = await showModalBottomSheet<AppLanguage>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF5F7FB),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...AppLanguage.values.map(
                (language) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    child: ListTile(
                      onTap: () => Navigator.pop(context, language),
                      title: Text(
                        language.label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      trailing: Icon(
                        language == languageNotifier.value
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        color: language == languageNotifier.value
                            ? const Color(0xFF526DFF)
                            : const Color(0xFFB4BBCA),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected != null) {
      languageNotifier.value = selected;
      if (context.mounted) Navigator.pop(context);
    }
  }
}

class EmailAccountsPage extends StatelessWidget {
  const EmailAccountsPage({super.key});

  String _lastScanLabel(GmxAccount account) {
    final scannedAt = account.lastSuccessfulScanAt;
    if (scannedAt == null) return 'Scanzeit noch nicht erfasst';
    final local = scannedAt.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return 'Letzter Scan: ${two(local.day)}.${two(local.month)}.${local.year}, '
        '${two(local.hour)}:${two(local.minute)} Uhr';
  }

  Future<void> _removeAccount(BuildContext context, GmxAccount account) async {
    final email = account.email;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('GMX-Konto entfernen?'),
        content: Text(
          'Die Verbindung zu $email und alle dazu lokal gespeicherten '
          'Scanergebnisse werden von diesem Gerät gelöscht. Dein GMX-Postfach '
          'wird nicht verändert.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC4473A),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Konto und lokale Daten löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await scanDataStore.removeAccount(account.scanAccountLabel);
    await accountScanStore.remove(account.scanAccountLabel);
    await gmxCredentialManager.deleteAccount(account);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$email wurde von diesem Gerät entfernt.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isPublicDemo) return const _PublicDemoAccountsPage();
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'E-Mail-Konten',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: const Color(0xFFF5F7FB),
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ValueListenableBuilder<List<GmxAccount>>(
            valueListenable: gmxAccountsNotifier,
            builder: (context, gmxAccounts, _) => ValueListenableBuilder(
              valueListenable: scanDataNotifier,
              builder: (context, dataset, _) {
                final gmailAccounts =
                    dataset?.accounts
                        .where(
                          (account) =>
                              account.toLowerCase().startsWith('gmail'),
                        )
                        .length ??
                    0;
                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const Text(
                      'Anbieter verbinden',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'YDI analysiert nur die notwendigen Metadaten und speichert die Ergebnisse lokal.',
                      style: TextStyle(color: Color(0xFF788399)),
                    ),
                    const SizedBox(height: 22),
                    _EmailProviderCard(
                      icon: Icons.g_mobiledata_rounded,
                      color: const Color(0xFF526DFF),
                      title: 'Google / Gmail',
                      subtitle: gmailAccounts == 0
                          ? 'Noch kein Konto analysiert'
                          : '$gmailAccounts Konto${gmailAccounts == 1 ? '' : 'en'} verbunden',
                      status: gmailAccounts == 0 ? 'Einrichten' : 'Verwalten',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const GoogleAccountsPage(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _EmailProviderCard(
                      icon: Icons.mail_outline_rounded,
                      color: const Color(0xFF29A583),
                      title: 'GMX',
                      subtitle: gmxAccounts.isEmpty
                          ? 'Noch kein Konto verbunden'
                          : '${gmxAccounts.length} Konto${gmxAccounts.length == 1 ? '' : 'en'} lokal erfasst',
                      status: gmxAccounts.isEmpty ? 'Einrichten' : 'Hinzufügen',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const GmxSetupPage()),
                      ),
                    ),
                    if (gmxAccounts.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      const Text(
                        'Verbundene GMX-Konten',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final account in gmxAccounts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 8,
                              ),
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFE2F4EF),
                                foregroundColor: Color(0xFF16866C),
                                child: Icon(Icons.mail_outline_rounded),
                              ),
                              title: Text(
                                account.email,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(_lastScanLabel(account)),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      GmxSetupPage(initialEmail: account.email),
                                ),
                              ),
                              trailing: IconButton(
                                tooltip: 'Konto entfernen',
                                onPressed: () =>
                                    _removeAccount(context, account),
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PublicDemoAccountsPage extends StatelessWidget {
  const _PublicDemoAccountsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'E-Mail-Konten · Demo',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: const Color(0xFFF5F7FB),
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0FF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text(
                  'Sicherer Demo-Modus: Die Verbindung wird nur gezeigt. '
                  'Es werden keine Zugangsdaten eingegeben oder übertragen.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 22),
              _EmailProviderCard(
                icon: Icons.g_mobiledata_rounded,
                color: const Color(0xFF526DFF),
                title: 'Google / Gmail',
                subtitle: 'OAuth-Verbindung in der späteren App',
                status: 'Demo',
                onTap: () => _showDemoNotice(context, 'Google / Gmail'),
              ),
              const SizedBox(height: 12),
              _EmailProviderCard(
                icon: Icons.mail_outline_rounded,
                color: const Color(0xFF29A583),
                title: 'GMX',
                subtitle: 'Geführte IMAP-Verbindung ansehen',
                status: 'Ansehen',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const _PublicDemoGmxPage()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _showDemoNotice(BuildContext context, String provider) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$provider verbinden'),
        content: const Text(
          'Die echte Anmeldung ist in dieser Web-Demo deaktiviert. '
          'Das Dashboard verwendet ausschließlich synthetische Beispieldaten.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Verstanden'),
          ),
        ],
      ),
    );
  }
}

class _PublicDemoGmxPage extends StatelessWidget {
  const _PublicDemoGmxPage();

  @override
  Widget build(BuildContext context) {
    const steps = [
      (
        '1',
        'IMAP bei GMX aktivieren',
        'In GMX den POP3/IMAP-Zugriff erlauben.',
      ),
      (
        '2',
        'Anwendungspasswort verwenden',
        'Ein separates Passwort für YDI erstellen.',
      ),
      (
        '3',
        'Lokal analysieren',
        'Nur benötigte Header und Metadaten auswerten.',
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('GMX verbinden · Demo'),
        backgroundColor: const Color(0xFFF5F7FB),
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(
                Icons.mail_outline_rounded,
                size: 58,
                color: Color(0xFF29A583),
              ),
              const SizedBox(height: 14),
              const Text(
                'So wird GMX später verbunden',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Diese Ansicht erklärt den Ablauf. Die öffentliche Demo '
                'akzeptiert bewusst keine echten Zugangsdaten.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF788399)),
              ),
              const SizedBox(height: 22),
              for (final step in steps)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(14),
                      leading: CircleAvatar(child: Text(step.$1)),
                      title: Text(
                        step.$2,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(step.$3),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: null,
                icon: const Icon(Icons.lock_outline_rounded),
                label: const Text('Echte Verbindung in der Demo deaktiviert'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmailProviderCard extends StatelessWidget {
  const _EmailProviderCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 12,
        ),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: .12),
          foregroundColor: color,
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(status, style: const TextStyle(color: Color(0xFF526DFF))),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class GmxSetupPage extends StatefulWidget {
  const GmxSetupPage({
    super.key,
    this.initialEmail,
    this.scanner,
    this.accountStore,
    this.credentialManager,
    this.realGmxTestAllowed = isRealGmxTestEnabled,
  });

  final String? initialEmail;
  final GmxImapScanner? scanner;
  final GmxAccountStore? accountStore;
  final GmxCredentialManager? credentialManager;
  final bool realGmxTestAllowed;

  @override
  State<GmxSetupPage> createState() => _GmxSetupPageState();
}

class _GmxSetupPageState extends State<GmxSetupPage>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  bool _hidePassword = true;
  bool _savePasswordFor30Days = false;
  bool _credentialAvailable = false;
  bool _checkingCredential = false;
  int _credentialCheckGeneration = 0;
  bool _busy = false;
  bool _cancelActiveScan = false;
  int _current = 0;
  int _total = 0;
  String? _message;
  bool _success = false;

  GmxAccountStore get _accountStore => widget.accountStore ?? gmxAccountStore;

  GmxCredentialManager get _credentialManager =>
      widget.credentialManager ?? gmxCredentialManager;

  String get _connectionDescription {
    if (kIsWeb) {
      return 'Der Chrome-Prototyp kann keine direkte verschlüsselte '
          'IMAP-Verbindung öffnen. Die Verbindung wird in der nativen App '
          'aktiviert.';
    }
    if (widget.realGmxTestAllowed) {
      return 'YDI verbindet sich direkt und verschlüsselt mit GMX. Das Konto '
          'und die verschlüsselten Analyseergebnisse bleiben lokal auf diesem '
          'Gerät verfügbar.';
    }
    return 'YDI verbindet sich nur in einem ausdrücklich freigegebenen '
        'privaten Test-Build mit GMX.';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
    final account = _accountStore.findByEmail(_emailController.text);
    if (account?.credentialAvailable == true) {
      _checkingCredential = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _verifyStoredCredential(account!);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailController.dispose();
    _passwordController.clear();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _passwordController.clear();
      if (_busy) _cancelActiveScan = true;
    }
  }

  void _emailChanged(String value) {
    _credentialCheckGeneration++;
    final account = _accountStore.findByEmail(value);
    setState(() {
      _credentialAvailable = false;
      _savePasswordFor30Days = false;
      _checkingCredential = account?.credentialAvailable == true;
    });
    if (account?.credentialAvailable == true) {
      _verifyStoredCredential(account!);
    }
  }

  Future<void> _verifyStoredCredential(GmxAccount account) async {
    final generation = ++_credentialCheckGeneration;
    String? credential;
    try {
      credential = await _credentialManager.readValid(account);
    } catch (_) {
      credential = null;
    }
    if (!mounted || generation != _credentialCheckGeneration) return;
    final currentAccount = _accountStore.findByEmail(_emailController.text);
    if (currentAccount?.accountId != account.accountId) return;
    final available = credential?.isNotEmpty == true;
    credential = null;
    setState(() {
      _credentialAvailable = available;
      _savePasswordFor30Days = available;
      _checkingCredential = false;
      if (!available && account.credentialAvailable) {
        _message =
            'Das gespeicherte Passwort ist nicht verfügbar. Bitte gib es erneut ein.';
      }
    });
  }

  Future<void> _testConnection() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _passwordController.clear();
      return;
    }
    await _run(
      operation: (password) => (widget.scanner ?? gmxImapScanner)
          .testConnection(_emailController.text, password),
      markScanned: false,
      successMessage: 'Verbindung erfolgreich. Du kannst die Analyse starten.',
    );
  }

  Future<void> _scan() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _passwordController.clear();
      return;
    }
    final usesStoredCredential = _credentialAvailable;
    _cancelActiveScan = false;
    await _run(
      operation: (password) async {
        await (widget.scanner ?? gmxImapScanner).scanAndSave(
          _emailController.text,
          password,
          onProgress: (current, total) {
            if (!mounted) return;
            setState(() {
              _current = current;
              _total = total;
              _message = 'Analysiere Nachrichten … $current / $total';
            });
          },
          isCancelled: () => _cancelActiveScan,
        );
      },
      markScanned: true,
      progressMessage: usesStoredCredential
          ? 'Synchronisiere …'
          : 'Verschlüsselte Verbindung wird hergestellt …',
      successMessage: usesStoredCredential
          ? 'Synchronisierung erfolgreich'
          : 'Analyse abgeschlossen. Die Ergebnisse wurden lokal verschlüsselt gespeichert.',
      failureMessage: usesStoredCredential
          ? 'Synchronisierung fehlgeschlagen. Bitte versuche es erneut.'
          : 'Verbindung fehlgeschlagen. Prüfe E-Mail-Adresse, Anwendungspasswort und ob IMAP bei GMX aktiviert ist.',
    );
  }

  Future<void> _run({
    required Future<void> Function(String password) operation,
    required bool markScanned,
    required String successMessage,
    String progressMessage = 'Verschlüsselte Verbindung wird hergestellt …',
    String failureMessage =
        'Verbindung fehlgeschlagen. Prüfe E-Mail-Adresse, Anwendungspasswort und ob IMAP bei GMX aktiviert ist.',
  }) async {
    setState(() {
      _busy = true;
      _success = false;
      _current = 0;
      _total = 0;
      _message = progressMessage;
    });
    try {
      final typedPassword = _passwordController.text;
      final existing = _accountStore.findByEmail(_emailController.text);
      final usedStoredCredential = typedPassword.isEmpty;
      final password = usedStoredCredential && existing != null
          ? await _credentialManager.readValid(existing)
          : typedPassword;
      if (password == null || password.isEmpty) {
        if (!mounted) return;
        setState(() {
          _credentialAvailable = false;
          _savePasswordFor30Days = false;
          _message = 'Bitte gib dein Anwendungspasswort erneut ein.';
        });
        return;
      }

      await operation(password);
      var account = await _accountStore.ensureAccount(_emailController.text);
      if (markScanned) {
        account = await _accountStore.markScanned(
          account.accountId,
          DateTime.now(),
        );
      }
      if (_savePasswordFor30Days) {
        if (!usedStoredCredential) {
          await _credentialManager.saveFor30Days(account, password);
        }
      } else {
        await _credentialManager.remove(account);
      }
      if (!mounted) return;
      setState(() {
        _credentialAvailable = _savePasswordFor30Days;
        _success = true;
        _message = successMessage;
      });
    } on GmxScanCancelledException {
      if (!mounted) return;
      setState(() {
        _message =
            'Die Synchronisierung wurde unterbrochen. Der letzte vollständige Stand bleibt erhalten.';
      });
    } on GmxCredentialStorageException {
      if (!mounted) return;
      setState(() {
        _credentialAvailable = false;
        _savePasswordFor30Days = false;
        _message =
            'Das gespeicherte Passwort ist nicht verfügbar. Bitte gib es erneut ein.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = failureMessage;
      });
    } finally {
      if (mounted) {
        _passwordController.clear();
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _removeStoredPassword() async {
    final account = _accountStore.findByEmail(_emailController.text);
    if (account == null) return;
    setState(() => _busy = true);
    try {
      await _credentialManager.remove(account);
      if (!mounted) return;
      setState(() {
        _credentialAvailable = false;
        _savePasswordFor30Days = false;
        _success = true;
        _message = 'Das gespeicherte Passwort wurde entfernt.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _success = false;
        _message = 'Das gespeicherte Passwort konnte nicht entfernt werden.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _credentialAvailable ? 'GMX synchronisieren' : 'GMX verbinden',
        ),
        backgroundColor: const Color(0xFFF5F7FB),
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(
                Icons.mail_outline_rounded,
                size: 58,
                color: Color(0xFF29A583),
              ),
              const SizedBox(height: 18),
              Text(
                _credentialAvailable
                    ? 'GMX synchronisieren'
                    : 'GMX sicher vorbereiten',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _connectionDescription,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF788399)),
              ),
              if (!_credentialAvailable && !_checkingCredential) ...[
                const SizedBox(height: 24),
                const _GmxSetupStep(
                  number: 1,
                  title: 'IMAP bei GMX aktivieren',
                  description:
                      'In GMX: E-Mail-Einstellungen → POP3/IMAP Abruf → Zugriff erlauben.',
                ),
                const _GmxSetupStep(
                  number: 2,
                  title: 'Anwendungspasswort verwenden',
                  description:
                      'Wenn GMX es verlangt, ein eigenes Anwendungspasswort für YDI erstellen – nicht das normale Passwort weitergeben.',
                ),
                const _GmxSetupStep(
                  number: 3,
                  title: 'Lokal analysieren',
                  description:
                      'YDI liest höchstens 5.000 aktuelle Header in kleinen Abschnitten. Mailtexte und Anhänge bleiben unberührt; die Ergebnisse werden lokal verschlüsselt gespeichert.',
                ),
              ],
              const SizedBox(height: 16),
              if (kIsWeb)
                FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: const Text('In der nativen App verfügbar'),
                )
              else if (!widget.realGmxTestAllowed)
                Column(
                  children: [
                    const Text(
                      'Der echte GMX-Test ist in diesem Build deaktiviert.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF657086)),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.lock_outline_rounded),
                      label: const Text('Privater GMX-Test nicht freigegeben'),
                    ),
                  ],
                )
              else
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        enabled:
                            !_busy &&
                            !_checkingCredential &&
                            !_credentialAvailable,
                        onChanged: _emailChanged,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        enableSuggestions: false,
                        textCapitalization: TextCapitalization.none,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'GMX-E-Mail-Adresse',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value != null &&
                                RegExp(
                                  r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                ).hasMatch(value.trim())
                            ? null
                            : 'Bitte gib eine gültige E-Mail-Adresse ein.',
                      ),
                      if (_checkingCredential) ...[
                        const SizedBox(height: 18),
                        const LinearProgressIndicator(),
                        const SizedBox(height: 10),
                        const Text(
                          'Gespeichertes Passwort wird sicher geprüft …',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF657086)),
                        ),
                      ] else if (!_credentialAvailable) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          enabled: !_busy,
                          keyboardType: TextInputType.visiblePassword,
                          obscureText: _hidePassword,
                          autocorrect: false,
                          enableSuggestions: false,
                          textCapitalization: TextCapitalization.none,
                          autofillHints: const <String>[],
                          decoration: InputDecoration(
                            labelText: 'Anwendungspasswort',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _hidePassword = !_hidePassword,
                              ),
                              icon: Icon(
                                _hidePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Bitte gib dein Anwendungspasswort ein.'
                              : null,
                        ),
                        const SizedBox(height: 10),
                        CheckboxListTile(
                          value: _savePasswordFor30Days,
                          onChanged: _busy
                              ? null
                              : (value) => setState(
                                  () => _savePasswordFor30Days = value ?? false,
                                ),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text(
                            'Passwort 30 Tage sicher speichern',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: const Text(
                            'Ohne Auswahl wird das Passwort nach dem Versuch verworfen.',
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 14),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              color: Color(0xFF16866C),
                            ),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Gespeichertes Passwort sicher verfügbar',
                                style: TextStyle(
                                  color: Color(0xFF16866C),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (_credentialAvailable) ...[
                        TextButton.icon(
                          onPressed: _busy ? null : _removeStoredPassword,
                          icon: const Icon(Icons.key_off_outlined),
                          label: const Text('Gespeichertes Passwort entfernen'),
                        ),
                        const Text(
                          'Dein GMX-Passwort wird dadurch nicht geändert.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF657086)),
                        ),
                      ],
                      if (_busy) ...[
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: _total > 0 ? _current / _total : null,
                        ),
                      ],
                      if (_message != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _message!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _success
                                ? const Color(0xFF16866C)
                                : const Color(0xFFB5523B),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (!_checkingCredential)
                        if (_credentialAvailable)
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _busy ? null : _scan,
                              icon: const Icon(Icons.sync_rounded),
                              label: const Text('Synchronisieren'),
                            ),
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _busy ? null : _testConnection,
                                  icon: const Icon(Icons.link_rounded),
                                  label: const Text('Verbindung testen'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _busy ? null : _scan,
                                  icon: const Icon(Icons.manage_search_rounded),
                                  label: const Text('Analyse starten'),
                                ),
                              ),
                            ],
                          ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GmxSetupStep extends StatelessWidget {
  const _GmxSetupStep({
    required this.number,
    required this.title,
    required this.description,
  });

  final int number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFFE1F3EE),
              foregroundColor: const Color(0xFF16866C),
              child: Text('$number'),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(color: Color(0xFF657086)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GoogleAccountsPage extends StatefulWidget {
  const GoogleAccountsPage({super.key});

  @override
  State<GoogleAccountsPage> createState() => _GoogleAccountsPageState();
}

class _GoogleAccountsPageState extends State<GoogleAccountsPage> {
  bool _isScanning = false;
  int _scanned = 0;
  int _total = 0;
  String? _scanMessage;
  bool _isAddingAnotherAccount = false;
  bool _syncAfterSignIn = false;

  @override
  void initState() {
    super.initState();
    googleAuthService.userNotifier.addListener(_handleGoogleUserChanged);
  }

  @override
  void dispose() {
    googleAuthService.userNotifier.removeListener(_handleGoogleUserChanged);
    super.dispose();
  }

  void _handleGoogleUserChanged() {
    final user = googleAuthService.userNotifier.value;
    if (!_syncAfterSignIn || user == null) return;
    _syncAfterSignIn = false;
    _isAddingAnotherAccount = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startScan();
    });
  }

  Future<void> _addAnotherAccount({bool syncAfterSignIn = false}) async {
    if (_isScanning) return;
    setState(() {
      _scanMessage = null;
      _isAddingAnotherAccount = true;
      _syncAfterSignIn = syncAfterSignIn;
    });
    await googleAuthService.switchAccount();
  }

  Future<void> _chooseAccountToSync() async {
    if (_isScanning) return;
    final user = googleAuthService.userNotifier.value;
    final storedAccounts =
        scanDataNotifier.value?.accounts
            .where((account) => account.toLowerCase().startsWith('gmail'))
            .toList() ??
        <String>[];
    if (user != null) {
      final currentLabel = gmailMetadataScanner.accountLabelFor(user.email);
      if (!storedAccounts.contains(currentLabel)) {
        storedAccounts.add(currentLabel);
      }
    }

    if (storedAccounts.length <= 1) {
      await _startScan();
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF5F7FB),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Text(
                  'Welches Konto synchronisieren?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              ...storedAccounts.map(
                (account) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    child: ListTile(
                      onTap: () => Navigator.pop(context, account),
                      leading: const Icon(
                        Icons.alternate_email_rounded,
                        color: Color(0xFF526DFF),
                      ),
                      title: Text(_accountPickerLabel(account)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;

    final currentEmail = googleAuthService.userNotifier.value?.email;
    if (currentEmail != null &&
        _accountPickerLabel(selected).toLowerCase() ==
            currentEmail.toLowerCase()) {
      await _startScan();
      return;
    }

    await _addAnotherAccount(syncAfterSignIn: true);
  }

  Future<void> _removeCurrentAccount() async {
    final user = googleAuthService.userNotifier.value;
    if (user == null || _isScanning) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konto aus YDI entfernen?'),
        content: const Text(
          'Der Google-Zugriff wird getrennt und alle lokal gespeicherten '
          'Analyseergebnisse dieses Kontos werden gelöscht.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final accountLabels = gmailMetadataScanner.accountLabelsFor(user.email);
    await googleAuthService.disconnect();
    final current = scanDataNotifier.value;
    if (current == null) return;
    final retained = current.withoutAccounts(accountLabels);
    if (retained.services.isEmpty) {
      await scanDataStore.clear();
    } else {
      await scanDataStore.save(retained);
    }
    if (mounted) setState(() => _scanMessage = null);
  }

  Future<void> _startScan() async {
    final user = googleAuthService.userNotifier.value;
    if (user == null || _isScanning) return;

    setState(() {
      _isScanning = true;
      _scanned = 0;
      _total = 0;
      _scanMessage = null;
    });

    try {
      final dataset = await gmailMetadataScanner.scanAndSave(
        user,
        onProgress: (current, total) {
          if (!mounted) return;
          setState(() {
            _scanned = current;
            _total = total;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _scanMessage =
            'Analyse abgeschlossen: ${dataset.services.length} Dienste insgesamt.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _scanMessage = 'Analyse fehlgeschlagen: $error');
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final googleSignInUnavailable =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'E-Mail-Konten',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: const Color(0xFFF5F7FB),
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ValueListenableBuilder(
              valueListenable: googleAuthService.userNotifier,
              builder: (context, user, _) {
                final hasStoredGoogleAccounts =
                    scanDataNotifier.value?.accounts.any(
                      (account) => account.toLowerCase().startsWith('gmail'),
                    ) ??
                    false;
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.alternate_email_rounded,
                        size: 58,
                        color: Color(0xFF526DFF),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        user == null
                            ? _isAddingAnotherAccount
                                  ? 'Weiteres Google-Konto auswählen'
                                  : hasStoredGoogleAccounts
                                  ? 'Google-Konten verbunden'
                                  : 'Verbinde dein erstes Google-Konto'
                            : 'Google-Konten verbunden',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        user == null
                            ? _isAddingAnotherAccount
                                  ? 'Öffne den Google-Kontowähler und wähle dort ein anderes Konto aus.'
                                  : hasStoredGoogleAccounts
                                  ? 'Wähle beim Synchronisieren aus, welches Konto aktualisiert werden soll.'
                                  : 'In diesem Schritt meldest du dich nur an. YDI liest noch keine Gmail-Nachrichten.'
                            : 'Wähle beim Synchronisieren aus, welches Konto aktualisiert werden soll.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF788399)),
                      ),
                      const SizedBox(height: 18),
                      ValueListenableBuilder(
                        valueListenable: scanDataNotifier,
                        builder: (context, dataset, _) {
                          final accounts =
                              dataset?.accounts
                                  .where(
                                    (account) => account
                                        .toLowerCase()
                                        .startsWith('gmail'),
                                  )
                                  .toList() ??
                              const <String>[];
                          if (accounts.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
                                  child: Text(
                                    'Hinzugefügte Google-Konten',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                ...accounts.map(
                                  (account) => ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    leading: const Icon(
                                      Icons.alternate_email_rounded,
                                      color: Color(0xFF526DFF),
                                    ),
                                    title: const Text(
                                      'Gmail',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: Text(
                                      account.replaceFirst(
                                        RegExp(r'^Gmail\s*[·â€¢]\s*'),
                                        '',
                                      ),
                                    ),
                                    trailing: const Chip(
                                      avatar: Icon(
                                        Icons.check_rounded,
                                        size: 16,
                                      ),
                                      label: Text('Verbunden'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 28),
                      if (googleSignInUnavailable)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: Color(0xFF526DFF),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Google-Anmeldung ist in der Windows-Testapp '
                                'noch nicht verfügbar.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Gmail funktioniert weiterhin im Web-Prototyp '
                                'und wird später nativ für Android und iPhone '
                                'angebunden. Unter Windows entwickeln wir jetzt '
                                'den direkten GMX-Connector.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFF788399)),
                              ),
                              const SizedBox(height: 14),
                              FilledButton.icon(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.arrow_back_rounded),
                                label: const Text('Zurück zu E-Mail-Konten'),
                              ),
                            ],
                          ),
                        )
                      else if (!googleAuthService.isConfigured)
                        const Text(
                          'Die lokale Google Client-ID fehlt. Starte YDI mit GOOGLE_WEB_CLIENT_ID.',
                          textAlign: TextAlign.center,
                        )
                      else if (user != null) ...[
                        if (_isScanning) ...[
                          LinearProgressIndicator(
                            value: _total == 0 ? null : _scanned / _total,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _total == 0
                                ? 'Gmail-Zugriff wird vorbereitet …'
                                : '$_scanned von $_total Metadaten analysiert',
                          ),
                        ] else
                          FilledButton.icon(
                            onPressed: _chooseAccountToSync,
                            icon: const Icon(Icons.sync_rounded),
                            label: const Text('Synchronisieren'),
                          ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _isScanning
                              ? null
                              : googleAuthService.disconnect,
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Verbindung trennen'),
                        ),
                        TextButton.icon(
                          onPressed: _isScanning ? null : _removeCurrentAccount,
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Konto und lokale Daten entfernen'),
                        ),
                        const SizedBox(height: 10),
                        if (hasYdiPlus)
                          FilledButton.tonalIcon(
                            onPressed: _isScanning
                                ? null
                                : () => _addAnotherAccount(),
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            label: const Text(
                              'Weiteres Google-Konto hinzufügen',
                            ),
                          )
                        else
                          const Text(
                            'Mehrere E-Mail-Konten sind in YDI Plus verfügbar.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF788399)),
                          ),
                        if (_scanMessage != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _scanMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _scanMessage!.startsWith('Analyse fehl')
                                  ? Colors.red
                                  : const Color(0xFF29A583),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ] else if (kIsWeb) ...[
                        renderGoogleSignInButton(
                          forceGeneric: _isAddingAnotherAccount,
                        ),
                        if (_isAddingAnotherAccount) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Google-Kontowähler öffnen',
                            style: TextStyle(color: Color(0xFF526DFF)),
                          ),
                        ],
                      ] else if (googleAuthService
                          .supportsInteractiveAuthentication)
                        FilledButton.icon(
                          onPressed: googleAuthService.authenticate,
                          icon: const Icon(Icons.login_rounded),
                          label: const Text('Mit Google verbinden'),
                        ),
                      const SizedBox(height: 18),
                      ValueListenableBuilder(
                        valueListenable: googleAuthService.errorNotifier,
                        builder: (context, error, _) => error == null
                            ? const SizedBox.shrink()
                            : Text(
                                error,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red),
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Icon(icon, color: const Color(0xFF526DFF)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class FeaturePage extends StatelessWidget {
  const FeaturePage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.items,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<FeatureItem> items;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: const Color(0xFFF5F7FB),
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: color, size: 30),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    child: ListTile(
                      onTap: item.service == null
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    ServiceDetailPage(service: item.service!),
                              ),
                            ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 7,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: color.withValues(alpha: .14),
                        foregroundColor: color,
                        child: Text(
                          item.monogram,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      title: Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(item.description),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Demo-Daten für den ersten YDI-Prototyp',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF788399), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ServiceDetailPage extends StatelessWidget {
  const ServiceDetailPage({super.key, required this.service});

  final ServiceItem service;

  Future<void> _openUnsubscribePage(BuildContext context, String url) async {
    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Die Abmeldeseite konnte nicht geöffnet werden.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText(languageNotifier.value);
    final newsletterCount = service.newsletterCountFor('Alle E-Mail-Konten');
    final hasUnsubscribeLink = service.hasUnsubscribeLinkFor(
      'Alle E-Mail-Konten',
    );
    final unsubscribeUrl = service.unsubscribeUrlFor('Alle E-Mail-Konten');
    final unsubscribeRequiresPost = service.unsubscribeRequiresPostFor(
      'Alle E-Mail-Konten',
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(service.name),
        backgroundColor: const Color(0xFFF5F7FB),
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            children: [
              _ServiceHero(service: service),
              const SizedBox(height: 20),
              _DetailCard(
                children: [
                  _DetailRow(
                    icon: Icons.category_outlined,
                    label: text.category,
                    value: text.categoryLabel(service.categoryId.id),
                  ),
                  const Divider(height: 28),
                  _DetailRow(
                    icon: Icons.email_outlined,
                    label: text.detectedEmails,
                    value: '${service.totalMailCount}',
                  ),
                  const Divider(height: 28),
                  _AccountUsageDetails(service: service),
                ],
              ),
              const SizedBox(height: 14),
              _DetailCard(
                children: [
                  _StatusRow(
                    icon: Icons.mark_email_unread_outlined,
                    label: newsletterCount > 0
                        ? 'Newsletter erkannt ($newsletterCount)'
                        : 'Kein Newsletter erkannt',
                    positive: newsletterCount > 0,
                  ),
                  const Divider(height: 28),
                  _StatusRow(
                    icon: Icons.unsubscribe_rounded,
                    label: hasUnsubscribeLink
                        ? unsubscribeRequiresPost
                              ? 'Technische One-Click-Abmeldung erkannt'
                              : 'Abmeldelink gefunden'
                        : 'Kein Abmeldelink gefunden',
                    positive: hasUnsubscribeLink,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: unsubscribeUrl == null || unsubscribeRequiresPost
                    ? null
                    : () => _openUnsubscribePage(context, unsubscribeUrl),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Abmeldeseite öffnen'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                unsubscribeRequiresPost
                    ? 'Dieser Anbieter erwartet eine technische POST-Abmeldung. '
                          'YDI führt sie nicht automatisch aus. Nutze vorerst den '
                          'sichtbaren Abmeldelink in der letzten Newsletter-Mail.'
                    : 'YDI öffnet nur die offizielle Abmeldeseite. Die Entscheidung '
                          'und Bestätigung bleiben bei dir.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF788399), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceHero extends StatelessWidget {
  const _ServiceHero({required this.service});
  final ServiceItem service;

  @override
  Widget build(BuildContext context) {
    final text = AppText(languageNotifier.value);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: service.color,
              borderRadius: BorderRadius.circular(19),
            ),
            child: Text(
              service.monogram,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 17),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text.categoryLabel(service.categoryId.id),
                  style: const TextStyle(color: Color(0xFF788399)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: children),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF526DFF)),
        const SizedBox(width: 13),
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _AccountUsageDetails extends StatelessWidget {
  const _AccountUsageDetails({required this.service});

  final ServiceItem service;

  @override
  Widget build(BuildContext context) {
    final text = AppText(languageNotifier.value);
    final accounts = service.mailCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.alternate_email_rounded, color: Color(0xFF526DFF)),
            const SizedBox(width: 13),
            const Expanded(child: Text('Verwendete Konten')),
            Text(
              '${accounts.length}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...accounts.indexed.map((indexedEntry) {
          final index = indexedEntry.$1;
          final entry = indexedEntry.$2;
          return Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : 10),
            child: Row(
              children: [
                const SizedBox(width: 37),
                Expanded(
                  child: Text(
                    _accountPickerLabel(entry.key),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF657086)),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  text.mails(entry.value),
                  style: const TextStyle(
                    color: Color(0xFF657086),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.positive,
  });

  final IconData icon;
  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final color = positive ? const Color(0xFF29A583) : const Color(0xFF788399);
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 13),
        Expanded(child: Text(label)),
        Icon(
          positive ? Icons.check_circle_rounded : Icons.remove_circle_outline,
          color: color,
        ),
      ],
    );
  }
}

class DashboardMetric {
  const DashboardMetric(this.value, this.label, this.icon, this.color);
  final String value;
  final String label;
  final IconData icon;
  final Color color;
}

class FeatureItem {
  const FeatureItem(
    this.title,
    this.description,
    this.monogram, {
    this.service,
  });
  final String title;
  final String description;
  final String monogram;
  final ServiceItem? service;
}
