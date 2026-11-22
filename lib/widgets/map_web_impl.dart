import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('document')
external JSObject get _document;

void _setStyle(String selector, String property, String value) => _document
    .callMethod<JSObject?>('querySelector'.toJS, selector.toJS)
    ?.getProperty<JSObject?>('style'.toJS)
    ?.setProperty(property.toJS, value.toJS);

/// A pointer over clickable things. Mapbox sets its own cursor on the map, so
/// Flutter's has no effect there; the canvas sits inside that and wins.
void setMapPointerCursor(bool pointer) =>
    _setStyle('.mapboxgl-canvas', 'cursor', pointer ? 'pointer' : '');

/// Stops Mapbox's logo and credits from drawing over cards and sheets.
void keepMapBehindFlutter() =>
    _setStyle('.mapboxgl-map', 'isolation', 'isolate');
