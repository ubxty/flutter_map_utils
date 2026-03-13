import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_utils/flutter_map_utils.dart';

void main() {
  group('SnappingEngine', () {
    final shapes = [
      DrawablePolygon(
        id: 'poly1',
        points: [
          LatLng(0, 0),
          LatLng(0, 0.001),
          LatLng(0.001, 0.001),
          LatLng(0.001, 0),
        ],
        style: ShapeStylePresets.zone,
      ),
      DrawablePolyline(
        id: 'line1',
        points: [LatLng(0.01, 0), LatLng(0.01, 0.01)],
        style: ShapeStylePresets.route,
      ),
    ];

    const config = SnapConfig(toleranceMeters: 50);

    test('snaps to nearest vertex', () {
      // Cursor very close to (0, 0)
      final result = SnappingEngine.findSnapTarget(
        LatLng(0.00001, 0.00001),
        shapes,
        config,
      );
      expect(result, isNotNull);
      expect(result!.type, SnapType.vertex);
      expect(result.point.latitude, closeTo(0, 0.001));
    });

    test('snaps to midpoint when no vertex is closer', () {
      // Cursor near midpoint of edge (0,0)-(0,0.001) = (0, 0.0005)
      final midConfig = const SnapConfig(
        toleranceMeters: 50,
        priorities: [SnapType.midpoint],
      );
      final result = SnappingEngine.findSnapTarget(
        LatLng(0, 0.00049),
        shapes,
        midConfig,
      );
      expect(result, isNotNull);
      expect(result!.type, SnapType.midpoint);
    });

    test('returns null when cursor is outside tolerance', () {
      // Use only vertex/edge priorities so grid doesn't interfere
      final noGridConfig = const SnapConfig(
        toleranceMeters: 50,
        priorities: [SnapType.vertex, SnapType.midpoint, SnapType.edge],
      );
      final result = SnappingEngine.findSnapTarget(
        LatLng(5, 5), // Very far away
        shapes,
        noGridConfig,
      );
      expect(result, isNull);
    });

    test('excludeShapeId skips the excluded shape', () {
      // Cursor at vertex of poly1, but poly1 is excluded
      final result = SnappingEngine.findSnapTarget(
        LatLng(0, 0),
        shapes,
        const SnapConfig(toleranceMeters: 5, priorities: [SnapType.vertex]),
        excludeShapeId: 'poly1',
      );
      // Should not snap to poly1's vertices
      if (result != null) {
        expect(result.sourceShapeId, isNot('poly1'));
      }
    });

    test('grid snap rounds to grid', () {
      final gridConfig = const SnapConfig(
        toleranceMeters: 500,
        priorities: [SnapType.grid],
        gridSpacing: 0.001,
      );
      final result = SnappingEngine.findSnapTarget(
        LatLng(0.00051, 0.00149),
        [],
        gridConfig,
      );
      expect(result, isNotNull);
      expect(result!.type, SnapType.grid);
      expect(result.point.latitude, closeTo(0.001, 0.0001));
      expect(result.point.longitude, closeTo(0.001, 0.0001));
    });

    test('disabled config returns null', () {
      final result = SnappingEngine.findSnapTarget(
        LatLng(0, 0),
        shapes,
        SnapConfig.disabled,
      );
      expect(result, isNull);
    });

    test('priority order is respected', () {
      // With vertex first, should snap to vertex
      final vertexFirst = const SnapConfig(
        toleranceMeters: 50,
        priorities: [SnapType.vertex, SnapType.edge],
      );
      final result = SnappingEngine.findSnapTarget(
        LatLng(0.00001, 0.00001),
        shapes,
        vertexFirst,
      );
      expect(result?.type, SnapType.vertex);
    });

    test('edge snap works', () {
      final edgeConfig = const SnapConfig(
        toleranceMeters: 500,
        priorities: [SnapType.edge],
      );
      // Cursor near the edge between (0.01, 0) and (0.01, 0.01)
      final result = SnappingEngine.findSnapTarget(
        LatLng(0.01, 0.005),
        shapes,
        edgeConfig,
      );
      expect(result, isNotNull);
      expect(result!.type, SnapType.edge);
    });
  });

  group('SnapConfig', () {
    test('default config has expected values', () {
      const config = SnapConfig();
      expect(config.enabled, true);
      expect(config.toleranceMeters, 15.0);
      expect(config.priorities.first, SnapType.vertex);
    });

    test('disabled config', () {
      expect(SnapConfig.disabled.enabled, false);
    });
  });

  group('SnapIndicatorData', () {
    test('iconLabel returns expected values', () {
      final result = SnapResult(
        type: SnapType.vertex,
        point: LatLng(0, 0),
        distance: 5,
      );
      final indicator = SnapIndicatorData(result: result);
      expect(indicator.iconLabel, '⊕');
    });
  });
}
