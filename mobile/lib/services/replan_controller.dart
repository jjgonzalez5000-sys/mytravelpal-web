import 'dart:async';

/// One automatic recalculation, handed to the task that performs it.
class ReplanRun {
  ReplanRun._(this._controller, this.signature);

  final ReplanController _controller;

  /// Signature of the request this run was started for.
  final String signature;

  /// True once the controller was disposed: nothing from this run may touch
  /// the screen.
  bool get cancelled => _controller._disposed;

  /// True when the driver changed something after this run started, so its
  /// result no longer matches what they built (a new run follows).
  bool get stale => cancelled || _controller.pendingSignature() != signature;
}

/// Turns edits into one recalculation at a time: waits for the driver to
/// stop editing, runs [task], and runs once more if they edited meanwhile.
/// The task fetches the plan and applies it only while `run.stale` is false.
class ReplanController {
  ReplanController({
    required this.pendingSignature,
    required this.appliedSignature,
    required this.task,
    this.debounce = const Duration(milliseconds: 1200),
    this.onChanged,
  });

  /// Signature of the request built from the driver's current edits.
  final String Function() pendingSignature;

  /// Signature of the request the plan on screen was computed from.
  final String Function() appliedSignature;

  final Future<void> Function(ReplanRun run) task;
  final Duration debounce;
  final void Function()? onChanged;

  Timer? _timer;
  int _holds = 0;
  bool _inFlight = false;
  bool _runWhenFree = false;
  bool _disposed = false;
  String? _failedSig;
  Object? _error;

  bool get inFlight => _inFlight;

  /// The error of the last run, kept until the driver retries or edits.
  Object? get error => _error;

  /// Call after every edit that can change the request.
  void schedule({Duration? delay}) {
    if (_disposed) return;
    _timer?.cancel();
    _timer = null;
    final pending = pendingSignature();
    if (pending == appliedSignature()) {
      _runWhenFree = false;
      _failedSig = null;
      _clearError();
      return;
    }
    if (pending == _failedSig) return;
    _failedSig = null;
    _clearError();
    _timer = Timer(delay ?? debounce, _fire);
  }

  /// Runs the failed request again.
  void retry() {
    _failedSig = null;
    _clearError();
    schedule(delay: Duration.zero);
  }

  /// Forgets a failure without running anything.
  void clearFailure() {
    _failedSig = null;
    _clearError();
  }

  /// Holds runs while a sheet that works on the current plan is open; a run
  /// due meanwhile starts when the last hold is released.
  void pause() => _holds++;

  void resume() {
    if (_holds > 0) _holds--;
    if (_holds == 0 && _runWhenFree) {
      _runWhenFree = false;
      schedule(delay: Duration.zero);
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }

  void _fire() {
    _timer = null;
    if (_disposed) return;
    if (_holds > 0 || _inFlight) {
      _runWhenFree = true;
      return;
    }
    unawaited(_run());
  }

  Future<void> _run() async {
    final pending = pendingSignature();
    if (pending == appliedSignature()) return;
    final run = ReplanRun._(this, pending);
    _inFlight = true;
    _clearError(notify: false);
    onChanged?.call();
    try {
      await task(run);
      // A current result that was not applied would loop forever.
      if (!run.stale && appliedSignature() != run.signature) {
        throw StateError('replan result was not applied');
      }
      _failedSig = null;
    } catch (e) {
      if (!run.cancelled) {
        _failedSig = run.signature;
        _error = e;
      }
    } finally {
      _inFlight = false;
    }
    if (_disposed) return;
    onChanged?.call();
    _chase();
  }

  void _chase() {
    if (_timer?.isActive ?? false) return;
    final pending = pendingSignature();
    if (pending == appliedSignature() || pending == _failedSig) return;
    if (_holds > 0) {
      _runWhenFree = true;
      return;
    }
    schedule(delay: Duration.zero);
  }

  void _clearError({bool notify = true}) {
    if (_error == null) return;
    _error = null;
    if (notify) onChanged?.call();
  }
}
