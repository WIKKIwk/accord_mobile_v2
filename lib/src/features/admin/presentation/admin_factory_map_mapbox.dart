import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapboxFactoryMapViewport extends StatefulWidget {
  const MapboxFactoryMapViewport({super.key});

  @override
  State<MapboxFactoryMapViewport> createState() =>
      _MapboxFactoryMapViewportState();
}

class _MapboxFactoryMapViewportState extends State<MapboxFactoryMapViewport> {
  static const _factoryModelId = 'accord-factory-model';
  static const _factorySourceId = 'accord-factory-source';
  static const _factoryLayerId = 'accord-factory-layer';

  MapboxMap? _map;
  bool _modelAdded = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MapWidget(
          key: const ValueKey('accord-mapbox-factory-map'),
          styleUri: '',
          viewport: CameraViewportState(
            center: Point(coordinates: Position(0, 0)),
            zoom: 16.5,
            bearing: 35,
            pitch: 55,
          ),
          onMapCreated: _onMapCreated,
          onStyleLoadedListener: (_) {
            unawaited(_installFactoryModel());
          },
        ),
        if (_error != null)
          ColoredBox(
            color: const Color(0xE6202426),
            child: Center(
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          )
        else if (!_modelAdded)
          const ColoredBox(
            color: Color(0x66202426),
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ],
    );
  }

  void _onMapCreated(MapboxMap map) {
    _map = map;
    unawaited(
      map.gestures.updateSettings(
        GesturesSettings(
          rotateEnabled: true,
          pinchToZoomEnabled: true,
          scrollEnabled: true,
          pitchEnabled: true,
        ),
      ),
    );
    unawaited(map.loadStyleJson(_factoryStyleJson));
  }

  Future<void> _installFactoryModel() async {
    final map = _map;
    if (map == null || _modelAdded) {
      return;
    }

    try {
      await map.style.addStyleModel(
        _factoryModelId,
        'asset://assets/models/zavod6-phone.glb',
      );
      await map.style.addSource(
        GeoJsonSource(id: _factorySourceId, data: _factorySourceJson),
      );

      final layer = ModelLayer(
        id: _factoryLayerId,
        sourceId: _factorySourceId,
        modelId: _factoryModelId,
        modelType: ModelType.COMMON_3D,
        modelScale: const [1, 1, 1],
        modelRotation: const [0, 0, 0],
        modelElevationReference: ModelElevationReference.GROUND,
        modelAllowDensityReduction: false,
        modelAmbientOcclusionIntensity: 1,
        modelCastShadows: true,
        modelReceiveShadows: true,
        modelColorMixIntensity: 0,
      );
      await map.style.addLayer(layer);

      if (mounted) {
        setState(() => _modelAdded = true);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Mapbox zavod modeli yuklanmadi: $error');
      }
    }
  }
}

const _factoryStyleJson = '''
{
  "version": 8,
  "name": "Accord Factory",
  "sources": {},
  "layers": [
    {
      "id": "accord-factory-background",
      "type": "background",
      "paint": { "background-color": "#202426" }
    }
  ]
}
''';

final _factorySourceJson = jsonEncode({
  'type': 'FeatureCollection',
  'features': [
    {
      'type': 'Feature',
      'properties': {'id': 'factory'},
      'geometry': {
        'type': 'Point',
        'coordinates': [0, 0],
      },
    },
  ],
});
