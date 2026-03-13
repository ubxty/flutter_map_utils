import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_utils/flutter_map_utils.dart';

void main() {
  group('GeometryUtils', () {
    test('pointInPolygon inside returns true', () {
      final polygon = [
        LatLng(0, 0),
        LatLng(0, 10),
        LatLng(10, 10),
        LatLng(10, 0),
      ];
      expect(GeometryUtils.pointInPolygon(LatLng(5, 5), polygon), true);
    });

    test('pointInPolygon outside returns false', () {
      final polygon = [
        LatLng(0, 0),
        LatLng(0, 10),
        LatLng(10, 10),
        LatLng(10, 0),
      ];
      expect(GeometryUtils.pointInPolygon(LatLng(15, 15), polygon), false);
    });

    test('centroid of square is center', () {
      final square = [
        LatLng(0, 0),
        LatLng(0, 2),
        LatLng(2, 2),
        LatLng(2, 0),
      ];
      final c = GeometryUtils.centroid(square);
      expect(c.latitude, closeTo(1, 0.01));
      expect(c.longitude, closeTo(1, 0.01));
    });

    test('polygonArea returns positive area', () {
      final square = [
        LatLng(0, 0),
        LatLng(0, 1),
        LatLng(1, 1),
        LatLng(1, 0),
      ];
      final area = GeometryUtils.polygonArea(square);
      expect(area, greaterThan(0));
      // ~1 degree squared ~ 12,300 km2 at equator
      expect(area, greaterThan(1e9)); // > 1 billion sq meters
    });

    test('polylineLength returns positive length', () {
      final line = [LatLng(0, 0), LatLng(0, 1)];
      final length = GeometryUtils.polylineLength(line);
      // 1 degree of longitude at equator ~ 111km
      expect(length, greaterThan(100000));
      expect(length, lessThan(120000));
    });

    test('midpoint of two points', () {
      final mid = GeometryUtils.midpoint(LatLng(0, 0), LatLng(2, 2));
      expect(mid.latitude, closeTo(1, 0.01));
      expect(mid.longitude, closeTo(1, 0.01));
    });

    test('distanceBetween two points', () {
      final d = GeometryUtils.distanceBetween(LatLng(0, 0), LatLng(0, 1));
      expect(d, greaterThan(100000));
      expect(d, lessThan(120000));
    });

    test('nearestPointOnSegment returns endpoint when closest', () {
      final result = GeometryUtils.nearestPointOnSegment(
        LatLng(2, 0),
        LatLng(0, 0),
        LatLng(1, 0),
      );
      expect(result.point.latitude, closeTo(1, 0.01));
      expect(result.t, closeTo(1, 0.01));
    });

    test('nearestPointOnSegment returns projection on segment', () {
      final result = GeometryUtils.nearestPointOnSegment(
        LatLng(1, 0.5),
        LatLng(0, 0),
        LatLng(0, 1),
      );
      expect(result.point.longitude, closeTo(0.5, 0.01));
      expect(result.t, closeTo(0.5, 0.01));
    });

    test('isSelfIntersecting detects figure-8', () {
      // A self-intersecting polygon
      final figure8 = [
        LatLng(0, 0),
        LatLng(0, 2),
        LatLng(2, 0),
        LatLng(2, 2),
      ];
      expect(GeometryUtils.isSelfIntersecting(figure8), true);
    });

    test('isSelfIntersecting returns false for simple polygon', () {
      final simple = [
        LatLng(0, 0),
        LatLng(0, 1),
        LatLng(1, 1),
        LatLng(1, 0),
      ];
      expect(GeometryUtils.isSelfIntersecting(simple), false);
    });

    test('isClockwise and ensureClockwise', () {
      // Counter-clockwise square
      final ccw = [
        LatLng(0, 0),
        LatLng(1, 0),
        LatLng(1, 1),
        LatLng(0, 1),
      ];
      final cw = GeometryUtils.ensureClockwise(ccw);
      expect(GeometryUtils.isClockwise(cw), true);
    });

    test('shapeArea for polygon', () {
      final poly = DrawablePolygon(
        id: 'gt1',
        points: [
          LatLng(0, 0),
          LatLng(0, 1),
          LatLng(1, 1),
          LatLng(1, 0),
        ],
        style: ShapeStylePresets.zone,
      );
      expect(GeometryUtils.shapeArea(poly), greaterThan(0));
    });

    test('shapePerimeter for polygon', () {
      final poly = DrawablePolygon(
        id: 'gt2',
        points: [
          LatLng(0, 0),
          LatLng(0, 1),
          LatLng(1, 1),
          LatLng(1, 0),
        ],
        style: ShapeStylePresets.zone,
      );
      expect(GeometryUtils.shapePerimeter(poly), greaterThan(0));
    });

    test('shapeArea for polyline is 0', () {
      final line = DrawablePolyline(
        id: 'gt3',
        points: [LatLng(0, 0), LatLng(1, 1)],
        style: ShapeStylePresets.route,
      );
      expect(GeometryUtils.shapeArea(line), 0);
    });

    test('boundingBox contains all points', () {
      final points = [
        LatLng(0, 0),
        LatLng(5, 10),
        LatLng(-3, 7),
      ];
      final bbox = FmGeometryUtils.boundingBox(points);
      expect(bbox.south, closeTo(-3, 0.01));
      expect(bbox.north, closeTo(5, 0.01));
      expect(bbox.west, closeTo(0, 0.01));
      expect(bbox.east, closeTo(10, 0.01));
    });
  });
}
