import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'encrypted_gmx_scan_store.dart';

GmxScanFile createGmxScanFile() => ApplicationSupportGmxScanFile();

class ApplicationSupportGmxScanFile implements GmxScanFile {
  ApplicationSupportGmxScanFile({
    Future<Directory> Function()? supportDirectory,
    File Function(String path)? fileFactory,
  }) : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
       _fileFactory = fileFactory ?? File.new;

  final Future<Directory> Function() _supportDirectory;
  final File Function(String path) _fileFactory;

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
    // A unique staging directory prevents simultaneous writes sharing a temp
    // file. Keeping it beside the target permits an atomic rename on iOS/POSIX.
    final staging = await file.parent.createTemp('.gmx-scan-');
    try {
      final temporary = _fileFactory('${staging.path}/snapshot.tmp');
      await temporary.writeAsBytes(bytes, flush: true);
      // Never delete the last valid snapshot before replacement. If the
      // platform cannot replace the target, fail while preserving that file.
      await temporary.rename(file.path);
    } finally {
      try {
        await staging.delete(recursive: true);
      } on FileSystemException {
        // Cleanup failure must not hide the outcome of the write/rename.
      }
    }
  }

  @override
  Future<void> delete() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
    final temporary = File('${file.path}.tmp');
    if (await temporary.exists()) await temporary.delete();
  }

  Future<File> _file({bool createDirectory = false}) async {
    final supportDirectory = await _supportDirectory();
    final directory = Directory('${supportDirectory.path}/$_directoryName');
    if (createDirectory && !await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File('${directory.path}/$_fileName');
  }
}
