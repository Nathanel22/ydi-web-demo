import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../models/scan_dataset.dart';
import '../models/gmx_sync_state.dart';
import '../services/gmx_credential_manager.dart';

abstract interface class GmxScanFile {
  Future<List<int>?> read();

  Future<void> write(List<int> bytes);

  Future<void> delete();
}

abstract interface class GmxScanPersistence {
  Future<ScanDataset?> load();

  Future<GmxSyncState?> loadSyncState(String account);

  Future<void> save(ScanDataset? dataset);

  Future<void> saveWithSyncState(
    ScanDataset dataset,
    String account,
    GmxSyncState syncState,
  );

  Future<void> removeAccount(String account);

  Future<void> clear();
}

class NoopGmxScanPersistence implements GmxScanPersistence {
  const NoopGmxScanPersistence();

  @override
  Future<ScanDataset?> load() async => null;

  @override
  Future<GmxSyncState?> loadSyncState(String account) async => null;

  @override
  Future<void> save(ScanDataset? dataset) async {}

  @override
  Future<void> saveWithSyncState(
    ScanDataset dataset,
    String account,
    GmxSyncState syncState,
  ) async {}

  @override
  Future<void> removeAccount(String account) async {}

  @override
  Future<void> clear() async {}
}

class EncryptedGmxScanPersistence implements GmxScanPersistence {
  EncryptedGmxScanPersistence(this._file, this._secureStorage, {Cipher? cipher})
    : _cipher = cipher ?? AesGcm.with256bits();

  static const _keyStorageKey = 'ydi_gmx_scan_file_key_v1';
  static const _version = 2;
  static final _associatedData = utf8.encode('ydi-gmx-scan-v1');

  final GmxScanFile _file;
  final GmxSecureStorage _secureStorage;
  final Cipher _cipher;

  @override
  Future<ScanDataset?> load() async => (await _loadSnapshot())?.dataset;

  @override
  Future<GmxSyncState?> loadSyncState(String account) async =>
      (await _loadSnapshot())?.syncStates[account];

