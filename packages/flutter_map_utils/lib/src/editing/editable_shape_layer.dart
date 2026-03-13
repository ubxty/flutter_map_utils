import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_utils_core/map_utils_core.dart';

/// A layer that provides vertex handles and edge handles for editing
/// the currently selected shape.
///
/// Place after the [DrawingLayer] in [FlutterMap.children].
///
/// ```dart
/// FlutterMap(
///   children: [
///     TileLayer(...),
///     DrawingLayer(drawingState: state),
///     EditableShapeLayer(drawingState: state),
///   ],
/// )
/// ```
class EditableShapeLayer extends StatefulWidget {
  /// The drawing state to edit shapes from.
  final DrawingState drawingState;

  /// Size of vertex handles in logical pixels.
  final double vertexHandleSize;

  /// Size of edge midpoint handles in logical pixels.
  final double edgeHandleSize;

  /// Color of vertex handles.
  final Color vertexHandleColor;

  /// Color of edge midpoint handles.
  final Color edgeHandleColor;

  /// Whether to show vertex index labels (debug mode).
  final bool debugShowVertexIndices;

  /// Whether to show edge midpoint handles for inserting new vertices.
  final bool showEdgeHandles;

  /// Callback when a vertex is long-pressed (for deletion).
  final void Function(int vertexIndex)? onVertexLongPress;

  const EditableShapeLayer({
    super.key,
    required this.drawingState,
    this.vertexHandleSize = 14,
    this.edgeHandleSize = 10,
    this.vertexHandleColor = const Color(0xFF2196F3),
    this.edgeHandleColor = const Color(0xFF66BB6A),
    this.debugShowVertexIndices = false,
    this.showEdgeHandles = true,
    this.onVertexLongPress,
  });

  @override
  State<EditableShapeLayer> createState() => _EditableShapeLayerState();
}

class _EditableShapeLayerState extends State<EditableShapeLayer> {

  @override
  void initState() {
    super.initState();
    widget.drawingState.addListener(_onStateChanged);
  }

