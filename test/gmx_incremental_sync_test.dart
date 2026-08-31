import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ydi_app/config/public_demo.dart';
import 'package:ydi_app/data/encrypted_gmx_scan_store.dart';
import 'package:ydi_app/data/scan_data_store.dart';
import 'package:ydi_app/models/gmx_sync_state.dart';
import 'package:ydi_app/models/scan_dataset.dart';
import 'package:ydi_app/services/gmx_imap_scanner.dart';

const _email = 'private-test@example.com';
const _account = 'GMX · $_email';

class _MemoryScanPreferences implements ScanPreferences {
  final Map<String, String> values = {};

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

class _MemoryGmxPersistence implements GmxScanPersistence {
  ScanDataset? dataset;
  final Map<String, GmxSyncState> syncStates = {};

  @override
  Future<ScanDataset?> load() async => dataset;

  @override
  Future<GmxSyncState?> loadSyncState(String account) async =>
      syncStates[account];

  @override
  Future<void> save(ScanDataset? value) async {
    dataset = value;
    if (value == null) syncStates.clear();
  }

  @override
  Future<void> saveWithSyncState(
    ScanDataset value,
    String account,
    GmxSyncState syncState,
  ) async {
    dataset = value;
    syncStates[account] = syncState;
  }

  @override
  Future<void> removeAccount(String account) async {
    dataset = dataset?.withoutAccounts({account});
    syncStates.remove(account);
  }

  @override
  Future<void> clear() async {
    dataset = null;
    syncStates.clear();
  }
}

class _FakeGmxSession implements GmxImapSession {
  _FakeGmxSession({
    required this.uids,
    this.uidValidity = 42,
    this.failOnFetchNumber,
  });

  final List<int> uids;
  final int? uidValidity;
  final int? failOnFetchNumber;
  final List<List<int>> fetchedChunks = [];
  final List<String> criteria = [];
  int? searchedAfterUid;

  @override
  Future<void> connect(String email, String password) async {}

  @override
  Future<GmxMailboxSnapshot> selectInbox() async =>
      GmxMailboxSnapshot(messagesExists: uids.length, uidValidity: uidValidity);

  @override
  Future<List<int>> searchUids({int? afterUid}) async {
    searchedAfterUid = afterUid;
    return afterUid == null
        ? List<int>.from(uids)
        : uids.where((uid) => uid > afterUid).toList();
  }

  @override
  Future<List<MimeMessage>> fetchSequenceRange(
    int firstSequenceId,
    int lastSequenceId, {
    required String criteria,
  }) => fetchUids(
    uids.sublist(firstSequenceId - 1, lastSequenceId),
    criteria: criteria,
  );

  @override
  Future<List<MimeMessage>> fetchUids(
    List<int> requestedUids, {
    required String criteria,
  }) async {
    fetchedChunks.add(List<int>.from(requestedUids));
    this.criteria.add(criteria);
    if (fetchedChunks.length == failOnFetchNumber) {
      throw StateError('Synthetic chunk failure.');
    }
    return requestedUids.map(_message).toList(growable: false);
  }

  MimeMessage _message(int uid) => MimeMessage.parseFromText(
    'From: Sender <sender@example.com>\r\n'
    'Subject: Synthetic message $uid\r\n'
    '\r\n',
  )..uid = uid;

