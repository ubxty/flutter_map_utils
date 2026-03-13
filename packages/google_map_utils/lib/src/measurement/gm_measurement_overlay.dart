import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';
import 'package:map_utils_core/map_utils_core.dart';

import 'package:google_map_utils/src/drawing/gm_drawing_controller.dart';
import 'package:google_map_utils/src/gm_extensions.dart';

/// Unit system for measurement display.
enum GmMeasurementUnit { metric, imperial }

/// State for the Google Maps measurement tool.
///
/// Pure [ChangeNotifier] that calculates distances and areas using
/// core [GeometryUtils]. Works identically to the flutter_map version.
class GmMeasurementState extends ChangeNotifier {
  final List<LatLng> _points = [];

  List<LatLng> get points => List.unmodifiable(_points);
  bool get isEmpty => _points.isEmpty;
  int get pointCount => _points.length;

  double get totalDistanceMeters {
    if (_points.length < 2) return 0;
    return GeometryUtils.polylineLength(_points);
  }

  double get areaSquareMeters {
    if (_points.length < 3) return 0;
    return GeometryUtils.polygonArea(_points);
  }

  List<double> get segmentDistances {
    if (_points.length < 2) return [];
    const haversine = Distance();
    return [
      for (var i = 0; i < _points.length - 1; i++)
        haversine.distance(_points[i], _points[i + 1]),
    ];
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

/// Measurement overlay that renders per-segment labels, total distance,
/// and area as positioned widgets over a Google Map.
///
/// The measurement polyline itself should be rendered via
/// [buildMeasurementPolyline]. This overlay adds the label widgets.
class GmMeasurementOverlay extends StatefulWidget {
  final GmMeasurementState measurementState;
  final GmDrawingController controller;

  /// Whether to show area when 3+ points exist.
  final bool showArea;

  /// Unit system for display.
  final GmMeasurementUnit unit;

  const GmMeasurementOverlay({
    super.key,
    required this.measurementState,
    required this.controller,
    this.showArea = true,
    this.unit = GmMeasurementUnit.metric,
  });

  /// Build a Google Maps polyline for the measurement path.
  ///
  /// Add this to your [gm.GoogleMap.polylines] set.
  static Set<gm.Polyline> buildMeasurementPolyline(
    GmMeasurementState state, {
    Color lineColor = const Color(0xFFFF5722),
    int lineWidth = 3,
  }) {
    if (state.pointCount < 2) return {};
    return {
      gm.Polyline(
        polylineId: const gm.PolylineId('__measurement__'),
        points: state.points.toGm(),
        color: lineColor,
        width: lineWidth,
        patterns: [gm.PatternItem.dash(12), gm.PatternItem.gap(6)],
      ),
    };
  }

  @override
  State<GmMeasurementOverlay> createState() => _GmMeasurementOverlayState();
}

class _GmMeasurementOverlayState extends State<GmMeasurementOverlay> {
  final List<Offset?> _labelPositions = [];
  Offset? _totalLabelPosition;
  Offset? _areaLabelPosition;

  @override
  void initState() {
    super.initState();
    widget.measurementState.addListener(_refresh);
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(GmMeasurementOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.measurementState != widget.measurementState) {
      oldWidget.measurementState.removeListener(_refresh);
      widget.measurementState.addListener(_refresh);
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.measurementState.removeListener(_refresh);
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => _refreshPositions();

  Future<void> _refreshPositions() async {
    final points = widget.measurementState.points;
    if (points.length < 2 || widget.controller.mapController == null) {
      _labelPositions.clear();
      _totalLabelPosition = null;
      _areaLabelPosition = null;
      if (mounted) setState(() {});
      return;
    }

    final newPositions = <Offset?>[];
    for (var i = 0; i < points.length - 1; i++) {
      final mid = GeometryUtils.midpoint(points[i], points[i + 1]);
      newPositions.add(await widget.controller.latLngToScreen(mid));
    }

    // Total label at the last point
    final totalPos = await widget.controller.latLngToScreen(points.last);

    // Area label at centroid
    Offset? areaPos;
    if (widget.showArea && points.length >= 3) {
      final centroid = GeometryUtils.centroid(points);
      areaPos = await widget.controller.latLngToScreen(centroid);
    }

    _labelPositions
      ..clear()
      ..addAll(newPositions);
    _totalLabelPosition = totalPos;
    _areaLabelPosition = areaPos;
    if (mounted) setState(() {});
  }

  String _formatDistance(double meters) {
    if (widget.unit == GmMeasurementUnit.imperial) {
      final feet = meters * 3.28084;
      if (feet >= 5280) return '${(feet / 5280).toStringAsFixed(2)} mi';
      return '${feet.toStringAsFixed(1)} ft';
    }
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(2)} km';
    return '${meters.toStringAsFixed(1)} m';
  }

  String _formatArea(double sqMeters) {
    if (widget.unit == GmMeasurementUnit.imperial) {
      final sqFt = sqMeters * 10.7639;
      if (sqFt >= 43560) {
        return '${(sqFt / 43560).toStringAsFixed(2)} ac';
      }
      return '${sqFt.toStringAsFixed(1)} ft\u00B2';
    }
    if (sqMeters >= 1e6) return '${(sqMeters / 1e6).toStringAsFixed(3)} km\u00B2';
    if (sqMeters >= 1e4) {
      return '${(sqMeters / 1e4).toStringAsFixed(2)} ha';
    }
    return '${sqMeters.toStringAsFixed(1)} m\u00B2';
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.measurementState;
    if (state.pointCount < 2) return const SizedBox.shrink();

    final segments = state.segmentDistances;
    final children = <Widget>[];

    // Per-segment distance labels
    for (var i = 0; i < _labelPositions.length && i < segments.length; i++) {
      final pos = _labelPositions[i];
      if (pos == null) continue;
      children.add(Positioned(
        left: pos.dx - 40,
        top: pos.dy - 12,
        child: _MeasurementLabel(text: _formatDistance(segments[i])),
      ));
    }

    // Total distance label
    if (_totalLabelPosition != null) {
      children.add(Positioned(
        left: _totalLabelPosition!.dx - 50,
        top: _totalLabelPosition!.dy + 8,
        child: _MeasurementLabel(
          text: 'Total: ${_formatDistance(state.totalDistanceMeters)}',
          highlight: true,
        ),
      ));
    }

    // Area label
    if (widget.showArea &&
        state.pointCount >= 3 &&
        _areaLabelPosition != null) {
      children.add(Positioned(
        left: _areaLabelPosition!.dx - 40,
        top: _areaLabelPosition!.dy - 12,
        child: _MeasurementLabel(
          text: _formatArea(state.areaSquareMeters),
          highlight: true,
        ),
      ));
    }

    return Stack(children: children);
  }
}

class _MeasurementLabel extends StatelessWidget {
  final String text;
  final bool highlight;

  const _MeasurementLabel({required this.text, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xDD1565C0) : const Color(0xDD000000),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
