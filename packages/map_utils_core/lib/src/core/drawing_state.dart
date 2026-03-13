import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import 'package:map_utils_core/src/core/drawing_mode.dart';
import 'package:map_utils_core/src/core/shape_model.dart';
import 'package:map_utils_core/src/core/shape_style.dart';
import 'package:map_utils_core/src/core/undo_redo_manager.dart';

const _uuid = Uuid();

/// Central state manager for the drawing/editing system.
///
/// Holds all shapes, selection state, active tool mode, and undo/redo history.
/// Built as a [ChangeNotifier] so it works with any state management approach
/// (Provider, Riverpod, Bloc, or plain ValueListenableBuilder).
///
/// ```dart
/// final state = DrawingState();
/// state.addListener(() => setState(() {}));
/// ```
class DrawingState extends ChangeNotifier {
  final List<DrawableShape> _shapes = [];
  String? _selectedShapeId;
  DrawingMode _activeMode = DrawingMode.none;
  bool _snappingEnabled = false;

  /// Points currently being drawn (before shape is finalized).
  final List<LatLng> _drawingPoints = [];

  /// Center point for circle drawing.
  LatLng? _circleCenter;

  /// The undo/redo manager for this state.
  final UndoRedoManager undoRedo;

  /// Default style applied to new shapes.
  ShapeStyle defaultStyle;

  DrawingState({
    int maxHistoryDepth = 100,
    this.defaultStyle = ShapeStylePresets.defaultWithStates,
  }) : undoRedo = UndoRedoManager(maxHistoryDepth: maxHistoryDepth);

  // -- Getters --

  /// All shapes in the current state.
  List<DrawableShape> get shapes => List.unmodifiable(_shapes);

  /// The currently selected shape, or null.
  DrawableShape? get selectedShape {
    if (_selectedShapeId == null) return null;
    final index = _shapes.indexWhere((s) => s.id == _selectedShapeId);
    return index >= 0 ? _shapes[index] : null;
  }

  /// The ID of the selected shape.
  String? get selectedShapeId => _selectedShapeId;

  /// The active drawing/editing mode.
  DrawingMode get activeMode => _activeMode;

  /// Whether snapping is enabled.
  bool get snappingEnabled => _snappingEnabled;

  /// Whether the system is in a drawing mode (not select/none).
  bool get isDrawing => switch (_activeMode) {
        DrawingMode.none || DrawingMode.select => false,
        _ => true,
      };

  /// Whether map gestures should be suppressed (during drawing/editing).
  bool get shouldAbsorbMapGestures => isDrawing || _isDraggingShape;

  bool _isDraggingShape = false;

  /// Points being drawn (live preview).
  List<LatLng> get drawingPoints => List.unmodifiable(_drawingPoints);

  /// Circle center during circle drawing.
  LatLng? get circleCenter => _circleCenter;

  /// Can undo.
  bool get canUndo => undoRedo.canUndo;

  /// Can redo.
  bool get canRedo => undoRedo.canRedo;

  // -- Mode management --

  /// Set the active mode.
  void setMode(DrawingMode mode) {
    if (_activeMode == mode) return;
    // Cancel any in-progress drawing when switching modes.
    cancelDrawing();
    _activeMode = mode;
    if (mode != DrawingMode.select) {
      _selectedShapeId = null;
    }
    notifyListeners();
  }

  // -- Drawing lifecycle --

  /// Add a point during drawing.
  void addDrawingPoint(LatLng point) {
    _drawingPoints.add(point);
    notifyListeners();
  }

  /// Remove the last drawing point (undo during draw).
  void undoDrawingPoint() {
    if (_drawingPoints.isNotEmpty) {
      _drawingPoints.removeLast();
      notifyListeners();
    }
  }

  /// Set circle center during circle drawing.
  void setCircleCenter(LatLng center) {
    _circleCenter = center;
    notifyListeners();
  }

  /// Finish drawing and create a shape from the current points.
  ///
  /// Returns the created shape, or `null` if insufficient points.
  DrawableShape? finishDrawing({ShapeStyle? style}) {
    final effectiveStyle = style ?? defaultStyle;
    DrawableShape? shape;

    switch (_activeMode) {
      case DrawingMode.polygon:
      case DrawingMode.freehand:
        if (_drawingPoints.length >= 3) {
          shape = DrawablePolygon(
            id: _uuid.v4(),
            points: List.of(_drawingPoints),
            style: effectiveStyle,
          );
        }
      case DrawingMode.polyline:
        if (_drawingPoints.length >= 2) {
          shape = DrawablePolyline(
            id: _uuid.v4(),
            points: List.of(_drawingPoints),
            style: effectiveStyle,
          );
        }
      case DrawingMode.rectangle:
        if (_drawingPoints.length >= 2) {
          shape = DrawableRectangle.fromCorners(
            id: _uuid.v4(),
            corner1: _drawingPoints.first,
            corner2: _drawingPoints.last,
            style: effectiveStyle,
          );
        }
      case DrawingMode.circle:
        // Circle is finalized via finishCircleDrawing.
        break;
      case DrawingMode.measure:
      case DrawingMode.hole:
      case DrawingMode.none:
      case DrawingMode.select:
        break;
    }

    if (shape != null) {
      _executeAdd(shape);
      _drawingPoints.clear();
      notifyListeners();
    }
    return shape;
  }

