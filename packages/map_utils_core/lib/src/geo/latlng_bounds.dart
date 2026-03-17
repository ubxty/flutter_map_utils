import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// An axis-aligned geographic bounding box defined by [southWest] and [northEast] corners.
///
/// Not present in latlong2 — a common missing piece for map SDK integrations.
class GeoBounds {
  final LatLng southWest;
  final LatLng northEast;

  const GeoBounds(this.southWest, this.northEast);

  /// Creates the smallest bounding box that contains all [points].
  factory GeoBounds.fromPoints(Iterable<LatLng> points) {
    double minLat = double.infinity,
        maxLat = double.negativeInfinity,
        minLng = double.infinity,
        maxLng = double.negativeInfinity;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return GeoBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
  }

  double get north => northEast.latitude;
  double get south => southWest.latitude;
  double get east => northEast.longitude;
  double get west => southWest.longitude;

  LatLng get northWest => LatLng(north, west);
  LatLng get southEast => LatLng(south, east);

  /// Geographic centre of the bounding box.
  LatLng get center => LatLng((north + south) / 2, (east + west) / 2);

  double get latSpan => north - south;
  double get lngSpan => east - west;

  /// Whether [point] lies inside (or on the boundary of) this bounding box.
  bool contains(LatLng point) =>
      point.latitude >= south &&
      point.latitude <= north &&
      point.longitude >= west &&
      point.longitude <= east;

  /// Whether this bounding box fully contains [other].
  bool containsBounds(GeoBounds other) =>
      other.south >= south &&
      other.north <= north &&
      other.west >= west &&
      other.east <= east;

  /// Whether this bounding box overlaps [other] at all.
  bool overlaps(GeoBounds other) =>
      !(other.east < west ||
          other.west > east ||
          other.north < south ||
          other.south > north);

  /// Returns a new bounding box expanded to include [point].
  GeoBounds extend(LatLng point) => GeoBounds(
        LatLng(math.min(south, point.latitude), math.min(west, point.longitude)),
        LatLng(math.max(north, point.latitude), math.max(east, point.longitude)),
      );

  /// Returns the smallest bounding box that contains both this and [other].
  GeoBounds union(GeoBounds other) => GeoBounds(
        LatLng(math.min(south, other.south), math.min(west, other.west)),
        LatLng(math.max(north, other.north), math.max(east, other.east)),
      );

  /// Returns the intersection of this and [other], or null if they do not overlap.
  GeoBounds? intersection(GeoBounds other) {
    if (!overlaps(other)) return null;
    return GeoBounds(
      LatLng(math.max(south, other.south), math.max(west, other.west)),
      LatLng(math.min(north, other.north), math.min(east, other.east)),
    );
  }

  @override
  String toString() => 'GeoBounds($southWest, $northEast)';

  @override
  bool operator ==(Object other) =>
      other is GeoBounds &&
      southWest == other.southWest &&
      northEast == other.northEast;

  @override
  int get hashCode => Object.hash(southWest, northEast);
}
