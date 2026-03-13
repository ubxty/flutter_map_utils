import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_utils_core/map_utils_core.dart';

import 'package:flutter_map_utils/src/drawing_tools/base_draw_tool.dart';
import 'package:flutter_map_utils/src/fm_extensions.dart';

/// A drawing tool for creating polylines by tapping points.
///
/// Minimum 2 points required. Finish via [finishDrawing], double-tap,
/// or secondary tap.
class PolylineDrawTool extends BaseDrawTool {
  /// Style override for the preview polyline.
  final ShapeStyle? previewStyle;

  /// Minimum number of points required.
  final int minPoints;

  const PolylineDrawTool({
    super.key,
    required super.drawingState,
    super.onDrawingComplete,
    super.showEdgeLengths,
    super.autoCloseThreshold = 0, // No auto-close for polylines
    this.previewStyle,
    this.minPoints = 2,
  }) : super(showAreaPreview: false);

  @override
  State<PolylineDrawTool> createState() => _PolylineDrawToolState();
}

class _PolylineDrawToolState extends BaseDrawToolState<PolylineDrawTool> {
  @override
  void initState() {
    super.initState();
    widget.drawingState.addListener(_onStateChanged);
  }

  @override
  void didUpdateWidget(PolylineDrawTool oldWidget) {
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

  @override
  void handleTap(LatLng point) {
    widget.drawingState.addDrawingPoint(point);
  }

  @override
  void finishDrawing() {
    final shape = widget.drawingState.finishDrawing(
      style: widget.previewStyle,
    );
    if (shape != null) {
      widget.onDrawingComplete?.call();
    }
  }

  @override
  List<Widget> buildPreviewLayers(BuildContext context, MapCamera camera) {
    final points = widget.drawingState.drawingPoints;
    if (points.isEmpty) return const [];

    final style = widget.previewStyle ?? widget.drawingState.defaultStyle;
    final resolved = style.resolve();
    final layers = <Widget>[];

    // Vertex markers
    layers.add(MarkerLayer(
      markers: [
        for (var i = 0; i < points.length; i++)
          Marker(
            point: points[i],
            width: 12,
            height: 12,
            child: Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == 0
                      ? const Color(0xFFFF5722)
                      : const Color(0xFF2196F3),
                  border:
                      Border.all(color: const Color(0xFFFFFFFF), width: 2),
                ),
              ),
            ),
          ),
      ],
    ));

    if (points.length >= 2) {
      layers.add(PolylineLayer(
        polylines: [
          Polyline(
            points: points,
            strokeWidth: resolved.borderWidth,
            color: resolved.borderColor,
              pattern: resolved.strokeType.toStrokePattern(),
          ),
        ],
      ));

      // Edge length labels
      final markers = buildEdgeLengthMarkers(points);
      if (markers.isNotEmpty) {
        layers.add(MarkerLayer(markers: markers));
      }
    }

    return layers;
  }
}
