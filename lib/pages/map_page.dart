import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../data/campus_buildings.dart';
import '../data/campus_map.dart';
import '../data/sight_line.dart';
import '../models/club_event.dart';
import '../theme/app_theme.dart';
import '../widgets/building_card.dart';
import '../widgets/map_compass.dart';
import '../widgets/map_legend.dart';
import '../widgets/map_web.dart';

Point _point((double, double) lngLat) =>
    Point(coordinates: Position(lngLat.$1, lngLat.$2));

final _initialCamera = CameraViewportState(
  center: _point(CampusCamera.center),
  zoom: CampusCamera.zoom,
  pitch: CampusCamera.pitch,
  bearing: CampusCamera.bearing,
);

const _pinSource = 'mcmap-rsvps';
const _pinLayer = 'mcmap-rsvp-pins';
const _buildingSource = 'mcmap-buildings';
const _outlineSource = 'mcmap-building-outlines';
const _basemapSource = 'mcmap-building-basemap';
const _buildingLayer = 'mcmap-buildings-3d';
const _pinImage = 'mcmap-pin';
const _groupPinImage = 'mcmap-pin-group';

const _mapboxToken = String.fromEnvironment('MAPBOX_TOKEN');

class McGillMapPage extends StatefulWidget {
  const McGillMapPage({
    super.key,
    this.events = const [],
    this.onOpenEvent,
    this.onOpenOrganization,
  });

  /// The student's RSVPed events, shown as pins.
  final List<ClubEvent> events;
  final ValueChanged<ClubEvent>? onOpenEvent;

  /// Opens a society's page from a building card, by catalog id.
  final ValueChanged<String>? onOpenOrganization;

  @override
  State<McGillMapPage> createState() => _McGillMapPageState();
}

class _McGillMapPageState extends State<McGillMapPage> {
  MapboxMap? _map;
  bool _isLoading = true;
  String? _mapError;
  final _bearing = ValueNotifier(CampusCamera.bearing);
  List<CampusPin> _pins = const [];
  bool _pinsReady = false;
  bool _buildingsReady = false;
  bool _tapsReady = false;
  CampusBuilding? _selected;
  CampusBuilding? _hovered;
  Offset? _pointer;
  bool _checkingHover = false;
  double _width = 0;
  double _height = 0;

