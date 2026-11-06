import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ptnv/widgets/app_switch.dart';
import 'package:ptnv/widgets/pressable.dart';

void main() {
  late List<MethodCall> platformCalls;

  setUp(() {
    platformCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platformCalls.add(call);
      return null;
    });
  });

  int haptics() => platformCalls.where((c) => c.method == 'HapticFeedback.vibrate').length;

  Future<void> pumpButton(WidgetTester tester, {VoidCallback? onTap, bool reduceMotion = false}) {
    return tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Center(
          child: Pressable(
            onTap: onTap,
            child: const SizedBox(width: 120, height: 48, child: Text('Tap me')),
          ),
        ),
      ),
    ));
  }

  double scale(WidgetTester tester) => tester
      .widget<ScaleTransition>(
          find.descendant(of: find.byType(Pressable), matching: find.byType(ScaleTransition)))
      .scale
      .value;

  double opacity(WidgetTester tester) => tester
      .widget<FadeTransition>(
          find.descendant(of: find.byType(Pressable), matching: find.byType(FadeTransition)))
      .opacity
      .value;

  testWidgets('shrinks and fades while pressed, springs back, taps once with a haptic',
      (tester) async {
    var taps = 0;
    await pumpButton(tester, onTap: () => taps++);

    final gesture = await tester.startGesture(tester.getCenter(find.text('Tap me')));
    await tester.pump(const Duration(milliseconds: 150)); // past the tap-down delay
    await tester.pump(const Duration(milliseconds: 150)); // press-in finished
    expect(scale(tester), closeTo(0.96, 0.001));
    expect(opacity(tester), closeTo(0.7, 0.001));
    expect(taps, 0, reason: 'nothing fires until the finger lifts');

    await gesture.up();
    await tester.pumpAndSettle();
    expect(scale(tester), 1.0);
    expect(opacity(tester), 1.0);
    expect(taps, 1);
    expect(haptics(), 1);
  });

  testWidgets('release springs back past full size, then settles at exactly 100%',
      (tester) async {
    await pumpButton(tester, onTap: () {});

    final gesture = await tester.startGesture(tester.getCenter(find.text('Tap me')));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
    expect(scale(tester), closeTo(0.96, 0.001));

    await gesture.up();
    var peak = 0.0;
    var frames = 0;
    for (; frames < 30 && (frames == 0 || tester.hasRunningAnimations); frames++) {
      await tester.pump(const Duration(milliseconds: 8));
      if (scale(tester) > peak) peak = scale(tester);
      expect(opacity(tester), lessThanOrEqualTo(1.0));
    }
    expect(peak, closeTo(1.02, 0.003), reason: 'bounces to ~102%');
    expect(frames * 8, lessThanOrEqualTo(PressRelease.duration.inMilliseconds + 16));
    expect(scale(tester), 1.0);
    expect(opacity(tester), 1.0);
  });

  testWidgets('a quick tap still shows a visible press', (tester) async {
    await pumpButton(tester, onTap: () {});

    await tester.tap(find.text('Tap me')); // down + up in the same frame
    await tester.pump(); // the press animation starts on this frame
    await tester.pump(const Duration(milliseconds: 60));
    expect(scale(tester), lessThan(0.99));

    await tester.pumpAndSettle();
    expect(scale(tester), 1.0);
  });

  testWidgets("a quick tap's action waits until the press has been on screen", (tester) async {
    var taps = 0;
    await pumpButton(tester, onTap: () => taps++);

    await tester.tap(find.text('Tap me'));
    expect(haptics(), 1, reason: 'the tick is immediate');
    expect(taps, 0, reason: 'a screen opened now would hide the press');

    await tester.pump(); // press-in starts
    await tester.pump(Pressable.pressInDuration);
    expect(taps, 0, reason: 'still pressing in');
    await tester.pump(const Duration(milliseconds: 16)); // the next frame: press-in done
    expect(taps, 1);
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('rapid taps are all delivered, in order', (tester) async {
    var taps = 0;
    await pumpButton(tester, onTap: () => taps++);

    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Tap me'));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.pumpAndSettle();
    expect(taps, 4);
    expect(haptics(), 4);
  });

  testWidgets('dragging off the button cancels without tapping', (tester) async {
    var taps = 0;
    await pumpButton(tester, onTap: () => taps++);

    final gesture = await tester.startGesture(tester.getCenter(find.text('Tap me')));
    await tester.pump(const Duration(milliseconds: 150));
    await gesture.moveBy(const Offset(0, 200));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(taps, 0);
    expect(haptics(), 0);
    expect(scale(tester), 1.0);
  });

  testWidgets('disabled: no press, no haptic', (tester) async {
    await pumpButton(tester, onTap: null);

    final gesture = await tester.startGesture(tester.getCenter(find.text('Tap me')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(scale(tester), 1.0);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(haptics(), 0);
  });

  testWidgets('reduce motion: no shrink, but the tap and haptic still happen', (tester) async {
    var taps = 0;
    await pumpButton(tester, onTap: () => taps++, reduceMotion: true);

    final gesture = await tester.startGesture(tester.getCenter(find.text('Tap me')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(scale(tester), 1.0);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(haptics(), 1);
  });

  testWidgets('a row in a scrolling list that opens a screen shows its press first',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ListView(children: [
            Pressable(
              onTap: () => Navigator.of(context).push(PageRouteBuilder<void>(
                transitionDuration: const Duration(milliseconds: 200),
                pageBuilder: (_, _, _) => const Scaffold(body: Text('Next page')),
                transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
              )),
              child: const SizedBox(height: 56, child: Text('Settings row')),
            ),
          ]),
        ),
      ),
    ));

    await tester.tap(find.text('Settings row')); // quick tap: down + up together
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50)); // mid press-in
    expect(find.text('Next page'), findsNothing, reason: 'the row is still visibly pressed');
    expect(scale(tester), lessThan(0.97));

    await tester.pumpAndSettle();
    expect(find.text('Next page'), findsOneWidget);
  });

  testWidgets('a switch toggle ticks and pulses', (tester) async {
    var value = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: StatefulBuilder(
            builder: (context, setState) =>
                AppSwitch(value: value, onChanged: (v) => setState(() => value = v)),
          ),
        ),
      ),
    ));
    double switchScale() => tester
        .widget<ScaleTransition>(
            find.descendant(of: find.byType(AppSwitch), matching: find.byType(ScaleTransition)))
        .scale
        .value;

    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(value, isTrue);
    expect(haptics(), 1);
    expect(switchScale(), lessThan(0.97));

    var peak = 0.0;
    for (var i = 0; i < 30 && tester.hasRunningAnimations; i++) {
      await tester.pump(const Duration(milliseconds: 8));
      if (switchScale() > peak) peak = switchScale();
    }
    expect(peak, closeTo(1.03, 0.005), reason: 'bounces to ~103%');
    await tester.pumpAndSettle();
    expect(switchScale(), 1.0);
  });
}
