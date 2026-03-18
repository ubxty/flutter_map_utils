import 'dart:async';
import 'dart:math' as math;

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

  /// Debounce timer for position refresh during zoom/pan.
  Timer? _refreshDebounce;

  // --- Anchor state for synchronous camera-follow transform ---
  Map<int, Offset>? _anchorVertexPositions;
  Map<int, Offset>? _anchorEdgePositions;
  LatLng? _anchorCenter;
  double? _anchorZoom;
  Size _widgetSize = Size.zero;

  DrawableShape? _dragStartShape;
  bool _dragMoved = false;
  bool _dragSyncInFlight = false;
  int? _pendingDragSyncIndex;
  Offset? _pendingDragSyncScreenPos;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    // Populate handles immediately on first mount without waiting for a
    // camera/state event (fixes: Edit tapped but no handles visible).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshPositions();
    });
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
    _refreshDebounce?.cancel();
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    // During active drag: screen positions are maintained via synchronous
    // delta math in _onVertexDragUpdate. Triggering a full async refresh
    // here would overwrite positions with stale values and cause flicker.
    if (widget.controller.drawingState.isDragging) return;

    final newCenter = widget.controller.cameraCenter;
    final newZoom = widget.controller.currentZoom;

    // Apply synchronous camera-follow transform so vertex handles move
    // in parallel with the map during pan/zoom/rotate.
    if (newCenter != null &&
        _vertexPositions.isNotEmpty &&
        _widgetSize != Size.zero) {
      if (_anchorVertexPositions == null) {
        _anchorVertexPositions = Map.of(_vertexPositions);
        _anchorEdgePositions = Map.of(_edgeMidPositions);
        _anchorCenter = newCenter;
        _anchorZoom = newZoom;
      } else {
        _applyCameraTransform(newCenter, newZoom);
        if (mounted) setState(() {});
      }
    }

    // Debounced full-accuracy refresh (fires after gesture stops).
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 200), () {
      _anchorVertexPositions = null;
      _anchorEdgePositions = null;
      _anchorCenter = null;
      _anchorZoom = null;
      _refreshPositions();
    });
  }

  void _applyCameraTransform(LatLng newCenter, double newZoom) {
    if (_anchorVertexPositions == null ||
        _anchorCenter == null ||
        _anchorZoom == null) return;

    final dLat = newCenter.latitude - _anchorCenter!.latitude;
    final dLng = newCenter.longitude - _anchorCenter!.longitude;

    final cosLat = math.cos(newCenter.latitude * math.pi / 180);
    final mapSize = 256.0 * math.pow(2.0, newZoom);
    final dpr = widget.controller.devicePixelRatio;

    final pxPerDegLng = mapSize / 360.0 / dpr;
    final pxPerDegLat = mapSize / (360.0 * cosLat) / dpr;

    final dx = -dLng * pxPerDegLng;
    final dy = dLat * pxPerDegLat;

    final zoomScale = math.pow(2.0, newZoom - _anchorZoom!);

    final cx = _widgetSize.width / 2;
    final cy = _widgetSize.height / 2;

    Offset transform(Offset p) {
      final sx = cx + (p.dx - cx) * zoomScale + dx;
      final sy = cy + (p.dy - cy) * zoomScale + dy;
      return Offset(sx, sy);
    }

    _vertexPositions.clear();
    for (final e in _anchorVertexPositions!.entries) {
      _vertexPositions[e.key] = transform(e.value);
    }
    _edgeMidPositions.clear();
    for (final e in (_anchorEdgePositions ?? {}).entries) {
      _edgeMidPositions[e.key] = transform(e.value);
    }
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
    // Clear anchor state — we now have accurate positions.
    _anchorVertexPositions = null;
    _anchorEdgePositions = null;
    _anchorCenter = null;
    _anchorZoom = null;
    if (mounted) setState(() {});
  }

  void _onVertexDragStart(int index) {
    final selected = widget.controller.drawingState.selectedShape;
    if (selected != null && index < selected.allPoints.length) {
      _dragStartShape = selected;
      _dragMoved = false;
    }
    widget.controller.drawingState.beginShapeDrag();
  }

  /// Drag update keeps the handle under finger immediately, while geometry
  /// sync runs through a throttled projection queue.
  void _onVertexDragUpdate(int index, DragUpdateDetails details) {
    final currentPos = _vertexPositions[index];
    if (currentPos == null) return;

    // Update screen-position cache immediately (pure Dart, no async).
    final newPos = currentPos + details.delta;
    _vertexPositions[index] = newPos;

    _dragMoved = true;
    _queueDraggedVertexProjectionSync(index, newPos);

    // Redraw handles with updated positions.
    if (mounted) setState(() {});
  }

  void _onVertexDragEnd(int index) async {
    // Flush the final finger position using exact screen->LatLng projection.
    final endScreenPos = _vertexPositions[index];
    if (endScreenPos != null) {
      final endPoint = await widget.controller.screenToLatLng(endScreenPos);
      if (endPoint != null) {
        final selected = widget.controller.drawingState.selectedShape;
        if (selected != null && index < selected.allPoints.length) {
          final points = List.of(selected.allPoints);
          points[index] = endPoint;
          _updateShapePoints(selected, points, recordHistory: false);
        }
      }
    }

    final finalShape = widget.controller.drawingState.selectedShape;
    if (_dragMoved && _dragStartShape != null && finalShape != null) {
      // Commit one undoable command for the entire drag gesture.
      widget.controller.drawingState.updateShape(_dragStartShape!, finalShape);
    }
    _dragStartShape = null;
    _dragMoved = false;
    _pendingDragSyncIndex = null;
    _pendingDragSyncScreenPos = null;
    widget.controller.drawingState.endShapeDrag();
    // Single accurate reconciliation refresh now that the gesture is done.
    _refreshPositions();
  }

  // Keeps dragged geometry aligned with the handle without flooding
  // platform channels on every move event.
  void _queueDraggedVertexProjectionSync(int index, Offset screenPos) {
    _pendingDragSyncIndex = index;
    _pendingDragSyncScreenPos = screenPos;
    if (_dragSyncInFlight) return;

    _dragSyncInFlight = true;
    Future<void>(() async {
      while (mounted &&
          _pendingDragSyncIndex != null &&
          _pendingDragSyncScreenPos != null) {
        final syncIndex = _pendingDragSyncIndex!;
        final syncScreen = _pendingDragSyncScreenPos!;
        _pendingDragSyncIndex = null;
        _pendingDragSyncScreenPos = null;

        final projectedPoint = await widget.controller.screenToLatLng(syncScreen);
        if (!mounted) break;
        if (projectedPoint != null) {
          final selected = widget.controller.drawingState.selectedShape;
          if (selected != null && syncIndex < selected.allPoints.length) {
            final points = List.of(selected.allPoints);
            points[syncIndex] = projectedPoint;
            _updateShapePoints(selected, points, recordHistory: false);
          }
        }
      }
      _dragSyncInFlight = false;
    });
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

  void _updateShapePoints(
    DrawableShape shape,
    List<LatLng> points, {
    bool recordHistory = true,
  }) {
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
    if (recordHistory) {
      widget.controller.drawingState.updateShape(shape, updated);
    } else {
      widget.controller.drawingState.updateShapeNoHistory(shape, updated);
    }
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

    return LayoutBuilder(
      builder: (context, constraints) {
        _widgetSize = constraints.biggest;
        return Stack(children: children);
      },
    );
  }

  Widget _buildVertexHandle(int index, Offset pos) {
    final size = widget.vertexHandleSize;
    final touchSize = size < 60 ? 60.0 : size;

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
