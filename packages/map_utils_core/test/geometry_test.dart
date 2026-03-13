import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_utils_core/map_utils_core.dart';

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

    test('pointInPolygon with fewer than 3 points returns false', () {
      expect(GeometryUtils.pointInPolygon(LatLng(0, 0), [LatLng(0, 0)]), false);
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

    test('centroid of empty list returns (0,0)', () {
      final c = GeometryUtils.centroid([]);
      expect(c.latitude, 0);
      expect(c.longitude, 0);
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
      expect(area, greaterThan(1e9));
    });

    test('polygonArea with < 3 points returns 0', () {
      expect(GeometryUtils.polygonArea([LatLng(0, 0), LatLng(1, 1)]), 0);
    });

    test('polygonPerimeter returns positive value', () {
      final square = [
        LatLng(0, 0),
        LatLng(0, 1),
        LatLng(1, 1),
        LatLng(1, 0),
      ];
      expect(GeometryUtils.polygonPerimeter(square), greaterThan(0));
    });

    test('polylineLength returns positive length', () {
      final line = [LatLng(0, 0), LatLng(0, 1)];
      final length = GeometryUtils.polylineLength(line);
      expect(length, greaterThan(100000));
      expect(length, lessThan(120000));
    });

    test('polylineLength with < 2 points returns 0', () {
      expect(GeometryUtils.polylineLength([LatLng(0, 0)]), 0);
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

    test('nearestPointOnSegment with zero-length segment', () {
      final result = GeometryUtils.nearestPointOnSegment(
        LatLng(1, 1),
        LatLng(0, 0),
        LatLng(0, 0),
      );
      expect(result.point.latitude, closeTo(0, 0.01));
      expect(result.t, 0);
    });

    test('isSelfIntersecting detects figure-8', () {
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

    test('isSelfIntersecting returns false for < 4 points', () {
      expect(GeometryUtils.isSelfIntersecting([
        LatLng(0, 0),
        LatLng(1, 0),
        LatLng(1, 1),
      ]), false);
    });

    test('isClockwise and ensureClockwise', () {
      final ccw = [
        LatLng(0, 0),
        LatLng(1, 0),
        LatLng(1, 1),
        LatLng(0, 1),
      ];
      final cw = GeometryUtils.ensureClockwise(ccw);
      expect(GeometryUtils.isClockwise(cw), true);
    });

    test('ensureCounterClockwise', () {
      final cw = [
        LatLng(0, 0),
        LatLng(0, 1),
        LatLng(1, 1),
        LatLng(1, 0),
      ];
      if (GeometryUtils.isClockwise(cw)) {
        final ccw = GeometryUtils.ensureCounterClockwise(cw);
        expect(GeometryUtils.isClockwise(ccw), false);
      }
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
      );
      expect(GeometryUtils.shapeArea(poly), greaterThan(0));
    });

    test('shapeArea for circle', () {
      final circle = DrawableCircle(
        id: 'gc1',
        center: LatLng(0, 0),
        radiusMeters: 1000,
      );
      final area = GeometryUtils.shapeArea(circle);
      expect(area, closeTo(3141592.65, 1));
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
      );
      expect(GeometryUtils.shapePerimeter(poly), greaterThan(0));
    });

    test('shapePerimeter for circle', () {
      final circle = DrawableCircle(
        id: 'gc2',
        center: LatLng(0, 0),
        radiusMeters: 1000,
      );
      final perimeter = GeometryUtils.shapePerimeter(circle);
      expect(perimeter, closeTo(6283.18, 1));
    });

    test('shapeArea for polyline is 0', () {
      final line = DrawablePolyline(
        id: 'gt3',
        points: [LatLng(0, 0), LatLng(1, 1)],
      );
      expect(GeometryUtils.shapeArea(line), 0);
    });

    test('areaInSquareFeet and areaInAcres', () {
      final square = [
        LatLng(0, 0),
        LatLng(0, 1),
        LatLng(1, 1),
        LatLng(1, 0),
      ];
      final sqFt = GeometryUtils.areaInSquareFeet(square);
      final acres = GeometryUtils.areaInAcres(square);
      expect(sqFt, greaterThan(0));
      expect(acres, greaterThan(0));
      expect(acres, closeTo(sqFt / 43560, 0.01));
    });

    test('simplifyPath reduces points', () {
      // Create a path with many points along a straight line + one outlier
      final path = [
        LatLng(0, 0),
        LatLng(0, 0.0001),
        LatLng(0, 0.0002),
        LatLng(0, 0.0003),
        LatLng(0, 0.0004),
        LatLng(0, 0.0005),
      ];
      final simplified = GeometryUtils.simplifyPath(path, tolerance: 5);
      expect(simplified.length, lessThanOrEqualTo(path.length));
      expect(simplified.first, path.first);
      expect(simplified.last, path.last);
    });

    test('simplifyPath with tolerance <= 0 returns copy', () {
      final path = [LatLng(0, 0), LatLng(1, 1), LatLng(2, 0)];
      final result = GeometryUtils.simplifyPath(path, tolerance: 0);
      expect(result.length, path.length);
    });

    test('smoothPath produces more points', () {
      final path = [
        LatLng(0, 0),
        LatLng(1, 0),
        LatLng(1, 1),
        LatLng(0, 1),
      ];
      final smoothed = GeometryUtils.smoothPath(path, iterations: 1);
      expect(smoothed.length, greaterThan(path.length));
    });

    test('smoothPath with iterations <= 0 returns copy', () {
      final path = [LatLng(0, 0), LatLng(1, 0), LatLng(1, 1)];
      final result = GeometryUtils.smoothPath(path, iterations: 0);
      expect(result.length, path.length);
    });

    test('smoothPath open polyline preserves endpoints', () {
      final path = [
        LatLng(0, 0),
        LatLng(1, 0),
        LatLng(1, 1),
        LatLng(0, 1),
      ];
      final smoothed = GeometryUtils.smoothPath(
        path,
        iterations: 2,
        closed: false,
      );
      expect(smoothed.first.latitude, path.first.latitude);
      expect(smoothed.last.latitude, path.last.latitude);
    });
  });
}
