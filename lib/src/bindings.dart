import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:convert';
import 'package:ffi/ffi.dart';

class RustHttpException implements Exception {
  final String message;

  RustHttpException(this.message);

  @override
  String toString() => 'RustHttpException: $message';
}

typedef InitHttpClientFunc = Bool Function();
typedef ExecuteRequestBytesFunc = ByteBuffer Function(Pointer<Utf8>);
typedef ExecuteBatchRequestsBytesFunc = ByteBuffer Function(Pointer<Utf8>);
typedef FreeByteBufferFunc = Void Function(ByteBuffer);
typedef FreeStringFunc = Void Function(Pointer<Utf8>);

typedef InitHttpClient = bool Function();
typedef ExecuteRequestBytes = ByteBuffer Function(Pointer<Utf8>);
typedef ExecuteBatchRequestsBytes = ByteBuffer Function(Pointer<Utf8>);
typedef FreeByteBuffer = void Function(ByteBuffer);
typedef FreeString = void Function(Pointer<Utf8>);

class ByteBuffer extends Struct {
  external Pointer<Uint8> ptr;
  @IntPtr()
  external int length;
  @IntPtr()
  external int capacity;
}

// Enhanced logging utility
class FFILogger {
  static const String _prefix = '[FFI-HTTP]';
  static bool debugEnabled = false;

  static void info(String message) {
    print('$_prefix INFO: $message');
  }

  static void warning(String message) {
    print('$_prefix WARNING: $message');
  }

  static void error(String message, [Object? exception]) {
    print('$_prefix ERROR: $message');
    if (exception != null) {
      print('$_prefix ERROR DETAILS: $exception');
    }
  }

  static void debug(String message) {
    if (debugEnabled) print('$_prefix DEBUG: $message');
  }
}

// ByteBuffer lifecycle manager
class ByteBufferManager {
  static final Map<int, ByteBuffer> _activeBuffers = {};
  static int _nextId = 1;

  static int track(ByteBuffer buffer) {
    final id = _nextId++;
    _activeBuffers[id] = buffer;
    FFILogger.debug('Tracking ByteBuffer #$id (ptr: ${buffer.ptr.address}, length: ${buffer.length})');
    return id;
  }

  static ByteBuffer? get(int id) {
    return _activeBuffers[id];
  }

  static void untrack(int id) {
    final buffer = _activeBuffers.remove(id);
    if (buffer != null) {
      FFILogger.debug('Untracked ByteBuffer #$id');
    }
  }

  static int getActiveCount() {
    return _activeBuffers.length;
  }

  static void logActiveBuffers() {
    if (!FFILogger.debugEnabled) return;

    FFILogger.info('Active ByteBuffers: ${_activeBuffers.length}');
    for (final entry in _activeBuffers.entries) {
      final buffer = entry.value;
      FFILogger.debug('  Buffer #${entry.key}: ptr=${buffer.ptr.address}, length=${buffer.length}');
    }
  }
}

class NativeLibrary {
  late DynamicLibrary _lib;
  late InitHttpClient _initHttpClient;
  late ExecuteRequestBytes _executeRequestBytes;
  late ExecuteBatchRequestsBytes _executeBatchRequestsBytes;
  late FreeByteBuffer _freeByteBuffer;
  late FreeString _freeString;

  // Singleton instance for each isolate
  static NativeLibrary? _instance;

  // Private constructor
  NativeLibrary._();

  // Factory method to get/create instance
  factory NativeLibrary.getInstance() {
    _instance ??= NativeLibrary._();
    return _instance!;
  }

  // Initialize the library (should be called once per isolate)
  void initialize() {
    try {
      FFILogger.debug('Loading native library...');
      _lib = _loadLibrary();
      FFILogger.info('Native library loaded successfully');

      FFILogger.debug('Looking up function symbols...');
      _initHttpClient = _lib
          .lookup<NativeFunction<InitHttpClientFunc>>('init_http_client')
          .asFunction();
      FFILogger.debug('Found init_http_client');

      _executeRequestBytes = _lib
          .lookup<NativeFunction<ExecuteRequestBytesFunc>>('execute_request_bytes')
          .asFunction();
      FFILogger.debug('Found execute_request_bytes');

      _executeBatchRequestsBytes = _lib
          .lookup<NativeFunction<ExecuteBatchRequestsBytesFunc>>('execute_batch_requests_bytes')
          .asFunction();
      FFILogger.debug('Found execute_batch_requests_bytes');

      _freeByteBuffer = _lib
          .lookup<NativeFunction<FreeByteBufferFunc>>('free_byte_buffer')
          .asFunction();
      FFILogger.debug('Found free_byte_buffer');

      _freeString = _lib
          .lookup<NativeFunction<FreeStringFunc>>('free_string')
          .asFunction();
      FFILogger.debug('Found free_string');

      FFILogger.info('Initializing HTTP client...');
      final initResult = _initHttpClient();
      FFILogger.info('HTTP client initialization result: $initResult');

    } catch (e) {
      FFILogger.error('Failed to initialize NativeLibrary', e);
      rethrow;
    }
  }

