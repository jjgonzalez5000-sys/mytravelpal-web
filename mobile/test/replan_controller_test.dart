import 'dart:async';

// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:mytravelpal/services/replan_controller.dart';

/// A stand-in screen: `edit` changes what the driver built, a run "fetches"
/// through a completer the test resolves, and applying sets the applied
/// signature exactly like the real screen does.
class _Harness {
  _Harness() {
    controller = ReplanController(
      pendingSignature: () => pending,
      appliedSignature: () => applied,
      task: _task,
      onChanged: () => changes++,
    );
  }

  late final ReplanController controller;
  String pending = 'A';
  String applied = 'A';
  int changes = 0;
  final List<String> started = [];
  final List<String> appliedLog = [];
  final List<String> discarded = [];
  final Map<String, Completer<void>> gates = {};

  Future<void> _task(ReplanRun run) async {
    started.add(run.signature);
    final gate = gates.putIfAbsent(run.signature, Completer<void>.new);
    await gate.future;
    if (run.stale) {
      discarded.add(run.signature);
      return;
    }
    applied = run.signature;
    appliedLog.add(run.signature);
  }

  void edit(String sig, {Duration? delay}) {
    pending = sig;
    controller.schedule(delay: delay);
  }

  void land(String sig) {
    gates.putIfAbsent(sig, Completer<void>.new).complete();
  }

  void fail(String sig, Object error) {
    gates.putIfAbsent(sig, Completer<void>.new).completeError(error);
  }
}

void main() {
  const debounce = Duration(milliseconds: 1200);

  test('a burst of edits makes exactly one request after the pause', () {
    fakeAsync((FakeAsync async) {
      final h = _Harness();
      h.edit('B');
      async.elapse(const Duration(milliseconds: 800));
      h.edit('C');
      async.elapse(const Duration(milliseconds: 800));
      h.edit('D');
      async.elapse(const Duration(milliseconds: 1100));
      expect(h.started, isEmpty);
      async.elapse(const Duration(milliseconds: 200));
      expect(h.started, ['D']);
      h.land('D');
      async.flushMicrotasks();
      expect(h.appliedLog, ['D']);
      expect(h.controller.inFlight, isFalse);
      async.elapse(const Duration(seconds: 5));
      expect(h.started, ['D']);
    });
  });

  test('undoing an edit before the timer fires cancels the request', () {
    fakeAsync((FakeAsync async) {
      final h = _Harness();
      h.edit('B');
      async.elapse(const Duration(milliseconds: 500));
      h.edit('A');
      async.elapse(const Duration(seconds: 3));
      expect(h.started, isEmpty);
    });
  });

  test('an edit during a request drops that result and runs the latest', () {
    fakeAsync((FakeAsync async) {
      final h = _Harness();
      h.edit('B');
      async.elapse(debounce);
      expect(h.started, ['B']);

      h.edit('C');
      async.elapse(debounce);
      expect(h.started, ['B'], reason: 'one request at a time');

      h.land('B');
      async.flushMicrotasks();
      expect(h.discarded, ['B']);
      expect(h.appliedLog, isEmpty);

      async.elapse(const Duration(milliseconds: 10));
      expect(h.started, ['B', 'C']);
      h.land('C');
      async.flushMicrotasks();
      expect(h.appliedLog, ['C']);
      expect(h.applied, 'C');
    });
  });

  test('an edit that lands back on the applied state needs no new request', () {
    fakeAsync((FakeAsync async) {
      final h = _Harness();
      h.edit('B');
      async.elapse(debounce);
      h.edit('A');
      h.land('B');
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 5));
      expect(h.discarded, ['B']);
      expect(h.started, ['B']);
      expect(h.applied, 'A');
    });
  });

  test('a failure stays put, is not retried alone, and retry runs it', () {
    fakeAsync((FakeAsync async) {
      final h = _Harness();
      h.edit('B');
      async.elapse(debounce);
      h.fail('B', StateError('boom'));
      async.flushMicrotasks();
      expect(h.controller.error, isA<StateError>());
      async.elapse(const Duration(seconds: 30));
      expect(h.started, ['B']);

      h.gates.remove('B');
      h.controller.retry();
      async.elapse(const Duration(milliseconds: 10));
      expect(h.started, ['B', 'B']);
      expect(h.controller.error, isNull);
      h.land('B');
      async.flushMicrotasks();
      expect(h.applied, 'B');
    });
  });

  test('a different edit after a failure clears it and runs normally', () {
    fakeAsync((FakeAsync async) {
      final h = _Harness();
      h.edit('B');
      async.elapse(debounce);
      h.fail('B', StateError('boom'));
      async.flushMicrotasks();
      expect(h.controller.error, isNotNull);

      h.edit('C');
      expect(h.controller.error, isNull);
      async.elapse(debounce);
      expect(h.started, ['B', 'C']);
    });
  });

  test('reverting to the applied state after a failure clears the error', () {
    fakeAsync((FakeAsync async) {
      final h = _Harness();
      h.edit('B');
      async.elapse(debounce);
      h.fail('B', StateError('boom'));
      async.flushMicrotasks();
      h.edit('A');
      expect(h.controller.error, isNull);
      async.elapse(const Duration(seconds: 5));
      expect(h.started, ['B']);
    });
  });

  test('a run due while a sheet is open waits for it to close', () {
    fakeAsync((FakeAsync async) {
      final h = _Harness();
      h.controller.pause();
      h.edit('B');
      async.elapse(const Duration(seconds: 5));
      expect(h.started, isEmpty);
      h.controller.resume();
      async.elapse(const Duration(milliseconds: 10));
      expect(h.started, ['B']);
    });
  });

  test('a result landing after dispose is ignored', () {
    fakeAsync((FakeAsync async) {
      final h = _Harness();
      h.edit('B');
      async.elapse(debounce);
      h.controller.dispose();
      h.land('B');
      async.flushMicrotasks();
      expect(h.appliedLog, isEmpty);
      expect(h.discarded, ['B']);
    });
  });

  test('a run that never applies its result is reported, not looped', () {
    fakeAsync((FakeAsync async) {
      var runs = 0;
      var applied = 'A';
      final c = ReplanController(
        pendingSignature: () => 'B',
        appliedSignature: () => applied,
        task: (run) async {
          runs++;
        },
      );
      c.schedule();
      async.elapse(const Duration(seconds: 10));
      expect(runs, 1);
      expect(c.error, isA<StateError>());
      applied = 'B';
    });
  });
}
