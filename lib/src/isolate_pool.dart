  // import 'dart:async';
  // import 'dart:collection';
  // import 'dart:isolate';
  // import 'package:isolate/isolate.dart';
  //
  // // Isolate worker entry point
  // void _isolateEntry(SendPort sendPort) {
  //   // Initialize the native library for this isolate
  //   final nativeLib = NativeLibrary.getInstance();
  //   nativeLib.initialize();
  //
  //   // Create a receive port for this isolate
  //   final receivePort = ReceivePort();
  //
  //   // Send the port back to the main isolate
  //   sendPort.send(receivePort.sendPort);
  //
  //   // Listen for messages
  //   receivePort.listen((message) {
  //     if (message is List && message.length == 3) {
  //       final SendPort replyPort = message[0];
  //       final String requestJson = message[1];
  //       final bool isBatch = message[2];
  //
  //       try {
  //         final result = isBatch
  //             ? nativeLib.executeBatchRequests(requestJson)
  //             : nativeLib.executeRequest(requestJson);
  //         replyPort.send(result);
  //       } catch (e) {
  //         replyPort.send(e);
  //       }
  //     }
  //   });
  // }
  //
  // // Isolate pool manager
  // class IsolatePool {
  //   final int _poolSize;
  //   final List<SendPort> _availableIsolates = [];
  //   final List<Completer<void>> _initializationCompleters = [];
  //   final Queue<_PendingRequest> _pendingRequests = Queue();
  //
  //   IsolatePool(this._poolSize);
  //
  //   Future<void> initialize() async {
  //     for (int i = 0; i < _poolSize; i++) {
  //       final completer = Completer<void>();
  //       _initializationCompleters.add(completer);
  //
  //       final receivePort = ReceivePort();
  //       await Isolate.spawn(_isolateEntry, receivePort.sendPort);
  //
  //       receivePort.listen((message) {
  //         if (message is SendPort) {
  //           _availableIsolates.add(message);
  //           completer.complete();
  //         }
  //       });
  //     }
  //
  //     // Wait for all isolates to initialize
  //     await Future.wait(_initializationCompleters.map((c) => c.future));
  //   }
  //
  //   Future<String> run<T, R>(String requestJson, {bool isBatch = false}) async {
  //     if (_availableIsolates.isEmpty) {
  //       // Queue the request if no isolates are available
  //       final completer = Completer<String>();
  //       _pendingRequests.add(_PendingRequest(completer, requestJson, isBatch));
  //       return completer.future;
  //     }
  //
  //     final isolate = _availableIsolates.removeAt(0);
  //     final responsePort = ReceivePort();
  //
  //     try {
  //       isolate.send([responsePort.sendPort, requestJson, isBatch]);
  //
  //       final response = await responsePort.first;
  //
  //       // Return the isolate to the pool
  //       _availableIsolates.add(isolate);
  //
  //       // Process any pending requests
  //       _processPendingRequests();
  //
  //       if (response is String) {
  //         return response;
  //       } else if (response is Exception) {
  //         throw response;
  //       } else {
  //         throw Exception('Unexpected response type: ${response.runtimeType}');
  //       }
  //     } catch (e) {
  //       // Return the isolate to the pool even if there's an error
  //       _availableIsolates.add(isolate);
  //       _processPendingRequests();
  //       rethrow;
  //     }
  //   }
  //
  //   void _processPendingRequests() {
  //     while (_pendingRequests.isNotEmpty && _availableIsolates.isNotEmpty) {
  //       final request = _pendingRequests.removeFirst();
  //       final isolate = _availableIsolates.removeAt(0);
  //       final responsePort = ReceivePort();
  //
  //       isolate.send([responsePort.sendPort, request.requestJson, request.isBatch]);
  //
  //       responsePort.first.then((response) {
  //         _availableIsolates.add(isolate);
  //         _processPendingRequests();
  //
  //         if (response is String) {
  //           request.completer.complete(response);
  //         } else if (response is Exception) {
  //           request.completer.completeError(response);
  //         } else {
  //           request.completer.completeError(Exception('Unexpected response type'));
  //         }
  //       }).catchError((e) {
  //         _availableIsolates.add(isolate);
  //         _processPendingRequests();
  //         request.completer.completeError(e);
  //       });
  //     }
  //   }
  //
  //   Future<void> close() async {
  //     // No need to explicitly close isolates in Dart
  //     _availableIsolates.clear();
  //     _pendingRequests.clear();
  //   }
  // }
  //
  // class _PendingRequest {
  //   final Completer<String> completer;
  //   final String requestJson;
  //   final bool isBatch;
  //
  //   _PendingRequest(this.completer, this.requestJson, this.isBatch);
  // }