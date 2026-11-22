import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../theme/app_theme.dart';

final _mcgillCampus = Point(coordinates: Position(-73.5772, 45.5048));

final _initialCamera = CameraViewportState(
  center: _mcgillCampus,
  zoom: 15.8,
  pitch: 65,
  bearing: -20,
);

const _mapboxToken = String.fromEnvironment('MAPBOX_TOKEN');

class McGillMapPage extends StatefulWidget {
  const McGillMapPage({super.key});

  @override
  State<McGillMapPage> createState() => _McGillMapPageState();
}

class _McGillMapPageState extends State<McGillMapPage> {
  MapboxMap? _map;
  bool _isLoading = true;
  String? _mapError;

  @override
  void initState() {
    super.initState();
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

  CameraOptions get _resetCamera =>
      CameraOptions(center: _mcgillCampus, zoom: 15.8, pitch: 65, bearing: -20);

  void _onMapCreated(MapboxMap map) {
    _map = map;
  }

  void _onStyleLoaded(StyleLoadedEventData _) {
    if (mounted) setState(() => _isLoading = false);
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
    await map.flyTo(_resetCamera, MapAnimationOptions(duration: 1200));
  }

  @override
  void dispose() {
    _map = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_mapboxToken.isNotEmpty &&
            (kIsWeb ||
                defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS))
          MapWidget(
            styleUri: MapboxStyles.STANDARD,
            viewport: _initialCamera,
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: _onStyleLoaded,
            onMapLoadErrorListener: _onMapLoadError,
            isOpaque: true,
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
          bottom: 16,
          child: Material(
            color: McMapColors.white,
            elevation: 4,
            shadowColor: McMapColors.ink.withValues(alpha: 0.22),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: IconButton(
              tooltip: 'Recenter on McGill',
              onPressed: _map == null ? null : _resetCameraPosition,
              icon: const Icon(
                Icons.my_location_rounded,
                color: McMapColors.red,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
