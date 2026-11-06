import 'dart:async';

import 'package:flutter/services.dart';

/// A file another app handed to Pod Tracker — "Open with Pod Tracker" or
/// "Share → Pod Tracker" on a backup received by messenger, email, Files,
/// Quick Share or AirDrop. [bytes] is null if the platform couldn't read it.
class IncomingFile {
  const IncomingFile(this.bytes);

  final Uint8List? bytes;
}

/// Receives [IncomingFile]s from the native side (`MainActivity.kt` on
/// Android, `IncomingFilePlugin` in `AppDelegate.swift` on iOS) over the
/// `ptnv/incoming_file` channel.
///
/// The native side holds a file that arrives before Dart is listening — a cold
/// launch straight into an import — until [start] collects it, and pushes any
/// later ones (app already running) through [files].
class IncomingFileService {
  IncomingFileService._();
  static final IncomingFileService instance = IncomingFileService._();

  static const MethodChannel _channel = MethodChannel('ptnv/incoming_file');

  final StreamController<IncomingFile> _files = StreamController<IncomingFile>.broadcast();
  bool _started = false;

  /// Every file handed to the app. Listen before calling [start], or a file
  /// the app was launched with is missed.
  Stream<IncomingFile> get files => _files.stream;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'fileReceived') _emit(call.arguments);
    });
    try {
      final pending = await _channel.invokeMethod<Object?>('takePending');
      if (pending != null) _emit(pending);
    } on MissingPluginException {
      // No native side on this platform (desktop, web, widget tests).
    } on PlatformException {
      // Nothing usable was pending.
    }
  }

  void _emit(Object? arguments) {
    final bytes = arguments is Map ? arguments['bytes'] : null;
    _files.add(IncomingFile(bytes is Uint8List ? bytes : null));
  }
}
