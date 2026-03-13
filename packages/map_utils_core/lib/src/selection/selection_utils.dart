import 'package:latlong2/latlong.dart';

import 'package:map_utils_core/src/core/shape_model.dart';
import 'package:map_utils_core/src/geometry/geometry_utils.dart';

/// Pure hit-testing algorithms for shape selection.
///
/// Extracted from the flutter_map `SelectionLayer` widget so the logic
/// can be shared across any map engine.
abstract final class SelectionUtils {
  static const Distance _haversine = Distance();

  /// Compute the distance from a point to any shape.
  ///
  /// For polygons/rectangles, returns 0 if inside, or nearest edge
  /// distance if outside. For polylines, returns nearest edge distance.
  /// For circles, returns absolute distance from the circle boundary.
  static double? distanceToShape(LatLng point, DrawableShape shape) {
    switch (shape) {
      case final DrawablePolygon s:
        if (GeometryUtils.pointInPolygon(point, s.points)) return 0;
        return nearestEdgeDistance(point, s.points, closed: true);
      case final DrawableRectangle s:
        if (GeometryUtils.pointInPolygon(point, s.points)) return 0;
        return nearestEdgeDistance(point, s.points, closed: true);
      case final DrawablePolyline s:
        return nearestEdgeDistance(point, s.points, closed: false);
      case final DrawableCircle s:
        final distToCenter = _haversine.distance(point, s.center);
        return (distToCenter - s.radiusMeters).abs();
    }
  }

  /// Find the nearest edge distance from a cursor to a point list.
  ///
  /// Set [closed] to true for polygons (last edge wraps to first point),
  /// false for open polylines.
  static double? nearestEdgeDistance(
    LatLng cursor,
    List<LatLng> points, {
    required bool closed,
  }) {
    if (points.isEmpty) return null;
    if (points.length == 1) {
      return _haversine.distance(cursor, points.first);
    }

    double best = double.infinity;
    final edgeCount = closed ? points.length : points.length - 1;

    for (var i = 0; i < edgeCount; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      final (:point, t: _) =
          GeometryUtils.nearestPointOnSegment(cursor, a, b);
      final dist = _haversine.distance(cursor, point);
      if (dist < best) best = dist;
    }

    return best;
  }

  /// Find the closest shape to a point within a tolerance.
  ///
  /// Returns the shape ID, or null if nothing is within tolerance.
  static String? findClosestShape(
    LatLng point,
    List<DrawableShape> shapes, {
    double toleranceMeters = 20.0,
  }) {
    String? hitId;
    double hitDist = double.infinity;

    for (final shape in shapes) {
      final dist = distanceToShape(point, shape);
      if (dist != null && dist < hitDist) {
        hitDist = dist;
        hitId = shape.id;
      }
    }

    return (hitId != null && hitDist <= toleranceMeters) ? hitId : null;
  }
}
