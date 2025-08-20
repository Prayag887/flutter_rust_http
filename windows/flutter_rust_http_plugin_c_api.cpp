#include "include/flutter_rust_http/flutter_rust_http_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flutter_rust_http_plugin.h"

void FlutterRustHttpPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_rust_http::FlutterRustHttpPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
