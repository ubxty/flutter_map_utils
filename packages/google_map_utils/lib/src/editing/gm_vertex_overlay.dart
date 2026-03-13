import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_utils_core/map_utils_core.dart';

import 'package:google_map_utils/src/drawing/gm_drawing_controller.dart';

/// Vertex and edge handle overlay for editing shapes on Google Maps.
///
/// Renders [Positioned] Flutter widgets over the map for each vertex
/// and edge midpoint of the selected shape. Handles are draggable to
/// move vertices, and tapping edge handles inserts new vertices.
///
/// ```dart
/// Stack(
///   children: [
///     GoogleMap(...),
///     GmVertexOverlay(controller: controller),
///   ],
/// )
/// ```
class GmVertexOverlay extends StatefulWidget {
  final GmDrawingController controller;

  /// Size of vertex handles in logical pixels.
  final double vertexHandleSize;

  /// Size of edge midpoint handles in logical pixels.
  final double edgeHandleSize;

  /// Color of vertex handles.
  final Color vertexHandleColor;

  /// Color of edge midpoint handles.
  final Color edgeHandleColor;

  /// Whether to show edge midpoint handles.
  final bool showEdgeHandles;

  /// Callback when a vertex is long-pressed (for deletion).
  final void Function(int vertexIndex)? onVertexLongPress;

  const GmVertexOverlay({
    super.key,
    required this.controller,
    this.vertexHandleSize = 14,
    this.edgeHandleSize = 10,
    this.vertexHandleColor = const Color(0xFF2196F3),
    this.edgeHandleColor = const Color(0xFF66BB6A),
    this.showEdgeHandles = true,
    this.onVertexLongPress,
  });

  @override
  State<GmVertexOverlay> createState() => _GmVertexOverlayState();
}

class _GmVertexOverlayState extends State<GmVertexOverlay> {
  /// Cached screen positions for each vertex.
  final Map<int, Offset> _vertexPositions = {};

  /// Cached screen positions for each edge midpoint.
  final Map<int, Offset> _edgeMidPositions = {};

  /// Whether we're currently refreshing positions.
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(GmVertexOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    _refreshPositions();
  }

  Future<void> _refreshPositions() async {
    if (_refreshing) return;
    _refreshing = true;

    final selected = widget.controller.drawingState.selectedShape;
    if (selected == null || widget.controller.mapController == null) {
      _vertexPositions.clear();
      _edgeMidPositions.clear();
      _refreshing = false;
      if (mounted) setState(() {});
      return;
    }

    final points = selected.allPoints;
    final newVertexPos = <int, Offset>{};
    final newEdgePos = <int, Offset>{};

    // Vertex positions
    for (var i = 0; i < points.length; i++) {
      final screen = await widget.controller.latLngToScreen(points[i]);
      if (screen != null) newVertexPos[i] = screen;
    }

    // Edge midpoint positions
    if (widget.showEdgeHandles && points.length >= 2) {
      final isPolygon =
          selected is DrawablePolygon || selected is DrawableRectangle;
      final edgeCount = isPolygon ? points.length : points.length - 1;

      for (var i = 0; i < edgeCount; i++) {
        final mid = GeometryUtils.midpoint(
          points[i],
          points[(i + 1) % points.length],
        );
        final screen = await widget.controller.latLngToScreen(mid);
        if (screen != null) newEdgePos[i] = screen;
      }
    }

    _vertexPositions
      ..clear()
      ..addAll(newVertexPos);
    _edgeMidPositions
      ..clear()
      ..addAll(newEdgePos);
    _refreshing = false;
    if (mounted) setState(() {});
  }

  void _onVertexDragStart(int index) {
    widget.controller.drawingState.beginShapeDrag();
  }

  Future<void> _onVertexDragUpdate(int index, DragUpdateDetails details) async {
    final selected = widget.controller.drawingState.selectedShape;
    if (selected == null) return;

    final currentPos = _vertexPositions[index];
    if (currentPos == null) return;

    final newPos = currentPos + details.delta;
    _vertexPositions[index] = newPos;

    final newLatLng = await widget.controller.screenToLatLng(newPos);
    if (newLatLng == null) return;

    final points = List.of(selected.allPoints);
    if (index >= points.length) return;
    points[index] = newLatLng;
    _updateShapePoints(selected, points);
  }

  void _onVertexDragEnd(int index) {
    widget.controller.drawingState.endShapeDrag();
    _refreshPositions();
  }

  void _onVertexLongPress(int index) {
    if (widget.onVertexLongPress != null) {
      widget.onVertexLongPress!(index);
      return;
    }
    _deleteVertex(index);
  }

  void _deleteVertex(int index) {
    final selected = widget.controller.drawingState.selectedShape;
    if (selected == null) return;

    final points = List.of(selected.allPoints);
    final minPoints = switch (selected) {
      DrawablePolygon _ || DrawableRectangle _ => 3,
      DrawablePolyline _ => 2,
      DrawableCircle _ => 1,
    };
    if (points.length <= minPoints) return;
    points.removeAt(index);
    _updateShapePoints(selected, points);
  }

  void _onEdgeHandleTap(int edgeIndex) {
    _insertVertexAtEdge(edgeIndex);
  }

  void _insertVertexAtEdge(int edgeIndex) {
    final selected = widget.controller.drawingState.selectedShape;
    if (selected == null) return;

    final points = List.of(selected.allPoints);
    final a = points[edgeIndex];
    final b = points[(edgeIndex + 1) % points.length];
    final mid = GeometryUtils.midpoint(a, b);
    points.insert(edgeIndex + 1, mid);
    _updateShapePoints(selected, points);
  }

  void _updateShapePoints(DrawableShape shape, List<LatLng> points) {
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
    widget.controller.drawingState.updateShape(shape, updated);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.controller.drawingState.selectedShape;
    if (selected == null) return const SizedBox.shrink();
    if (_vertexPositions.isEmpty) return const SizedBox.shrink();

    final children = <Widget>[];

    // Vertex handles
    for (final entry in _vertexPositions.entries) {
      children.add(_buildVertexHandle(entry.key, entry.value));
    }

    // Edge midpoint handles
    if (widget.showEdgeHandles) {
      for (final entry in _edgeMidPositions.entries) {
        children.add(_buildEdgeHandle(entry.key, entry.value));
      }
    }

    return Stack(children: children);
  }

  Widget _buildVertexHandle(int index, Offset pos) {
    final size = widget.vertexHandleSize;
    final touchSize = size < 48 ? 48.0 : size;

    return Positioned(
      left: pos.dx - touchSize / 2,
      top: pos.dy - touchSize / 2,
      width: touchSize,
      height: touchSize,
      child: GestureDetector(
        onPanStart: (_) => _onVertexDragStart(index),
        onPanUpdate: (details) => _onVertexDragUpdate(index, details),
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

  Widget _buildEdgeHandle(int edgeIndex, Offset pos) {
    final size = widget.edgeHandleSize;
    final touchSize = size < 48 ? 48.0 : size;

    return Positioned(
      left: pos.dx - touchSize / 2,
      top: pos.dy - touchSize / 2,
      width: touchSize,
      height: touchSize,
      child: GestureDetector(
        onTap: () => _onEdgeHandleTap(edgeIndex),
        child: Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
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
}
