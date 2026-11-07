import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ptnv/screens/history_screen.dart';
import 'package:ptnv/state/pod.dart';
import 'package:ptnv/state/root_tabs.dart';
import 'package:ptnv/widgets/pressable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A finished session as `endPod` would record it.
SessionRecord _record(
  DateTime started,
  DateTime ended, {
  String site = 'Abdomen',
  String reason = 'Planned',
  int plannedHours = 72,
  int? graceHours = 8,
}) {
  final worn = ended.difference(started);
  return SessionRecord(
    date: ended,
    outcome: SessionRecord.outcomeFor(
      started: started,
      ended: ended,
      plannedHours: plannedHours,
      graceHours: graceHours ?? 8,
    ),
    started: started,
    ended: ended,
    worn: worn,
    placedOn: site,
    whyChanged: reason,
    remindersSent: 1,
    changes: SessionRecord.formatChanges(worn, Duration(hours: plannedHours)),
    plannedHours: plannedHours,
    graceHours: graceHours,
  );
}

/// A controller whose saved history is [history], newest first.
Future<PodController> _controller(List<SessionRecord> history) async {
  SharedPreferences.setMockInitialValues({
    'history': jsonEncode(history.map((e) => e.toJson()).toList()),
  });
  final c = PodController();
  addTearDown(c.dispose);
  await c.loaded;
  return c;
}