  static Future<bool> verifyLibrary() async {
    FFILogger.info('Verifying native library availability...');

    // Log build mode
    final isRelease = const bool.fromEnvironment('dart.vm.product');
    final isProfile = const bool.fromEnvironment('dart.vm.profile');
    FFILogger.info('Build mode - Release: $isRelease, Profile: $isProfile, Debug: ${!isRelease && !isProfile}');

    try {
      final lib = _loadLibrary();

      // Test each function symbol individually
      final functions = {
        'init_http_client': InitHttpClientFunc,
        'execute_request_bytes': ExecuteRequestBytesFunc,
        'execute_batch_requests_bytes': ExecuteBatchRequestsBytesFunc,
        'free_byte_buffer': FreeByteBufferFunc,
        'free_string': FreeStringFunc,
      };

      for (final entry in functions.entries) {
        try {
          final symbol = lib.lookup(entry.key);
          FFILogger.info('✓ Found symbol: ${entry.key} at address ${symbol.address}');
        } catch (e) {
          FFILogger.error('✗ Missing symbol: ${entry.key}', e);
          return false;
        }
      }

      FFILogger.info('Native library verification successful');
      return true;
    } catch (e) {
      FFILogger.error('Native library verification failed', e);
      return false;
    }
  }

  static DynamicLibrary _loadLibrary() {
    final platform = Platform.operatingSystem;
    FFILogger.debug('Loading library for platform: $platform');

    try {
      DynamicLibrary lib;

      if (Platform.isAndroid) {
        FFILogger.debug('Loading Android library: libflutter_rust_http.so');
        lib = DynamicLibrary.open('libflutter_rust_http.so');
      } else if (Platform.isIOS) {
        FFILogger.debug('Loading iOS library from process');
        lib = DynamicLibrary.process();
      } else if (Platform.isLinux) {
        FFILogger.debug('Loading Linux library: libflutter_rust_http.so');
        lib = DynamicLibrary.open('libflutter_rust_http.so');
      } else if (Platform.isMacOS) {
        FFILogger.debug('Loading macOS library: libflutter_rust_http.dylib');
        lib = DynamicLibrary.open('libflutter_rust_http.dylib');
      } else if (Platform.isWindows) {
        FFILogger.debug('Loading Windows library: flutter_rust_http.dll');
        lib = DynamicLibrary.open('flutter_rust_http.dll');
      } else {
        throw UnsupportedError('Platform not supported: $platform');
      }

      // Verify the library loaded correctly by checking for a known symbol
      try {
        lib.lookup<NativeFunction<InitHttpClientFunc>>('init_http_client');
        FFILogger.info('Library verification successful - found init_http_client symbol');
      } catch (e) {
        FFILogger.error('Library loaded but symbols not found - this indicates a packaging issue', e);
        throw Exception('Library symbols not accessible: $e');
      }

      return lib;
    } catch (e) {
      FFILogger.error('Failed to load library for platform $platform', e);
      rethrow;
    }
  }

