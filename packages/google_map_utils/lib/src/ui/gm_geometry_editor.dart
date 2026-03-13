import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:map_utils_core/map_utils_core.dart';

import 'package:google_map_utils/src/drawing/gm_drawing_controller.dart';
import 'package:google_map_utils/src/drawing/gm_freehand_overlay.dart';
import 'package:google_map_utils/src/editing/gm_shape_dragger.dart';
import 'package:google_map_utils/src/editing/gm_vertex_overlay.dart';
import 'package:google_map_utils/src/gm_extensions.dart';
import 'package:google_map_utils/src/measurement/gm_measurement_overlay.dart';
import 'package:google_map_utils/src/rendering/gm_shape_renderer.dart';

/// All-in-one wrapper that layers drawing, editing, selection,
/// measurement, toolbar, and info panel on a [gm.GoogleMap].
///
/// ```dart
/// GoogleMapGeometryEditor(
///   drawingState: myDrawingState,
///   initialCameraPosition: CameraPosition(
///     target: LatLng(0, 0),
///     zoom: 12,
///   ),
/// )
/// ```
class GoogleMapGeometryEditor extends StatefulWidget {
  /// The shared drawing state.
  final DrawingState drawingState;

  /// Measurement state (optional).
  final GmMeasurementState? measurementState;

  /// Initial camera position.
  final gm.CameraPosition initialCameraPosition;

  /// Map type (normal, satellite, hybrid, terrain).
  final gm.MapType mapType;

  /// Whether to show the toolbar.
  final bool showToolbar;

  /// Whether to show the info panel for selected shapes.
  final bool showInfoPanel;

  /// Toolbar position alignment.
  final Alignment toolbarAlignment;

  /// Info panel position alignment.
  final Alignment infoPanelAlignment;

  /// Available drawing modes for the toolbar.
  final List<DrawingMode>? toolbarModes;

  /// Additional polygons to render.
  final Set<gm.Polygon> additionalPolygons;

  /// Additional polylines to render.
  final Set<gm.Polyline> additionalPolylines;

  /// Additional circles to render.
  final Set<gm.Circle> additionalCircles;

  /// Additional markers to render.
  final Set<gm.Marker> additionalMarkers;

  /// Callback when the map is created.
  final void Function(gm.GoogleMapController)? onMapCreated;

  /// Callback when the camera moves.
  final void Function(gm.CameraPosition)? onCameraMove;

  /// Style override for selected shapes.
  final ShapeStyle? selectedStyle;

  /// Whether freehand drawing closes as polygon.
  final bool freehandCloseAsPolygon;

  /// Whether to show my-location button.
  final bool myLocationButtonEnabled;

  /// Whether to show my-location layer.
  final bool myLocationEnabled;

  /// Whether to show compass.
  final bool compassEnabled;

  /// Whether to show map toolbar.
  final bool mapToolbarEnabled;

  /// Minimum zoom level.
  final gm.MinMaxZoomPreference zoomPreference;

  const GoogleMapGeometryEditor({
    super.key,
    required this.drawingState,
    this.measurementState,
    required this.initialCameraPosition,
    this.mapType = gm.MapType.normal,
    this.showToolbar = true,
    this.showInfoPanel = true,
    this.toolbarAlignment = Alignment.centerLeft,
    this.infoPanelAlignment = Alignment.topRight,
    this.toolbarModes,
    this.additionalPolygons = const {},
    this.additionalPolylines = const {},
    this.additionalCircles = const {},
    this.additionalMarkers = const {},
    this.onMapCreated,
    this.onCameraMove,
    this.selectedStyle,
    this.freehandCloseAsPolygon = true,
    this.myLocationButtonEnabled = false,
    this.myLocationEnabled = false,
    this.compassEnabled = true,
    this.mapToolbarEnabled = false,
    this.zoomPreference = gm.MinMaxZoomPreference.unbounded,
  });

  @override
  State<GoogleMapGeometryEditor> createState() =>
      _GoogleMapGeometryEditorState();
}

class _GoogleMapGeometryEditorState extends State<GoogleMapGeometryEditor> {
  late final GmDrawingController _controller;
  late final GmShapeRenderer _renderer;

