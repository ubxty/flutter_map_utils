import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_utils_core/map_utils_core.dart';

void main() {
  group('GeoJsonUtils export', () {
    test('polygon to GeoJSON Feature', () {
      final poly = DrawablePolygon(
        id: 'gj1',
        points: [LatLng(0, 0), LatLng(1, 0), LatLng(1, 1), LatLng(0, 1)],
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
      );
      final feature = GeoJsonUtils.toGeoJsonFeature(line);
      expect(feature['geometry']['type'], 'LineString');
    });

    test('circle to GeoJSON Feature with radius in properties', () {
      final circle = DrawableCircle(
        id: 'gj3',
        center: LatLng(10, 20),
        radiusMeters: 500,
      );
      final feature = GeoJsonUtils.toGeoJsonFeature(circle);
      expect(feature['geometry']['type'], 'Point');
      expect(feature['properties']['radius'], 500);
    });

    test('rectangle to GeoJSON Feature as Polygon', () {
      final rect = DrawableRectangle.fromCorners(
        id: 'gj_rect',
        corner1: LatLng(0, 0),
        corner2: LatLng(1, 1),
      );
      final feature = GeoJsonUtils.toGeoJsonFeature(rect);
      expect(feature['geometry']['type'], 'Polygon');
      expect(feature['properties']['shapeType'], 'rectangle');
    });

    test('polygon with holes exports correctly', () {
      final poly = DrawablePolygon(
        id: 'gj_holes',
        points: [LatLng(0, 0), LatLng(0, 10), LatLng(10, 10), LatLng(10, 0)],
        holes: [
          [LatLng(2, 2), LatLng(2, 4), LatLng(4, 4), LatLng(4, 2)],
        ],
      );
      final feature = GeoJsonUtils.toGeoJsonFeature(poly);
      final rings =
          feature['geometry']['coordinates'] as List;
      expect(rings.length, 2); // outer + 1 hole
    });

    test('toFeatureCollection creates collection', () {
      final shapes = <DrawableShape>[
        DrawablePolygon(
          id: 'gj4',
          points: [LatLng(0, 0), LatLng(1, 0), LatLng(1, 1)],
        ),
        DrawablePolyline(
          id: 'gj5',
          points: [LatLng(2, 2), LatLng(3, 3)],
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
        ),
      ];
      final jsonStr = GeoJsonUtils.toGeoJsonString(shapes);
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(parsed['type'], 'FeatureCollection');
    });

    test('toGeoJsonString pretty prints', () {
      final shapes = <DrawableShape>[
        DrawablePolygon(
          id: 'gj7',
          points: [LatLng(0, 0), LatLng(1, 0), LatLng(1, 1)],
        ),
      ];
      final jsonStr = GeoJsonUtils.toGeoJsonString(shapes, pretty: true);
      expect(jsonStr, contains('\n'));
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

    test('fromGeoJson imports rectangle via shapeType hint', () {
      final geojson = {
        'type': 'Feature',
        'geometry': {
          'type': 'Polygon',
          'coordinates': [
            [
              [0.0, 1.0],
              [1.0, 1.0],
              [1.0, 0.0],
              [0.0, 0.0],
              [0.0, 1.0],
            ]
          ],
        },
        'properties': {'shapeType': 'rectangle'},
      };
      final shapes = GeoJsonUtils.fromGeoJson(geojson);
      expect(shapes.length, 1);
      expect(shapes.first, isA<DrawableRectangle>());
    });

    test('fromGeoJson handles raw geometry', () {
      final geojson = {
        'type': 'LineString',
        'coordinates': [
          [0.0, 0.0],
          [1.0, 1.0],
        ],
      };
      final shapes = GeoJsonUtils.fromGeoJson(geojson);
      expect(shapes.length, 1);
      expect(shapes.first, isA<DrawablePolyline>());
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