  String executeRequest(String requestJson) {
    FFILogger.debug('Executing HTTP request');
    FFILogger.debug('Request JSON length: ${requestJson.length} characters');

    final requestPtr = requestJson.toNativeUtf8();
    FFILogger.debug('Allocated UTF8 string at address: ${requestPtr.address}');

    ByteBuffer? buffer;
    int? bufferId;

    try {
      FFILogger.debug('Calling execute_request_bytes...');
      buffer = _executeRequestBytes(requestPtr);
      bufferId = ByteBufferManager.track(buffer);

      FFILogger.debug('Received ByteBuffer #$bufferId from Rust');
      FFILogger.debug('Buffer details: ptr=${buffer.ptr.address}, length=${buffer.length}, capacity=${buffer.capacity}');

      if (buffer.ptr == nullptr) {
        throw RustHttpException('Received null pointer from native function');
      }

      if (buffer.length <= 0) {
        throw RustHttpException('Received invalid buffer length: ${buffer.length}');
      }

      FFILogger.debug('Converting buffer to TypedData...');
      final data = buffer.ptr.asTypedList(buffer.length);
      FFILogger.debug('TypedData created, decoding UTF8...');

      final response = utf8.decode(data, allowMalformed: true);
      FFILogger.debug('Successfully decoded response (${response.length} characters)');

      FFILogger.debug('Parsing JSON response...');
      final responseMap = jsonDecode(response);
      if (responseMap is Map<String, dynamic> && responseMap.containsKey('error')) {
        final errorMsg = responseMap['error'];
        FFILogger.error('Rust function returned error: $errorMsg');
        throw RustHttpException(errorMsg);
      }

      FFILogger.debug('Request executed successfully');
      return response;

    } catch (e) {
      FFILogger.error('Error during request execution', e);
      rethrow;
    } finally {
      // Ensure ByteBuffer is freed even if an exception occurs
      if (buffer != null && bufferId != null) {
        try {
          FFILogger.debug('Freeing ByteBuffer #$bufferId...');
          _freeByteBuffer(buffer);
          ByteBufferManager.untrack(bufferId);
          FFILogger.debug('ByteBuffer #$bufferId freed successfully');
        } catch (e) {
          FFILogger.error('Failed to free ByteBuffer #$bufferId', e);
        }
      }

      // Ensure UTF8 string is freed
      try {
        FFILogger.debug('Freeing UTF8 string at address: ${requestPtr.address}');
        calloc.free(requestPtr);
        FFILogger.debug('UTF8 string freed successfully');
      } catch (e) {
        FFILogger.error('Failed to free UTF8 string', e);
      }

      // Log active buffer count
      final activeBuffers = ByteBufferManager.getActiveCount();
      if (activeBuffers > 0 && FFILogger.debugEnabled) {
        FFILogger.warning('$activeBuffers ByteBuffers still active after request');
        ByteBufferManager.logActiveBuffers();
      }
    }
  }

  String executeBatchRequests(String requestsJson) {
    FFILogger.debug('Executing batch HTTP requests');
    FFILogger.debug('Batch requests JSON length: ${requestsJson.length} characters');

    final requestPtr = requestsJson.toNativeUtf8();
    FFILogger.debug('Allocated UTF8 string at address: ${requestPtr.address}');

    ByteBuffer? buffer;
    int? bufferId;

    try {
      FFILogger.debug('Calling execute_batch_requests_bytes...');
      buffer = _executeBatchRequestsBytes(requestPtr);
      bufferId = ByteBufferManager.track(buffer);

      FFILogger.debug('Received ByteBuffer #$bufferId from Rust');
      FFILogger.debug('Buffer details: ptr=${buffer.ptr.address}, length=${buffer.length}, capacity=${buffer.capacity}');

      if (buffer.ptr == nullptr) {
        throw RustHttpException('Received null pointer from native function');
      }

      if (buffer.length <= 0) {
        throw RustHttpException('Received invalid buffer length: ${buffer.length}');
      }

      FFILogger.debug('Converting buffer to TypedData...');
      final data = buffer.ptr.asTypedList(buffer.length);
      FFILogger.debug('TypedData created, decoding UTF8...');

      final response = utf8.decode(data, allowMalformed: true);
      FFILogger.debug('Successfully decoded batch response (${response.length} characters)');

      FFILogger.debug('Parsing JSON response...');
      final responseMap = jsonDecode(response);
      if (responseMap is Map<String, dynamic> && responseMap.containsKey('error')) {
        final errorMsg = responseMap['error'];
        FFILogger.error('Rust function returned error: $errorMsg');
        throw RustHttpException(errorMsg);
      }

      FFILogger.debug('Batch requests executed successfully');
      return response;

    } catch (e) {
      FFILogger.error('Error during batch request execution', e);
      rethrow;
    } finally {
      // Ensure ByteBuffer is freed even if an exception occurs
      if (buffer != null && bufferId != null) {
        try {
          FFILogger.debug('Freeing ByteBuffer #$bufferId...');
          _freeByteBuffer(buffer);
          ByteBufferManager.untrack(bufferId);
          FFILogger.debug('ByteBuffer #$bufferId freed successfully');
        } catch (e) {
          FFILogger.error('Failed to free ByteBuffer #$bufferId', e);
        }
      }

      // Ensure UTF8 string is freed
      try {
        FFILogger.debug('Freeing UTF8 string at address: ${requestPtr.address}');
        calloc.free(requestPtr);
        FFILogger.debug('UTF8 string freed successfully');
      } catch (e) {
        FFILogger.error('Failed to free UTF8 string', e);
      }

      // Log active buffer count
      final activeBuffers = ByteBufferManager.getActiveCount();
      if (activeBuffers > 0 && FFILogger.debugEnabled) {
        FFILogger.warning('$activeBuffers ByteBuffers still active after batch request');
        ByteBufferManager.logActiveBuffers();
      }
    }
  }
}

