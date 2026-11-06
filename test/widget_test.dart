import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ptnv/main.dart';
import 'package:ptnv/state/pod.dart';
import 'package:ptnv/widgets/home_parts.dart';
import 'package:ptnv/widgets/pressable.dart';

/// Taps [finder] and lets the button's press play out, so its action has run
/// by the time this returns — a [Pressable]'s action waits until its press has
/// been on screen. Ends on a zero-length frame, so any animation the action
/// started (a sheet sliding up, a route fading in) has begun, as a plain
/// `tap` + `pump()` used to leave things.
Future<void> tapButton(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(Pressable.pressInDuration + const Duration(milliseconds: 16));
  await tester.pump();
}

void main() {
  final start = DateTime(2026, 5, 31, 20, 17);
  final s = PodSession(startedAt: start);

  group('PodSession lifecycle', () {
    test('on track within the first 72h', () {
      final now = start.add(const Duration(hours: 1));
      expect(s.statusAt(now), TrackedItemStatus.onTrack);
      expect(s.remaining(now), const Duration(hours: 71));
      expect(s.progress(now), greaterThan(0));
      expect(s.progress(now), lessThan(0.05));
    });

    test('grace between 72h and 80h', () {
      final now = start.add(const Duration(hours: 74, minutes: 18));
      expect(s.statusAt(now), TrackedItemStatus.grace);
      expect(s.graceLeft(now), const Duration(hours: 5, minutes: 42));
      expect(s.progress(now), 1.0);
    });

    test('late after 80h, with overdue time', () {
      final now = start.add(const Duration(hours: 83, minutes: 43));
      expect(s.statusAt(now), TrackedItemStatus.late);
      expect(s.overdue(now), const Duration(hours: 3, minutes: 43));
      expect(s.worn(now), const Duration(hours: 83, minutes: 43));
    });

    test('exactly 72h is grace (no longer on track)', () {
      expect(s.statusAt(start.add(const Duration(hours: 72))), TrackedItemStatus.grace);
    });

    test('exactly 80h is late', () {
      expect(s.statusAt(start.add(const Duration(hours: 80))), TrackedItemStatus.late);
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
      await tapButton(tester, find.byIcon(Icons.add_rounded));
      await tester.pump(const Duration(milliseconds: 400)); // sheet slide-up

      expect(find.text('Start New Pod'), findsOneWidget);
      expect(find.text('INSERTION SITE'), findsOneWidget);
      expect(find.text('Start Pod'), findsOneWidget);

      // Switching the insertion site must not throw.
      await tapButton(tester, find.text('Left arm'));

      // Start the pod → sheet dismisses, Home shows the on-track countdown.
      await tapButton(tester, find.text('Start Pod'));
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

      await tapButton(tester, find.byIcon(Icons.add_rounded));
      await tester.pump(const Duration(milliseconds: 400));

      // Open the Custom start-time picker.
      await tapButton(tester, find.text('Custom'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Start time'), findsOneWidget);
      expect(find.text('Set start time'), findsOneWidget);

      // Confirm → picker closes, back on the Add Pod sheet.
      await tapButton(tester, find.text('Set start time'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Start time'), findsNothing);
      expect(find.text('Start New Pod'), findsOneWidget);
    });

    testWidgets('starting a new pod while one is active asks to confirm', (tester) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const PodTrackerApp());
      await tester.pump(const Duration(milliseconds: 1300));

      // Start a first pod so one is active.
      await tapButton(tester, find.byIcon(Icons.add_rounded));
      await tester.pump(const Duration(milliseconds: 400));
      await tapButton(tester, find.text('Abdomen'));
      await tapButton(tester, find.text('Start Pod'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('ON TRACK'), findsOneWidget);

      // Open the sheet again and try to start another → confirmation appears.
      await tapButton(tester, find.byIcon(Icons.add_rounded));
      await tester.pump(const Duration(milliseconds: 400));
      await tapButton(tester, find.text('Left arm'));
      await tapButton(tester, find.text('Start Pod'));
      await tester.pump(const Duration(milliseconds: 300)); // dialog fade-in
      expect(find.text('Start a new pod?'), findsOneWidget);

      // Cancel → dialog closes, still on the sheet, no replacement happened.
      // (The sheet has its own "Cancel" behind the dialog; tap the dialog's,
      // which is the topmost/last one.)
      await tapButton(tester, find.text('Cancel').last);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Start a new pod?'), findsNothing);
      expect(find.text('Start New Pod'), findsOneWidget); // sheet still open

      // Confirm this time → sheet closes and Home shows the new pod on track.
      await tapButton(tester, find.text('Start Pod'));
      await tester.pump(const Duration(milliseconds: 300));
      await tapButton(tester, find.text('Yes, start new'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Start New Pod'), findsNothing);
      expect(find.text('ON TRACK'), findsOneWidget);
    });

    testWidgets('Cancel dismisses the sheet without starting a pod', (tester) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const PodTrackerApp());
      await tester.pump(const Duration(milliseconds: 1300));

      await tapButton(tester, find.byIcon(Icons.add_rounded));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Start New Pod'), findsOneWidget);

      await tapButton(tester, find.text('Cancel'));
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
      await tapButton(tester, find.text('End Pod'));
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('End Pod button opens the sheet and confirming ends the pod', (tester) async {
      await openSheet(tester);
      expect(find.text('End Pod Session'), findsOneWidget);
      expect(find.text('REASON FOR CHANGE'), findsOneWidget);

      // The sheet's red "End Pod" button is the last "End Pod" in the tree.
      await tapButton(tester, find.text('End Pod').last);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('End Pod Session'), findsNothing);
      expect(find.text('No Active Pod'), findsOneWidget);
    });

    testWidgets('Cancel keeps the pod active', (tester) async {
      await openSheet(tester);
      await tapButton(tester, find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('End Pod Session'), findsNothing);
      expect(find.text('ON TRACK'), findsOneWidget);
    });

    testWidgets('END TIME Custom reuses the picker with End-time wording', (tester) async {
      await openSheet(tester);
      await tapButton(tester, find.text('Custom'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('End time'), findsOneWidget);
      expect(find.text('Set end time'), findsOneWidget);

      await tapButton(tester, find.text('Set end time'));
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
      await tapButton(tester, find.byIcon(Icons.inventory_2_outlined).last);
      await tester.pump(const Duration(milliseconds: 400)); // route transition
    }

    testWidgets('+/- adjust by 1 and days-of-supply tracks stock × 3', (tester) async {
      await openStock(tester);
      expect(find.text('CURRENT STOCK'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(find.text('≈ 18 days'), findsOneWidget);

      await tapButton(tester, find.byKey(const ValueKey('stockPlus')));
      expect(find.text('7'), findsOneWidget);
      expect(find.text('≈ 21 days'), findsOneWidget);

      await tapButton(tester, find.byKey(const ValueKey('stockMinus')));
      await tapButton(tester, find.byKey(const ValueKey('stockMinus')));
      expect(find.text('5'), findsOneWidget);
      expect(find.text('≈ 15 days'), findsOneWidget);
    });

    testWidgets('See all opens the stock history', (tester) async {
      await openStock(tester);
      await tapButton(tester, find.text('See all ›'));
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

      await tapButton(tester, find.byIcon(Icons.history_rounded));
      await tester.pump(const Duration(milliseconds: 400)); // route transition
    }

    testWidgets('History tab opens the Log with seeded session cards', (tester) async {
      await openHistory(tester);
      // Title only — the bottom bar's "History" label is a second match.
      expect(find.widgetWithText(AppBarWave, 'History'), findsOneWidget);
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

      await tapButton(tester, find.byIcon(Icons.settings_outlined));
      await tester.pump(const Duration(milliseconds: 400)); // route transition
    }

    testWidgets('Settings tab opens the screen with its sections', (tester) async {
      await openSettings(tester);
      expect(find.widgetWithText(AppBarWave, 'Settings'), findsOneWidget);
      expect(find.text('Pod Settings'), findsOneWidget);
      expect(find.text('Default Pod Duration'), findsOneWidget);
      expect(find.text('Grace Period'), findsOneWidget);
    });

    testWidgets('Grace Period row cycles its value', (tester) async {
      await openSettings(tester);
      expect(find.text('2 hours'), findsOneWidget);

      await tapButton(tester, find.text('Grace Period'));
      expect(find.text('4 hours'), findsOneWidget);
      expect(find.text('2 hours'), findsNothing);
    });

    testWidgets('a notification toggle flips', (tester) async {
      await openSettings(tester);
      final sound = find.widgetWithText(Row, 'Sound');
      final toggle = find.descendant(of: sound, matching: find.byType(Switch));
      expect(tester.widget<Switch>(toggle).value, isTrue);

      await tapButton(tester, toggle);
      expect(tester.widget<Switch>(toggle).value, isFalse);
    });

    testWidgets('bottom bar cross-navigates from Settings to Stock', (tester) async {
      await openSettings(tester);
      expect(find.widgetWithText(AppBarWave, 'Settings'), findsOneWidget);

      // Tap the Stock tab in the bottom bar (the bar icon is the last one).
      await tapButton(tester, find.byIcon(Icons.inventory_2_outlined).last);
      await tester.pump(const Duration(milliseconds: 400)); // route transition

      // Previously this only showed "Coming soon"; now it opens the Stock screen.
      expect(find.text('Pod Stock'), findsOneWidget);
      expect(find.text('CURRENT STOCK'), findsOneWidget);
    });
  });
}
