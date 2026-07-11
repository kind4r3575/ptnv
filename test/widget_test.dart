import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ptnv/main.dart';
import 'package:ptnv/state/pod.dart';

void main() {
  final start = DateTime(2026, 5, 31, 20, 17);
  final s = PodSession(startedAt: start);

  group('PodSession lifecycle', () {
    test('on track within the first 72h', () {
      final now = start.add(const Duration(hours: 1));
      expect(s.statusAt(now), PodStatus.onTrack);
      expect(s.remaining(now), const Duration(hours: 71));
      expect(s.progress(now), greaterThan(0));
      expect(s.progress(now), lessThan(0.05));
    });

    test('grace between 72h and 80h', () {
      final now = start.add(const Duration(hours: 74, minutes: 18));
      expect(s.statusAt(now), PodStatus.grace);
      expect(s.graceLeft(now), const Duration(hours: 5, minutes: 42));
      expect(s.progress(now), 1.0);
    });

    test('late after 80h, with overdue time', () {
      final now = start.add(const Duration(hours: 83, minutes: 43));
      expect(s.statusAt(now), PodStatus.late);
      expect(s.overdue(now), const Duration(hours: 3, minutes: 43));
      expect(s.worn(now), const Duration(hours: 83, minutes: 43));
    });

    test('exactly 72h is grace (no longer on track)', () {
      expect(s.statusAt(start.add(const Duration(hours: 72))), PodStatus.grace);
    });

    test('exactly 80h is late', () {
      expect(s.statusAt(start.add(const Duration(hours: 80))), PodStatus.late);
    });

    test('negative durations are clamped to zero', () {
      final now = start.add(const Duration(hours: 100));
      expect(s.remaining(now), Duration.zero);
      expect(s.graceLeft(now), Duration.zero);
      expect(s.progress(now), 1.0);
    });
  });

  group('Add Pod sheet', () {
    testWidgets('+ opens the sheet and Start Pod begins a session', (tester) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const PodTrackerApp());
      // Let the initial boot (1.2s) complete so Home shows the active state.
      await tester.pump(const Duration(milliseconds: 1300));

      // Tap the center "+" in the bottom bar.
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400)); // sheet slide-up

      expect(find.text('Start New Pod'), findsOneWidget);
      expect(find.text('INSERTION SITE'), findsOneWidget);
      expect(find.text('Start Pod'), findsOneWidget);

      // Switching the insertion site must not throw.
      await tester.tap(find.text('Left arm'));
      await tester.pump();

      // Start the pod → sheet dismisses, Home shows the on-track countdown.
      await tester.tap(find.text('Start Pod'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400)); // sheet dismiss

      expect(find.text('Start New Pod'), findsNothing);
      expect(find.text('ON TRACK'), findsOneWidget);
    });

    testWidgets('Custom opens the start-time picker and returns to the sheet', (tester) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const PodTrackerApp());
      await tester.pump(const Duration(milliseconds: 1300));

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Open the Custom start-time picker.
      await tester.tap(find.text('Custom'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Start time'), findsOneWidget);
      expect(find.text('Set start time'), findsOneWidget);

      // Confirm → picker closes, back on the Add Pod sheet.
      await tester.tap(find.text('Set start time'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Start time'), findsNothing);
      expect(find.text('Start New Pod'), findsOneWidget);
    });

    testWidgets('Cancel dismisses the sheet without starting a pod', (tester) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const PodTrackerApp());
      await tester.pump(const Duration(milliseconds: 1300));

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Start New Pod'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Start New Pod'), findsNothing);
    });
  });

  group('End Pod sheet', () {
    Future<void> openSheet(WidgetTester tester) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const PodTrackerApp());
      await tester.pump(const Duration(milliseconds: 1300));

      // The Home "End Pod" button is the only "End Pod" text before opening.
      await tester.tap(find.text('End Pod'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('End Pod button opens the sheet and confirming ends the pod', (tester) async {
      await openSheet(tester);
      expect(find.text('End Pod Session'), findsOneWidget);
      expect(find.text('REASON FOR CHANGE'), findsOneWidget);

      // The sheet's red "End Pod" button is the last "End Pod" in the tree.
      await tester.tap(find.text('End Pod').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('End Pod Session'), findsNothing);
      expect(find.text('No Active Pod'), findsOneWidget);
    });

    testWidgets('Cancel keeps the pod active', (tester) async {
      await openSheet(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('End Pod Session'), findsNothing);
      expect(find.text('ON TRACK'), findsOneWidget);
    });

    testWidgets('END TIME Custom reuses the picker with End-time wording', (tester) async {
      await openSheet(tester);
      await tester.tap(find.text('Custom'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('End time'), findsOneWidget);
      expect(find.text('Set end time'), findsOneWidget);

      await tester.tap(find.text('Set end time'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('End time'), findsNothing);
      expect(find.text('End Pod Session'), findsOneWidget);
    });
  });

  group('Stock screen', () {
    Future<void> openStock(WidgetTester tester) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const PodTrackerApp());
      await tester.pump(const Duration(milliseconds: 1300));

      // Home shows an inventory icon in both the Stock info-row and the bottom
      // bar; the bottom-bar tab is the last one.
      await tester.tap(find.byIcon(Icons.inventory_2_outlined).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400)); // route transition
    }

    testWidgets('+/- adjust by 1 and days-of-supply tracks stock × 3', (tester) async {
      await openStock(tester);
      expect(find.text('CURRENT STOCK'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(find.text('≈ 18 days'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('stockPlus')));
      await tester.pump();
      expect(find.text('7'), findsOneWidget);
      expect(find.text('≈ 21 days'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('stockMinus')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('stockMinus')));
      await tester.pump();
      expect(find.text('5'), findsOneWidget);
      expect(find.text('≈ 15 days'), findsOneWidget);
    });

    testWidgets('See all opens the stock history', (tester) async {
      await openStock(tester);
      await tester.tap(find.text('See all ›'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Stock History'), findsOneWidget);
    });
  });

  group('History screen', () {
    Future<void> openHistory(WidgetTester tester) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const PodTrackerApp());
      await tester.pump(const Duration(milliseconds: 1300));

      await tester.tap(find.byIcon(Icons.history_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400)); // route transition
    }

    testWidgets('History tab opens the Log with seeded session cards', (tester) async {
      await openHistory(tester);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Jun 5, 2026'), findsOneWidget);
      expect(find.text('Ended early'), findsOneWidget);
      expect(find.text('12h 30m'), findsOneWidget);
      expect(find.text('Changed 59h 30m early'), findsOneWidget);
    });
  });

  group('Settings screen', () {
    Future<void> openSettings(WidgetTester tester) async {
      tester.view.physicalSize = const Size(440, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const PodTrackerApp());
      await tester.pump(const Duration(milliseconds: 1300));

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400)); // route transition
    }

    testWidgets('Settings tab opens the screen with its sections', (tester) async {
      await openSettings(tester);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Pod Settings'), findsOneWidget);
      expect(find.text('Default Pod Duration'), findsOneWidget);
      expect(find.text('Grace Period'), findsOneWidget);
    });

    testWidgets('Grace Period row cycles its value', (tester) async {
      await openSettings(tester);
      expect(find.text('2 hours'), findsOneWidget);

      await tester.tap(find.text('Grace Period'));
      await tester.pump();
      expect(find.text('4 hours'), findsOneWidget);
      expect(find.text('2 hours'), findsNothing);
    });

    testWidgets('a notification toggle flips', (tester) async {
      await openSettings(tester);
      final sound = find.widgetWithText(Row, 'Sound');
      final toggle = find.descendant(of: sound, matching: find.byType(Switch));
      expect(tester.widget<Switch>(toggle).value, isTrue);

      await tester.tap(toggle);
      await tester.pump();
      expect(tester.widget<Switch>(toggle).value, isFalse);
    });

    testWidgets('bottom bar cross-navigates from Settings to Stock', (tester) async {
      await openSettings(tester);
      expect(find.text('Settings'), findsOneWidget);

      // Tap the Stock tab in the bottom bar (the bar icon is the last one).
      await tester.tap(find.byIcon(Icons.inventory_2_outlined).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400)); // route transition

      // Previously this only showed "Coming soon"; now it opens the Stock screen.
      expect(find.text('Pod Stock'), findsOneWidget);
      expect(find.text('CURRENT STOCK'), findsOneWidget);
    });
  });
}
