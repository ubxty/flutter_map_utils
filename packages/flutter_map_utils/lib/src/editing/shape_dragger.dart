import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_utils_core/map_utils_core.dart';

/// Provides whole-shape drag functionality for the selected shape.
///
/// Uses a transparent [GestureDetector] overlay that activates when
/// a shape is selected and the user starts dragging.
class ShapeDragger extends StatefulWidget {
  final DrawingState drawingState;

  const ShapeDragger({super.key, required this.drawingState});

  @override
  State<ShapeDragger> createState() => _ShapeDraggerState();
}

class _ShapeDraggerState extends State<ShapeDragger> {
  LatLng? _lastDragLatLng;

  @override
  void initState() {
    super.initState();
    widget.drawingState.addListener(_onStateChanged);
  }

  @override
  void didUpdateWidget(ShapeDragger oldWidget) {
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

  void _onPanStart(DragStartDetails details) {
    final camera = MapCamera.of(context);
    _lastDragLatLng = camera.screenOffsetToLatLng(details.localPosition);
    widget.drawingState.beginShapeDrag();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_lastDragLatLng == null) return;

    final camera = MapCamera.of(context);
    final selected = widget.drawingState.selectedShape;
    if (selected == null) return;

    final currentScreen = details.localPosition;
    final newLatLng = camera.screenOffsetToLatLng(currentScreen);
    final latDelta = newLatLng.latitude - _lastDragLatLng!.latitude;
    final lngDelta = newLatLng.longitude - _lastDragLatLng!.longitude;

    if (latDelta == 0 && lngDelta == 0) return;

    _lastDragLatLng = newLatLng;
    _offsetShape(selected, latDelta, lngDelta);
  }

  void _onPanEnd(DragEndDetails details) {
    _lastDragLatLng = null;
    widget.drawingState.endShapeDrag();
  }

  void _offsetShape(DrawableShape shape, double latDelta, double lngDelta) {
    LatLng offset(LatLng p) =>
        LatLng(p.latitude + latDelta, p.longitude + lngDelta);

    final DrawableShape updated;
    switch (shape) {
      case final DrawablePolygon s:
        updated = s.copyWith(
          points: s.points.map(offset).toList(),
          holes: s.holes
              .map((h) => h.map(offset).toList())
              .toList(),
        );
      case final DrawablePolyline s:
        updated = s.copyWith(points: s.points.map(offset).toList());
      case final DrawableCircle s:
        updated = s.copyWith(center: offset(s.center));
      case final DrawableRectangle s:
        updated = s.copyWith(points: s.points.map(offset).toList());
    }
    widget.drawingState.updateShape(shape, updated);
  }

  @override
  Widget build(BuildContext context) {
    // Only active when a shape is selected and not in drawing mode
    if (widget.drawingState.selectedShape == null ||
        widget.drawingState.isDrawing) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: const SizedBox.expand(),
    );
  }
}
