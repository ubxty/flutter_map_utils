import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Extended drop-in replacement for [Distance] with advanced geodetic methods.
///
/// All [Distance] methods are inherited unchanged — fully API-compatible:
///
/// ```dart
/// import 'package:map_utils_core/map_utils_core.dart';
///
/// // Drop-in for Distance — same API
/// final d = const GeoDistance();
/// final km = d.as(LengthUnit.Kilometer, p1, p2);
///
/// // Extra methods not in Distance
/// final mid = d.midpoint(p1, p2);
/// final perp = d.crossTrackDistance(point, segStart, segEnd);
/// ```
class GeoDistance extends Distance {
  const GeoDistance({
    bool roundResult = true,
    DistanceCalculator calculator = const Vincenty(),
  }) : super(roundResult: roundResult, calculator: calculator);

  /// Uses the faster [Haversine] algorithm (slightly less accurate for long distances).
  const GeoDistance.haversine({bool roundResult = true})
      : super(roundResult: roundResult, calculator: const Haversine());

  // ── Great-circle arc utilities ────────────────────────────────────────────

  /// Midpoint along the great-circle arc from [p1] to [p2].
  LatLng midpoint(LatLng p1, LatLng p2) {
    final lat1 = p1.latitudeInRad, lng1 = p1.longitudeInRad;
    final lat2 = p2.latitudeInRad;
    final dLng = p2.longitudeInRad - lng1;
    final bx = math.cos(lat2) * math.cos(dLng);
    final by = math.cos(lat2) * math.sin(dLng);
    final latM = math.atan2(
      math.sin(lat1) + math.sin(lat2),
      math.sqrt((math.cos(lat1) + bx) * (math.cos(lat1) + bx) + by * by),
    );
    final lngM = lng1 + math.atan2(by, math.cos(lat1) + bx);
    return LatLng(radianToDeg(latM), radianToDeg(lngM));
  }

  /// Point at fraction [t] ∈ [0, 1] along the great-circle arc [p1]→[p2].
  LatLng interpolate(LatLng p1, LatLng p2, double t) {
    assert(t >= 0.0 && t <= 1.0, 't must be in [0, 1]');
    final d = calculator.distance(p1, p2);
    return calculator.offset(p1, d * t, bearing(p1, p2));
  }

  // ── Cross/along-track ─────────────────────────────────────────────────────

  /// Cross-track distance (meters) from [point] to the great-circle path
  /// defined by [start]→[end].
  ///
  /// Positive = point is to the right when facing [end]; negative = left.
  double crossTrackDistance(LatLng point, LatLng start, LatLng end) {
    final d13 = calculator.distance(start, point) / radius;
    final t13 = degToRadian(normalizeBearing(bearing(start, point)));
    final t12 = degToRadian(normalizeBearing(bearing(start, end)));
    return math.asin(math.sin(d13) * math.sin(t13 - t12)) * radius;
  }

  /// Along-track distance (meters) from [start] to the closest point on
  /// [start]→[end] to [point].
  double alongTrackDistance(LatLng point, LatLng start, LatLng end) {
    final d13 = calculator.distance(start, point) / radius;
    final xt = crossTrackDistance(point, start, end) / radius;
    return math.acos(
          (math.cos(d13) / math.cos(xt)).clamp(-1.0, 1.0),
        ).abs() *
        radius;
  }

  /// Angular distance in radians between [p1] and [p2].
  double angularDistance(LatLng p1, LatLng p2) =>
      calculator.distance(p1, p2) / radius;

  // ── Polyline utilities ────────────────────────────────────────────────────

  /// Total length of a polyline [points] in meters (unrounded).
  double pathLength(List<LatLng> points) {
    var total = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      total += calculator.distance(points[i], points[i + 1]);
    }
    return total;
  }

  /// Coordinate at fraction [t] ∈ [0, 1] along the polyline [points].
  ///
  /// t = 0.0 → [points.first], t = 1.0 → [points.last].
  LatLng pointAlongPath(List<LatLng> points, double t) {
    assert(points.length >= 2, 'need at least 2 points');
    assert(t >= 0.0 && t <= 1.0, 't must be in [0, 1]');
    final total = pathLength(points);
    final target = total * t;
    var accumulated = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      final seg = calculator.distance(points[i], points[i + 1]);
      if (accumulated + seg >= target) {
        return interpolate(points[i], points[i + 1],
            seg == 0 ? 0 : (target - accumulated) / seg);
      }
      accumulated += seg;
    }
    return points.last;
  }
}
