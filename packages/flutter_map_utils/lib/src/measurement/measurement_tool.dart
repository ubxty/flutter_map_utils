import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_utils_core/map_utils_core.dart';

/// Unit system for measurement display.
enum MeasurementUnit {
  metric,
  imperial,
}

/// State for the measurement tool.
class MeasurementState extends ChangeNotifier {
  final List<LatLng> _points = [];

  List<LatLng> get points => List.unmodifiable(_points);

  bool get isEmpty => _points.isEmpty;

  int get pointCount => _points.length;

  /// Total path distance in meters.
  double get totalDistanceMeters {
    if (_points.length < 2) return 0;
    return GeometryUtils.polylineLength(_points);
  }

  /// Area in square meters (if 3+ points, treats as closed polygon).
  double get areaSquareMeters {
    if (_points.length < 3) return 0;
    return GeometryUtils.polygonArea(_points);
  }

  /// Segment distances in meters.
  List<double> get segmentDistances {
    if (_points.length < 2) return [];
    const haversine = Distance();
    final distances = <double>[];
    for (var i = 0; i < _points.length - 1; i++) {
      distances.add(haversine.distance(_points[i], _points[i + 1]));
    }
    return distances;
  }

  void addPoint(LatLng point) {
    _points.add(point);
    notifyListeners();
  }

  void undoLastPoint() {
    if (_points.isNotEmpty) {
      _points.removeLast();
      notifyListeners();
    }
  }

  void clear() {
    _points.clear();
    notifyListeners();
  }
}

/// A measurement layer that draws measurement lines, distance labels,
/// and optionally area information.
class MeasurementLayer extends StatefulWidget {
  final MeasurementState measurementState;

  /// Whether to show area when 3+ points exist.
  final bool showArea;

  /// Unit system for display.
  final MeasurementUnit unit;

  /// Line color for measurement lines.
  final Color lineColor;

  /// Width of the measurement line.
  final double lineWidth;

  /// Whether to show per-segment distance labels.
  final bool showSegmentLabels;

  const MeasurementLayer({
    super.key,
    required this.measurementState,
    this.showArea = true,
    this.unit = MeasurementUnit.metric,
    this.lineColor = const Color(0xFFFF5722),
    this.lineWidth = 2.5,
    this.showSegmentLabels = true,
  });

  @override
  State<MeasurementLayer> createState() => _MeasurementLayerState();
}

class _MeasurementLayerState extends State<MeasurementLayer> {
  @override
  void initState() {
    super.initState();
    widget.measurementState.addListener(_onStateChanged);
  }

  @override
  void didUpdateWidget(MeasurementLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.measurementState != widget.measurementState) {
      oldWidget.measurementState.removeListener(_onStateChanged);
      widget.measurementState.addListener(_onStateChanged);
    }
  }

  @override
  void dispose() {
    widget.measurementState.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.measurementState.points;
    if (points.isEmpty) return const SizedBox.shrink();

    final layers = <Widget>[];

    // Measurement line
    if (points.length >= 2) {
      layers.add(
        PolylineLayer(
          polylines: [
            Polyline(
              points: points,
              color: widget.lineColor,
              strokeWidth: widget.lineWidth,
              pattern: const StrokePattern.dotted(),
            ),
          ],
        ),
      );
    }

    // Vertex markers
    final markers = <Marker>[];
    for (var i = 0; i < points.length; i++) {
      markers.add(
        Marker(
          point: points[i],
          width: 12,
          height: 12,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.lineColor,
              border: Border.all(
                color: const Color(0xFFFFFFFF),
                width: 2,
              ),
            ),
          ),
        ),
      );
    }
    layers.add(MarkerLayer(markers: markers));

    // Segment distance labels
    if (widget.showSegmentLabels && points.length >= 2) {
      final labelMarkers = <Marker>[];
      final distances = widget.measurementState.segmentDistances;
      for (var i = 0; i < distances.length; i++) {
        final mid = GeometryUtils.midpoint(points[i], points[i + 1]);
        labelMarkers.add(
          Marker(
            point: mid,
            width: 80,
            height: 24,
            child: _DistanceLabel(
              text: _formatDistance(distances[i]),
            ),
          ),
        );
      }
      layers.add(MarkerLayer(markers: labelMarkers));
    }

    // Total distance label at last point
    if (points.length >= 2) {
      final total = widget.measurementState.totalDistanceMeters;
      markers.add(
        Marker(
          point: points.last,
          width: 120,
          height: 40,
          alignment: const Alignment(0, -2),
          child: _TotalLabel(
            distance: _formatDistance(total),
            area: widget.showArea && points.length >= 3
                ? _formatArea(widget.measurementState.areaSquareMeters)
                : null,
          ),
        ),
      );
    }

    return Stack(children: layers);
  }

  String _formatDistance(double meters) {
    if (widget.unit == MeasurementUnit.imperial) {
      final feet = meters * 3.28084;
      if (feet < 5280) return '${feet.toStringAsFixed(0)} ft';
      return '${(feet / 5280).toStringAsFixed(2)} mi';
    }
    if (meters < 1000) return '${meters.toStringAsFixed(1)} m';
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  String _formatArea(double sqMeters) {
    if (widget.unit == MeasurementUnit.imperial) {
      final sqFeet = sqMeters * 10.7639;
      if (sqFeet < 43560) return '${sqFeet.toStringAsFixed(0)} ft²';
      return '${(sqFeet / 43560).toStringAsFixed(2)} ac';
    }
    if (sqMeters < 10000) return '${sqMeters.toStringAsFixed(1)} m²';
    final hectares = sqMeters / 10000;
    if (hectares < 100) return '${hectares.toStringAsFixed(2)} ha';
    return '${(sqMeters / 1e6).toStringAsFixed(2)} km²';
  }
}

class _DistanceLabel extends StatelessWidget {
  final String text;
  const _DistanceLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xE6FFFFFF),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 2,
          ),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF333333),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TotalLabel extends StatelessWidget {
  final String distance;
  final String? area;
  const _TotalLabel({required this.distance, this.area});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xF0FF5722),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x60000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            distance,
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (area != null)
            Text(
              area!,
              style: const TextStyle(
                color: Color(0xDDFFFFFF),
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }
}
