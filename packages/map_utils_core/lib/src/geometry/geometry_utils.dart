import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'package:map_utils_core/src/core/shape_model.dart';

/// Geometry utility functions.
///
/// Pure algorithms with no map-SDK dependency. Uses latlong2 for
/// coordinate math and Haversine distance.
abstract final class GeometryUtils {
  static const Distance _haversine = Distance();
  static const double _earthRadius = 6371000.0; // meters

  // -- Point-in-polygon --

  /// Check if a point is inside a polygon (ray casting algorithm).
  static bool pointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;

    var inside = false;
    final n = polygon.length;
    for (var i = 0, j = n - 1; i < n; j = i++) {
      final yi = polygon[i].latitude;
      final xi = polygon[i].longitude;
      final yj = polygon[j].latitude;
      final xj = polygon[j].longitude;

      if (((yi > point.latitude) != (yj > point.latitude)) &&
          (point.longitude <
              (xj - xi) * (point.latitude - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
    }
    return inside;
  }

  // -- Distance --

  /// Haversine distance between two points in meters.
  /// Delegates to latlong2's [Distance.distance].
  static double distanceBetween(LatLng a, LatLng b) {
    return _haversine.distance(a, b);
  }

  // -- Centroid --

  /// Compute the centroid (average) of a list of points.
  static LatLng centroid(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(0, 0);
    var latSum = 0.0;
    var lngSum = 0.0;
    for (final p in points) {
      latSum += p.latitude;
      lngSum += p.longitude;
    }
    return LatLng(latSum / points.length, lngSum / points.length);
  }

  // -- Area --

  /// Compute the geodesic area of a polygon in square meters.
  ///
  /// Uses the spherical excess formula. Accurate for polygons of any size.
  static double polygonArea(List<LatLng> points) {
    if (points.length < 3) return 0;

    final n = points.length;
    var sum = 0.0;
    for (var i = 0; i < n; i++) {
      final p1 = points[i];
      final p2 = points[(i + 1) % n];
      sum += (p2.longitudeInRad - p1.longitudeInRad) *
          (2 + math.sin(p1.latitudeInRad) + math.sin(p2.latitudeInRad));
    }
    return (sum.abs() * _earthRadius * _earthRadius / 2);
  }

  /// Compute the perimeter of a polygon in meters.
  static double polygonPerimeter(List<LatLng> points) {
    if (points.length < 2) return 0;
    var total = 0.0;
    for (var i = 0; i < points.length; i++) {
      total += _haversine.distance(
        points[i],
        points[(i + 1) % points.length],
      );
    }
    return total;
  }

  /// Compute the total length of a polyline in meters.
  static double polylineLength(List<LatLng> points) {
    if (points.length < 2) return 0;
    var total = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      total += _haversine.distance(points[i], points[i + 1]);
    }
    return total;
  }

  /// Compute the area of a shape (polygon, rectangle, or circle).
  /// Returns 0 for polylines.
  static double shapeArea(DrawableShape shape) {
    return switch (shape) {
      final DrawablePolygon s => polygonArea(s.points),
      final DrawableRectangle s => polygonArea(s.points),
      final DrawableCircle s => math.pi * s.radiusMeters * s.radiusMeters,
      DrawablePolyline _ => 0,
    };
  }

  /// Compute the perimeter/circumference/length of a shape.
  static double shapePerimeter(DrawableShape shape) {
    return switch (shape) {
      final DrawablePolygon s => polygonPerimeter(s.points),
      final DrawableRectangle s => polygonPerimeter(s.points),
      final DrawableCircle s => 2 * math.pi * s.radiusMeters,
      final DrawablePolyline s => polylineLength(s.points),
    };
  }

  // -- Segment utilities --

  /// Find the nearest point on a line segment to a given point.
  ///
  /// Returns the projected point and a `t` parameter (0..1) along the segment.
  static ({LatLng point, double t}) nearestPointOnSegment(
    LatLng point,
    LatLng segA,
    LatLng segB,
  ) {
    final dx = segB.longitude - segA.longitude;
    final dy = segB.latitude - segA.latitude;
    final lenSq = dx * dx + dy * dy;

    if (lenSq == 0) return (point: segA, t: 0);

    final t = (((point.longitude - segA.longitude) * dx +
                (point.latitude - segA.latitude) * dy) /
            lenSq)
        .clamp(0.0, 1.0);

    return (
      point: LatLng(segA.latitude + t * dy, segA.longitude + t * dx),
      t: t,
    );
  }

  /// Find the midpoint of a line segment.
  static LatLng midpoint(LatLng a, LatLng b) {
    return LatLng(
      (a.latitude + b.latitude) / 2,
      (a.longitude + b.longitude) / 2,
    );
  }

  // -- Validation --

  /// Check if a polygon is self-intersecting.
  static bool isSelfIntersecting(List<LatLng> points) {
    if (points.length < 4) return false;

    final n = points.length;
    for (var i = 0; i < n; i++) {
      final a = points[i];
      final b = points[(i + 1) % n];
      // Check against non-adjacent edges
      for (var j = i + 2; j < n; j++) {
        if (i == 0 && j == n - 1) continue; // Skip first-last adjacency
        final c = points[j];
        final d = points[(j + 1) % n];
        if (_segmentsIntersect(a, b, c, d)) return true;
      }
    }
    return false;
  }

  /// Check if a polygon has clockwise winding.
  static bool isClockwise(List<LatLng> points) {
    if (points.length < 3) return false;
    var sum = 0.0;
    for (var i = 0; i < points.length; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      sum += (b.longitude - a.longitude) * (b.latitude + a.latitude);
    }
    return sum > 0;
  }

  /// Ensure polygon points are in clockwise order.
  static List<LatLng> ensureClockwise(List<LatLng> points) {
    if (isClockwise(points)) return points;
    return points.reversed.toList();
  }

  /// Ensure polygon points are in counter-clockwise order.
  static List<LatLng> ensureCounterClockwise(List<LatLng> points) {
    if (!isClockwise(points)) return points;
    return points.reversed.toList();
  }

  // -- Segment intersection --

  static bool _segmentsIntersect(LatLng a, LatLng b, LatLng c, LatLng d) {
    final d1 = _cross(c, d, a);
    final d2 = _cross(c, d, b);
    final d3 = _cross(a, b, c);
    final d4 = _cross(a, b, d);

    if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) {
      return true;
    }

    if (d1 == 0 && _onSegment(c, d, a)) return true;
    if (d2 == 0 && _onSegment(c, d, b)) return true;
    if (d3 == 0 && _onSegment(a, b, c)) return true;
    if (d4 == 0 && _onSegment(a, b, d)) return true;

    return false;
  }

