import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_utils_core/map_utils_core.dart';

void main() {
  group('ShapeStyle', () {
    test('resolve returns base style when not selected or hovered', () {
      final style = ShapeStylePresets.zone;
      final resolved = style.resolve();
      expect(resolved.fillColor, style.fillColor);
      expect(resolved.borderColor, style.borderColor);
    });

    test('resolve returns selected override when selected', () {
      final style = ShapeStylePresets.defaultWithStates;
      final resolved = style.resolve(selected: true);
      expect(resolved.borderColor, ShapeStylePresets.selected.borderColor);
    });

    test('resolve returns hover override when hovered', () {
      final style = ShapeStylePresets.defaultWithStates;
      final resolved = style.resolve(hovered: true);
      expect(resolved.fillOpacity, ShapeStylePresets.hover.fillOpacity);
    });

    test('toJson and fromJson roundtrip', () {
      final style = ShapeStylePresets.zone;
      final json = style.toJson();
      final restored = ShapeStyle.fromJson(json);
      expect(restored.fillColor, style.fillColor);
      expect(restored.borderColor, style.borderColor);
      expect(restored.borderWidth, style.borderWidth);
    });

    test('copyWith overrides specified fields', () {
      final style = ShapeStylePresets.zone;
      final copy = style.copyWith(borderWidth: 5.0);
      expect(copy.borderWidth, 5.0);
      expect(copy.fillColor, style.fillColor);
    });

    test('effectiveFillColor applies opacity', () {
      const style = ShapeStyle(fillOpacity: 0.5);
      final effective = style.effectiveFillColor;
      expect(effective.a, closeTo(0.5, 0.01));
    });
  });

  group('DrawableShape', () {
    test('DrawablePolygon allPoints returns points', () {
      final poly = DrawablePolygon(
        id: 'p1',
        points: [LatLng(0, 0), LatLng(1, 0), LatLng(1, 1)],
        style: ShapeStylePresets.zone,
      );
      expect(poly.allPoints.length, 3);
      expect(poly.type, ShapeType.polygon);
    });

    test('DrawablePolygon copyWith preserves id', () {
      final poly = DrawablePolygon(
        id: 'p2',
        points: [LatLng(0, 0), LatLng(1, 0), LatLng(1, 1)],
        style: ShapeStylePresets.zone,
      );
      final copy = poly.copyWith(
        points: [LatLng(2, 2), LatLng(3, 3), LatLng(4, 4)],
      );
      expect(copy.id, poly.id);
      expect(copy.points.first.latitude, 2);
    });

    test('DrawablePolygon with holes', () {
      final poly = DrawablePolygon(
        id: 'ph1',
        points: [LatLng(0, 0), LatLng(0, 10), LatLng(10, 10), LatLng(10, 0)],
        holes: [
          [LatLng(2, 2), LatLng(2, 4), LatLng(4, 4), LatLng(4, 2)],
        ],
      );
      expect(poly.holes.length, 1);
      final copy = poly.copyWith(holes: []);
      expect(copy.holes.isEmpty, true);
    });

    test('DrawableCircle allPoints returns center', () {
      final circle = DrawableCircle(
        id: 'c1',
        center: LatLng(10, 20),
        radiusMeters: 500,
        style: ShapeStylePresets.zone,
      );
      expect(circle.allPoints.length, 1);
      expect(circle.allPoints.first, LatLng(10, 20));
      expect(circle.type, ShapeType.circle);
    });

    test('DrawableCircle copyWith', () {
      final circle = DrawableCircle(
        id: 'cc1',
        center: LatLng(10, 20),
        radiusMeters: 500,
      );
      final copy = circle.copyWith(radiusMeters: 1000);
      expect(copy.radiusMeters, 1000);
      expect(copy.center, circle.center);
    });

    test('DrawableRectangle fromCorners creates 4 points', () {
      final rect = DrawableRectangle.fromCorners(
        id: 'r1',
        corner1: LatLng(0, 0),
        corner2: LatLng(1, 1),
        style: ShapeStylePresets.zone,
      );
      expect(rect.points.length, 4);
      expect(rect.type, ShapeType.rectangle);
    });

    test('DrawablePolyline basics', () {
      final line = DrawablePolyline(
        id: 'l0',
        points: [LatLng(0, 0), LatLng(1, 1)],
      );
      expect(line.type, ShapeType.polyline);
      expect(line.allPoints.length, 2);
      final copy = line.copyWith(points: [LatLng(2, 2), LatLng(3, 3)]);
      expect(copy.points.first.latitude, 2);
    });

    test('toJson and fromJson roundtrip for polygon', () {
      final poly = DrawablePolygon(
        id: 'p3',
        points: [LatLng(0, 0), LatLng(1, 0), LatLng(1, 1)],
        style: ShapeStylePresets.zone,
        metadata: {'name': 'Test'},
      );
      final json = poly.toJson();
      final restored = DrawableShape.fromJson(json);
      expect(restored, isA<DrawablePolygon>());
      expect((restored as DrawablePolygon).points.length, 3);
      expect(restored.metadata['name'], 'Test');
    });

    test('toJson and fromJson roundtrip for circle', () {
      final circle = DrawableCircle(
        id: 'c2',
        center: LatLng(10, 20),
        radiusMeters: 500,
        style: ShapeStylePresets.zone,
      );
      final json = circle.toJson();
      final restored = DrawableShape.fromJson(json);
      expect(restored, isA<DrawableCircle>());
      expect((restored as DrawableCircle).radiusMeters, 500);
    });

    test('toJson and fromJson roundtrip for polyline', () {
      final line = DrawablePolyline(
        id: 'l1',
        points: [LatLng(0, 0), LatLng(1, 1)],
        style: ShapeStylePresets.route,
      );
      final json = line.toJson();
      final restored = DrawableShape.fromJson(json);
      expect(restored, isA<DrawablePolyline>());
      expect((restored as DrawablePolyline).points.length, 2);
    });

    test('toJson and fromJson roundtrip for rectangle', () {
      final rect = DrawableRectangle.fromCorners(
        id: 'r2',
        corner1: LatLng(0, 0),
        corner2: LatLng(1, 1),
      );
      final json = rect.toJson();
      final restored = DrawableShape.fromJson(json);
      expect(restored, isA<DrawableRectangle>());
      expect((restored as DrawableRectangle).points.length, 4);
    });
  });

  group('UndoRedoManager', () {
    test('execute adds to undo stack', () {
      final shapes = <DrawableShape>[];
      final mgr = UndoRedoManager();
      final shape = DrawablePolygon(
        id: 'u1',
        points: [LatLng(0, 0), LatLng(1, 0), LatLng(1, 1)],
      );
      mgr.execute(AddShapeCommand(shapes: shapes, shape: shape));
      expect(shapes.length, 1);
      expect(mgr.canUndo, true);
      expect(mgr.canRedo, false);
    });

    test('undo reverses the last command', () {
      final shapes = <DrawableShape>[];
      final mgr = UndoRedoManager();
      final shape = DrawablePolygon(
        id: 'u2',
        points: [LatLng(0, 0), LatLng(1, 0), LatLng(1, 1)],
      );
      mgr.execute(AddShapeCommand(shapes: shapes, shape: shape));
      mgr.undo();
      expect(shapes.isEmpty, true);
      expect(mgr.canUndo, false);
      expect(mgr.canRedo, true);
    });

    test('redo re-applies the undone command', () {
      final shapes = <DrawableShape>[];
      final mgr = UndoRedoManager();
      final shape = DrawablePolygon(
        id: 'u3',
        points: [LatLng(0, 0), LatLng(1, 0), LatLng(1, 1)],
      );
      mgr.execute(AddShapeCommand(shapes: shapes, shape: shape));
      mgr.undo();
      mgr.redo();
      expect(shapes.length, 1);
    });

    test('RemoveShapeCommand preserves index on undo', () {
      final shapes = <DrawableShape>[];
      final mgr = UndoRedoManager();
      final s1 = DrawablePolygon(
        id: 'u4a',
        points: [LatLng(0, 0), LatLng(1, 0), LatLng(1, 1)],
      );
      final s2 = DrawablePolyline(
        id: 'u4b',
        points: [LatLng(2, 2), LatLng(3, 3)],
      );
      mgr.execute(AddShapeCommand(shapes: shapes, shape: s1));
      mgr.execute(AddShapeCommand(shapes: shapes, shape: s2));
      mgr.execute(RemoveShapeCommand(shapes: shapes, shape: s1));
      expect(shapes.length, 1);
      expect(shapes.first.id, s2.id);
      mgr.undo();
      expect(shapes.length, 2);
      expect(shapes.first.id, s1.id);
    });

    test('UpdateShapeCommand replaces and undoes', () {
      final shapes = <DrawableShape>[];
      final mgr = UndoRedoManager();
      final original = DrawablePolygon(
        id: 'upd1',
        points: [LatLng(0, 0), LatLng(1, 0), LatLng(1, 1)],
      );
      final updated = original.copyWith(
        points: [LatLng(5, 5), LatLng(6, 6), LatLng(7, 7)],
      );
      mgr.execute(AddShapeCommand(shapes: shapes, shape: original));
      mgr.execute(UpdateShapeCommand(
        shapes: shapes,
        oldShape: original,
        newShape: updated,
        matcher: (a, b) => a.id == b.id,
      ));
      expect((shapes.first as DrawablePolygon).points.first.latitude, 5);
      mgr.undo();
      expect((shapes.first as DrawablePolygon).points.first.latitude, 0);
    });

    test('maxHistoryDepth trims old entries', () {
      final shapes = <DrawableShape>[];
      final mgr = UndoRedoManager(maxHistoryDepth: 3);
      for (var i = 0; i < 5; i++) {
        mgr.execute(AddShapeCommand(
          shapes: shapes,
          shape: DrawablePolygon(
            id: 'trim_$i',
            points: [LatLng(i.toDouble(), 0), LatLng(0, 1), LatLng(1, 1)],
          ),
        ));
      }
      var undoCount = 0;
      while (mgr.canUndo) {
        mgr.undo();
        undoCount++;
      }
      expect(undoCount, 3);
    });

    test('clear resets stacks', () {
      final shapes = <DrawableShape>[];
      final mgr = UndoRedoManager();
      mgr.execute(AddShapeCommand(
        shapes: shapes,
        shape: DrawablePolygon(
          id: 'cl1',
          points: [LatLng(0, 0), LatLng(1, 0), LatLng(1, 1)],
        ),
      ));
      mgr.undo();
      expect(mgr.canRedo, true);
      mgr.clear();
      expect(mgr.canUndo, false);
      expect(mgr.canRedo, false);
    });
  });

  group('DrawingState', () {
    test('add and retrieve shapes', () {
      final state = DrawingState();
      final polygon = DrawablePolygon(
        id: 'ds1',
        points: [LatLng(0, 0), LatLng(1, 0), LatLng(1, 1)],
      );
      state.addShape(polygon);
      expect(state.shapes.length, 1);
      expect(state.shapes.first.id, polygon.id);
    });

    test('selectShape and clear', () {
      final state = DrawingState();
      final polygon = DrawablePolygon(
        id: 'ds2',
        points: [LatLng(0, 0), LatLng(1, 0), LatLng(1, 1)],
      );
      state.addShape(polygon);
      state.selectShape(polygon.id);
      expect(state.selectedShape?.id, polygon.id);
      state.clearSelection();
      expect(state.selectedShape, isNull);
    });

    test('setMode and isDrawing', () {
      final state = DrawingState();
      state.setMode(DrawingMode.polygon);
      expect(state.activeMode, DrawingMode.polygon);
      expect(state.isDrawing, true);
      state.addDrawingPoint(LatLng(0, 0));
      expect(state.isDrawing, true);
      state.setMode(DrawingMode.none);
      expect(state.isDrawing, false);
    });

    test('finishDrawing creates polygon', () {
      final state = DrawingState();
      state.setMode(DrawingMode.polygon);
      state.addDrawingPoint(LatLng(0, 0));
      state.addDrawingPoint(LatLng(1, 0));
      state.addDrawingPoint(LatLng(1, 1));
      final shape = state.finishDrawing();
      expect(shape, isNotNull);
      expect(shape, isA<DrawablePolygon>());
      expect(state.shapes.length, 1);
    });

    test('finishDrawing creates polyline', () {
      final state = DrawingState();
      state.setMode(DrawingMode.polyline);
      state.addDrawingPoint(LatLng(0, 0));
      state.addDrawingPoint(LatLng(1, 1));
      final shape = state.finishDrawing();
      expect(shape, isNotNull);
      expect(shape, isA<DrawablePolyline>());
    });

    test('finishDrawing creates rectangle', () {
      final state = DrawingState();
      state.setMode(DrawingMode.rectangle);
      state.addDrawingPoint(LatLng(0, 0));
      state.addDrawingPoint(LatLng(1, 1));
      final shape = state.finishDrawing();
      expect(shape, isNotNull);
      expect(shape, isA<DrawableRectangle>());
    });

    test('finishCircleDrawing creates circle', () {
      final state = DrawingState();
      state.setMode(DrawingMode.circle);
      state.setCircleCenter(LatLng(10, 20));
      state.addDrawingPoint(LatLng(10.01, 20));
      final shape = state.finishCircleDrawing(1000);
      expect(shape, isNotNull);
      expect(shape, isA<DrawableCircle>());
    });

    test('finishCircleDrawing returns null for invalid input', () {
      final state = DrawingState();
      state.setMode(DrawingMode.circle);
      expect(state.finishCircleDrawing(1000), isNull); // no center
      state.setCircleCenter(LatLng(10, 20));
      expect(state.finishCircleDrawing(0), isNull); // zero radius
    });

    test('finishHoleDrawing adds hole to selected polygon', () {
      final state = DrawingState();
      final poly = DrawablePolygon(
        id: 'hole1',
        points: [LatLng(0, 0), LatLng(0, 10), LatLng(10, 10), LatLng(10, 0)],
      );
      state.addShape(poly);
      state.setMode(DrawingMode.hole);
      // Select AFTER setMode since setMode clears selection for non-select modes
      state.selectShape(poly.id);
      state.addDrawingPoint(LatLng(2, 2));
      state.addDrawingPoint(LatLng(2, 4));
      state.addDrawingPoint(LatLng(4, 4));
      final result = state.finishHoleDrawing();
      expect(result, true);
      expect((state.shapes.first as DrawablePolygon).holes.length, 1);
    });

    test('undo removes last shape', () {
      final state = DrawingState();
      state.addShape(DrawablePolygon(
        id: 'ds_undo',
        points: [LatLng(0, 0), LatLng(1, 0), LatLng(1, 1)],
      ));
      expect(state.shapes.length, 1);
      state.undo();
      expect(state.shapes.length, 0);
    });

    test('redo re-adds shape', () {
      final state = DrawingState();
      state.addShape(DrawablePolygon(
        id: 'ds_redo',
        points: [LatLng(0, 0), LatLng(1, 0), LatLng(1, 1)],
      ));
      state.undo();
      state.redo();
      expect(state.shapes.length, 1);
    });

    test('cancelDrawing clears points', () {
      final state = DrawingState();
      state.setMode(DrawingMode.polygon);
      state.addDrawingPoint(LatLng(0, 0));
      state.addDrawingPoint(LatLng(1, 0));
      state.cancelDrawing();
      expect(state.drawingPoints.isEmpty, true);
    });

    test('undoDrawingPoint removes last point', () {
      final state = DrawingState();
      state.setMode(DrawingMode.polygon);
      state.addDrawingPoint(LatLng(0, 0));
      state.addDrawingPoint(LatLng(1, 0));
      state.undoDrawingPoint();
      expect(state.drawingPoints.length, 1);
    });

    test('duplicateSelected creates a copy', () {
      final state = DrawingState();
      final poly = DrawablePolygon(
        id: 'ds_dup',
        points: [LatLng(0, 0), LatLng(1, 0), LatLng(1, 1)],
      );
      state.addShape(poly);
      state.selectShape(poly.id);
      final copy = state.duplicateSelected();
      expect(copy, isNotNull);
      expect(state.shapes.length, 2);
      expect(state.shapes[0].id, isNot(state.shapes[1].id));
    });

    test('removeShape removes by id', () {
      final state = DrawingState();
      final poly = DrawablePolygon(
        id: 'rm1',
        points: [LatLng(0, 0), LatLng(1, 0), LatLng(1, 1)],
      );
      state.addShape(poly);
      state.removeShape(poly.id);
      expect(state.shapes.isEmpty, true);
    });

    test('removeSelected removes selected shape', () {
      final state = DrawingState();
      final poly = DrawablePolygon(
        id: 'rms1',
        points: [LatLng(0, 0), LatLng(1, 0), LatLng(1, 1)],
      );
      state.addShape(poly);
      state.selectShape(poly.id);
      state.removeSelected();
      expect(state.shapes.isEmpty, true);
      expect(state.selectedShape, isNull);
    });

    test('updateShape replaces shape', () {
      final state = DrawingState();
      final poly = DrawablePolygon(
        id: 'upd1',
        points: [LatLng(0, 0), LatLng(1, 0), LatLng(1, 1)],
      );
      state.addShape(poly);
      final updated = poly.copyWith(
        points: [LatLng(5, 5), LatLng(6, 6), LatLng(7, 7)],
      );
      state.updateShape(poly, updated);
      expect(
        (state.shapes.first as DrawablePolygon).points.first.latitude,
        5,
      );
    });

    test('shapesToJson and loadShapesFromJson roundtrip', () {
      final state = DrawingState();
      state.addShape(DrawablePolygon(
        id: 'json1',
        points: [LatLng(0, 0), LatLng(1, 0), LatLng(1, 1)],
      ));
      state.addShape(DrawableCircle(
        id: 'json2',
        center: LatLng(5, 5),
        radiusMeters: 100,
      ));

      final json = state.shapesToJson();
      final state2 = DrawingState();
      state2.loadShapesFromJson(json);
      expect(state2.shapes.length, 2);
      expect(state2.shapes[0], isA<DrawablePolygon>());
      expect(state2.shapes[1], isA<DrawableCircle>());
    });

    test('clearAll removes everything', () {
      final state = DrawingState();
      state.addShape(DrawablePolygon(
        id: 'ds_clear',
        points: [LatLng(0, 0), LatLng(1, 0), LatLng(1, 1)],
      ));
      state.clearAll();
      expect(state.shapes.isEmpty, true);
      expect(state.canUndo, false);
    });

    test('shouldAbsorbMapGestures during drawing', () {
      final state = DrawingState();
      expect(state.shouldAbsorbMapGestures, false);
      state.setMode(DrawingMode.polygon);
      expect(state.shouldAbsorbMapGestures, true);
    });

    test('shouldAbsorbMapGestures during drag', () {
      final state = DrawingState();
      expect(state.shouldAbsorbMapGestures, false);
      state.beginShapeDrag();
      expect(state.shouldAbsorbMapGestures, true);
      state.endShapeDrag();
      expect(state.shouldAbsorbMapGestures, false);
    });

    test('snapping toggle', () {
      final state = DrawingState();
      expect(state.snappingEnabled, false);
      state.setSnapping(true);
      expect(state.snappingEnabled, true);
    });

    test('notifies listeners on state changes', () {
      final state = DrawingState();
      var notified = false;
      state.addListener(() => notified = true);
      state.addShape(DrawablePolygon(
        id: 'ds_notify',
        points: [LatLng(0, 0), LatLng(1, 0), LatLng(1, 1)],
      ));
      expect(notified, true);
    });
  });

  group('DrawingMode', () {
    test('all modes are defined', () {
      expect(DrawingMode.values.length, 9);
      expect(DrawingMode.values, contains(DrawingMode.freehand));
      expect(DrawingMode.values, contains(DrawingMode.hole));
      expect(DrawingMode.values, contains(DrawingMode.measure));
    });
  });
}
