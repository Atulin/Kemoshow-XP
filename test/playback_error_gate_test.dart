import 'package:flutter_test/flutter_test.dart';
import 'package:kemoshow/ui/features/slideshow/views/widgets/playback_error_gate.dart';

void main() {
  group('PlaybackErrorGate', () {
    late List<String> shown;
    late int cleared;

    PlaybackErrorGate buildGate({Duration? grace}) {
      return PlaybackErrorGate(
        grace: grace ?? const Duration(milliseconds: 500),
        onShow: shown.add,
        onClear: () => cleared++,
      );
    }

    setUp(() {
      shown = [];
      cleared = 0;
    });

    testWidgets('holds an error back for the grace period', (tester) async {
      final gate = buildGate();
      addTearDown(gate.dispose);

      gate.report('codec not found');
      await tester.pump(const Duration(milliseconds: 499));

      expect(shown, isEmpty);
      expect(gate.hasPending, isTrue);

      await tester.pump(const Duration(milliseconds: 1));

      expect(shown, ['codec not found']);
      expect(gate.hasPending, isFalse);
      expect(gate.shownError, 'codec not found');
    });

    testWidgets('drops a pending error when playback recovers', (tester) async {
      final gate = buildGate();
      addTearDown(gate.dispose);

      gate.report('codec not found');
      gate.recovered();
      await tester.pump(const Duration(seconds: 1));

      expect(shown, isEmpty);
      expect(cleared, 0);
    });

    testWidgets('dismisses an error that is already visible', (tester) async {
      final gate = buildGate();
      addTearDown(gate.dispose);

      gate.report('codec not found');
      await tester.pump(const Duration(milliseconds: 500));
      expect(shown, ['codec not found']);

      gate.recovered();

      expect(gate.shownError, isNull);
      expect(cleared, 1);
      gate.recovered();
      expect(cleared, 1);
    });

    testWidgets('restarts the grace period for repeated errors', (
      tester,
    ) async {
      final gate = buildGate();
      addTearDown(gate.dispose);

      gate.report('first');
      await tester.pump(const Duration(milliseconds: 400));
      gate.report('second');
      await tester.pump(const Duration(milliseconds: 400));

      expect(shown, isEmpty);

      await tester.pump(const Duration(milliseconds: 100));

      expect(shown, ['second']);
    });

    testWidgets('ignores empty error messages', (tester) async {
      final gate = buildGate();
      addTearDown(gate.dispose);

      gate.report('');
      await tester.pump(const Duration(seconds: 1));

      expect(shown, isEmpty);
      expect(gate.hasPending, isFalse);
    });
  });
}
