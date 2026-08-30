import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ydi_app/data/gmx_account_store.dart';
import 'package:ydi_app/main.dart';
import 'package:ydi_app/models/gmx_account.dart';
import 'package:ydi_app/models/scan_dataset.dart';
import 'package:ydi_app/services/gmx_credential_manager.dart';
import 'package:ydi_app/services/gmx_imap_scanner.dart';

class _MemoryPreferences implements GmxAccountPreferences {
  _MemoryPreferences([Map<String, String>? values])
    : values = values ?? <String, String>{};

  final Map<String, String> values;

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

class _MemorySecureStorage implements GmxSecureStorage {
  _MemorySecureStorage([Map<String, String>? values])
    : values = values ?? <String, String>{};

  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class _FakeGmxScanner extends GmxImapScanner {
  _FakeGmxScanner({required this.shouldFail});

  final bool shouldFail;
  String? receivedPassword;

  @override
  Future<void> testConnection(String email, String password) async {
    receivedPassword = password;
    if (shouldFail) throw StateError('Synthetic connection failure.');
  }

  @override
  Future<ScanDataset> scanAndSave(
    String email,
    String password, {
    required void Function(int current, int total) onProgress,
  }) async {
    receivedPassword = password;
    if (shouldFail) throw StateError('Synthetic scan failure.');
    onProgress(1, 1);
    return const ScanDataset(services: [], sourceFiles: []);
  }
}

void main() {
  ({
    GmxAccountStore accountStore,
    GmxCredentialManager credentialManager,
    _MemorySecureStorage secureStorage,
  })
  persistenceWithNow(DateTime Function() now) {
    final accountStore = GmxAccountStore(
      preferences: _MemoryPreferences(),
      notifier: ValueNotifier<List<GmxAccount>>(const []),
      publicDemo: false,
      now: now,
      randomIdPart: () => 42,
    );
    final secureStorage = _MemorySecureStorage();
    return (
      accountStore: accountStore,
      credentialManager: GmxCredentialManager(
        accountStore: accountStore,
        secureStorage: secureStorage,
        now: now,
      ),
      secureStorage: secureStorage,
    );
  }

  ({
    GmxAccountStore accountStore,
    GmxCredentialManager credentialManager,
    _MemorySecureStorage secureStorage,
  })
  persistence() => persistenceWithNow(() => DateTime.utc(2026, 8, 1));

  Future<void> pumpPage(
    WidgetTester tester,
    GmxImapScanner scanner,
    ({
      GmxAccountStore accountStore,
      GmxCredentialManager credentialManager,
      _MemorySecureStorage secureStorage,
    })
    persistence, {
    String? initialEmail,
  }) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: GmxSetupPage(
          initialEmail: initialEmail,
          scanner: scanner,
          accountStore: persistence.accountStore,
          credentialManager: persistence.credentialManager,
          realGmxTestAllowed: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enterCredentialsAndTest(WidgetTester tester) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'private-test@example.com');
    await tester.enterText(fields.at(1), 'synthetic-password');
    await tester.ensureVisible(find.text('Verbindung testen'));
    await tester.tap(find.text('Verbindung testen'));
    await tester.pumpAndSettle();
  }

  String passwordValue(WidgetTester tester) => tester
      .widget<TextFormField>(find.byType(TextFormField).at(1))
      .controller!
      .text;

  testWidgets('Passwort wird nach erfolgreichem Versuch gelöscht', (
    tester,
  ) async {
    await pumpPage(tester, _FakeGmxScanner(shouldFail: false), persistence());
    await enterCredentialsAndTest(tester);

    expect(passwordValue(tester), isEmpty);
    expect(find.textContaining('Verbindung erfolgreich'), findsOneWidget);
  });

  testWidgets('Passwort wird nach fehlgeschlagenem Versuch gelöscht', (
    tester,
  ) async {
    await pumpPage(tester, _FakeGmxScanner(shouldFail: true), persistence());
    await enterCredentialsAndTest(tester);

    expect(passwordValue(tester), isEmpty);
    expect(find.textContaining('Verbindung fehlgeschlagen'), findsOneWidget);
  });

