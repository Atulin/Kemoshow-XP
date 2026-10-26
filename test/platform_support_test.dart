import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kemoshow/ui/core/platform_support.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('reports desktop only on desktop platforms', () {
    for (final platform in [
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.macOS,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      expect(isDesktopPlatform, isTrue, reason: '$platform');
    }

    for (final platform in [
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.fuchsia,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      expect(isDesktopPlatform, isFalse, reason: '$platform');
    }
  });
}
