import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ptnv/services/backup_service.dart';
import 'package:ptnv/state/pod.dart';
import 'package:shared_preferences/shared_preferences.dart';

SessionRecord _session(DateTime started, DateTime ended, {String site = 'Left arm'}) =>
    SessionRecord(
      date: ended,
      outcome: HistoryOutcome.completed,
      started: started,
      ended: ended,
      worn: ended.difference(started),
      placedOn: site,
      whyChanged: 'Expired',
      remindersSent: 0,
      changes: 'None',
    );

TrackedItemActivity _stockEntry(DateTime at, int delta) =>
    TrackedItemActivity(delta: delta, label: delta > 0 ? 'Added' : 'Removed', at: at);

/// The `data` object of a backup file, in the shape `toBackupJson` writes.
Map<String, dynamic> _data({
  int stock = 5,
  List<SessionRecord> history = const [],
  List<TrackedItemActivity> activity = const [],
  PodSession? session,
  List<PodTypePreset> customPodTypes = const [],
  String dateFormat = 'DD/MM/YYYY',
}) =>
    {
      'stock': stock,
      'history': history.map((e) => e.toJson()).toList(),
      'activity': activity.map((e) => e.toJson()).toList(),
      'session': session?.toJson(),
      'customPodTypes': customPodTypes.map((e) => e.toJson()).toList(),
      'dateFormat': dateFormat,
    };

Uint8List _file(Object doc) => Uint8List.fromList(utf8.encode(jsonEncode(doc)));

Future<PodController> _controller() async {
  final c = PodController();
  addTearDown(c.dispose);
  await c.loaded;
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final d1 = DateTime(2026, 10, 1, 8);
  final d2 = DateTime(2026, 10, 4, 8);
  final d3 = DateTime(2026, 10, 7, 8);
  final d4 = DateTime(2026, 10, 10, 8);

  group('BackupService.parse', () {
    test('reads a valid backup and summarises it', () {
      final b = BackupService.parse(_file({
        'schemaVersion': 1,
        'exportedAt': '2026-11-05T10:00:00.000',
        'data': _data(history: [_session(d1, d2)], activity: [_stockEntry(d1, 2)]),
      }));
      expect(b.historyCount, 1);
      expect(b.activityCount, 1);
      expect(b.exportedAt, DateTime(2026, 11, 5, 10));
    });

    test('tolerates a UTF-8 byte-order mark', () {
      final bytes = Uint8List.fromList(
          [0xEF, 0xBB, 0xBF, ..._file({'schemaVersion': 1, 'data': _data()})]);
      expect(BackupService.parse(bytes).historyCount, 0);
    });

    test('rejects files that are not a backup', () {
      for (final bytes in [
        Uint8List.fromList(utf8.encode('not json')),
        _file([1, 2, 3]),
        _file({'hello': 'world'}),
        _file({'schemaVersion': 1, 'data': 'nope'}),
      ]) {
        expect(() => BackupService.parse(bytes), throwsFormatException);
      }
    });

    test('rejects a backup from a newer schema with an update hint', () {
      expect(
        () => BackupService.parse(_file({'schemaVersion': 99, 'data': _data()})),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('newer version'))),
      );
    });
  });

  group('PodController import', () {
    test('a fresh install has no user data', () async {
      final c = await _controller();
      expect(c.hasUserData, isFalse);
    });

    test('replace makes this phone an exact copy of the backup', () async {
      final c = await _controller();
      c.restoreFromBackupJson(_data(history: [_session(d1, d2)], stock: 9));
      expect(c.hasUserData, isTrue);

      c.restoreFromBackupJson(_data(
        history: [_session(d3, d4)],
        stock: 3,
        dateFormat: 'YYYY-MM-DD',
      ));
      expect(c.history.map((r) => r.started), [d3]);
      expect(c.stock, 3);
      expect(c.dateFormat, 'YYYY-MM-DD');
    });

    test('merge combines history newest-first and drops duplicates', () async {
      final c = await _controller();
      c.restoreFromBackupJson(_data(history: [_session(d2, d3), _session(d1, d2)]));

      c.mergeFromBackupJson(_data(history: [_session(d3, d4), _session(d1, d2)]));

      expect(c.history.map((r) => r.started), [d3, d2, d1]);
    });

    test('merge keeps the stock count from the side that changed most recently', () async {
      final c = await _controller();
      c.restoreFromBackupJson(_data(stock: 7, activity: [_stockEntry(d3, 1)]));
      c.mergeFromBackupJson(_data(stock: 2, activity: [_stockEntry(d1, -1)]));
      expect(c.stock, 7, reason: "this phone's last change (d3) is newer");
      expect(c.activity.map((a) => a.at), [d3, d1]);

      final c2 = await _controller();
      c2.restoreFromBackupJson(_data(stock: 7, activity: [_stockEntry(d1, 1)]));
      c2.mergeFromBackupJson(_data(stock: 2, activity: [_stockEntry(d3, -1)]));
      expect(c2.stock, 2, reason: "the backup's last change (d3) is newer");
    });

    test('merge keeps the more recently placed pod', () async {
      final c = await _controller();
      final now = DateTime.now();
      final older = PodSession(startedAt: now.subtract(const Duration(hours: 30)), site: 'Belly');
      final newer = PodSession(startedAt: now.subtract(const Duration(hours: 2)), site: 'Thigh');

      c.restoreFromBackupJson(_data(session: newer));
      c.mergeFromBackupJson(_data(session: older));
      expect(c.session?.site, 'Thigh');

      c.restoreFromBackupJson(_data(session: older));
      c.mergeFromBackupJson(_data(session: newer));
      expect(c.session?.site, 'Thigh');

      c.restoreFromBackupJson(_data(session: older));
      c.mergeFromBackupJson(_data());
      expect(c.session?.site, 'Belly', reason: 'a pod on only one side is kept');
    });

    test('merge unions custom pod types and takes settings from the backup', () async {
      final c = await _controller();
      const mine = PodTypePreset(name: 'Mine', durationHours: 48, graceHours: 2);
      const theirs = PodTypePreset(name: 'Theirs', durationHours: 96, graceHours: 6);
      c.restoreFromBackupJson(_data(customPodTypes: [mine], dateFormat: 'DD/MM/YYYY'));

      c.mergeFromBackupJson(_data(customPodTypes: [theirs], dateFormat: 'MM/DD/YYYY'));

      expect(c.customPodTypes.map((t) => t.name), ['Theirs', 'Mine']);
      expect(c.dateFormat, 'MM/DD/YYYY');
    });

    test('a backup without reminder rules keeps this phone\'s; an empty list clears them',
        () async {
      final c = await _controller();
      final seeded = c.rules.length;
      expect(seeded, greaterThan(0), reason: 'a fresh install seeds default reminders');

      c.restoreFromBackupJson(_data()); // no 'rules' key at all
      expect(c.rules.length, seeded);
      c.mergeFromBackupJson(_data());
      expect(c.rules.length, seeded);

      c.mergeFromBackupJson(_data()..['rules'] = <Object>[]);
      expect(c.rules, isEmpty);
    });

    test('a damaged backup throws without touching current data', () async {
      final c = await _controller();
      c.restoreFromBackupJson(_data(history: [_session(d1, d2)], stock: 4));

      final broken = _data()..['history'] = [<String, dynamic>{'started': 'garbage'}];
      expect(() => c.mergeFromBackupJson(broken), throwsA(anything));
      expect(() => c.restoreFromBackupJson(broken), throwsA(anything));

      expect(c.history.map((r) => r.started), [d1]);
      expect(c.stock, 4);
    });
  });
}
