import 'dart:async';
import 'dart:isolate';
import 'package:isolate/isolate.dart';

class IsolatePool {
  final int _poolSize;
  final List<IsolateRunner> _isolates = [];
  final List<bool> _busy = [];

  IsolatePool(this._poolSize);

  Future<void> initialize() async {
    for (int i = 0; i < _poolSize; i++) {
      final isolate = await IsolateRunner.spawn();
      _isolates.add(isolate);
      _busy.add(false);
    }
  }

  Future<R> run<R, P>(FutureOr<R> Function(P argument) function, P argument) async {
    // Wait for a free isolate
    int idx;
    while (true) {
      idx = _busy.indexOf(false);
      if (idx != -1) break;
      await Future.delayed(Duration(milliseconds: 1));
    }

    _busy[idx] = true;
    try {
      final result = await _isolates[idx].run(function, argument);
      return result;
    } finally {
      _busy[idx] = false;
    }
  }

  Future<void> close() async {
    for (final isolate in _isolates) {
      await isolate.close();
    }
    _isolates.clear();
    _busy.clear();
  }
}
