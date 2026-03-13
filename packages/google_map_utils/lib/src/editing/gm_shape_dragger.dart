import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_utils_core/map_utils_core.dart';

import 'package:google_map_utils/src/drawing/gm_drawing_controller.dart';

/// Provides whole-shape drag functionality on Google Maps.
///
/// When a shape is selected and the user drags on this overlay,
/// all points of the shape are offset by the drag delta.
///
/// Place this as a sibling of [GoogleMap] inside a [Stack], only
/// when a shape is selected and not in drawing mode.
class GmShapeDragger extends StatefulWidget {
  final GmDrawingController controller;

  const GmShapeDragger({super.key, required this.controller});

  @override
  State<GmShapeDragger> createState() => _GmShapeDraggerState();
}

class _GmShapeDraggerState extends State<GmShapeDragger> {
  LatLng? _lastDragLatLng;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(GmShapeDragger oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _onPanStart(DragStartDetails details) async {
    final pos = await widget.controller.screenToLatLng(details.localPosition);
    if (pos == null) return;
    _lastDragLatLng = pos;
    widget.controller.drawingState.beginShapeDrag();
  }

  Future<void> _onPanUpdate(DragUpdateDetails details) async {
    if (_lastDragLatLng == null) return;
    final selected = widget.controller.drawingState.selectedShape;
    if (selected == null) return;

    final newLatLng =
        await widget.controller.screenToLatLng(details.localPosition);
    if (newLatLng == null) return;

    final latDelta = newLatLng.latitude - _lastDragLatLng!.latitude;
    final lngDelta = newLatLng.longitude - _lastDragLatLng!.longitude;

    if (latDelta == 0 && lngDelta == 0) return;

    _lastDragLatLng = newLatLng;
    _offsetShape(selected, latDelta, lngDelta);
  }

  void _onPanEnd(DragEndDetails details) {
    _lastDragLatLng = null;
    widget.controller.drawingState.endShapeDrag();
  }

  void _offsetShape(DrawableShape shape, double latDelta, double lngDelta) {
    LatLng offset(LatLng p) =>
        LatLng(p.latitude + latDelta, p.longitude + lngDelta);

    final DrawableShape updated;
    switch (shape) {
      case final DrawablePolygon s:
        updated = s.copyWith(
          points: s.points.map(offset).toList(),
          holes: s.holes.map((h) => h.map(offset).toList()).toList(),
        );
      case final DrawablePolyline s:
        updated = s.copyWith(points: s.points.map(offset).toList());
      case final DrawableCircle s:
        updated = s.copyWith(center: offset(s.center));
      case final DrawableRectangle s:
        updated = s.copyWith(points: s.points.map(offset).toList());
    }
    widget.controller.drawingState.updateShape(shape, updated);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.drawingState;
    if (state.selectedShape == null || state.isDrawing) {
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
