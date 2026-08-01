import '../data/scan_data_store.dart';
import '../models/scan_dataset.dart';
import 'scan_csv_importer.dart';

const scanRefreshService = ScanRefreshService();

class ScanRefreshService {
  const ScanRefreshService();

  Future<ScanDataset?> pickRefreshAndSave() async {
    final incoming = await const ScanCsvImporter().pickAndImport();
    if (incoming == null) return null;

    final current = scanDataNotifier.value;
    final complete = current == null
        ? incoming
        : current.replacingAccountsWith(incoming);

    await scanDataStore.save(complete);
    return scanDataNotifier.value;
  }
}
