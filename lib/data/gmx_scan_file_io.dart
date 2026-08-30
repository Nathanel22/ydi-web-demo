import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'encrypted_gmx_scan_store.dart';

GmxScanFile createGmxScanFile() => ApplicationSupportGmxScanFile();

class ApplicationSupportGmxScanFile implements GmxScanFile {
  static const _directoryName = 'ydi_private';
  static const _fileName = 'gmx_scan_v1.enc';

  @override
  Future<List<int>?> read() async {
    final file = await _file();
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  @override
  Future<void> write(List<int> bytes) async {
    final file = await _file(createDirectory: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsBytes(bytes, flush: true);
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }

  @override
  Future<void> delete() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
    final temporary = File('${file.path}.tmp');
    if (await temporary.exists()) await temporary.delete();
  }

  Future<File> _file({bool createDirectory = false}) async {
    final supportDirectory = await getApplicationSupportDirectory();
    final directory = Directory('${supportDirectory.path}/$_directoryName');
    if (createDirectory && !await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File('${directory.path}/$_fileName');
  }
}
