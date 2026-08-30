import '../data/demo_services.dart';
import '../models/scan_dataset.dart';

/// Compile-time switch for the read-only web demonstration.
const isPublicDemo = bool.fromEnvironment('YDI_PUBLIC_DEMO');

/// Compile-time opt-in for the temporary private GMX test path.
///
/// Real GMX access stays disabled unless a build explicitly enables it. A
/// public demo can never enable real GMX access, even if both flags are set.
const allowRealGmxTest = bool.fromEnvironment('YDI_ALLOW_REAL_GMX_TEST');

const isRealGmxTestEnabled = !isPublicDemo && allowRealGmxTest;

class RealGmxAccessPolicy {
  const RealGmxAccessPolicy({
    required this.isPublicDemo,
    required this.allowRealGmxTest,
  });

  final bool isPublicDemo;
  final bool allowRealGmxTest;

  bool get isAllowed => !isPublicDemo && allowRealGmxTest;

  void ensureAllowed() {
    if (!isAllowed) {
      throw StateError('Real GMX access is disabled for this build.');
    }
  }
}

const realGmxAccessPolicy = RealGmxAccessPolicy(
  isPublicDemo: isPublicDemo,
  allowRealGmxTest: allowRealGmxTest,
);

const publicDemoDataset = ScanDataset(
  services: DemoServices.all,
  sourceFiles: ['YDI Web-Demo'],
);
