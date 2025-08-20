import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'package:isolate/isolate.dart';

class IsolatePool {
  final int _poolSize;
  final List<IsolateRunner> _isolates = [];
  final Queue<Completer<void>> _available = Queue();

  IsolatePool(this._poolSize);

  Future<void> initialize() async {
    for (int i = 0; i < _poolSize; i++) {
      final isolate = await IsolateRunner.spawn();
      _isolates.add(isolate);
      _available.add(Completer()..complete());
    }
  }

  Future<R> run<R, P>(FutureOr<R> Function(P argument) function, P argument) async {
    while (_available.isEmpty) {
      await Future.delayed(Duration(milliseconds: 10));
    }

    final availableCompleter = _available.removeFirst();
    try {
      final result = await _isolates[_available.length].run(function, argument);
      return result;
    } finally {
      _available.add(Completer()..complete());
    }
  }

  Future<void> close() async {
    for (final isolate in _isolates) {
      await isolate.close();
    }
    _isolates.clear();
    _available.clear();
  }
}