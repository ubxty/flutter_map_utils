import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_utils_core/map_utils_core.dart';

import 'package:flutter_map_utils/src/editing/editable_shape_layer.dart';
import 'package:flutter_map_utils/src/layers/drawing_layer.dart';
import 'package:flutter_map_utils/src/measurement/measurement_tool.dart';
import 'package:flutter_map_utils/src/selection/selection_layer.dart';
import 'package:flutter_map_utils/src/ui/coordinate_display.dart';
import 'package:flutter_map_utils/src/ui/drawing_toolbar.dart';
import 'package:flutter_map_utils/src/ui/shape_info_panel.dart';

/// All-in-one wrapper that layers drawing, editing, selection,
/// measurement, toolbar, and info panel on a [FlutterMap].
///
/// ```dart
/// FlutterMapGeometryEditor(
///   drawingState: myDrawingState,
///   measurementState: myMeasurementState,
///   mapOptions: MapOptions(initialCenter: LatLng(0, 0), initialZoom: 12),
///   tileLayer: TileLayer(urlTemplate: '...'),
/// )
/// ```
class FlutterMapGeometryEditor extends StatefulWidget {
  /// The shared drawing state.
  final DrawingState drawingState;

  /// Measurement state (optional — only if measurement is needed).
  final MeasurementState? measurementState;

  /// Map options. [onTap] and [onSecondaryTap] are wired automatically.
  final MapOptions mapOptions;

  /// The tile layer to display.
  final TileLayer tileLayer;

  /// Additional map children to render below the drawing layers.
  final List<Widget> additionalLayers;

  /// Whether to show the toolbar.
  final bool showToolbar;

  /// Whether to show the info panel for selected shapes.
  final bool showInfoPanel;

  /// Whether to show coordinate display.
  final bool showCoordinateDisplay;

  /// Toolbar position alignment.
  final Alignment toolbarAlignment;

  /// Info panel position alignment.
  final Alignment infoPanelAlignment;

  /// Coordinate display alignment.
  final Alignment coordinateDisplayAlignment;

  /// Available drawing modes for the toolbar.
  final List<DrawingMode>? toolbarModes;

  const FlutterMapGeometryEditor({
    super.key,
    required this.drawingState,
    this.measurementState,
    required this.mapOptions,
    required this.tileLayer,
    this.additionalLayers = const [],
    this.showToolbar = true,
    this.showInfoPanel = true,
    this.showCoordinateDisplay = true,
    this.toolbarAlignment = Alignment.centerLeft,
    this.infoPanelAlignment = Alignment.topRight,
    this.coordinateDisplayAlignment = Alignment.bottomCenter,
    this.toolbarModes,
  });

  @override
  State<FlutterMapGeometryEditor> createState() =>
      _FlutterMapGeometryEditorState();
}

class _FlutterMapGeometryEditorState extends State<FlutterMapGeometryEditor> {
  final GlobalKey<DrawingLayerState> _drawingLayerKey = GlobalKey();
  final GlobalKey<CoordinateDisplayState> _coordKey = GlobalKey();
  late final SelectionLayer _selectionLayer;

  @override
  void initState() {
    super.initState();
    _selectionLayer = SelectionLayer(drawingState: widget.drawingState);
    widget.drawingState.addListener(_onDrawingStateChanged);
  }

  @override
  void didUpdateWidget(FlutterMapGeometryEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.drawingState != widget.drawingState) {
      oldWidget.drawingState.removeListener(_onDrawingStateChanged);
      widget.drawingState.addListener(_onDrawingStateChanged);
    }
  }

  @override
  void dispose() {
    widget.drawingState.removeListener(_onDrawingStateChanged);
    super.dispose();
  }

  void _onDrawingStateChanged() {
    if (mounted) setState(() {});
  }

  void _handleTap(TapPosition tapPosition, LatLng point) {
    // Forward to user callback first
    widget.mapOptions.onTap?.call(tapPosition, point);

    final mode = widget.drawingState.activeMode;

    if (mode == DrawingMode.select) {
      _selectionLayer.handleTap(point);
    } else if (mode == DrawingMode.measure) {
      widget.measurementState?.addPoint(point);
    } else {
      _drawingLayerKey.currentState?.handleTap(point);
    }
  }

  void _handleSecondaryTap(TapPosition tapPosition, LatLng point) {
    widget.mapOptions.onSecondaryTap?.call(tapPosition, point);
    _drawingLayerKey.currentState?.handleSecondaryTap(point);
  }

  void _handleLongPress(TapPosition tapPosition, LatLng point) {
    widget.mapOptions.onLongPress?.call(tapPosition, point);
    _drawingLayerKey.currentState?.handleLongPress(point);
  }

  void _handlePointerHover(PointerHoverEvent event, LatLng point) {
    widget.mapOptions.onPointerHover?.call(event, point);
    _drawingLayerKey.currentState?.handlePointerHover(point);
    _coordKey.currentState?.updatePosition(point);
  }

  @override
  Widget build(BuildContext context) {
    // Lock map gestures during drawing/editing
    final interactionOptions = widget.drawingState.shouldAbsorbMapGestures
        ? InteractionOptions(
            flags: InteractiveFlag.none,
            cursorKeyboardRotationOptions:
                widget.mapOptions.interactionOptions.cursorKeyboardRotationOptions,
          )
        : widget.mapOptions.interactionOptions;

    // Build map options with our handlers wired in
    final options = MapOptions(
      initialCenter: widget.mapOptions.initialCenter,
      initialZoom: widget.mapOptions.initialZoom,
      minZoom: widget.mapOptions.minZoom,
      maxZoom: widget.mapOptions.maxZoom,
      initialRotation: widget.mapOptions.initialRotation,
      interactionOptions: interactionOptions,
      cameraConstraint: widget.mapOptions.cameraConstraint,
      onTap: _handleTap,
      onSecondaryTap: _handleSecondaryTap,
      onLongPress: _handleLongPress,
      onPointerHover: _handlePointerHover,
      onMapReady: widget.mapOptions.onMapReady,
      onPositionChanged: widget.mapOptions.onPositionChanged,
      onMapEvent: widget.mapOptions.onMapEvent,
    );

    return Stack(
      children: [
        FlutterMap(
          options: options,
          children: [
            widget.tileLayer,
            ...widget.additionalLayers,
            DrawingLayer(
              key: _drawingLayerKey,
              drawingState: widget.drawingState,
            ),
            EditableShapeLayer(drawingState: widget.drawingState),
            if (widget.measurementState != null)
              MeasurementLayer(
                measurementState: widget.measurementState!,
              ),
          ],
        ),
        // Toolbar overlay
        if (widget.showToolbar)
          Align(
            alignment: widget.toolbarAlignment,
            child: DrawingToolbar(
              drawingState: widget.drawingState,
              modes: widget.toolbarModes,
            ),
          ),
        // Info panel overlay
        if (widget.showInfoPanel)
          Align(
            alignment: widget.infoPanelAlignment,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: ShapeInfoPanel(drawingState: widget.drawingState),
            ),
          ),
        // Coordinate display
        if (widget.showCoordinateDisplay)
          Align(
            alignment: widget.coordinateDisplayAlignment,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CoordinateDisplay(key: _coordKey),
            ),
          ),
      ],
    );
  }
}
