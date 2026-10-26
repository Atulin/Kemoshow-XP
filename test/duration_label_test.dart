import 'package:flutter_test/flutter_test.dart';
import 'package:kemoshow/ui/core/duration_label.dart';

void main() {
  test('formats durations under an hour as m:ss', () {
    expect(formatDuration(Duration.zero), '0:00');
    expect(formatDuration(const Duration(seconds: 5)), '0:05');
    expect(formatDuration(const Duration(minutes: 1, seconds: 5)), '1:05');
    expect(formatDuration(const Duration(minutes: 59, seconds: 59)), '59:59');
  });

  test('formats durations of an hour or more as h:mm:ss', () {
    expect(formatDuration(const Duration(hours: 1)), '1:00:00');
    expect(
      formatDuration(const Duration(hours: 2, minutes: 3, seconds: 4)),
      '2:03:04',
    );
  });
}
