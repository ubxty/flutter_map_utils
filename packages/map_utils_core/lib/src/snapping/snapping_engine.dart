import 'package:latlong2/latlong.dart';

import 'package:map_utils_core/src/core/shape_model.dart';
import 'package:map_utils_core/src/geometry/geometry_utils.dart';

/// Types of snap targets.
enum SnapType {
  /// Snap to an existing vertex.
  vertex,

  /// Snap to the midpoint of an edge.
  midpoint,

  /// Snap to the nearest point on an edge.
  edge,

  /// Snap to the intersection of two edges.
  intersection,

  /// Snap to a grid.
  grid,

  /// Snap perpendicular to a nearby edge.
  perpendicular,
}

/// Configuration for the snapping engine.
class SnapConfig {
  /// Whether snapping is enabled.
  final bool enabled;

  /// Snap tolerance in meters. Points within this distance will snap.
  final double toleranceMeters;

  /// Ordered list of snap types by priority. First match wins.
  final List<SnapType> priorities;

  /// Grid spacing in degrees (for grid snap).
  final double gridSpacing;

  const SnapConfig({
    this.enabled = true,
    this.toleranceMeters = 15.0,
    this.priorities = const [
      SnapType.vertex,
      SnapType.midpoint,
      SnapType.edge,
      SnapType.intersection,
      SnapType.grid,
    ],
    this.gridSpacing = 0.0001,
  });

  /// Create a disabled config.
  static const disabled = SnapConfig(enabled: false);
}

/// Result of a snap operation.
class SnapResult {
  /// The type of snap that was found.
  final SnapType type;

  /// The snapped-to point.
  final LatLng point;

  /// The ID of the source shape (if snap was to a shape).
  final String? sourceShapeId;

  /// Distance from cursor to snap point in meters.
  final double distance;

  const SnapResult({
    required this.type,
    required this.point,
    this.sourceShapeId,
    required this.distance,
  });
}

/// The snapping engine. Evaluates snap candidates in priority order.
abstract final class SnappingEngine {
  static const Distance _haversine = Distance();

  /// Find the best snap target for a cursor position.
  ///
  /// Returns `null` if no snap is within tolerance. Evaluates snap types
  /// in [config.priorities] order; first match within tolerance wins.
  static SnapResult? findSnapTarget(
    LatLng cursor,
    List<DrawableShape> shapes,
    SnapConfig config, {
    String? excludeShapeId,
  }) {
    if (!config.enabled) return null;

    for (final snapType in config.priorities) {
      final result = switch (snapType) {
        SnapType.vertex =>
          _findNearestVertex(cursor, shapes, config, excludeShapeId),
        SnapType.midpoint =>
          _findNearestMidpoint(cursor, shapes, config, excludeShapeId),
        SnapType.edge =>
          _findNearestEdge(cursor, shapes, config, excludeShapeId),
        SnapType.intersection =>
          _findNearestIntersection(cursor, shapes, config, excludeShapeId),
        SnapType.grid => _findGridSnap(cursor, config),
        SnapType.perpendicular =>
          _findPerpendicular(cursor, shapes, config, excludeShapeId),
      };

      if (result != null) return result;
    }

    return null;
  }

  static SnapResult? _findNearestVertex(
    LatLng cursor,
    List<DrawableShape> shapes,
    SnapConfig config,
    String? excludeShapeId,
  ) {
    SnapResult? best;

    for (final shape in shapes) {
      if (shape.id == excludeShapeId) continue;
      for (final point in shape.allPoints) {
        final dist = _haversine.distance(cursor, point);
        if (dist <= config.toleranceMeters &&
            (best == null || dist < best.distance)) {
          best = SnapResult(
            type: SnapType.vertex,
            point: point,
            sourceShapeId: shape.id,
            distance: dist,
          );
        }
      }
    }

    return best;
  }

  static SnapResult? _findNearestMidpoint(
    LatLng cursor,
    List<DrawableShape> shapes,
    SnapConfig config,
    String? excludeShapeId,
  ) {
    SnapResult? best;

    for (final shape in shapes) {
      if (shape.id == excludeShapeId) continue;
      final points = shape.allPoints;
      if (points.length < 2) continue;

      final isPolygon =
          shape is DrawablePolygon || shape is DrawableRectangle;
      final edgeCount = isPolygon ? points.length : points.length - 1;

      for (var i = 0; i < edgeCount; i++) {
        final a = points[i];
        final b = points[(i + 1) % points.length];
        final mid = GeometryUtils.midpoint(a, b);
        final dist = _haversine.distance(cursor, mid);
        if (dist <= config.toleranceMeters &&
            (best == null || dist < best.distance)) {
          best = SnapResult(
            type: SnapType.midpoint,
            point: mid,
            sourceShapeId: shape.id,
            distance: dist,
          );
        }
      }
    }

    return best;
  }