  @override
  void initState() {
    super.initState();
    _controller = GmDrawingController(
      drawingState: widget.drawingState,
      freehandCloseAsPolygon: widget.freehandCloseAsPolygon,
    );
    _renderer = GmShapeRenderer(
      drawingState: widget.drawingState,
      selectedStyle: widget.selectedStyle,
      onShapeTap: (id) {
        if (widget.drawingState.activeMode == DrawingMode.select) {
          widget.drawingState.selectShape(id);
        }
      },
    );
    _controller.addListener(_onChanged);
    widget.drawingState.addListener(_onChanged);
    widget.measurementState?.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(GoogleMapGeometryEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.drawingState != widget.drawingState) {
      oldWidget.drawingState.removeListener(_onChanged);
      widget.drawingState.addListener(_onChanged);
    }
    if (oldWidget.measurementState != widget.measurementState) {
      oldWidget.measurementState?.removeListener(_onChanged);
      widget.measurementState?.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    widget.drawingState.removeListener(_onChanged);
    widget.measurementState?.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _onMapCreated(gm.GoogleMapController gmController) {
    _controller.onMapCreated(gmController);
    widget.onMapCreated?.call(gmController);
  }

  void _onTap(gm.LatLng point) {
    final mode = widget.drawingState.activeMode;
    if (mode == DrawingMode.measure) {
      widget.measurementState?.addPoint(point.toCore());
    } else {
      _controller.handleTap(point);
    }
  }

  void _onLongPress(gm.LatLng point) {
    _controller.handleLongPress(point);
  }

  void _onCameraMove(gm.CameraPosition position) {
    widget.onCameraMove?.call(position);
    _controller.onCameraChanged();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.drawingState;
    final mode = state.activeMode;
    final lockGestures = state.shouldAbsorbMapGestures;

    // Build shape sets
    final polygons = {...widget.additionalPolygons, ..._renderer.polygons};
    final polylines = {...widget.additionalPolylines, ..._renderer.polylines};
    final circles = {...widget.additionalCircles, ..._renderer.circles};

    // Drawing preview
    final isPolygonLike = mode == DrawingMode.polygon ||
        mode == DrawingMode.rectangle ||
        mode == DrawingMode.hole;
    polylines.addAll(_renderer.buildDrawingPreview(closed: isPolygonLike));

    // Circle preview
    circles.addAll(
      _renderer.buildCirclePreview(
        radiusMeters: _controller.circlePreviewRadius,
      ),
    );

    // Measurement polyline
    if (widget.measurementState != null) {
      polylines.addAll(
        GmMeasurementOverlay.buildMeasurementPolyline(
            widget.measurementState!),
      );
    }

    return Stack(
      children: [
        gm.GoogleMap(
          initialCameraPosition: widget.initialCameraPosition,
          mapType: widget.mapType,
          onMapCreated: _onMapCreated,
          onTap: mode != DrawingMode.freehand ? _onTap : null,
          onLongPress: _onLongPress,
          onCameraMove: _onCameraMove,
          polygons: polygons,
          polylines: polylines,
          circles: circles,
          markers: widget.additionalMarkers,
          scrollGesturesEnabled: !lockGestures,
          zoomGesturesEnabled: !lockGestures,
          rotateGesturesEnabled: !lockGestures,
          tiltGesturesEnabled: !lockGestures,
          myLocationButtonEnabled: widget.myLocationButtonEnabled,
          myLocationEnabled: widget.myLocationEnabled,
          compassEnabled: widget.compassEnabled,
          mapToolbarEnabled: widget.mapToolbarEnabled,
          minMaxZoomPreference: widget.zoomPreference,
        ),

        // Freehand overlay
        if (mode == DrawingMode.freehand)
          GmFreehandOverlay(
            controller: _controller,
            closeAsPolygon: widget.freehandCloseAsPolygon,
          ),

        // Vertex editing overlay
        if (state.selectedShape != null && !state.isDrawing)
          GmVertexOverlay(controller: _controller),

        // Shape dragger overlay
        if (state.selectedShape != null &&
            !state.isDrawing &&
            mode == DrawingMode.select)
          GmShapeDragger(controller: _controller),

        // Measurement labels overlay
        if (widget.measurementState != null &&
            widget.measurementState!.pointCount >= 2)
          GmMeasurementOverlay(
            measurementState: widget.measurementState!,
            controller: _controller,
          ),

        // Toolbar
        if (widget.showToolbar)
          Align(
            alignment: widget.toolbarAlignment,
            child: DrawingToolbar(
              drawingState: state,
              modes: widget.toolbarModes,
            ),
          ),

        // Info panel
        if (widget.showInfoPanel)
          Align(
            alignment: widget.infoPanelAlignment,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: ShapeInfoPanel(drawingState: state),
            ),
          ),
      ],
    );
  }
}

