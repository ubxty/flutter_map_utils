import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_utils/flutter_map_utils.dart';

void main() {
  group('GeoJsonUtils export', () {
    test('polygon to GeoJSON Feature', () {
      final poly = DrawablePolygon(
        id: 'gj1',
        points: [LatLng(0, 0), LatLng(1, 0), LatLng(1, 1), LatLng(0, 1)],
        style: ShapeStylePresets.zone,
        metadata: {'name': 'Test Zone'},
      );
      final feature = GeoJsonUtils.toGeoJsonFeature(poly);
      expect(feature['type'], 'Feature');
      expect(feature['geometry']['type'], 'Polygon');
      expect(feature['properties']['name'], 'Test Zone');
    });

    test('polyline to GeoJSON Feature', () {
      final line = DrawablePolyline(
        id: 'gj2',
        points: [LatLng(0, 0), LatLng(1, 1)],
        style: ShapeStylePresets.route,
      );
      final feature = GeoJsonUtils.toGeoJsonFeature(line);
      expect(feature['geometry']['type'], 'LineString');
    });

    test('circle to GeoJSON Feature with radius in properties', () {
      final circle = DrawableCircle(
        id: 'gj3',
        center: LatLng(10, 20),
        radiusMeters: 500,
        style: ShapeStylePresets.zone,
      );
      final feature = GeoJsonUtils.toGeoJsonFeature(circle);
      expect(feature['geometry']['type'], 'Point');
      expect(feature['properties']['radius'], 500);
    });

    test('toFeatureCollection creates collection', () {
      final shapes = <DrawableShape>[
        DrawablePolygon(
          id: 'gj4',
          points: [LatLng(0, 0), LatLng(1, 0), LatLng(1, 1)],
          style: ShapeStylePresets.zone,
        ),
        DrawablePolyline(
          id: 'gj5',
          points: [LatLng(2, 2), LatLng(3, 3)],
          style: ShapeStylePresets.route,
        ),
      ];
      final collection = GeoJsonUtils.toFeatureCollection(shapes);
      expect(collection['type'], 'FeatureCollection');
      expect((collection['features'] as List).length, 2);
    });

    test('toGeoJsonString produces valid JSON', () {
      final shapes = <DrawableShape>[
        DrawablePolygon(
          id: 'gj6',
          points: [LatLng(0, 0), LatLng(1, 0), LatLng(1, 1)],
          style: ShapeStylePresets.zone,
        ),
      ];
      final jsonStr = GeoJsonUtils.toGeoJsonString(shapes);
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(parsed['type'], 'FeatureCollection');
    });
  });

  group('GeoJsonUtils import', () {
    test('fromGeoJson imports polygon', () {
      final geojson = {
        'type': 'Feature',
        'geometry': {
          'type': 'Polygon',
          'coordinates': [
            [
              [0.0, 0.0],
              [1.0, 0.0],
              [1.0, 1.0],
              [0.0, 1.0],
              [0.0, 0.0],
            ]
          ],
        },
        'properties': {'name': 'Imported'},
      };
      final shapes = GeoJsonUtils.fromGeoJson(geojson);
      expect(shapes.length, 1);
      expect(shapes.first, isA<DrawablePolygon>());
      expect(shapes.first.metadata['name'], 'Imported');
    });

    test('fromGeoJson imports linestring', () {
      final geojson = {
        'type': 'Feature',
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            [0.0, 0.0],
            [1.0, 1.0],
          ],
        },
        'properties': {},
      };
      final shapes = GeoJsonUtils.fromGeoJson(geojson);
      expect(shapes.length, 1);
      expect(shapes.first, isA<DrawablePolyline>());
    });

    test('fromGeoJson imports circle from Point with radius', () {
      final geojson = {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [20.0, 10.0],
        },
        'properties': {'radius': 500.0},
      };
      final shapes = GeoJsonUtils.fromGeoJson(geojson);
      expect(shapes.length, 1);
      expect(shapes.first, isA<DrawableCircle>());
      expect((shapes.first as DrawableCircle).radiusMeters, 500);
    });

    test('fromGeoJson imports FeatureCollection', () {
      final geojson = {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Polygon',
              'coordinates': [
                [
                  [0.0, 0.0],
                  [1.0, 0.0],
                  [1.0, 1.0],
                  [0.0, 0.0],
                ]
              ],
            },
            'properties': {},
          },
          {
            'type': 'Feature',
            'geometry': {
              'type': 'LineString',
              'coordinates': [
                [2.0, 2.0],
                [3.0, 3.0],
              ],
            },
            'properties': {},
          },
        ],
      };
      final shapes = GeoJsonUtils.fromGeoJson(geojson);
      expect(shapes.length, 2);
    });

    test('roundtrip: export then import', () {
      final original = DrawablePolygon(
        id: 'roundtrip1',
        points: [
          LatLng(0, 0),
          LatLng(1, 0),
          LatLng(1, 1),
          LatLng(0, 1),
        ],
        style: ShapeStylePresets.zone,
        metadata: {'name': 'roundtrip'},
      );
      final geojsonStr = GeoJsonUtils.toGeoJsonString([original]);
      final imported = GeoJsonUtils.fromGeoJsonString(geojsonStr);
      expect(imported.length, 1);
      expect(imported.first, isA<DrawablePolygon>());
      final restored = imported.first as DrawablePolygon;
      expect(restored.points.length, original.points.length);
      expect(restored.metadata['name'], 'roundtrip');
    });
  });
}
