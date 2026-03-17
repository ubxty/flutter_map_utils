import 'package:latlong2/latlong.dart';

import 'latlng_bounds.dart';

/// A geographic circle defined by a [center] and [radius] in meters.
///
/// Significantly extends [latlong2.Circle] which only had [isPointInside]:
///
/// - [contains] — alias for [isPointInside] with clearer name
/// - [toPolygon] — polygon approximation (not in latlong2.Circle at all)
/// - [overlaps] — circle-circle intersection test
/// - [toGeoBounds] — approximate bounding box
/// - [distanceToEdge] — signed distance from a point to the circumference
/// - Proper [==], [hashCode], [toString]
class GeoCircle {
  final LatLng center;

  /// Radius in meters.
  final double radius;

  static const _dist = Distance();

  const GeoCircle(this.center, this.radius) : assert(radius > 0);

  // ── Containment ───────────────────────────────────────────────────────────

  /// Returns true if [point] lies within (or on the boundary of) this circle.
  ///
  /// API-compatible with [latlong2.Circle.isPointInside].
  bool isPointInside(LatLng point) => _dist(center, point) <= radius;

  /// Alias for [isPointInside] with a clearer name.
  bool contains(LatLng point) => isPointInside(point);

  /// Signed distance (meters) from [point] to the circumference.
  ///
  /// Negative = inside the circle; positive = outside.
  double distanceToEdge(LatLng point) => _dist(center, point) - radius;

  // ── Circle–circle relations ───────────────────────────────────────────────

  /// Returns true if this circle overlaps [other].
  bool overlaps(GeoCircle other) =>
      _dist(center, other.center) < radius + other.radius;

  /// Returns true if this circle fully contains [other].
  bool containsCircle(GeoCircle other) =>
      _dist(center, other.center) + other.radius <= radius;

  // ── Geometry output ───────────────────────────────────────────────────────

  /// Generates a polygon approximation with [steps] equally-spaced vertices.
  ///
  /// Default [steps] = 36 (10° per segment). Increase for smoother circles.
  List<LatLng> toPolygon({int steps = 36}) {
    assert(steps >= 3, 'need at least 3 steps');
    return [
      for (int i = 0; i < steps; i++)
        _dist.offset(center, radius, 360.0 * i / steps),
    ];
  }

  /// Approximate axis-aligned bounding box for this circle.
  GeoBounds toGeoBounds() {
    // Project 4 cardinal points then take bounds — works for all latitudes
    final n = _dist.offset(center, radius, 0);
    final s = _dist.offset(center, radius, 180);
    final e = _dist.offset(center, radius, 90);
    final w = _dist.offset(center, radius, 270);
    return GeoBounds(
      LatLng(s.latitude, w.longitude),
      LatLng(n.latitude, e.longitude),
    );
  }

  @override
  String toString() =>
      'GeoCircle(center: $center, radius: ${radius.toStringAsFixed(1)}m)';

  @override
  bool operator ==(Object other) =>
      other is GeoCircle && center == other.center && radius == other.radius;

  @override
  int get hashCode => Object.hash(center, radius);
}