  static SnapResult? _findNearestEdge(
    LatLng cursor,
    List<DrawableShape> shapes,
    SnapConfig config,
    String? excludeShapeId,
  ) {
    SnapResult? best;

    for (final shape in shapes) {
      if (shape.id == excludeShapeId) continue;
      final points = shape.allPoints;
      if (points.length < 2) continue;

      final isPolygon =
          shape is DrawablePolygon || shape is DrawableRectangle;
      final edgeCount = isPolygon ? points.length : points.length - 1;

      for (var i = 0; i < edgeCount; i++) {
        final a = points[i];
        final b = points[(i + 1) % points.length];
        final (:point, t: _) =
            GeometryUtils.nearestPointOnSegment(cursor, a, b);
        final dist = _haversine.distance(cursor, point);
        if (dist <= config.toleranceMeters &&
            (best == null || dist < best.distance)) {
          best = SnapResult(
            type: SnapType.edge,
            point: point,
            sourceShapeId: shape.id,
            distance: dist,
          );
        }
      }
    }

    return best;
  }

  static SnapResult? _findNearestIntersection(
    LatLng cursor,
    List<DrawableShape> shapes,
    SnapConfig config,
    String? excludeShapeId,
  ) {
    final edges = <({LatLng a, LatLng b, String shapeId})>[];
    for (final shape in shapes) {
      if (shape.id == excludeShapeId) continue;
      final points = shape.allPoints;
      if (points.length < 2) continue;

      final isPolygon =
          shape is DrawablePolygon || shape is DrawableRectangle;
      final edgeCount = isPolygon ? points.length : points.length - 1;

      for (var i = 0; i < edgeCount; i++) {
        edges.add((
          a: points[i],
          b: points[(i + 1) % points.length],
          shapeId: shape.id,
        ));
      }
    }

    SnapResult? best;

    for (var i = 0; i < edges.length; i++) {
      for (var j = i + 1; j < edges.length; j++) {
        final intersection = _lineIntersection(
          edges[i].a,
          edges[i].b,
          edges[j].a,
          edges[j].b,
        );
        if (intersection != null) {
          final dist = _haversine.distance(cursor, intersection);
          if (dist <= config.toleranceMeters &&
              (best == null || dist < best.distance)) {
            best = SnapResult(
              type: SnapType.intersection,
              point: intersection,
              distance: dist,
            );
          }
        }
      }
    }

    return best;
  }

  static SnapResult? _findGridSnap(LatLng cursor, SnapConfig config) {
    final gridLat = (cursor.latitude / config.gridSpacing).round() *
        config.gridSpacing;
    final gridLng = (cursor.longitude / config.gridSpacing).round() *
        config.gridSpacing;
    final gridPoint = LatLng(gridLat, gridLng);
    final dist = _haversine.distance(cursor, gridPoint);

    if (dist <= config.toleranceMeters) {
      return SnapResult(
        type: SnapType.grid,
        point: gridPoint,
        distance: dist,
      );
    }
    return null;
  }

  static SnapResult? _findPerpendicular(
    LatLng cursor,
    List<DrawableShape> shapes,
    SnapConfig config,
    String? excludeShapeId,
  ) {
    return _findNearestEdge(cursor, shapes, config, excludeShapeId);
  }

  static LatLng? _lineIntersection(
    LatLng a1,
    LatLng a2,
    LatLng b1,
    LatLng b2,
  ) {
    final d1x = a2.longitude - a1.longitude;
    final d1y = a2.latitude - a1.latitude;
    final d2x = b2.longitude - b1.longitude;
    final d2y = b2.latitude - b1.latitude;

    final denom = d1x * d2y - d1y * d2x;
    if (denom.abs() < 1e-12) return null;

    final dx = b1.longitude - a1.longitude;
    final dy = b1.latitude - a1.latitude;

    final t = (dx * d2y - dy * d2x) / denom;
    final u = (dx * d1y - dy * d1x) / denom;

    if (t < 0 || t > 1 || u < 0 || u > 1) return null;

    return LatLng(
      a1.latitude + t * d1y,
      a1.longitude + t * d1x,
    );
  }
}

/// Visual indicator data for snap feedback.
class SnapIndicatorData {
  /// The snap result to display.
  final SnapResult result;

  /// Icon label for the snap type.
  String get iconLabel => switch (result.type) {
        SnapType.vertex => '⊕',
        SnapType.midpoint => '◇',
        SnapType.edge => '⊥',
        SnapType.intersection => '✕',
        SnapType.grid => '⊞',
        SnapType.perpendicular => '⊥',
      };

  const SnapIndicatorData({required this.result});
}
