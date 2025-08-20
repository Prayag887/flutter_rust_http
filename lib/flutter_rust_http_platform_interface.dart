// import 'package:plugin_platform_interface/plugin_platform_interface.dart';
//
// import 'flutter_rust_http_method_channel.dart';
//
// abstract class FlutterRustHttpPlatform extends PlatformInterface {
//   /// Constructs a FlutterRustHttpPlatform.
//   FlutterRustHttpPlatform() : super(token: _token);
//
//   static final Object _token = Object();
//
//   static FlutterRustHttpPlatform _instance = MethodChannelFlutterRustHttp();
//
//   /// The default instance of [FlutterRustHttpPlatform] to use.
//   ///
//   /// Defaults to [MethodChannelFlutterRustHttp].
//   static FlutterRustHttpPlatform get instance => _instance;
//
//   /// Platform-specific implementations should set this with their own
//   /// platform-specific class that extends [FlutterRustHttpPlatform] when
//   /// they register themselves.
//   static set instance(FlutterRustHttpPlatform instance) {
//     // PlatformInterface.verifyToken(instance, _token);
//     _instance = instance;
//   }
//
//   Future<String?> getPlatformVersion() {
//     throw UnimplementedError('platformVersion() has not been implemented.');
//   }
// }
