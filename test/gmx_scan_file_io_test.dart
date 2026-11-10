import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ydi_app/data/gmx_scan_file_io.dart';

class _FailingStagedFile extends Fake implements File {
  _FailingStagedFile(this.file, {required this.failWrite});

  final File file;
  final bool failWrite;

  @override
  Future<File> writeAsBytes(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) async {
    if (failWrite) {
      await file.writeAsBytes(bytes.take(1).toList(), flush: flush);
      throw FileSystemException('Simulated partial write failure', file.path);
    }
    return file.writeAsBytes(bytes, mode: mode, flush: flush);
  }

  @override
  Future<File> rename(String newPath) async {
    throw FileSystemException('Simulated rename failure', file.path);
  }
}

void main() {
  late Directory support;
  late ApplicationSupportGmxScanFile store;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('ydi-gmx-file-test-');
    store = ApplicationSupportGmxScanFile(
      supportDirectory: () async => support,
    );
  });

  tearDown(() async {
    await support.delete(recursive: true);
  });

  test(
    'Successful rename replaces an existing snapshot without temp files',
    () async {
      await store.write([1, 2, 3]);
      await store.write([4, 5, 6]);
      expect(await store.read(), [4, 5, 6]);
      final entries = await support.list(recursive: true).toList();
      expect(entries.whereType<File>(), hasLength(1));
      expect(entries.whereType<Directory>(), hasLength(1));
    },
  );

  for (final failWrite in [true, false]) {
    test(
      '${failWrite ? 'Partial write' : 'Rename'} failure preserves the old file',
      () async {
        await store.write([1, 2, 3]);
        final failingStore = ApplicationSupportGmxScanFile(
          supportDirectory: () async => support,
          fileFactory: (path) =>
              _FailingStagedFile(File(path), failWrite: failWrite),
        );

        await expectLater(
          failingStore.write([4, 5, 6]),
          throwsA(isA<FileSystemException>()),
        );

        // A fresh reader must still see the complete previously committed file.
        final restarted = ApplicationSupportGmxScanFile(
          supportDirectory: () async => support,
        );
        expect(await restarted.read(), [1, 2, 3]);
        final entries = await support.list(recursive: true).toList();
        expect(entries.whereType<File>(), hasLength(1));
        expect(entries.whereType<Directory>(), hasLength(1));
        // The failed operation must not prevent a later successful update.
        await restarted.write([7, 8, 9]);
        expect(await restarted.read(), [7, 8, 9]);
      },
    );
  }
}
