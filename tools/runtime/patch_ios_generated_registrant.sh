#!/usr/bin/env bash
set -euo pipefail

registrant="${SRCROOT:-}/Runner/GeneratedPluginRegistrant.m"
if [ ! -f "$registrant" ]; then
  exit 0
fi

ruby - "$registrant" <<'RUBY'
path = ARGV.fetch(0)
text = File.read(path)
exit 0 if text.include?('static void RegisterFlutterPlugin')

modules = {
  'FilePickerPlugin' => 'file_picker',
  'FLTFirebaseCorePlugin' => 'firebase_core',
  'FLTFirebaseMessagingPlugin' => 'firebase_messaging',
  'FlutterLocalNotificationsPlugin' => 'flutter_local_notifications',
  'GalPlugin' => 'gal',
  'FLTImagePickerPlugin' => 'image_picker_ios',
  'FLALocalAuthPlugin' => 'local_auth_darwin',
  'MobileScannerPlugin' => 'mobile_scanner',
  'PdfxPlugin' => 'pdfx',
  'FPPSharePlusPlugin' => 'share_plus',
  'SharedPreferencesPlugin' => 'shared_preferences_foundation',
  'URLLauncherPlugin' => 'url_launcher_ios',
  'WebViewFlutterPlugin' => 'webview_flutter_wkwebview',
}

generated_modules = text.scan(
  /#if __has_include\(<[^>]+\/([A-Za-z0-9_]+)\.h>\)\s*#import[^\n]*\s*#else\s*@import\s+([A-Za-z0-9_]+);\s*#endif/m,
).to_h
modules.merge!(generated_modules)

text = text.sub(
  '@implementation GeneratedPluginRegistrant',
  "static void RegisterFlutterPlugin(NSObject<FlutterPluginRegistry>* registry, NSString* className, NSString* moduleName);\n\n@implementation GeneratedPluginRegistrant",
)

text = text.gsub(
  /  \[([A-Za-z0-9_]+) registerWithRegistrar:\[registry registrarForPlugin:@"([^"]+)"\]\];/,
) do
  class_name = Regexp.last_match(1)
  module_name = modules.fetch(class_name, Regexp.last_match(2))
  "  RegisterFlutterPlugin(registry, @\"#{class_name}\", @\"#{module_name}\");"
end

helper = <<'OBJC'

static void RegisterFlutterPlugin(NSObject<FlutterPluginRegistry>* registry, NSString* className, NSString* moduleName) {
  Class pluginClass = NSClassFromString(className);
  if (pluginClass == Nil) {
    pluginClass = NSClassFromString([NSString stringWithFormat:@"%@.%@", moduleName, className]);
  }
  if (pluginClass == Nil || ![pluginClass respondsToSelector:@selector(registerWithRegistrar:)]) {
    return;
  }
  NSObject<FlutterPluginRegistrar>* registrar = [registry registrarForPlugin:className];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
  [pluginClass performSelector:@selector(registerWithRegistrar:) withObject:registrar];
#pragma clang diagnostic pop
}
OBJC

text = text.sub(/\n@end\s*\z/, "\n@end\n#{helper}")
File.write(path, text)
RUBY