  /// Finish circle drawing with a specific radius.
  DrawableShape? finishCircleDrawing(double radiusMeters,
      {ShapeStyle? style}) {
    if (_circleCenter == null || radiusMeters <= 0) return null;
    final effectiveStyle = style ?? defaultStyle;

    final shape = DrawableCircle(
      id: _uuid.v4(),
      center: _circleCenter!,
      radiusMeters: radiusMeters,
      style: effectiveStyle,
    );
    _executeAdd(shape);
    _circleCenter = null;
    _drawingPoints.clear();
    notifyListeners();
    return shape;
  }

  /// Finish drawing a hole and add it to the selected polygon.
  bool finishHoleDrawing() {
    if (_drawingPoints.length < 3) return false;
    final selected = selectedShape;
    if (selected is! DrawablePolygon) return false;

    final updated = selected.copyWith(
      holes: [...selected.holes, List.of(_drawingPoints)],
    );
    _executeUpdate(selected, updated);
    _drawingPoints.clear();
    notifyListeners();
    return true;
  }

  /// Cancel the current drawing and discard points.
  void cancelDrawing() {
    _drawingPoints.clear();
    _circleCenter = null;
    notifyListeners();
  }

  // -- Shape CRUD --

  /// Add a shape (with undo support).
  void addShape(DrawableShape shape) {
    _executeAdd(shape);
    notifyListeners();
  }

  /// Remove a shape by ID (with undo support).
  void removeShape(String id) {
    final index = _shapes.indexWhere((s) => s.id == id);
    if (index < 0) return;
    final shape = _shapes[index];
    undoRedo
        .execute(RemoveShapeCommand(shapes: _shapes, shape: shape));
    if (_selectedShapeId == id) _selectedShapeId = null;
    notifyListeners();
  }

  /// Remove the currently selected shape.
  void removeSelected() {
    if (_selectedShapeId != null) removeShape(_selectedShapeId!);
  }

  /// Update a shape (replace old with new, with undo support).
  void updateShape(DrawableShape oldShape, DrawableShape newShape) {
    _executeUpdate(oldShape, newShape);
    notifyListeners();
  }

  /// Duplicate the selected shape with a small offset.
  DrawableShape? duplicateSelected({
    double latOffset = 0.0005,
    double lngOffset = 0.0005,
  }) {
    final selected = selectedShape;
    if (selected == null) return null;
    final newId = _uuid.v4();

    final DrawableShape copy;
    switch (selected) {
      case final DrawablePolygon s:
        copy = s.copyWith(
          id: newId,
          points: s.points
              .map((p) => LatLng(
                  p.latitude + latOffset, p.longitude + lngOffset))
              .toList(),
          holes: s.holes
              .map((h) => h
                  .map((p) => LatLng(
                      p.latitude + latOffset, p.longitude + lngOffset))
                  .toList())
              .toList(),
        );
      case final DrawablePolyline s:
        copy = s.copyWith(
          id: newId,
          points: s.points
              .map((p) => LatLng(
                  p.latitude + latOffset, p.longitude + lngOffset))
              .toList(),
        );
      case final DrawableCircle s:
        copy = s.copyWith(
          id: newId,
          center: LatLng(s.center.latitude + latOffset,
              s.center.longitude + lngOffset),
        );
      case final DrawableRectangle s:
        copy = s.copyWith(
          id: newId,
          points: s.points
              .map((p) => LatLng(
                  p.latitude + latOffset, p.longitude + lngOffset))
              .toList(),
        );
    }
    _executeAdd(copy);
    _selectedShapeId = copy.id;
    notifyListeners();
    return copy;
  }

  // -- Selection --

  /// Select a shape by ID (or null to deselect).
  void selectShape(String? id) {
    if (_selectedShapeId == id) return;
    _selectedShapeId = id;
    notifyListeners();
  }

  /// Clear selection.
  void clearSelection() => selectShape(null);

  // -- Snapping --

  /// Enable or disable snapping.
  void setSnapping(bool enabled) {
    if (_snappingEnabled == enabled) return;
    _snappingEnabled = enabled;
    notifyListeners();
  }

  // -- Dragging state --

  /// Begin a shape drag (suppresses map gestures).
  void beginShapeDrag() {
    _isDraggingShape = true;
    notifyListeners();
  }

  /// End a shape drag.
  void endShapeDrag() {
    _isDraggingShape = false;
    notifyListeners();
  }

  // -- Undo/Redo --

  /// Undo the last command.
  void undo() {
    if (undoRedo.undo() != null) notifyListeners();
  }

  /// Redo the last undone command.
  void redo() {
    if (undoRedo.redo() != null) notifyListeners();
  }

  // -- Serialization --

  /// Export all shapes to JSON.
  List<Map<String, dynamic>> shapesToJson() =>
      _shapes.map((s) => s.toJson()).toList();

  /// Load shapes from JSON, replacing current state.
  void loadShapesFromJson(List<dynamic> json) {
    _shapes.clear();
    _selectedShapeId = null;
    undoRedo.clear();
    for (final item in json) {
      _shapes.add(
          DrawableShape.fromJson(item as Map<String, dynamic>));
    }
    notifyListeners();
  }

  /// Clear everything.
  void clearAll() {
    _shapes.clear();
    _selectedShapeId = null;
    _drawingPoints.clear();
    _circleCenter = null;
    undoRedo.clear();
    _activeMode = DrawingMode.none;
    notifyListeners();
  }

  // -- Internal --

  void _executeAdd(DrawableShape shape) {
    undoRedo
        .execute(AddShapeCommand(shapes: _shapes, shape: shape));
  }

  void _executeUpdate(
      DrawableShape oldShape, DrawableShape newShape) {
    undoRedo.execute(UpdateShapeCommand(
      shapes: _shapes,
      oldShape: oldShape,
      newShape: newShape,
      matcher: (a, b) => a.id == b.id,
    ));
  }
}