/// Taps a [Pressable] and lets its press play out so its action has run.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(Pressable.pressInDuration + const Duration(milliseconds: 16));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final d1 = DateTime(2026, 10, 1, 8);
  final d2 = DateTime(2026, 10, 4, 8); // d1 + 72h
  final d3 = DateTime(2026, 10, 4, 9);
  final d4 = DateTime(2026, 10, 7, 9);

  group('SessionRecord.withEdits', () {
    test('a new end time recalculates worn, badge, changes and date', () {
      final r = _record(d1, d2); // exactly 72h: completed
      expect(r.outcome, HistoryOutcome.completed);

      final early = r.withEdits(ended: d1.add(const Duration(hours: 50)), fallbackGraceHours: 2);
      expect(early.worn, const Duration(hours: 50));
      expect(early.outcome, HistoryOutcome.endedEarly);
      expect(early.changes, '-22h 0m');
      expect(early.date, d1.add(const Duration(hours: 50)));
      expect(early.id, r.id, reason: 'id survives the edit');
      expect(early.graceHours, 8, reason: "the record's own grace wins over the fallback");

      final late = r.withEdits(ended: d1.add(const Duration(hours: 81)), fallbackGraceHours: 2);
      expect(late.outcome, HistoryOutcome.wornTooLong);
      expect(late.changes, '+9h 0m');
    });

    test('a new planned time recalculates the badge', () {
      final r = _record(d1, d2); // 72h worn
      final edited = r.withEdits(plannedHours: 96, fallbackGraceHours: 8);
      expect(edited.outcome, HistoryOutcome.endedEarly);
      expect(edited.changes, '-24h 0m');
    });

    test('changing only the site keeps the stored badge, even with no stored grace', () {
      // 75h worn on a record saved before grace was stored: completed with
      // its original 8h grace; a 2h fallback would call it worn too long.
      final r = _record(d1, d1.add(const Duration(hours: 75)), graceHours: null);
      final edited = r.withEdits(placedOn: 'Left arm', fallbackGraceHours: 2);
      expect(edited.placedOn, 'Left arm');
      expect(edited.outcome, HistoryOutcome.completed);
      expect(edited.worn, r.worn);
      expect(edited.changes, r.changes);
      expect(edited.date, r.date);
    });

    test('records saved before id/edited/grace existed load with defaults', () {
      final json = _record(d1, d2).toJson()
        ..remove('id')
        ..remove('edited')
        ..remove('graceHours');
      final r = SessionRecord.fromJson(json);
      expect(r.id, '${d1.toIso8601String()}|${d2.toIso8601String()}');
      expect(r.edited, isFalse);
      expect(r.graceHours, isNull);
    });
  });

  group('PodController history editing', () {
    test('saving an edit marks it edited, and that survives a save/load', () async {
      final c = await _controller([_record(d1, d2)]);
      final original = c.history.single;
      c.updateHistoryRecord(
        original,
        original.withEdits(whyChanged: 'Leak', remindersSent: 3, fallbackGraceHours: 8),
      );
      final saved = c.history.single;
      expect(saved.whyChanged, 'Leak');
      expect(saved.remindersSent, 3);
      expect(saved.edited, isTrue);
      expect(saved.id, original.id);

      final reloaded = SessionRecord.fromJson(
          jsonDecode(jsonEncode(saved.toJson())) as Map<String, dynamic>);
      expect(reloaded.edited, isTrue);
      expect(reloaded.id, original.id);
      expect(reloaded.whyChanged, 'Leak');
    });

    test('an edit that changes nothing is not saved and not marked edited', () async {
      final c = await _controller([_record(d1, d2)]);
      final original = c.history.single;
      c.updateHistoryRecord(original, original.withEdits(fallbackGraceHours: 8));
      expect(identical(c.history.single, original), isTrue);
      expect(c.history.single.edited, isFalse);
    });

    test('moving the end time keeps the list newest first', () async {
      final c = await _controller([_record(d3, d4), _record(d1, d2)]);
      final older = c.history[1];
      final later = d4.add(const Duration(hours: 1));
      c.updateHistoryRecord(older, older.withEdits(ended: later, fallbackGraceHours: 8));
      expect(c.history.map((r) => r.ended), [later, d4]);
      expect(c.history.first.edited, isTrue);
    });

    test('delete then restore puts the record back where it was', () async {
      final c = await _controller([_record(d3, d4), _record(d1, d2)]);
      final second = c.history[1];
      final index = c.deleteHistoryRecord(second);
      expect(index, 1);
      expect(c.history.map((r) => r.ended), [d4]);

      c.restoreHistoryRecord(second, index);
      expect(c.history.map((r) => r.ended), [d4, d2]);
      expect(identical(c.history[1], second), isTrue);

      c.restoreHistoryRecord(second, index); // a second undo does nothing
      expect(c.history, hasLength(2));
    });

    test("a merge keeps one copy of a session edited on this phone", () async {
      final c = await _controller([_record(d1, d2)]);
      final original = c.history.single;
      c.updateHistoryRecord(
        original,
        original.withEdits(ended: d2.add(const Duration(hours: 2)), fallbackGraceHours: 8),
      );

      // The backup still holds the unedited copy of the same session.
      c.mergeFromBackupJson({
        'history': [_record(d1, d2).toJson()],
      });
      expect(c.history, hasLength(1));
      expect(c.history.single.edited, isTrue);
      expect(c.history.single.ended, d2.add(const Duration(hours: 2)));
    });
  });

  group('History screen', () {
    Future<PodController> pumpHistory(WidgetTester tester, List<SessionRecord> history) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final c = await _controller(history);
      final tabs = RootTabController()..index = 3;
      await tester.pumpWidget(MaterialApp(home: HistoryScreen(controller: c, tabs: tabs)));
      await tester.pump();
      return c;
    }

    /// Lets the debounced save, notification resync and any snack bar finish
    /// so no timers are left pending when the test ends.
    Future<void> settleTimers(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('holding a card enters edit mode with pencils, Cancel and Save',
        (tester) async {
      await pumpHistory(tester, [_record(d1, d2)]);
      expect(find.text('Save'), findsNothing);
      expect(find.byIcon(Icons.edit_rounded), findsNothing);

      await tester.longPress(find.text('Abdomen'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      // STARTED, ENDED, PLANNED, PLACED ON, WHY CHANGED, REMINDERS.
      expect(find.byIcon(Icons.edit_rounded), findsNWidgets(6));

      await _tap(tester, find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Save'), findsNothing);
      await settleTimers(tester);
    });

    testWidgets('the card swings once as edit mode starts and once as it ends',
        (tester) async {
      /// The card's current tilt: sin(angle) of the rotation wrapped around it
      /// (the press-down scale around it has no rotation part).
      double tilt() => tester
          .widgetList<Transform>(find.ancestor(
            of: find.byType(SessionHistoryCard),
            matching: find.byType(Transform),
          ))
          .map((t) => t.transform.entry(1, 0))
          .firstWhere((v) => v != 0, orElse: () => 0);

      await pumpHistory(tester, [_record(d1, d2)]);
      expect(tilt(), 0);

      await tester.longPress(find.text('Abdomen'));
      await tester.pump(); // swing starts
      await tester.pump(const Duration(milliseconds: 100));
      expect(tilt(), isNot(0), reason: 'swinging as edit mode starts');
      await tester.pump(const Duration(milliseconds: 600));
      expect(tilt(), 0, reason: 'settled');
      await tester.pump(const Duration(seconds: 2));
      expect(tilt(), 0, reason: 'and stays still while editing');
      expect(find.text('Save'), findsOneWidget);

      // Change something and save: the saved card swings once more.
      await _tap(tester, find.text('WHY CHANGED'));
      await tester.pump(const Duration(milliseconds: 400));
      await _tap(tester, find.text('Leak'));
      await tester.pump(const Duration(milliseconds: 400));
      await _tap(tester, find.text('Save'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tilt(), isNot(0), reason: 'swinging as edit mode ends');
      await tester.pump(const Duration(milliseconds: 600));
      expect(tilt(), 0);
      expect(find.text('Edited'), findsOneWidget);
      await settleTimers(tester);
    });

    testWidgets('changing a value and saving shows Edited', (tester) async {
      final c = await pumpHistory(tester, [_record(d1, d2)]);
      await tester.longPress(find.text('Abdomen'));
      await tester.pump(const Duration(milliseconds: 300));

      await _tap(tester, find.text('PLACED ON'));
      await tester.pump(const Duration(milliseconds: 400)); // picker slides up
      expect(find.text('Where was this pod placed?'), findsOneWidget);
      await _tap(tester, find.text('Left thigh'));
      await tester.pump(const Duration(milliseconds: 400)); // picker closes

      // Shown on the card, but not saved until Save.
      expect(find.text('Left thigh'), findsOneWidget);
      expect(c.history.single.placedOn, 'Abdomen');
      expect(find.text('Edited'), findsNothing);

      await _tap(tester, find.text('Save'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(c.history.single.placedOn, 'Left thigh');
      expect(c.history.single.edited, isTrue);
      expect(find.text('Edited'), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      await settleTimers(tester);
    });

    testWidgets('Cancel throws the changes away', (tester) async {
      final c = await pumpHistory(tester, [_record(d1, d2)]);
      await tester.longPress(find.text('Abdomen'));
      await tester.pump(const Duration(milliseconds: 300));

      await _tap(tester, find.text('WHY CHANGED'));
      await tester.pump(const Duration(milliseconds: 400));
      await _tap(tester, find.text('Leak'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Leak'), findsOneWidget);

      await _tap(tester, find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Leak'), findsNothing);
      expect(find.text('Planned'), findsOneWidget);
      expect(find.text('Edited'), findsNothing);
      expect(c.history.single.edited, isFalse);
      await settleTimers(tester);
    });

    testWidgets('swiping left deletes, and Undo brings it back', (tester) async {
      final c = await pumpHistory(tester, [_record(d3, d4), _record(d1, d2)]);
      expect(find.byType(SessionHistoryCard), findsNWidgets(2));

      await tester.drag(find.byType(SessionHistoryCard).first, const Offset(-400, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500)); // slide out
      await tester.pump(const Duration(milliseconds: 500)); // collapse

      expect(c.history.map((r) => r.ended), [d2]);
      expect(find.text('Session deleted'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500)); // snack bar slides in

      await tester.tap(find.text('Undo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(c.history.map((r) => r.ended), [d4, d2]);
      expect(find.byType(SessionHistoryCard), findsNWidgets(2));
      await settleTimers(tester);
    });

    testWidgets('a short swipe springs back without deleting', (tester) async {
      final c = await pumpHistory(tester, [_record(d1, d2)]);
      await tester.drag(find.byType(SessionHistoryCard), const Offset(-60, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(c.history, hasLength(1));
      expect(find.text('Session deleted'), findsNothing);
      await settleTimers(tester);
    });

    testWidgets('a card being edited cannot be swiped away', (tester) async {
      final c = await pumpHistory(tester, [_record(d1, d2)]);
      await tester.longPress(find.text('Abdomen'));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(SessionHistoryCard), const Offset(-400, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      expect(c.history, hasLength(1));
      expect(find.text('Save'), findsOneWidget);
      await settleTimers(tester);
    });

    testWidgets('leaving the tab ends edit mode without saving', (tester) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = await _controller([_record(d1, d2)]);
      final tabs = RootTabController()..index = 3;
      await tester.pumpWidget(MaterialApp(home: HistoryScreen(controller: c, tabs: tabs)));
      await tester.pump();

      await tester.longPress(find.text('Abdomen'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Save'), findsOneWidget);

      tabs.goTo(0);
      await tester.pump();
      tabs.goTo(3);
      await tester.pump();
      expect(find.text('Save'), findsNothing);
      await settleTimers(tester);
    });
  });
}