  static double _cross(LatLng a, LatLng b, LatLng c) {
    return (b.longitude - a.longitude) * (c.latitude - a.latitude) -
        (b.latitude - a.latitude) * (c.longitude - a.longitude);
  }

  static bool _onSegment(LatLng a, LatLng b, LatLng p) {
    return math.min(a.longitude, b.longitude) <= p.longitude &&
        p.longitude <= math.max(a.longitude, b.longitude) &&
        math.min(a.latitude, b.latitude) <= p.latitude &&
        p.latitude <= math.max(a.latitude, b.latitude);
  }

  // -- Area conversions --

  /// Polygon area in square feet.
  static double areaInSquareFeet(List<LatLng> points) {
    return polygonArea(points) * 10.7639;
  }

  /// Polygon area in acres (1 acre = 43 560 ft²).
  static double areaInAcres(List<LatLng> points) {
    return areaInSquareFeet(points) / 43560;
  }

  // -- Path simplification & smoothing --

  /// Simplify a path using the Douglas-Peucker algorithm.
  ///
  /// Removes points that deviate less than [tolerance] meters from the
  /// simplified line. Higher tolerance = fewer points.
  /// Returns a copy of [points] if tolerance ≤ 0 or fewer than 3 points.
  static List<LatLng> simplifyPath(
    List<LatLng> points, {
    double tolerance = 5.0,
  }) {
    if (tolerance <= 0 || points.length < 3) return List.of(points);

    final kept = List.filled(points.length, false);
    kept[0] = true;
    kept[points.length - 1] = true;

    _dpRecursive(points, kept, 0, points.length - 1, tolerance);

    return [
      for (var i = 0; i < points.length; i++)
        if (kept[i]) points[i],
    ];
  }