  testWidgets('Passwort wird bei Inaktivität aus dem Eingabefeld gelöscht', (
    tester,
  ) async {
    await pumpPage(tester, _FakeGmxScanner(shouldFail: false), persistence());
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'synthetic-password',
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    expect(passwordValue(tester), isEmpty);
  });

  testWidgets(
    'Passwort nicht speichern erzeugt keinen Secure-Storage-Eintrag',
    (tester) async {
      final stores = persistence();
      await pumpPage(tester, _FakeGmxScanner(shouldFail: false), stores);
      await enterCredentialsAndTest(tester);

      expect(stores.accountStore.accounts, hasLength(1));
      expect(stores.accountStore.accounts.single.credentialAvailable, isFalse);
      expect(stores.secureStorage.values, isEmpty);
    },
  );

  testWidgets('Explizite Auswahl speichert Passwort sicher für 30 Tage', (
    tester,
  ) async {
    final stores = persistence();
    await pumpPage(tester, _FakeGmxScanner(shouldFail: false), stores);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'private-test@example.com',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'synthetic-password',
    );
    await tester.ensureVisible(find.text('Passwort 30 Tage sicher speichern'));
    await tester.tap(find.text('Passwort 30 Tage sicher speichern'));
    await tester.ensureVisible(find.text('Verbindung testen'));
    await tester.tap(find.text('Verbindung testen'));
    await tester.pumpAndSettle();

    expect(stores.accountStore.accounts.single.credentialAvailable, isTrue);
    expect(stores.secureStorage.values.values, contains('synthetic-password'));
  });

  testWidgets('Gültiges gespeichertes Passwort erlaubt Sync ohne Eingabe', (
    tester,
  ) async {
    final stores = persistence();
    var account = await stores.accountStore.ensureAccount(
      'private-test@example.com',
    );
    await stores.credentialManager.saveFor30Days(account, 'synthetic-password');
    account = stores.accountStore.findById(account.accountId)!;
    expect(account.credentialAvailable, isTrue);
    final scanner = _FakeGmxScanner(shouldFail: false);
    await pumpPage(tester, scanner, stores, initialEmail: account.email);

    expect(find.text('Anwendungspasswort'), findsNothing);
    expect(find.text('Synchronisieren'), findsOneWidget);

    await tester.ensureVisible(find.text('Synchronisieren'));
    await tester.tap(find.text('Synchronisieren'));
    await tester.pumpAndSettle();

    expect(scanner.receivedPassword, 'synthetic-password');
    expect(find.text('Synchronisierung erfolgreich'), findsOneWidget);
  });

  testWidgets(
    'Credential unter 30 Tagen erlaubt Sync nach simuliertem Neustart',
    (tester) async {
      final preferenceValues = <String, String>{};
      final keychainValues = <String, String>{};
      final firstAccountStore = GmxAccountStore(
        preferences: _MemoryPreferences(preferenceValues),
        notifier: ValueNotifier<List<GmxAccount>>(const []),
        publicDemo: false,
        now: () => DateTime.utc(2026, 8, 1),
        randomIdPart: () => 42,
      );
      final firstManager = GmxCredentialManager(
        accountStore: firstAccountStore,
        secureStorage: _MemorySecureStorage(keychainValues),
        now: () => DateTime.utc(2026, 8, 1),
      );
      final firstAccount = await firstAccountStore.ensureAccount(
        'private-test@example.com',
      );
      await firstManager.saveFor30Days(firstAccount, 'synthetic-password');

      final restartedAccountStore = GmxAccountStore(
        preferences: _MemoryPreferences(preferenceValues),
        notifier: ValueNotifier<List<GmxAccount>>(const []),
        publicDemo: false,
      );
      await restartedAccountStore.load();
      final restartedManager = GmxCredentialManager(
        accountStore: restartedAccountStore,
        secureStorage: _MemorySecureStorage(keychainValues),
        now: () => DateTime.utc(2026, 8, 2),
      );
      await restartedManager.discardExpiredCredentials();
      final scanner = _FakeGmxScanner(shouldFail: false);
      final stores = (
        accountStore: restartedAccountStore,
        credentialManager: restartedManager,
        secureStorage: _MemorySecureStorage(keychainValues),
      );
      await pumpPage(
        tester,
        scanner,
        stores,
        initialEmail: restartedAccountStore.accounts.single.email,
      );

      expect(find.text('Anwendungspasswort'), findsNothing);
      expect(find.text('Synchronisieren'), findsOneWidget);

      await tester.ensureVisible(find.text('Synchronisieren'));
      await tester.tap(find.text('Synchronisieren'));
      await tester.pumpAndSettle();

      expect(scanner.receivedPassword, 'synthetic-password');
      expect(find.text('Bitte gib dein Anwendungspasswort ein.'), findsNothing);
      expect(find.text('Synchronisierung erfolgreich'), findsOneWidget);
    },
  );

