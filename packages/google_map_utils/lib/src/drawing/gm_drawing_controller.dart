import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';
import 'package:map_utils_core/map_utils_core.dart';

import 'package:google_map_utils/src/gm_extensions.dart';

/// Central controller for Google Maps drawing operations.
///
/// Wraps [DrawingState] and [gm.GoogleMapController] to handle coordinate
/// conversion, tap routing, and mode-based behavior.
///
/// ```dart
/// final controller = GmDrawingController(drawingState: state);
///
/// // After GoogleMap.onMapCreated:
/// controller.onMapCreated(gmController);
///
/// // Wire into GoogleMap callbacks:
/// GoogleMap(
///   onTap: controller.handleTap,
///   onLongPress: controller.handleLongPress,
/// )
/// ```
class GmDrawingController extends ChangeNotifier {
  final DrawingState drawingState;

  /// Google Maps controller (set after map creation).
  gm.GoogleMapController? _mapController;

  /// Haversine distance calculator.
  static const Distance _haversine = Distance();

  /// Callback when drawing finishes (shape committed).
  final VoidCallback? onDrawingComplete;

  /// Preview radius during circle drawing (meters).
  double? _circlePreviewRadius;

  /// Whether freehand close as polygon.
  final bool freehandCloseAsPolygon;

  GmDrawingController({
    required this.drawingState,
    this.onDrawingComplete,
    this.freehandCloseAsPolygon = true,
  }) {
    drawingState.addListener(_onStateChanged);
  }

  /// The Google Maps controller.
  gm.GoogleMapController? get mapController => _mapController;

  /// Circle preview radius in meters (during circle drawing).
  double? get circlePreviewRadius => _circlePreviewRadius;

  /// Set the map controller (call from [gm.GoogleMap.onMapCreated]).
  void onMapCreated(gm.GoogleMapController controller) {
    _mapController = controller;
    notifyListeners();
  }

  void _onStateChanged() => notifyListeners();

  /// Route a map tap to the active drawing tool.
  void handleTap(gm.LatLng gmPoint) {
    final point = gmPoint.toCore();
    final state = drawingState;

    switch (state.activeMode) {
      case DrawingMode.polygon:
        state.addDrawingPoint(point);
      case DrawingMode.polyline:
        state.addDrawingPoint(point);
      case DrawingMode.rectangle:
        _handleRectangleTap(point);
      case DrawingMode.circle:
        _handleCircleTap(point);
      case DrawingMode.freehand:
        break; // Handled by GmFreehandOverlay
      case DrawingMode.hole:
        state.addDrawingPoint(point);
      case DrawingMode.measure:
        state.addDrawingPoint(point);
      case DrawingMode.select:
        _handleSelectionTap(point);
      case DrawingMode.none:
        break;
    }
  }

  /// Handle a long press to finish the current drawing.
  void handleLongPress(gm.LatLng gmPoint) {
    if (drawingState.isDrawing) finishDrawing();
  }

  /// Finish the active drawing operation.
  void finishDrawing() {
    final state = drawingState;
    switch (state.activeMode) {
      case DrawingMode.polygon:
      case DrawingMode.polyline:
      case DrawingMode.rectangle:
      case DrawingMode.freehand:
        final shape = state.finishDrawing();
        if (shape != null) onDrawingComplete?.call();
      case DrawingMode.circle:
        _finishCircle();
      case DrawingMode.hole:
        state.finishHoleDrawing();
      default:
        break;
    }
  }

  /// Cancel the active drawing.
  void cancelDrawing() {
    _circlePreviewRadius = null;
    drawingState.cancelDrawing();
  }

  // -- Selection --

  void _handleSelectionTap(LatLng point) {
    final hitId = SelectionUtils.findClosestShape(
      point,
      drawingState.shapes,
      toleranceMeters: 20.0,
    );
    if (hitId != null) {
      drawingState.selectShape(hitId);
    } else {
      drawingState.clearSelection();
    }
  }

  // -- Rectangle --

  void _handleRectangleTap(LatLng point) {
    if (drawingState.drawingPoints.isEmpty) {
      drawingState.addDrawingPoint(point);
    } else {
      drawingState.addDrawingPoint(point);
      finishDrawing();
    }
  }

  // -- Circle --

  void _handleCircleTap(LatLng point) {
    if (drawingState.circleCenter == null) {
      drawingState.setCircleCenter(point);
    } else {
      final radius = _haversine.distance(drawingState.circleCenter!, point);
      if (radius > 0) {
        final shape = drawingState.finishCircleDrawing(radius);
        _circlePreviewRadius = null;
        if (shape != null) onDrawingComplete?.call();
      }
    }
  }

  void _finishCircle() {
    if (drawingState.circleCenter != null && _circlePreviewRadius != null) {
      final shape =
          drawingState.finishCircleDrawing(_circlePreviewRadius!);
      _circlePreviewRadius = null;
      if (shape != null) onDrawingComplete?.call();
    }
  }

  /// Update circle preview radius (call from camera move or hover).
  void updateCirclePreview(gm.LatLng gmPoint) {
    if (drawingState.activeMode == DrawingMode.circle &&
        drawingState.circleCenter != null) {
      _circlePreviewRadius =
          _haversine.distance(drawingState.circleCenter!, gmPoint.toCore());
      notifyListeners();
    }
  }

  /// Convert a screen coordinate to LatLng (async).
  Future<LatLng?> screenToLatLng(Offset screenPoint) async {
    if (_mapController == null) return null;
    final gmLatLng = await _mapController!.getLatLng(
      gm.ScreenCoordinate(
        x: screenPoint.dx.round(),
        y: screenPoint.dy.round(),
      ),
    );
    return gmLatLng.toCore();
  }

  /// Convert a LatLng to screen coordinate (async).
  Future<Offset?> latLngToScreen(LatLng point) async {
    if (_mapController == null) return null;
    final screenCoord =
        await _mapController!.getScreenCoordinate(point.toGm());
    return Offset(screenCoord.x.toDouble(), screenCoord.y.toDouble());
  }

  /// Notify listeners that the camera or state has changed.
  ///
  /// Call this from [gm.GoogleMap.onCameraMove] to keep overlays in sync.
  void onCameraChanged() => notifyListeners();

  @override
  void dispose() {
    drawingState.removeListener(_onStateChanged);
    super.dispose();
  }
}
