// Small fixes to Mapbox's page elements on the web. Do nothing elsewhere.
export 'map_web_stub.dart' if (dart.library.js_interop) 'map_web_impl.dart';
