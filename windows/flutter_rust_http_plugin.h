#ifndef FLUTTER_PLUGIN_FLUTTER_RUST_HTTP_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_RUST_HTTP_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace flutter_rust_http {

class FlutterRustHttpPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  FlutterRustHttpPlugin();

  virtual ~FlutterRustHttpPlugin();

  // Disallow copy and assign.
  FlutterRustHttpPlugin(const FlutterRustHttpPlugin&) = delete;
  FlutterRustHttpPlugin& operator=(const FlutterRustHttpPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace flutter_rust_http

#endif  // FLUTTER_PLUGIN_FLUTTER_RUST_HTTP_PLUGIN_H_
