import 'dart:async';

/// Centralized permission state tracker.
///
/// Widgets (e.g. [SafeArtworkWidget]) check [granted] before calling native
/// plugin methods that require media permission.  This prevents the
/// `on_audio_query_pluse` native crash ("Reply already submitted") that
/// occurs when `queryArtwork` is invoked without permission.
///
/// Additionally exposes a [readyCompleter] so that widgets can `await`
/// the first permission resolution instead of polling.
class AudioPermissionState {
  AudioPermissionState._();

  /// Whether the app has been granted audio/media read permission.
  static bool granted = false;

  /// Completes when the first permission check finishes (regardless of the
  /// result).  Widgets that depend on permission state can `await` this
  /// to avoid making native calls before permission is resolved.
  static Completer<bool> _readyCompleter = Completer<bool>();

  /// A future that completes with `true` once permission has been resolved
  /// for the first time.  Subsequent resets (e.g. retry) create a new
  /// completer so callers can await again.
  static Future<bool> get ready => _readyCompleter.future;

  /// Whether the permission resolution has completed at least once.
  static bool get isResolved => _readyCompleter.isCompleted;

  /// Called by [_MyAppState] after permission has been determined.
  static void resolve(bool isGranted) {
    granted = isGranted;
    if (!_readyCompleter.isCompleted) {
      _readyCompleter.complete(isGranted);
    }
  }

  /// Reset the completer (called before a retry so that widgets can await
  /// again).
  static void reset() {
    if (_readyCompleter.isCompleted) {
      _readyCompleter = Completer<bool>();
    }
    granted = false;
  }
}
