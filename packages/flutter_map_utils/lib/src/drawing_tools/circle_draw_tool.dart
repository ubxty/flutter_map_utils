import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_utils_core/map_utils_core.dart';

import 'package:flutter_map_utils/src/drawing_tools/base_draw_tool.dart';

/// A drawing tool for creating circles.
///
/// First tap sets the center, second tap defines the radius.
/// Shows a preview circle with radius label during drawing.
class CircleDrawTool extends BaseDrawTool {
  /// Style override for the preview circle.
  final ShapeStyle? previewStyle;

  const CircleDrawTool({
    super.key,
    required super.drawingState,
    super.onDrawingComplete,
    this.previewStyle,
  }) : super(
          showEdgeLengths: false,
          showAreaPreview: false,
          autoCloseThreshold: 0,
        );

  @override
  State<CircleDrawTool> createState() => _CircleDrawToolState();
}

class _CircleDrawToolState extends BaseDrawToolState<CircleDrawTool> {
  static const Distance _haversine = Distance();

  /// Tracks the hover position for live radius preview.
  LatLng? _hoverPoint;

  @override
  void initState() {
    super.initState();
    widget.drawingState.addListener(_onStateChanged);
  }

  @override
  void didUpdateWidget(CircleDrawTool oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.drawingState != widget.drawingState) {
      oldWidget.drawingState.removeListener(_onStateChanged);
      widget.drawingState.addListener(_onStateChanged);
    }
  }

  @override
  void dispose() {
    widget.drawingState.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  /// Update hover position for live radius preview.
  void updateHoverPoint(LatLng? point) {
    if (_hoverPoint != point) {
      _hoverPoint = point;
      if (mounted) setState(() {});
    }
  }

  @override
  void handleTap(LatLng point) {
    final center = widget.drawingState.circleCenter;

    if (center == null) {
      // First tap: set center
      widget.drawingState.setCircleCenter(point);
    } else {
      // Second tap: compute radius and finish
      final radius = _haversine.distance(center, point);
      if (radius > 0) {
        finishDrawingWithRadius(radius);
      }
    }
  }

  void finishDrawingWithRadius(double radius) {
    final shape = widget.drawingState.finishCircleDrawing(
      radius,
      style: widget.previewStyle,
    );
    _hoverPoint = null;
    if (shape != null) {
      widget.onDrawingComplete?.call();
    }
  }

  @override
  void finishDrawing() {
    // For circle: finish requires a radius from the hover point
    final center = widget.drawingState.circleCenter;
    if (center != null && _hoverPoint != null) {
      final radius = _haversine.distance(center, _hoverPoint!);
      if (radius > 0) {
        finishDrawingWithRadius(radius);
      }
    }
  }

  @override
  void cancelDrawing() {
    _hoverPoint = null;
    super.cancelDrawing();
  }

  @override
  List<Widget> buildPreviewLayers(BuildContext context, MapCamera camera) {
    final center = widget.drawingState.circleCenter;
    if (center == null) return const [];

    final style = widget.previewStyle ?? widget.drawingState.defaultStyle;
    final resolved = style.resolve();
    final layers = <Widget>[];

    final edgePoint = _hoverPoint;
    final double? radiusMeters =
        edgePoint != null ? _haversine.distance(center, edgePoint) : null;

    if (radiusMeters != null && radiusMeters > 0) {
      // Circle preview
      layers.add(CircleLayer(
        circles: [
          CircleMarker(
            point: center,
            radius: radiusMeters,
            useRadiusInMeter: true,
            color: resolved.fillColor
                .withValues(alpha: resolved.fillOpacity),
            borderStrokeWidth: resolved.borderWidth,
            borderColor: resolved.borderColor,
          ),
        ],
      ));

      // Radius line
      layers.add(PolylineLayer(
        polylines: [
          Polyline(
            points: [center, edgePoint!],
            strokeWidth: 1.5,
            color: resolved.borderColor.withValues(alpha: 0.6),
            pattern: StrokePattern.dashed(segments: const [8, 4]),
          ),
        ],
      ));

      // Radius label at midpoint
      final midLat = (center.latitude + edgePoint.latitude) / 2;
      final midLng = (center.longitude + edgePoint.longitude) / 2;
      layers.add(MarkerLayer(
        markers: [
          Marker(
            point: LatLng(midLat, midLng),
            width: 90,
            height: 24,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xDD000000),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'r=${formatDistance(radiusMeters)}',
                  style: const TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ));
    }

    // Center marker
    layers.add(MarkerLayer(
      markers: [
        Marker(
          point: center,
          width: 16,
          height: 16,
          child: Center(
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF5722),
                border: Border.all(color: const Color(0xFFFFFFFF), width: 2),
              ),
            ),
          ),
        ),
      ],
    ));

    return layers;
  }
}