  @override
  Future<void> close() async {}
}

({
  GmxImapScanner scanner,
  ScanDataStore store,
  _MemoryGmxPersistence persistence,
})
_scannerWith(_FakeGmxSession session, {_MemoryGmxPersistence? persistence}) {
  final memoryPersistence = persistence ?? _MemoryGmxPersistence();
  final store = ScanDataStore(
    preferences: _MemoryScanPreferences(),
    gmxPersistence: memoryPersistence,
    notifier: ValueNotifier<ScanDataset?>(memoryPersistence.dataset),
    clearAccountScanTimes: () async {},
    removeAccountScanTime: (_) async {},
  );
  return (
    scanner: GmxImapScanner(
      accessPolicy: const RealGmxAccessPolicy(
        isPublicDemo: false,
        allowRealGmxTest: true,
      ),
      sessionFactory: () => session,
      dataStore: store,
    ),
    store: store,
    persistence: memoryPersistence,
  );
}

Future<ScanDataset> _scan(
  GmxImapScanner scanner, {
  void Function(int current, int total)? onProgress,
}) => scanner.scanAndSave(
  _email,
  'synthetic-password',
  onProgress: onProgress ?? (_, _) {},
);

void main() {
  test('Erstscan verarbeitet mehrere kontrollierte Chunks', () async {
    final session = _FakeGmxSession(
      uids: [for (var uid = 1; uid <= 730; uid++) uid],
    );
    final setup = _scannerWith(session);
    final progress = <(int, int)>[];

    final dataset = await _scan(
      setup.scanner,
      onProgress: (current, total) => progress.add((current, total)),
    );

    expect(session.fetchedChunks.map((chunk) => chunk.length), [250, 250, 230]);
    expect(progress.last, (730, 730));
    expect(dataset.services.single.mailCountFor(_account), 730);
    expect(setup.persistence.syncStates[_account]?.lastProcessedUid, 730);
  });

  test(
    'Erstscan mit weniger als 5.000 Nachrichten nutzt nur einen Chunk',
    () async {
      final session = _FakeGmxSession(
        uids: [for (var uid = 1; uid <= 80; uid++) uid],
      );
      final setup = _scannerWith(session);

      await _scan(setup.scanner);

      expect(session.fetchedChunks, hasLength(1));
      expect(session.fetchedChunks.single, hasLength(80));
    },
  );

  test('Erstscan hält das harte Maximum von 5.000 ein', () async {
    final session = _FakeGmxSession(
      uids: [for (var uid = 1; uid <= 5100; uid++) uid],
    );
    final setup = _scannerWith(session);

    final dataset = await _scan(setup.scanner);

    expect(session.fetchedChunks, hasLength(20));
    expect(session.fetchedChunks.expand((chunk) => chunk), hasLength(5000));
    expect(session.fetchedChunks.first.first, 101);
    expect(dataset.services.single.mailCountFor(_account), 5000);
  });

  test('Chunks laden ausschließlich UID und vorgesehene Header', () async {
    final session = _FakeGmxSession(uids: [1]);
    final setup = _scannerWith(session);

    await _scan(setup.scanner);

    expect(session.criteria.single, GmxImapScanner.headerFetchCriteria);
    expect(session.criteria.single, contains('UID'));
    expect(session.criteria.single, contains('FROM'));
    expect(session.criteria.single, contains('SUBJECT'));
    expect(session.criteria.single, contains('LIST-UNSUBSCRIBE'));
    expect(session.criteria.single, contains('LIST-UNSUBSCRIBE-POST'));
    expect(session.criteria.single, contains('LIST-ID'));
    expect(session.criteria.single, isNot(contains('BODY[]')));
  });

  test('Späterer Sync verarbeitet nur neue UIDs ohne Dubletten', () async {
    final first = _FakeGmxSession(
      uids: [for (var uid = 1; uid <= 300; uid++) uid],
    );
    final initial = _scannerWith(first);
    await _scan(initial.scanner);

    final next = _FakeGmxSession(
      uids: [for (var uid = 1; uid <= 320; uid++) uid],
    );
    final incremental = _scannerWith(next, persistence: initial.persistence);
    final dataset = await _scan(incremental.scanner);

    expect(next.searchedAfterUid, 300);
    expect(next.fetchedChunks.single, [
      for (var uid = 301; uid <= 320; uid++) uid,
    ]);
    expect(dataset.services.single.mailCountFor(_account), 320);

    final unchanged = _FakeGmxSession(
      uids: [for (var uid = 1; uid <= 320; uid++) uid],
    );
    final repeated = _scannerWith(unchanged, persistence: initial.persistence);
    final repeatedDataset = await _scan(repeated.scanner);
    expect(unchanged.fetchedChunks, isEmpty);
    expect(repeatedDataset.services.single.mailCountFor(_account), 320);
  });

  test(
    'Neue UIDVALIDITY erzwingt einen begrenzten vollständigen Rescan',
    () async {
      final first = _FakeGmxSession(
        uids: [for (var uid = 1; uid <= 300; uid++) uid],
      );
      final initial = _scannerWith(first);
      await _scan(initial.scanner);

      final changed = _FakeGmxSession(
        uids: [for (var uid = 1; uid <= 10; uid++) uid],
        uidValidity: 99,
      );
      final reset = _scannerWith(changed, persistence: initial.persistence);
      final dataset = await _scan(reset.scanner);

      expect(changed.searchedAfterUid, isNull);
      expect(dataset.services.single.mailCountFor(_account), 10);
      expect(reset.persistence.syncStates[_account]?.uidValidity, 99);
    },
  );

  test('Fehlgeschlagener Chunk behält letzten vollständigen Stand', () async {
    final first = _FakeGmxSession(
      uids: [for (var uid = 1; uid <= 100; uid++) uid],
    );
    final initial = _scannerWith(first);
    final previous = await _scan(initial.scanner);
    final previousState = initial.persistence.syncStates[_account];

    final failing = _FakeGmxSession(
      uids: [for (var uid = 1; uid <= 400; uid++) uid],
      failOnFetchNumber: 2,
    );
    final retry = _scannerWith(failing, persistence: initial.persistence);

    await expectLater(_scan(retry.scanner), throwsStateError);
    expect(initial.persistence.dataset?.toJson(), previous.toJson());
    expect(
      initial.persistence.syncStates[_account]?.lastProcessedUid,
      previousState?.lastProcessedUid,
    );
  });

  test('Abbruch zwischen Chunks speichert keinen halbfertigen Stand', () async {
    final session = _FakeGmxSession(
      uids: [for (var uid = 1; uid <= 600; uid++) uid],
    );
    final setup = _scannerWith(session);
    var cancelled = false;

    await expectLater(
      setup.scanner.scanAndSave(
        _email,
        'synthetic-password',
        onProgress: (current, _) {
          if (current == GmxImapScanner.chunkSize) cancelled = true;
        },
        isCancelled: () => cancelled,
      ),
      throwsA(isA<GmxScanCancelledException>()),
    );

    expect(session.fetchedChunks, hasLength(1));
    expect(setup.persistence.dataset, isNull);
    expect(setup.persistence.syncStates, isEmpty);
  });
}
