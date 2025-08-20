// import 'package:flutter/services.dart';
// import 'package:flutter_test/flutter_test.dart';
// import 'package:flutter_rust_http/flutter_rust_http_method_channel.dart';
//
// void main() {
//   TestWidgetsFlutterBinding.ensureInitialized();
//
//   MethodChannelFlutterRustHttp platform = MethodChannelFlutterRustHttp();
//   const MethodChannel channel = MethodChannel('flutter_rust_http');
//
//   setUp(() {
//     TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
//       channel,
//       (MethodCall methodCall) async {
//         return '42';
//       },
//     );
//   });
//
//   tearDown(() {
//     TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
//   });
//
//   test('getPlatformVersion', () async {
//     expect(await platform.getPlatformVersion(), '42');
//   });
// }