  @override
  void initState() {
    super.initState();
    _pins = campusPins(widget.events);
    final isSupportedPlatform =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!isSupportedPlatform) {
      _isLoading = false;
      _mapError = 'Interactive 3D maps are available on web, Android, and iOS in this app build.';
    } else if (_mapboxToken.isEmpty) {
      _isLoading = false;
      _mapError = 'No Mapbox token was provided. Run with --dart-define-from-file=.env.';
    }
  }

  @override
  void didUpdateWidget(McGillMapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.events, oldWidget.events)) {
      _pins = campusPins(widget.events);
      unawaited(_updatePins());
    }
  }

  CameraOptions get _resetCamera => CameraOptions(
    center: _point(CampusCamera.center),
    zoom: CampusCamera.zoom,
    pitch: CampusCamera.pitch,
    bearing: CampusCamera.bearing,
  );

  void _onMapCreated(MapboxMap map) {
    setState(() => _map = map);
    unawaited(_lockToCampus(map));
  }

  Future<void> _lockToCampus(MapboxMap map) async {
    await _try('camera limits', () async {
      await map.setBounds(
        CameraBoundsOptions(
          bounds: CoordinateBounds(
            southwest: _point(CampusCamera.southwest),
            northeast: _point(CampusCamera.northeast),
            infiniteBounds: false,
          ),
          minZoom: CampusCamera.minZoom,
          maxZoom: CampusCamera.maxZoom,
          minPitch: CampusCamera.minPitch,
          maxPitch: CampusCamera.maxPitch,
        ),
      );
    });
    await _try('gestures', () async {
      await map.gestures.updateSettings(
        GesturesSettings(
          scrollEnabled: true,
          pinchToZoomEnabled: true,
          // Two-finger twist; right-click or Ctrl + drag on desktop.
          rotateEnabled: true,
          simultaneousRotateAndPinchToZoomEnabled: true,
          // Two-finger vertical drag, and tilting while rotating on desktop.
          pitchEnabled: true,
          pitchWithRotateEnabled: true,
        ),
      );
    });
    // The McGill compass replaces these.
    await _try('ornaments', () async {
      await map.compass.updateSettings(CompassSettings(enabled: false));
      await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    });
  }

  /// Glides back once the map comes to rest too close to the campus edge.
  Future<void> _keepCampusInView() async {
    final map = _map;
    if (map == null) return;
    await _try('campus view', () async {
      final camera = await map.getCameraState();
      final position = camera.center.coordinates;
      final (longitude, latitude) = (
        position.lng.toDouble(),
        position.lat.toDouble(),
      );
      final target = CampusCamera.keepInView((
        longitude,
        latitude,
      ), zoom: camera.zoom);
      if (!mounted ||
          (target.$1 - longitude).abs() + (target.$2 - latitude).abs() < 1e-5) {
        return;
      }
      final options = CameraOptions(center: _point(target));
      if (MediaQuery.disableAnimationsOf(context)) {
        await map.setCamera(options);
      } else {
        await map.easeTo(options, MapAnimationOptions(duration: 600));
      }
    });
  }

  /// The map still works if one refinement isn't available on a platform.
  Future<void> _try(String what, Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      debugPrint('McMap: $what could not be applied: $error');
    }
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    final map = _map;
    if (map == null) return;
    _pinsReady = false;
    keepMapBehindFlutter();
    // One at a time: an option this style version doesn't have can't block
    // the rest.
    for (final MapEntry(:key, :value) in campusBasemap.entries) {
      await _try(
        key,
        () => map.setStyleImportConfigProperty('basemap', key, value),
      );
    }
    _buildingsReady = false;
    // Buildings first, so pins draw on top and win taps.
    await _try('buildings', () => _addBuildings(map));
    await _try('pins', () => _addPins(map));
    // Once: they outlive the style.
    if (!_tapsReady) await _try('taps', () async => _addTaps(map));
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _addBuildings(MapboxMap map) async {
    for (final (id, data) in [
      (_outlineSource, campusOutlineCollection()),
      (_basemapSource, campusBasemapCollection()),
      (_buildingSource, campusBuildingCollection()),
    ]) {
      if (!await map.styleSourceExists(id)) {
        await map.addStyleSource(
          id,
          jsonEncode({'type': 'geojson', 'data': data}),
        );
      }
    }
    for (final layer in _buildingLayerSpecs) {
      final id = layer['id']! as String;
      // Separately, so the colours still show if the glow or the removal of
      // the basemap's copy isn't supported.
      await _try(id, () async {
        if (!await map.styleLayerExists(id)) {
          await map.addStyleLayer(jsonEncode(layer), null);
        }
      });
    }
    _buildingsReady = true;
    if (_selected case final selected?) {
      await _setBuildingState(selected, 'selected', true);
    }
  }

  /// Pins first, then buildings, then everything else closes the card.
  void _addTaps(MapboxMap map) {
    _tapsReady = true;
    map
      ..addInteraction(
        TapInteraction.onMap((_) => _select(null)),
        interactionID: 'mcmap-background',
      )
      ..addInteraction(
        // Hits the exact 3D shape, whatever the tilt and rotation.
        TapInteraction(FeaturesetDescriptor(layerId: _buildingLayer), (
          feature,
          context,
        ) async {
          final building = campusBuildingsById[feature.properties['building']];
          final point = context.touchPosition;
          final hidden =
              building != null &&
              await _isHidden(building, Offset(point.x, point.y));
          _select(hidden ? null : building);
        }),
        interactionID: _buildingLayer,
      )
      ..addInteraction(
        TapInteraction(FeaturesetDescriptor(layerId: _pinLayer), (feature, _) {
          _onPinTapped(feature.properties['key']);
        }),
        interactionID: _pinLayer,
      );
  }

  /// Whether another building stands in front of [building] at [point]. The
  /// map reports everything along the line of sight, hidden or not.
  Future<bool> _isHidden(CampusBuilding building, Offset point) async {
    final map = _map;
    if (map == null) return false;
    var hidden = false;
    await _try('line of sight', () async {
      final camera = await map.getCameraState();
      final others = await map.basemapBuildingsAt(point);
      final middle = camera.center.coordinates;
      final line = SightLine.through(
        x: point.dx,
        y: point.dy,
        width: _width,
        height: _height,
        center: (middle.lng.toDouble(), middle.lat.toDouble()),
        zoom: camera.zoom,
        pitch: camera.pitch,
        bearing: camera.bearing,
      );
      final distance = building.shape.distanceOn(line);
      if (distance == null) return;
      for (final (polygons, base, top) in others) {
        for (final rings in polygons) {
          final other = line.distanceTo(rings, base: base, top: top);
          // Walls shared with a neighbour are the same distance away.
          if (other != null && other < distance - 1.5) {
            hidden = true;
            return;
          }
        }
      }
    });
    return hidden;
  }

  Future<void> _setBuildingState(
    CampusBuilding building,
    String key,
    bool value,
  ) => _try('building highlight', () async {
    final map = _map;
    if (map == null || !_buildingsReady) return;
    for (final source in [_buildingSource, _outlineSource]) {
      await map.setFeatureState(
        source,
        null,
        '${building.featureId}',
        jsonEncode({key: value}),
      );
    }
  });

  void _select(CampusBuilding? building) {
    final previous = _selected;
    if (!mounted || building == previous) return;
    setState(() => _selected = building);
    if (previous != null) {
      unawaited(_setBuildingState(previous, 'selected', false));
      // Touch leaves no pointer behind to end the hover.
      unawaited(_onHover(null));
    }
    if (building != null) {
      unawaited(_setBuildingState(building, 'selected', true));
      unawaited(_focusOn(building));
    }
  }

  bool get _isWide => _width >= 700;
  double get _sheetHeight => math.min(_height * 0.5, 420);

  Future<void> _focusOn(CampusBuilding building) => _try('focus', () async {
    final map = _map;
    if (map == null) return;
    final camera = await map.getCameraState();
    if (!mounted) return;
    final zoom = math.max(camera.zoom, CampusCamera.buildingZoom);
    // Less tilt, so neighbouring towers don't hide it.
    final pitch = math.min(camera.pitch, CampusCamera.buildingPitch);
    final options = CameraOptions(
      center: _point(
        CampusCamera.focusOn(
          building.shape.center,
          zoom: zoom,
          bearing: camera.bearing,
          pitch: pitch,
          left: _isWide ? (_cardWidth + 16) / 2 : 0,
          up: _isWide ? 0 : _sheetHeight / 2,
        ),
      ),
      zoom: zoom,
      pitch: pitch,
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      await map.setCamera(options);
    } else {
      await map.easeTo(options, MapAnimationOptions(duration: 900));
    }
  });

  /// Mouse only: a pointer cursor over pins and buildings, and a glow.
  Future<void> _onHover(Offset? position) async {
    _pointer = position;
    if (_checkingHover) return;
    _checkingHover = true;
    try {
      Offset? checked;
      do {
        checked = _pointer;
        await _hoverAt(checked);
      } while (mounted && checked != _pointer);
    } finally {
      _checkingHover = false;
    }
  }

  Future<void> _hoverAt(Offset? position) => _try('hover', () async {
    final map = _map;
    if (map == null || !_buildingsReady) return;
    var clickable = false;
    CampusBuilding? building;
    if (position != null) {
      final hits = await map.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenCoordinate(
          ScreenCoordinate(x: position.dx, y: position.dy),
        ),
        RenderedQueryOptions(layerIds: [_pinLayer, _buildingLayer]),
      );
      final top = hits.nonNulls.firstOrNull;
      clickable = top != null;
      if (top != null && !top.layers.contains(_pinLayer)) {
        final properties = top.queriedFeature.feature['properties'];
        if (properties is Map) {
          building = campusBuildingsById[properties['building']];
          if (building != null && await _isHidden(building, position)) {
            building = null;
            clickable = false;
          }
        }
      }
    }
    if (!mounted) return;
    setMapPointerCursor(clickable);
    final previous = _hovered;
    if (building == previous) return;
    _hovered = building;
    if (previous != null) await _setBuildingState(previous, 'hover', false);
    if (building != null) await _setBuildingState(building, 'hover', true);
  });

  Future<void> _addPins(MapboxMap map) async {
    for (final (id, dot) in [(_pinImage, true), (_groupPinImage, false)]) {
      await map.addImage(
        id,
        _pinPixelRatio,
        StyleImage.bytes(await _drawPin(dot: dot)),
      );
    }
    if (!await map.styleSourceExists(_pinSource)) {
      await map.addStyleSource(
        _pinSource,
        jsonEncode({'type': 'geojson', 'data': campusPinCollection(_pins)}),
      );
    }
    if (!await map.styleLayerExists(_pinLayer)) {
      await map.addStyleLayer(jsonEncode(_pinLayerSpec), null);
    }
    _pinsReady = true;
    await _updatePins();
  }

  Future<void> _updatePins() async {
    final map = _map;
    if (map == null || !_pinsReady) return;
    await _try(
      'pins',
      () => map.setStyleSourceProperty(
        _pinSource,
        'data',
        jsonEncode(campusPinCollection(_pins)),
      ),
    );
  }

  void _onPinTapped(Object? key) {
    final pin = _pins.where((pin) => pin.key == key).firstOrNull;
    final open = widget.onOpenEvent;
    if (!mounted || pin == null || open == null) return;
    if (pin.events.length == 1) return open(pin.events.single);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final event in pin.events)
              ListTile(
                leading: const Icon(
                  Icons.place_rounded,
                  color: McMapColors.red,
                ),
                title: Text(event.title),
                subtitle: Text(event.location),
                onTap: () {
                  Navigator.of(sheet).pop();
                  open(event);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _onMapLoadError(MapLoadingErrorEventData event) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _mapError = event.message.isEmpty
          ? 'The map could not be loaded. Check your connection.'
          : event.message;
    });
  }

  Future<void> _resetCameraPosition() async {
    final map = _map;
    if (map == null) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      await map.setCamera(_resetCamera);
    } else {
      await map.flyTo(_resetCamera, MapAnimationOptions(duration: 1200));
    }
  }

  @override
  void dispose() {
    _map = null;
    _bearing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _width = constraints.maxWidth;
      _height = constraints.maxHeight;
      return Stack(
        fit: StackFit.expand,
        children: [
          if (_mapboxToken.isNotEmpty &&
              (kIsWeb ||
                  defaultTargetPlatform == TargetPlatform.android ||
                  defaultTargetPlatform == TargetPlatform.iOS))
            MouseRegion(
              onHover: (event) => unawaited(_onHover(event.localPosition)),
              onExit: (_) => unawaited(_onHover(null)),
              child: MapWidget(
                styleUri: MapboxStyles.STANDARD,
                viewport: _initialCamera,
                onMapCreated: _onMapCreated,
                onStyleLoadedListener: _onStyleLoaded,
                onMapLoadErrorListener: _onMapLoadError,
                onMapIdleListener: (_) => unawaited(_keepCampusInView()),
                onCameraChangeListener: (event) {
                  if (mounted) _bearing.value = event.cameraState.bearing;
                },
                isOpaque: true,
              ),
            ),
          if (_isLoading)
            const ColoredBox(
              color: McMapColors.surfaceMuted,
              child: Center(
                child: CircularProgressIndicator(color: McMapColors.red),
              ),
            ),
          if (_mapError != null)
            ColoredBox(
              color: McMapColors.surfaceMuted,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off_rounded,
                        size: 42,
                        color: McMapColors.red,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Map unavailable',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _mapError!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            right: 16,
            top: 16,
            child: MapCompass(
              bearing: _bearing,
              onPressed: _map == null ? null : _resetCameraPosition,
            ),
          ),
          if (_mapError == null)
            const Positioned(left: 16, top: 16, child: MapLegend()),
          if (_selected case final building?) _card(building),
        ],
      );
    },
  );

  Widget _card(CampusBuilding building) {
    Widget card(BorderRadius radius) => BuildingCard(
      key: ValueKey(building.id),
      building: building,
      borderRadius: radius,
      onClose: () => _select(null),
      onOpenOrganization: widget.onOpenOrganization,
    );
    if (_isWide) {
      return Positioned(
        right: 16,
        // Clear of the compass above and Mapbox's credits below.
        top: 76,
        bottom: 40,
        width: _cardWidth,
        child: Align(
          alignment: Alignment.topCenter,
          child: card(const BorderRadius.all(Radius.circular(16))),
        ),
      );
    }
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: _sheetHeight),
        child: card(const BorderRadius.vertical(top: Radius.circular(20))),
      ),
    );
  }
}

