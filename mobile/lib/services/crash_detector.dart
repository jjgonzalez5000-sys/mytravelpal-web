import 'dart:async';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// One detected crash event — enough to render the SOS modal.
class CrashEvent {
  const CrashEvent({
    required this.peakG,
    required this.speedDropKmh,
    required this.detectedAt,
    this.lat,
    this.lon,
  });

  /// Peak acceleration magnitude (Earth g's) that triggered the event.
  final double peakG;

  /// GPS speed drop in km/h in the 2 s window before the peak.
  final double speedDropKmh;

  final DateTime detectedAt;
  final double? lat;
  final double? lon;
}

/// Fuses accelerometer + GPS to detect a crash while keeping
/// false-positive rate low:
///
/// A crash fires when BOTH conditions align in the same 2-second
/// window:
/// 1. Accelerometer magnitude peaks above [_impactG] (≥4 g).
/// 2. GPS speed dropped from > [_prevSpeedMinKmh] (30 km/h) to
///    below [_postSpeedMaxKmh] (5 km/h) in that window.
///
/// Both filters together exclude the common false-positive
/// sources:
/// - Phone drops / bumps: no speed history above 30 km/h → filter
///   out.
/// - Hard braking without impact: no accelerometer spike above
///   4 g typically.
/// - Potholes: speed doesn't drop to near-zero.
///
/// The stream emits [CrashEvent]s. The consumer decides UX
/// (countdown modal, cancellation).
class CrashDetector {
  CrashDetector({
    Stream<Position>? positionStream,
    Stream<UserAccelerometerEvent>? accelStream,
  })  : _positionStream = positionStream,
        _accelStream = accelStream;

  // Thresholds (tuned conservative — high floor for real crashes,
  // low false positive on rough roads).
  static const double _impactG = 4.0;
  static const double _prevSpeedMinKmh = 30.0;
  static const double _postSpeedMaxKmh = 5.0;
  static const Duration _speedWindow = Duration(seconds: 3);
  static const Duration _cooldown = Duration(minutes: 2);

  final Stream<Position>? _positionStream;
  final Stream<UserAccelerometerEvent>? _accelStream;

  StreamSubscription<Position>? _posSub;
  StreamSubscription<UserAccelerometerEvent>? _accelSub;

  final _controller = StreamController<CrashEvent>.broadcast();
  Stream<CrashEvent> get events => _controller.stream;

  // Sliding-window state.
  final List<_SpeedSample> _speedHistory = [];
  Position? _lastPosition;
  DateTime? _lastCrashAt;

  /// Start listening. Idempotent — calling start twice is a no-op.
  void start() {
    if (_accelSub != null) return;
    final posStream = _positionStream ??
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        );
    _posSub = posStream.listen(_onPosition);

    final accelStream = _accelStream ?? userAccelerometerEventStream();
    _accelSub = accelStream.listen(_onAccel);
  }

  Future<void> stop() async {
    await _posSub?.cancel();
    await _accelSub?.cancel();
    _posSub = null;
    _accelSub = null;
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }

  void _onPosition(Position p) {
    _lastPosition = p;
    final speedKmh = p.speed * 3.6;
    _speedHistory.add(_SpeedSample(
      at: DateTime.now(),
      speedKmh: speedKmh,
    ));
    // Trim samples older than the window.
    final cutoff = DateTime.now().subtract(_speedWindow * 2);
    _speedHistory.removeWhere((s) => s.at.isBefore(cutoff));
  }

  void _onAccel(UserAccelerometerEvent e) {
    // Magnitude of "real" acceleration (userAccelerometer already
    // strips gravity, so at rest this is ~0).
    final magMps2 = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    final magG = magMps2 / 9.81;
    if (magG < _impactG) return;

    // Cool-down after a detection so a single crash doesn't emit
    // a dozen events as the phone keeps rattling.
    final now = DateTime.now();
    if (_lastCrashAt != null &&
        now.difference(_lastCrashAt!) < _cooldown) {
      return;
    }

    // Speed-drop confirmation. Look at the max speed in the
    // 3 s window and the current (last) speed.
    if (_speedHistory.isEmpty) return;
    final windowStart = now.subtract(_speedWindow);
    final windowSpeeds = _speedHistory
        .where((s) => s.at.isAfter(windowStart))
        .map((s) => s.speedKmh)
        .toList();
    if (windowSpeeds.isEmpty) return;

    final maxSpeed = windowSpeeds.reduce(math.max);
    final currentSpeed = _speedHistory.last.speedKmh;
    if (maxSpeed < _prevSpeedMinKmh) return; // wasn't moving
    if (currentSpeed > _postSpeedMaxKmh) return; // didn't stop

    _lastCrashAt = now;
    _controller.add(CrashEvent(
      peakG: magG,
      speedDropKmh: maxSpeed - currentSpeed,
      detectedAt: now,
      lat: _lastPosition?.latitude,
      lon: _lastPosition?.longitude,
    ));
  }
}

class _SpeedSample {
  const _SpeedSample({required this.at, required this.speedKmh});
  final DateTime at;
  final double speedKmh;
}