  /// Smooth a path using Chaikin's corner-cutting algorithm.
  ///
  /// Each iteration replaces every edge with two new points at 1/4 and 3/4
  /// along the edge, producing progressively smoother curves.
  ///
  /// Set [closed] to `true` for polygons (wraps last edge to first point)
  /// or `false` for open polylines (preserves start/end points).
  static List<LatLng> smoothPath(
    List<LatLng> points, {
    int iterations = 2,
    bool closed = true,
  }) {
    if (iterations <= 0 || points.length < 3) return List.of(points);

    var current = points;
    for (var iter = 0; iter < iterations; iter++) {
      final result = <LatLng>[];
      final count = closed ? current.length : current.length - 1;
      for (var i = 0; i < count; i++) {
        final p0 = current[i];
        final p1 = current[(i + 1) % current.length];
        result.add(LatLng(
          0.75 * p0.latitude + 0.25 * p1.latitude,
          0.75 * p0.longitude + 0.25 * p1.longitude,
        ));
        result.add(LatLng(
          0.25 * p0.latitude + 0.75 * p1.latitude,
          0.25 * p0.longitude + 0.75 * p1.longitude,
        ));
      }
      if (!closed && current.length >= 2) {
        result[0] = current.first;
        result[result.length - 1] = current.last;
      }
      current = result;
    }
    return current;
  }

  // -- Douglas-Peucker internals --

  static void _dpRecursive(
    List<LatLng> points,
    List<bool> kept,
    int start,
    int end,
    double tolerance,
  ) {
    if (end - start < 2) return;

    var maxDist = 0.0;
    var maxIndex = start;

    final a = points[start];
    final b = points[end];

    for (var i = start + 1; i < end; i++) {
      final d = _perpendicularDistance(points[i], a, b);
      if (d > maxDist) {
        maxDist = d;
        maxIndex = i;
      }
    }

    if (maxDist > tolerance) {
      kept[maxIndex] = true;
      _dpRecursive(points, kept, start, maxIndex, tolerance);
      _dpRecursive(points, kept, maxIndex, end, tolerance);
    }
  }

  /// Perpendicular distance from point to line segment in meters
  /// (planar approximation for speed).
  static double _perpendicularDistance(LatLng point, LatLng a, LatLng b) {
    final dx = b.longitude - a.longitude;
    final dy = b.latitude - a.latitude;

    if (dx == 0 && dy == 0) {
      final pdx = point.longitude - a.longitude;
      final pdy = point.latitude - a.latitude;
      return math.sqrt(pdx * pdx + pdy * pdy) * 111320;
    }

    final t = ((point.longitude - a.longitude) * dx +
            (point.latitude - a.latitude) * dy) /
        (dx * dx + dy * dy);

    final clamped = t.clamp(0.0, 1.0);
    final projLng = a.longitude + clamped * dx;
    final projLat = a.latitude + clamped * dy;

    final distLng = (point.longitude - projLng) *
        111320 *
        math.cos(point.latitude * math.pi / 180);
    final distLat = (point.latitude - projLat) * 111320;

    return math.sqrt(distLng * distLng + distLat * distLat);
  }
}