extension on MapboxMap {
  /// The basemap's buildings under [point] that we haven't replaced, as
  /// GeoJSON polygons with their heights in metres.
  Future<List<(List<List<dynamic>>, double, double)>> basemapBuildingsAt(
    Offset point,
  ) async {
    final features = await queryRenderedFeaturesForFeatureset(
      featureset: StandardBuildings(),
      geometry: RenderedQueryGeometry.fromScreenCoordinate(
        ScreenCoordinate(x: point.dx, y: point.dy),
      ),
    );
    return [
      for (final feature in features)
        (
          [
            for (final rings in switch (feature.geometry) {
              {'type': 'Polygon', 'coordinates': final List<dynamic> rings} => [
                rings,
              ],
              {
                'type': 'MultiPolygon',
                'coordinates': final List<dynamic> polygons,
              } =>
                polygons.cast<List<dynamic>>(),
              _ => const <List<dynamic>>[],
            })
              if (!isReplacedBasemapBuilding(feature.id?.id, rings)) rings,
          ],
          (feature.properties['min_height'] as num? ?? 0).toDouble(),
          (feature.properties['height'] as num? ?? 0).toDouble(),
        ),
    ];
  }
}

const _cardWidth = 380.0;

const _isSelected = [
  'boolean',
  ['feature-state', 'selected'],
  false,
];
const _isHovered = [
  'boolean',
  ['feature-state', 'hover'],
  false,
];

