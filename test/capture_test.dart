import 'package:flutter_test/flutter_test.dart';
import 'package:penny/services/capture.dart';

void main() {
  group('shouldAskForCapture', () {
    test('says nothing when everything is already granted', () {
      // The regression this exists for: the old check also required capture to
      // be *running*, which is false during the first frame, so the explainer
      // appeared on every single launch.
      expect(
        shouldAskForCapture(
            overlay: true, notifications: true, askedBefore: false),
        isFalse,
      );
    });

    test('asks when a permission is missing', () {
      expect(
        shouldAskForCapture(
            overlay: false, notifications: true, askedBefore: false),
        isTrue,
      );
      expect(
        shouldAskForCapture(
            overlay: true, notifications: false, askedBefore: false),
        isTrue,
      );
    });

    test('takes "Later" for an answer', () {
      expect(
        shouldAskForCapture(
            overlay: false, notifications: false, askedBefore: true),
        isFalse,
        reason: 'Overview and Profile both still offer to turn it on',
      );
    });
  });
}