  testWidgets('Credential über 30 Tagen erfordert Passwort, Konto bleibt', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 8, 1);
    final stores = persistenceWithNow(() => now);
    final account = await stores.accountStore.ensureAccount(
      'private-test@example.com',
    );
    await stores.credentialManager.saveFor30Days(account, 'synthetic-password');
    now = DateTime.utc(2026, 9, 1, 0, 0, 1);
    await stores.credentialManager.discardExpiredCredentials();
    final scanner = _FakeGmxScanner(shouldFail: false);
    await pumpPage(tester, scanner, stores, initialEmail: account.email);

    expect(find.text('Anwendungspasswort'), findsOneWidget);
    expect(find.text('Synchronisieren'), findsNothing);
    expect(scanner.receivedPassword, isNull);
    expect(stores.accountStore.accounts, hasLength(1));
    expect(stores.accountStore.accounts.single.credentialAvailable, isFalse);
  });

  testWidgets('Fehlendes gespeichertes Passwort erfordert erneute Eingabe', (
    tester,
  ) async {
    final stores = persistence();
    final account = await stores.accountStore.ensureAccount(
      'private-test@example.com',
    );
    await stores.accountStore.setCredentialAvailable(account.accountId, true);
    final scanner = _FakeGmxScanner(shouldFail: false);
    await pumpPage(tester, scanner, stores, initialEmail: account.email);

    expect(find.text('Anwendungspasswort'), findsOneWidget);
    expect(find.text('Synchronisieren'), findsNothing);
    expect(scanner.receivedPassword, isNull);
    expect(stores.accountStore.accounts.single.credentialAvailable, isFalse);
  });

  testWidgets('Fehlgeschlagener Background-Sync zeigt generischen Fehler', (
    tester,
  ) async {
    final stores = persistence();
    var account = await stores.accountStore.ensureAccount(
      'private-test@example.com',
    );
    await stores.credentialManager.saveFor30Days(account, 'synthetic-password');
    account = stores.accountStore.findById(account.accountId)!;
    final scanner = _FakeGmxScanner(shouldFail: true);
    await pumpPage(tester, scanner, stores, initialEmail: account.email);

    await tester.tap(find.text('Synchronisieren'));
    await tester.pumpAndSettle();

    expect(
      find.text('Synchronisierung fehlgeschlagen. Bitte versuche es erneut.'),
      findsOneWidget,
    );
    expect(find.textContaining('Synthetic scan failure'), findsNothing);
    expect(find.textContaining('StateError'), findsNothing);
  });

  testWidgets('GMX-Eingabefelder sind für iOS sicher konfiguriert', (
    tester,
  ) async {
    await pumpPage(tester, _FakeGmxScanner(shouldFail: false), persistence());
    final formFields = find.byType(TextFormField);
    final email = tester.widget<TextField>(
      find.descendant(of: formFields.at(0), matching: find.byType(TextField)),
    );
    final password = tester.widget<TextField>(
      find.descendant(of: formFields.at(1), matching: find.byType(TextField)),
    );

    expect(email.keyboardType, TextInputType.emailAddress);
    expect(email.autocorrect, isFalse);
    expect(email.enableSuggestions, isFalse);
    expect(email.textCapitalization, TextCapitalization.none);
    expect(email.autofillHints, contains(AutofillHints.email));
    expect(password.keyboardType, TextInputType.visiblePassword);
    expect(password.obscureText, isTrue);
    expect(password.autocorrect, isFalse);
    expect(password.enableSuggestions, isFalse);
    expect(password.textCapitalization, TextCapitalization.none);
    expect(password.autofillHints, isEmpty);
  });
}