const _buildingLayerSpecs = <Map<String, Object>>[
  // A glow on the ground around the hovered or selected building.
  {
    'id': 'mcmap-building-glow',
    'type': 'line',
    'source': _outlineSource,
    'slot': 'middle',
    'layout': {'line-join': 'round'},
    'paint': {
      'line-color': ['get', 'color'],
      'line-width': 14,
      'line-blur': 8,
      'line-emissive-strength': 1,
      'line-opacity': ['case', _isSelected, 1, _isHovered, 0.7, 0],
    },
  },
  // Removes the basemap's own copy of these buildings. Must be above them,
  // and below ours.
  {
    'id': 'mcmap-building-clear',
    'type': 'clip',
    'source': _basemapSource,
    'slot': 'top',
    'layout': {
      'clip-layer-types': ['model', 'symbol'],
      'clip-layer-scope': ['basemap'],
    },
  },
  {
    'id': _buildingLayer,
    'type': 'fill-extrusion',
    'source': _buildingSource,
    'slot': 'top',
    'paint': {
      'fill-extrusion-color': [
        'case',
        _isSelected,
        ['get', 'selected'],
        _isHovered,
        ['get', 'hover'],
        ['get', 'color'],
      ],
      'fill-extrusion-base': ['get', 'base'],
      'fill-extrusion-height': ['get', 'top'],
      'fill-extrusion-emissive-strength': 0.35,
      // Soft shading where walls meet the ground and each other.
      'fill-extrusion-ambient-occlusion-intensity': 0.35,
      'fill-extrusion-ambient-occlusion-wall-radius': 3,
    },
  },
];

