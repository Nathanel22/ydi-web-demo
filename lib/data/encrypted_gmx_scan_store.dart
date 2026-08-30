import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../models/scan_dataset.dart';
import '../services/gmx_credential_manager.dart';

abstract interface class GmxScanFile {
  Future<List<int>?> read();

  Future<void> write(List<int> bytes);

  Future<void> delete();
}

abstract interface class GmxScanPersistence {
  Future<ScanDataset?> load();

  Future<void> save(ScanDataset? dataset);

  Future<void> removeAccount(String account);

  Future<void> clear();
}

class NoopGmxScanPersistence implements GmxScanPersistence {
  const NoopGmxScanPersistence();

  @override
  Future<ScanDataset?> load() async => null;

  @override
  Future<void> save(ScanDataset? dataset) async {}

  @override
  Future<void> removeAccount(String account) async {}

  @override
  Future<void> clear() async {}
}

class EncryptedGmxScanPersistence implements GmxScanPersistence {
  EncryptedGmxScanPersistence(this._file, this._secureStorage, {Cipher? cipher})
    : _cipher = cipher ?? AesGcm.with256bits();

  static const _keyStorageKey = 'ydi_gmx_scan_file_key_v1';
  static const _version = 1;
  static final _associatedData = utf8.encode('ydi-gmx-scan-v1');

  final GmxScanFile _file;
  final GmxSecureStorage _secureStorage;
  final Cipher _cipher;

  @override
  Future<ScanDataset?> load() async {
    final encrypted = await _file.read();
    if (encrypted == null) return null;
    try {
      final key = await _readKey();
      if (key == null) throw const FormatException();
      final envelope = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(encrypted)) as Map,
      );
      if (envelope['version'] != _version) throw const FormatException();
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
      final dataset = ScanDataset.fromJson(
        Map<String, dynamic>.from(jsonDecode(utf8.decode(clearText)) as Map),
      );
      if (!_containsOnlyGmxData(dataset)) throw const FormatException();
      return dataset;
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
    if (!_containsOnlyGmxData(dataset)) {
      throw ArgumentError('Encrypted GMX storage accepts only GMX data.');
    }
    final key = await _keyForWrite();
    final secretBox = await _cipher.encrypt(
      utf8.encode(jsonEncode(dataset.toJson())),
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
    final current = await load();
    if (current == null) return;
    final updated = current.withoutAccounts({account});
    await save(
      updated.services.isEmpty && updated.sourceFiles.isEmpty ? null : updated,
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
