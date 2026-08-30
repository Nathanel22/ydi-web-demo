import 'encrypted_gmx_scan_store.dart';
import 'gmx_scan_file_stub.dart'
    if (dart.library.io) 'gmx_scan_file_io.dart'
    as implementation;

GmxScanFile createGmxScanFile() => implementation.createGmxScanFile();
