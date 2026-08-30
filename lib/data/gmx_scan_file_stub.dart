import 'encrypted_gmx_scan_store.dart';

GmxScanFile createGmxScanFile() => _UnsupportedGmxScanFile();

class _UnsupportedGmxScanFile implements GmxScanFile {
  @override
  Future<List<int>?> read() => throw UnsupportedError(
    'Encrypted GMX scan files are unavailable on this platform.',
  );

  @override
  Future<void> write(List<int> bytes) => throw UnsupportedError(
    'Encrypted GMX scan files are unavailable on this platform.',
  );

  @override
  Future<void> delete() => throw UnsupportedError(
    'Encrypted GMX scan files are unavailable on this platform.',
  );
}
