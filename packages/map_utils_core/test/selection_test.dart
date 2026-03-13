import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_utils_core/map_utils_core.dart';

void main() {
  group('SelectionUtils', () {
    test('distanceToShape returns 0 for point inside polygon', () {
      final poly = DrawablePolygon(
        id: 'sel1',
        points: [
          LatLng(0, 0),
          LatLng(0, 10),
          LatLng(10, 10),
          LatLng(10, 0),
        ],
      );
      expect(SelectionUtils.distanceToShape(LatLng(5, 5), poly), 0);
    });

    test('distanceToShape returns positive for point outside polygon', () {
      final poly = DrawablePolygon(
        id: 'sel2',
        points: [
          LatLng(0, 0),
          LatLng(0, 1),
          LatLng(1, 1),
          LatLng(1, 0),
        ],
      );
      final dist = SelectionUtils.distanceToShape(LatLng(5, 5), poly);
      expect(dist, isNotNull);
      expect(dist!, greaterThan(0));
    });

    test('distanceToShape returns 0 for point inside rectangle', () {
      final rect = DrawableRectangle.fromCorners(
        id: 'sel3',
        corner1: LatLng(0, 0),
        corner2: LatLng(10, 10),
      );
      expect(SelectionUtils.distanceToShape(LatLng(5, 5), rect), 0);
    });

    test('distanceToShape for polyline returns edge distance', () {
      final line = DrawablePolyline(
        id: 'sel4',
        points: [LatLng(0, 0), LatLng(0, 1)],
      );
      final dist = SelectionUtils.distanceToShape(LatLng(0, 0.5), line);
      expect(dist, isNotNull);
      // Should be very close to the line
      expect(dist!, lessThan(100));
    });

    test('distanceToShape for circle', () {
      final circle = DrawableCircle(
        id: 'sel5',
        center: LatLng(0, 0),
        radiusMeters: 1000,
      );
      // Point at center — distance from boundary is radiusMeters
      final dist = SelectionUtils.distanceToShape(LatLng(0, 0), circle);
      expect(dist, isNotNull);
      expect(dist!, closeTo(1000, 10));
    });

    test('nearestEdgeDistance for closed polygon', () {
      final points = [
        LatLng(0, 0),
        LatLng(0, 1),
        LatLng(1, 1),
        LatLng(1, 0),
      ];
      final dist = SelectionUtils.nearestEdgeDistance(
        LatLng(0.5, 0.5),
        points,
        closed: true,
      );
      expect(dist, isNotNull);
      expect(dist!, greaterThan(0));
    });

    test('nearestEdgeDistance for open polyline', () {
      final points = [LatLng(0, 0), LatLng(0, 1)];
      final dist = SelectionUtils.nearestEdgeDistance(
        LatLng(0, 0.5),
        points,
        closed: false,
      );
      expect(dist, isNotNull);
      expect(dist!, lessThan(100));
    });

    test('nearestEdgeDistance returns null for empty list', () {
      expect(
        SelectionUtils.nearestEdgeDistance(LatLng(0, 0), [], closed: false),
        isNull,
      );
    });

    test('findClosestShape returns nearest shape within tolerance', () {
      final shapes = [
        DrawablePolygon(
          id: 'fc1',
          points: [
            LatLng(0, 0),
            LatLng(0, 0.001),
            LatLng(0.001, 0.001),
            LatLng(0.001, 0),
          ],
        ),
        DrawablePolyline(
          id: 'fc2',
          points: [LatLng(1, 1), LatLng(1, 2)],
        ),
      ];
      // Point inside the polygon
      final id = SelectionUtils.findClosestShape(
        LatLng(0.0005, 0.0005),
        shapes,
        toleranceMeters: 100,
      );
      expect(id, 'fc1');
    });

    test('findClosestShape returns null when nothing is close', () {
      final shapes = [
        DrawablePolygon(
          id: 'fc3',
          points: [LatLng(0, 0), LatLng(0, 1), LatLng(1, 1)],
        ),
      ];
      final id = SelectionUtils.findClosestShape(
        LatLng(50, 50),
        shapes,
        toleranceMeters: 20,
      );
      expect(id, isNull);
    });
  });
}
