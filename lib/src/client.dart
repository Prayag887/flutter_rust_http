import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'dart:ffi';

class _WorkerRequest {
  final String id;
  final String type;
  final Uint8List payload;

  _WorkerRequest(this.id, this.type, this.payload);
}

class _WorkerResponse {
  final String id;
  final String? result;
  final String? error;

  _WorkerResponse(this.id, {this.result, this.error});
}

extension _Uint8ListPtr on Uint8List {
  @pragma('vm:prefer-inline')
  Pointer<Uint8> allocatePointer() {
    final ptr = malloc<Uint8>(length);
    ptr.asTypedList(length).setRange(0, length, this);
    return ptr;
  }
}

void _workerIsolateEntry(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  bool initialized = false;

  // Send port immediately
  mainSendPort.send(receivePort.sendPort);

  receivePort.listen((message) {
    if (message is _WorkerRequest) {
      try {
        if (!initialized) {
          initialized = initHttpClient();
          if (!initialized) {
            mainSendPort.send(_WorkerResponse(message.id, error: 'Init failed'));
            return;
          }
        }

        final ptr = message.payload.allocatePointer();
        try {
          final buffer = message.type == 'single'
              ? executeRequestBinary(ptr, message.payload.length)
              : executeRequestsBatchBinary(ptr, message.payload.length);

          if (buffer.ptr.address == 0) {
            mainSendPort.send(_WorkerResponse(message.id, error: 'Null response'));
            return;
          }

          try {
            final result = utf8.decode(buffer.ptr.asTypedList(buffer.len));
            mainSendPort.send(_WorkerResponse(message.id, result: result));
          } finally {
            freeBuffer(buffer.ptr, buffer.len);
          }
        } finally {
          malloc.free(ptr);
        }
      } catch (e) {
        mainSendPort.send(_WorkerResponse(message.id, error: e.toString()));
      }
    } else if (message == 'shutdown') {
      if (initialized)
      receivePort.close();
    }
  });
}

class FlutterRustHttp {
  static final FlutterRustHttp instance = FlutterRustHttp._private();
  FlutterRustHttp._private();

  bool _initialized = false;
  Isolate? _workerIsolate;
  SendPort? _workerSendPort;
  final Map<String, Completer<String>> _pendingRequests = <String, Completer<String>>{};
  int _requestIdCounter = 0;
  Completer<void>? _initCompleter;
  ReceivePort? _receivePort;

  Future<void> init() async {
    if (_initialized) return;
    if (_initCompleter != null) {
      await _initCompleter!.future;
      return;
    }

    _initCompleter = Completer<void>();
    await _startWorkerIsolate();
  }

  Future<void> _startWorkerIsolate() async {
    _receivePort = ReceivePort();

    _receivePort!.listen((message) {
      if (message is SendPort && !_initialized) {
        _workerSendPort = message;
        _initialized = true;
        _initCompleter?.complete();
        _initCompleter = null;
      } else if (message is _WorkerResponse) {
        final completer = _pendingRequests.remove(message.id);
        if (completer != null && !completer.isCompleted) {
          if (message.error != null) {
            completer.completeError(Exception(message.error!));
          } else {
            completer.complete(message.result!);
          }
        }
      }
    });

    _workerIsolate = await Isolate.spawn(_workerIsolateEntry, _receivePort!.sendPort);
  }

  @pragma('vm:prefer-inline')
  Future<String> _sendRequest(String type, Uint8List payload) async {
    if (!_initialized) await init();

    final id = 'req_${_requestIdCounter++}';
    final completer = Completer<String>();
    _pendingRequests[id] = completer;
    _workerSendPort!.send(_WorkerRequest(id, type, payload));
    return completer.future;
  }

  @pragma('vm:prefer-inline')
  Future<Map<String, dynamic>> request(Map<String, dynamic> payload) async {
    final jsonBytes = utf8.encode(jsonEncode(payload));
    final result = await _sendRequest('single', Uint8List.fromList(jsonBytes));
    return jsonDecode(result) as Map<String, dynamic>;
  }

  @pragma('vm:prefer-inline')
  Future<List<Map<String, dynamic>>> requestBatch(List<Map<String, dynamic>> payloads) async {
    final jsonBytes = utf8.encode(jsonEncode(payloads));
    final result = await _sendRequest('batch', Uint8List.fromList(jsonBytes));
    return (jsonDecode(result) as List).cast<Map<String, dynamic>>();
  }

  @pragma('vm:prefer-inline')
  Future<Map<String, dynamic>> get(String url, {Map<String, dynamic>? headers}) {
    return request(_createCompleteRequest(url, 'GET', headers));
  }

  @pragma('vm:prefer-inline')
  Future<Map<String, dynamic>> post(String url, {Map<String, dynamic>? headers, dynamic body}) {
    final req = _createCompleteRequest(url, 'POST', headers);
    if (body != null) req['body'] = body;
    return request(req);
  }

  @pragma('vm:prefer-inline')
  Future<Map<String, dynamic>> put(String url, {Map<String, dynamic>? headers, dynamic body}) {
    final req = _createCompleteRequest(url, 'PUT', headers);
    if (body != null) req['body'] = body;
    return request(req);
  }

  @pragma('vm:prefer-inline')
  Future<Map<String, dynamic>> delete(String url, {Map<String, dynamic>? headers}) {
    return request(_createCompleteRequest(url, 'DELETE', headers));
  }

  @pragma('vm:prefer-inline')
  Map<String, dynamic> _createCompleteRequest(String url, String method, Map<String, dynamic>? headers) {
    return <String, dynamic>{
      'url': url,
      'method': method,
      'headers': headers ?? <String, String>{},
      'body': null,
      'query_params': <String, String>{},
      'timeout_ms': 30000,
      'follow_redirects': true,
      'max_redirects': 5,
      'connect_timeout_ms': 15000,
      'read_timeout_ms': 30000,
      'write_timeout_ms': 30000,
      'auto_referer': true,
      'decompress': true,
      'http3_only': false,
    };
  }

  Future<void> shutdown() async {
    if (!_initialized) return;

    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('Shutdown'));
      }
    }
    _pendingRequests.clear();

    _workerSendPort?.send('shutdown');
    _workerIsolate?.kill(priority: Isolate.immediate);
    _receivePort?.close();

    _workerIsolate = null;
    _workerSendPort = null;
    _receivePort = null;
    _initialized = false;
    _initCompleter = null;
  }
}