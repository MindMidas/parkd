import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/core/theme/app_motion.dart';
import 'package:parkd/core/utils/app_feedback.dart';
import 'package:parkd/core/widgets/app_buttons.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets('AppFeedback skips when animations are disabled', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: buildTestApp(
          Builder(
            builder: (context) {
              // Must not throw when haptics are skipped.
              AppFeedback.light(context);
              AppFeedback.selection(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  });

  testWidgets('AppPrimaryButton press drives AnimatedScale below 1', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        AppPrimaryButton(label: 'Continue', onPressed: () {}),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(FilledButton)),
    );
    await tester.pump(AppMotion.press);

    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.scale, AppMotion.pressScale);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      1.0,
    );
  });
}