// Isolate worker entry point
void _isolateEntry(SendPort sendPort) {
  // Initialize the native library for this isolate
  final nativeLib = NativeLibrary.getInstance();
  nativeLib.initialize();

  // Create a receive port for this isolate
  final receivePort = ReceivePort();

  // Send the port back to the main isolate
  sendPort.send(receivePort.sendPort);

  // Listen for messages
  receivePort.listen((message) {
    if (message is List && message.length == 3) {
      final SendPort replyPort = message[0];
      final String requestJson = message[1];
      final bool isBatch = message[2];

      try {
        final result = isBatch
            ? nativeLib.executeBatchRequests(requestJson)
            : nativeLib.executeRequest(requestJson);
        replyPort.send(result);
      } catch (e) {
        replyPort.send(e);
      }
    }
  });
}

// Isolate pool manager
class IsolatePool {
  final int _poolSize;
  final List<SendPort> _availableIsolates = [];
  final List<Completer<void>> _initializationCompleters = [];
  final Queue<_PendingRequest> _pendingRequests = Queue();

  IsolatePool(this._poolSize);

  Future<void> initialize() async {
    for (int i = 0; i < _poolSize; i++) {
      final completer = Completer<void>();
      _initializationCompleters.add(completer);

      final receivePort = ReceivePort();
      await Isolate.spawn(_isolateEntry, receivePort.sendPort);

      receivePort.listen((message) {
        if (message is SendPort) {
          _availableIsolates.add(message);
          completer.complete();
        }
      });
    }

    // Wait for all isolates to initialize
    await Future.wait(_initializationCompleters.map((c) => c.future));
  }

  Future<String> run<T, R>(String requestJson, {bool isBatch = false}) async {
    if (_availableIsolates.isEmpty) {
      // Queue the request if no isolates are available
      final completer = Completer<String>();
      _pendingRequests.add(_PendingRequest(completer, requestJson, isBatch));
      return completer.future;
    }

    final isolate = _availableIsolates.removeAt(0);
    final responsePort = ReceivePort();

    try {
      isolate.send([responsePort.sendPort, requestJson, isBatch]);

      final response = await responsePort.first;

      // Return the isolate to the pool
      _availableIsolates.add(isolate);

      // Process any pending requests
      _processPendingRequests();

      if (response is String) {
        return response;
      } else if (response is Exception) {
        throw response;
      } else {
        throw Exception('Unexpected response type: ${response.runtimeType}');
      }
    } catch (e) {
      // Return the isolate to the pool even if there's an error
      _availableIsolates.add(isolate);
      _processPendingRequests();
      rethrow;
    }
  }

  void _processPendingRequests() {
    while (_pendingRequests.isNotEmpty && _availableIsolates.isNotEmpty) {
      final request = _pendingRequests.removeFirst();
      final isolate = _availableIsolates.removeAt(0);
      final responsePort = ReceivePort();

      isolate.send([responsePort.sendPort, request.requestJson, request.isBatch]);

      responsePort.first.then((response) {
        _availableIsolates.add(isolate);
        _processPendingRequests();

        if (response is String) {
          request.completer.complete(response);
        } else if (response is Exception) {
          request.completer.completeError(response);
        } else {
          request.completer.completeError(Exception('Unexpected response type'));
        }
      }).catchError((e) {
        _availableIsolates.add(isolate);
        _processPendingRequests();
        request.completer.completeError(e);
      });
    }
  }

  Future<void> close() async {
    // No need to explicitly close isolates in Dart
    _availableIsolates.clear();
    _pendingRequests.clear();
  }
}

class _PendingRequest {
  final Completer<String> completer;
  final String requestJson;
  final bool isBatch;

  _PendingRequest(this.completer, this.requestJson, this.isBatch);
}