  Future<_GmxScanSnapshot?> _loadSnapshot() async {
    final encrypted = await _file.read();
    if (encrypted == null) return null;
    try {
      final key = await _readKey();
      if (key == null) throw const FormatException();
      final envelope = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(encrypted)) as Map,
      );
      final version = envelope['version'];
      if (version != 1 && version != _version) throw const FormatException();
      final secretBox = SecretBox(
        base64Decode(envelope['cipherText'] as String),
        nonce: base64Decode(envelope['nonce'] as String),
        mac: Mac(base64Decode(envelope['mac'] as String)),
      );
      final clearText = await _cipher.decrypt(
        secretBox,
        secretKey: SecretKey(key),
        aad: _associatedData,
      );
      final decoded = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(clearText)) as Map,
      );
      final snapshot = version == 1
          ? _GmxScanSnapshot(
              dataset: ScanDataset.fromJson(decoded),
              syncStates: const {},
            )
          : _GmxScanSnapshot.fromJson(decoded);
      final dataset = snapshot.dataset;
      if (!_containsOnlyGmxData(dataset)) throw const FormatException();
      if (!snapshot.syncStates.keys.every(_accountsIn(dataset).contains)) {
        throw const FormatException();
      }
      return snapshot;
    } catch (_) {
      await _clearBestEffort();
      return null;
    }
  }

  @override
  Future<void> save(ScanDataset? dataset) async {
    if (dataset == null ||
        (dataset.services.isEmpty && dataset.sourceFiles.isEmpty)) {
      await clear();
      return;
    }
    final existing = await _loadSnapshot();
    final retainedStates = <String, GmxSyncState>{
      for (final entry in (existing?.syncStates ?? const {}).entries)
        if (_accountsIn(dataset).contains(entry.key)) entry.key: entry.value,
    };
    await _saveSnapshot(
      _GmxScanSnapshot(dataset: dataset, syncStates: retainedStates),
    );
  }

  @override
  Future<void> saveWithSyncState(
    ScanDataset dataset,
    String account,
    GmxSyncState syncState,
  ) async {
    final existing = await _loadSnapshot();
    await _saveSnapshot(
      _GmxScanSnapshot(
        dataset: dataset,
        syncStates: {
          for (final entry in (existing?.syncStates ?? const {}).entries)
            if (_accountsIn(dataset).contains(entry.key))
              entry.key: entry.value,
          account: syncState,
        },
      ),
    );
  }

  Future<void> _saveSnapshot(_GmxScanSnapshot snapshot) async {
    if (!_containsOnlyGmxData(snapshot.dataset) ||
        !snapshot.syncStates.keys.every(
          _accountsIn(snapshot.dataset).contains,
        )) {
      throw ArgumentError('Encrypted GMX storage accepts only GMX data.');
    }
    final key = await _keyForWrite();
    final secretBox = await _cipher.encrypt(
      utf8.encode(jsonEncode(snapshot.toJson())),
      secretKey: SecretKey(key),
      aad: _associatedData,
    );
    final envelope = utf8.encode(
      jsonEncode({
        'version': _version,
        'nonce': base64Encode(secretBox.nonce),
        'cipherText': base64Encode(secretBox.cipherText),
        'mac': base64Encode(secretBox.mac.bytes),
      }),
    );
    await _file.write(envelope);
  }

  @override
  Future<void> removeAccount(String account) async {
    final current = await _loadSnapshot();
    if (current == null) return;
    final updated = current.dataset.withoutAccounts({account});
    if (updated.services.isEmpty && updated.sourceFiles.isEmpty) {
      await clear();
      return;
    }
    await _saveSnapshot(
      _GmxScanSnapshot(
        dataset: updated,
        syncStates: Map.from(current.syncStates)..remove(account),
      ),
    );
  }

  @override
  Future<void> clear() async {
    await _file.delete();
    await _secureStorage.delete(_keyStorageKey);
  }

  Future<List<int>?> _readKey() async {
    final encoded = await _secureStorage.read(_keyStorageKey);
    if (encoded == null) return null;
    final key = base64Decode(encoded);
    return key.length == 32 ? key : null;
  }

  Future<List<int>> _keyForWrite() async {
    final existing = await _readKey();
    if (existing != null) return existing;
    final secretKey = await _cipher.newSecretKey();
    final key = await secretKey.extractBytes();
    await _secureStorage.write(_keyStorageKey, base64Encode(key));
    final verified = await _readKey();
    if (verified == null || !_sameBytes(key, verified)) {
      await _clearBestEffort();
      throw StateError('Secure scan storage is unavailable.');
    }
    return key;
  }

  bool _containsOnlyGmxData(ScanDataset dataset) {
    final sourcesAreGmx = dataset.sourceFiles.every(
      (source) => source.toLowerCase().startsWith('gmx-imap:'),
    );
    final accountsAreGmx = dataset.accounts.every(
      (account) => account.toLowerCase().startsWith('gmx · '),
    );
    return sourcesAreGmx && accountsAreGmx;
  }

  Set<String> _accountsIn(ScanDataset dataset) => {
    ...dataset.accounts,
    ...dataset.sourceFiles
        .where((source) => source.toLowerCase().startsWith('gmx-imap:'))
        .map((source) => source.substring('gmx-imap:'.length)),
  };

  bool _sameBytes(List<int> first, List<int> second) {
    if (first.length != second.length) return false;
    var difference = 0;
    for (var index = 0; index < first.length; index++) {
      difference |= first[index] ^ second[index];
    }
    return difference == 0;
  }

  Future<void> _clearBestEffort() async {
    try {
      await _file.delete();
    } catch (_) {}
    try {
      await _secureStorage.delete(_keyStorageKey);
    } catch (_) {}
  }
}

class _GmxScanSnapshot {
  const _GmxScanSnapshot({required this.dataset, required this.syncStates});

  final ScanDataset dataset;
  final Map<String, GmxSyncState> syncStates;

  Map<String, Object> toJson() => {
    'dataset': dataset.toJson(),
    'syncStates': syncStates.map(
      (account, state) => MapEntry(account, state.toJson()),
    ),
  };

  factory _GmxScanSnapshot.fromJson(Map<String, dynamic> json) {
    final rawStates = Map<String, dynamic>.from(json['syncStates'] as Map);
    return _GmxScanSnapshot(
      dataset: ScanDataset.fromJson(
        Map<String, dynamic>.from(json['dataset'] as Map),
      ),
      syncStates: rawStates.map(
        (account, state) => MapEntry(
          account,
          GmxSyncState.fromJson(Map<String, dynamic>.from(state as Map)),
        ),
      ),
    );
  }
}
