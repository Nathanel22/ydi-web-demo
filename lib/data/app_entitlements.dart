/// Temporary prototype entitlement.
///
/// The real app will replace this compile-time switch with the verified
/// App Store / Play Store purchase state.
const bool hasYdiPlus = bool.fromEnvironment('YDI_PLUS', defaultValue: true);
