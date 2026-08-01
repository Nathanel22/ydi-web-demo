import '../data/demo_services.dart';
import '../models/scan_dataset.dart';

/// Compile-time switch for the read-only web demonstration.
const isPublicDemo = bool.fromEnvironment('YDI_PUBLIC_DEMO');

const publicDemoDataset = ScanDataset(
  services: DemoServices.all,
  sourceFiles: ['YDI Web-Demo'],
);