const _pinLayerSpec = <String, Object>{
  'id': _pinLayer,
  'type': 'symbol',
  'source': _pinSource,
  'slot': 'top',
  'layout': {
    'icon-image': [
      'case',
      [
        '==',
        ['get', 'count'],
        '',
      ],
      _pinImage,
      _groupPinImage,
    ],
    'icon-anchor': 'bottom',
    'icon-allow-overlap': true,
    'icon-ignore-placement': true,
    'text-field': ['get', 'count'],
    'text-size': 14,
    'text-font': ['DIN Pro Bold', 'Arial Unicode MS Bold'],
    'text-offset': [0, -2.2],
    'text-allow-overlap': true,
    'text-ignore-placement': true,
  },
  'paint': {
    // Full colour in any lighting, and visible behind buildings.
    'icon-emissive-strength': 1,
    'icon-occlusion-opacity': 1,
    'text-emissive-strength': 1,
    'text-occlusion-opacity': 1,
    'text-color': '#FFFFFF',
  },
};

const _pinPixelRatio = 3.0;

/// A McGill-red pin whose tip is the bottom centre of the image. Pins for
/// several events leave out the [dot] to make room for the count.
Future<Uint8List> _drawPin({required bool dot}) async {
  const width = 38.0;
  const height = 50.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(_pinPixelRatio);
  final pin = Path()
    ..moveTo(19, 48.5)
    ..cubicTo(14, 38, 3, 31, 3, 18.5)
    ..arcToPoint(
      const Offset(35, 18.5),
      radius: const Radius.circular(16),
      largeArc: true,
    )
    ..cubicTo(35, 31, 24, 38, 19, 48.5)
    ..close();
  canvas
    ..drawPath(pin, Paint()..color = McMapColors.red)
    ..drawPath(
      pin,
      Paint()
        ..color = McMapColors.white
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 2.5,
    );
  if (dot) {
    canvas.drawCircle(
      const Offset(19, 18.5),
      5.5,
      Paint()..color = McMapColors.white,
    );
  }
  final image = await recorder.endRecording().toImage(
    (width * _pinPixelRatio).toInt(),
    (height * _pinPixelRatio).toInt(),
  );
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return png!.buffer.asUint8List();
}
