import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_utils/flutter_map_utils.dart';

void main() {
  group('MeasurementState', () {
    test('starts empty', () {
      final state = MeasurementState();
      expect(state.isEmpty, true);
      expect(state.pointCount, 0);
      expect(state.totalDistanceMeters, 0);
      expect(state.areaSquareMeters, 0);
    });

    test('addPoint increases count', () {
      final state = MeasurementState();
      state.addPoint(LatLng(0, 0));
      expect(state.pointCount, 1);
      expect(state.isEmpty, false);
    });

    test('totalDistanceMeters with 2 points', () {
      final state = MeasurementState();
      state.addPoint(LatLng(0, 0));
      state.addPoint(LatLng(0, 1));
      // ~111 km
      expect(state.totalDistanceMeters, greaterThan(100000));
      expect(state.totalDistanceMeters, lessThan(120000));
    });

    test('segmentDistances returns per-segment', () {
      final state = MeasurementState();
      state.addPoint(LatLng(0, 0));
      state.addPoint(LatLng(0, 1));
      state.addPoint(LatLng(1, 1));
      final segments = state.segmentDistances;
      expect(segments.length, 2);
      expect(segments[0], greaterThan(100000));
      expect(segments[1], greaterThan(100000));
    });

    test('areaSquareMeters with 3+ points', () {
      final state = MeasurementState();
      state.addPoint(LatLng(0, 0));
      state.addPoint(LatLng(0, 1));
      state.addPoint(LatLng(1, 1));
      expect(state.areaSquareMeters, greaterThan(0));
    });

    test('areaSquareMeters with < 3 points is 0', () {
      final state = MeasurementState();
      state.addPoint(LatLng(0, 0));
      state.addPoint(LatLng(0, 1));
      expect(state.areaSquareMeters, 0);
    });

    test('undoLastPoint removes last', () {
      final state = MeasurementState();
      state.addPoint(LatLng(0, 0));
      state.addPoint(LatLng(1, 1));
      state.undoLastPoint();
      expect(state.pointCount, 1);
    });

    test('clear removes all', () {
      final state = MeasurementState();
      state.addPoint(LatLng(0, 0));
      state.addPoint(LatLng(1, 1));
      state.clear();
      expect(state.isEmpty, true);
    });

    test('notifies listeners', () {
      final state = MeasurementState();
      var count = 0;
      state.addListener(() => count++);
      state.addPoint(LatLng(0, 0));
      state.addPoint(LatLng(1, 1));
      state.undoLastPoint();
      state.clear();
      expect(count, 4);
    });
  });
}
