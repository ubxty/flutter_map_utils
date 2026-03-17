import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'latlng_bounds.dart';

/// An enhanced path of [LatLng] coordinates.
///
/// API-compatible superset of [latlong2.Path] — all Path methods present:
/// [add], [addAll], [clear], [first], [last], [coordinates], [nrOfCoordinates],
/// [distance], [center], [equalize], [operator[]].
///
/// Additional features over [Path]:
/// - [bounds] — axis-aligned bounding box ([GeoBounds])
/// - [isEmpty] / [isNotEmpty]
/// - [reverse] — reversed copy
/// - [subPath] — slice by index range
/// - [nearest] — closest coordinate to a query point
/// - [bearing] — heading between two indexed coordinates
/// - [bearings] — list of headings along the path
/// - [toList] — defensive copy as plain List
class GeoPath {
  final List<LatLng> _coordinates;

  static const _dist = Distance();

  GeoPath() : _coordinates = [];

  GeoPath.from(Iterable<LatLng> coords) : _coordinates = List.from(coords);

  // ── latlong2.Path compatible API ─────────────────────────────────────────

  List<LatLng> get coordinates => _coordinates;

  void add(LatLng value) => _coordinates.add(value);
  void addAll(Iterable<LatLng> values) => _coordinates.addAll(values);
  void clear() => _coordinates.clear();

  LatLng get first => _coordinates.first;
  LatLng get last => _coordinates.last;

  LatLng operator [](int index) => _coordinates[index];

  int get nrOfCoordinates => _coordinates.length;

  /// Total path distance in meters (sums all consecutive segments).
  double get distance {
    var total = 0.0;
    for (int i = 0; i < _coordinates.length - 1; i++) {
      total += _dist(_coordinates[i], _coordinates[i + 1]);
    }
    return round(total);
  }

  /// Geographic centre via 3D unit-sphere averaging (identical to [Path.center]).
  LatLng get center {
    assert(_coordinates.isNotEmpty, 'coordinates must not be empty');
    double x = 0, y = 0, z = 0;
    for (final c in _coordinates) {
      final lat = c.latitudeInRad, lng = c.longitudeInRad;
      x += math.cos(lat) * math.cos(lng);
      y += math.cos(lat) * math.sin(lng);
      z += math.sin(lat);
    }
    final n = _coordinates.length;
    x /= n;
    y /= n;
    z /= n;
    final lng = math.atan2(y, x);
    final lat = math.atan2(z, math.sqrt(x * x + y * y));
    return LatLng(round(radianToDeg(lat)), round(radianToDeg(lng)));
  }

  /// Redistributes coordinates at equal [distanceInMeters] intervals using
  /// CatmullRom spline interpolation (delegates to [Path.equalize]).
  ///
  /// [smoothPath] = true requires at least 3 coordinates; false requires 2.
  GeoPath equalize(double distanceInMeters, {bool smoothPath = true}) {
    final delegate = Path<LatLng>.from(_coordinates);
    final result = delegate.equalize(distanceInMeters, smoothPath: smoothPath);
    return GeoPath.from(List<LatLng>.from(result.coordinates));
  }

  // ── Extra API ─────────────────────────────────────────────────────────────

  bool get isEmpty => _coordinates.isEmpty;
  bool get isNotEmpty => _coordinates.isNotEmpty;

  List<LatLng> toList() => List.from(_coordinates);

  /// Axis-aligned bounding box that covers all coordinates.
  GeoBounds get bounds => GeoBounds.fromPoints(_coordinates);

  /// Returns a new [GeoPath] with coordinates in reverse order.
  GeoPath reverse() => GeoPath.from(List.from(_coordinates.reversed));

  /// Returns a sub-path from index [start] (inclusive) to [end] (exclusive).
  GeoPath subPath(int start, int end) =>
      GeoPath.from(_coordinates.sublist(start, end));

  /// Returns the coordinate closest (great-circle) to [point].
  LatLng nearest(LatLng point) {
    assert(_coordinates.isNotEmpty, 'coordinates must not be empty');
    LatLng best = _coordinates.first;
    double bestDist = _dist(point, best);
    for (final c in _coordinates) {
      final d = _dist(point, c);
      if (d < bestDist) {
        bestDist = d;
        best = c;
      }
    }
    return best;
  }

  /// Initial bearing (degrees) from coordinate at [fromIndex] to [toIndex].
  double bearing(int fromIndex, int toIndex) =>
      _dist.bearing(_coordinates[fromIndex], _coordinates[toIndex]);

  /// List of initial bearings (degrees) between each consecutive pair of points.
  List<double> get bearings {
    final result = <double>[];
    for (int i = 0; i < _coordinates.length - 1; i++) {
      result.add(_dist.bearing(_coordinates[i], _coordinates[i + 1]));
    }
    return result;
  }

  @override
  String toString() => 'GeoPath(${_coordinates.length} points, '
      '${(distance / 1000).toStringAsFixed(2)} km)';
}
