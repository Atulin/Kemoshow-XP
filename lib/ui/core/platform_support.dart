import 'package:flutter/foundation.dart';

/// Whether the app is running on a desktop operating system, where a hardware
/// keyboard and its shortcuts can be expected.
///
/// Mobile builds hide keyboard references, although the shortcuts keep working
/// when a physical keyboard is attached.
bool get isDesktopPlatform => switch (defaultTargetPlatform) {
  TargetPlatform.windows ||
  TargetPlatform.linux ||
  TargetPlatform.macOS => true,
  TargetPlatform.android ||
  TargetPlatform.iOS ||
  TargetPlatform.fuchsia => false,
};