  @override
  void didUpdateWidget(EditableShapeLayer oldWidget) {
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
  Widget build(BuildContext context) {
    final selected = widget.drawingState.selectedShape;
    if (selected == null) return const SizedBox.shrink();

    final points = selected.allPoints;
    if (points.isEmpty) return const SizedBox.shrink();

    final layers = <Widget>[];

    // Vertex handles
    final vertexMarkers = <Marker>[];
    for (var i = 0; i < points.length; i++) {
      vertexMarkers.add(_buildVertexHandle(context, i, points[i]));
    }
    layers.add(MarkerLayer(markers: vertexMarkers));

    // Edge midpoint handles
    if (widget.showEdgeHandles && points.length >= 2) {
      final edgeMarkers = <Marker>[];
      final isPolygon = selected is DrawablePolygon ||
          selected is DrawableRectangle;
      final edgeCount = isPolygon ? points.length : points.length - 1;

      for (var i = 0; i < edgeCount; i++) {
        final a = points[i];
        final b = points[(i + 1) % points.length];
        final mid = GeometryUtils.midpoint(a, b);
        edgeMarkers.add(_buildEdgeHandle(context, i, mid));
      }
      layers.add(MarkerLayer(markers: edgeMarkers));
    }

    // Debug vertex indices
    if (widget.debugShowVertexIndices) {
      final debugMarkers = <Marker>[];
      for (var i = 0; i < points.length; i++) {
        debugMarkers.add(Marker(
          point: points[i],
          width: 24,
          height: 16,
          child: Text(
            '$i',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFFF0000),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ));
      }
      layers.add(MarkerLayer(markers: debugMarkers));
    }

    return Stack(children: layers);
  }

  Marker _buildVertexHandle(BuildContext context, int index, LatLng point) {
    final size = widget.vertexHandleSize;
    // Touch target is at least 48px for accessibility
    final touchSize = size < 48 ? 48.0 : size;

    return Marker(
      point: point,
      width: touchSize,
      height: touchSize,
      child: GestureDetector(
        onPanStart: (_) => _onVertexDragStart(index, point),
        onPanUpdate: (details) =>
            _onVertexDragUpdate(context, index, details),
        onPanEnd: (_) => _onVertexDragEnd(index),
        onLongPress: () => _onVertexLongPress(index),
        child: Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.vertexHandleColor,
              border: Border.all(
                color: const Color(0xFFFFFFFF),
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Marker _buildEdgeHandle(BuildContext context, int edgeIndex, LatLng mid) {
    final size = widget.edgeHandleSize;
    final touchSize = size < 48 ? 48.0 : size;

    return Marker(
      point: mid,
      width: touchSize,
      height: touchSize,
      child: GestureDetector(
        onTap: () => _onEdgeHandleTap(edgeIndex),
        onPanStart: (_) =>
            _onEdgeHandleDragStart(edgeIndex, mid),
        onPanUpdate: (details) =>
            _onEdgeHandleDragUpdate(context, edgeIndex, details),
        onPanEnd: (_) => _onVertexDragEnd(edgeIndex + 1),
        child: Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(2),
              color: widget.edgeHandleColor,
              border: Border.all(
                color: const Color(0xFFFFFFFF),
                width: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -- Vertex dragging --

  void _onVertexDragStart(int index, LatLng point) {
    widget.drawingState.beginShapeDrag();
  }

  void _onVertexDragUpdate(
    BuildContext context,
    int index,
    DragUpdateDetails details,
  ) {
    final camera = MapCamera.of(context);
    final selected = widget.drawingState.selectedShape;
    if (selected == null) return;

    final points = List.of(selected.allPoints);
    if (index >= points.length) return;

    // Convert screen delta to LatLng
    final currentScreen = camera.latLngToScreenOffset(points[index]);
    final newScreen = currentScreen + details.delta;
    final newLatLng = camera.screenOffsetToLatLng(newScreen);

    points[index] = newLatLng;
    _updateSelectedShapePoints(selected, points);
  }

  void _onVertexDragEnd(int index) {
    widget.drawingState.endShapeDrag();
  }

  void _onVertexLongPress(int index) {
    if (widget.onVertexLongPress != null) {
      widget.onVertexLongPress!(index);
      return;
    }
    // Default: delete vertex if shape has enough remaining
    _deleteVertex(index);
  }

  void _deleteVertex(int index) {
    final selected = widget.drawingState.selectedShape;
    if (selected == null) return;

    final points = List.of(selected.allPoints);
    final minPoints = switch (selected) {
      DrawablePolygon _ || DrawableRectangle _ => 3,
      DrawablePolyline _ => 2,
      DrawableCircle _ => 1,
    };

    if (points.length <= minPoints) return;
    points.removeAt(index);
    _updateSelectedShapePoints(selected, points);
  }

  // -- Edge handle actions --

  void _onEdgeHandleTap(int edgeIndex) {
    _insertVertexAtEdge(edgeIndex);
  }

  void _onEdgeHandleDragStart(int edgeIndex, LatLng mid) {
    _insertVertexAtEdge(edgeIndex);
    // Now start dragging the newly inserted vertex
    widget.drawingState.beginShapeDrag();
  }

  void _onEdgeHandleDragUpdate(
    BuildContext context,
    int edgeIndex,
    DragUpdateDetails details,
  ) {
    // The inserted vertex is at edgeIndex + 1
    _onVertexDragUpdate(context, edgeIndex + 1, details);
  }

  void _insertVertexAtEdge(int edgeIndex) {
    final selected = widget.drawingState.selectedShape;
    if (selected == null) return;

    final points = List.of(selected.allPoints);
    final a = points[edgeIndex];
    final b = points[(edgeIndex + 1) % points.length];
    final mid = GeometryUtils.midpoint(a, b);

    points.insert(edgeIndex + 1, mid);
    _updateSelectedShapePoints(selected, points);
  }

  // -- Update shape points --

  void _updateSelectedShapePoints(DrawableShape shape, List<LatLng> points) {
    final DrawableShape updated;
    switch (shape) {
      case final DrawablePolygon s:
        updated = s.copyWith(points: points);
      case final DrawablePolyline s:
        updated = s.copyWith(points: points);
      case final DrawableRectangle s:
        updated = s.copyWith(points: points);
      case final DrawableCircle s:
        if (points.isNotEmpty) {
          updated = s.copyWith(center: points.first);
        } else {
          return;
        }
    }
    widget.drawingState.updateShape(shape, updated);
  }
}
