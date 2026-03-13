import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_utils_core/map_utils_core.dart';

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
      ),
      DrawablePolyline(
        id: 'line1',
        points: [LatLng(0.01, 0), LatLng(0.01, 0.01)],
      ),
    ];

    const config = SnapConfig(toleranceMeters: 50);

    test('snaps to nearest vertex', () {
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
      final noGridConfig = const SnapConfig(
        toleranceMeters: 50,
        priorities: [SnapType.vertex, SnapType.midpoint, SnapType.edge],
      );
      final result = SnappingEngine.findSnapTarget(
        LatLng(5, 5),
        shapes,
        noGridConfig,
      );
      expect(result, isNull);
    });

    test('excludeShapeId skips the excluded shape', () {
      final result = SnappingEngine.findSnapTarget(
        LatLng(0, 0),
        shapes,
        const SnapConfig(toleranceMeters: 5, priorities: [SnapType.vertex]),
        excludeShapeId: 'poly1',
      );
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

    test('all snap types have icon labels', () {
      for (final type in SnapType.values) {
        final result = SnapResult(
          type: type,
          point: LatLng(0, 0),
          distance: 0,
        );
        final indicator = SnapIndicatorData(result: result);
        expect(indicator.iconLabel, isNotEmpty);
      }
    });
  });
}
