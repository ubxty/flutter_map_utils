# flutter_map_utils — Complete Usage Guide

> **Version 0.1.1** · Built on `flutter_map ^8.0.0`
> Maintained by [UBXTY – Unboxing Technology](https://ubxty.com)

This guide covers every public class, method, and parameter in the package. Use the table of contents to jump to any section.

---

## Table of Contents

1. [Installation](#installation)
2. [Quick Start](#quick-start)
3. [Core](#core)
   - [DrawingMode](#drawingmode)
   - [DrawingState](#drawingstate)
   - [Shape Models](#shape-models)
   - [ShapeStyle](#shapestyle)
   - [UndoRedoManager](#undoredomanager)
4. [Drawing Tools](#drawing-tools)
   - [PolygonDrawTool](#polygondrawtool)
   - [PolylineDrawTool](#polylinedrawtool)
   - [RectangleDrawTool](#rectangledrawtool)
   - [CircleDrawTool](#circledrawtool)
   - [FreehandDrawTool](#freehanddrawtool)
5. [Drawing Layer](#drawing-layer)
6. [Editing](#editing)
   - [EditableShapeLayer](#editableshapelayer)
   - [ShapeDragger](#shapedragger)
7. [Selection](#selection)
8. [Snapping](#snapping)
9. [Measurement](#measurement)
10. [Geometry Utilities](#geometry-utilities)
11. [GeoJSON Import / Export](#geojson-import--export)
12. [UI Widgets](#ui-widgets)
    - [FlutterMapGeometryEditor](#fluttermapgeometryeditor)
    - [DrawingToolbar](#drawingtoolbar)
    - [ShapeInfoPanel](#shapeinfopanel)
    - [CoordinateDisplay](#coordinatedisplay)
13. [Recipes](#recipes)

---

## Installation

```yaml
dependencies:
  flutter_map_utils:
    git:
      url: https://github.com/ubxty/flutter_map_utils.git
      ref: v0.1.1
```

Import everything:

```dart
import 'package:flutter_map_utils/flutter_map_utils.dart';
```

---

## Quick Start

### Option A — All-in-one widget (fastest)

```dart
final drawingState = DrawingState();

@override
Widget build(BuildContext context) {
  return FlutterMapGeometryEditor(
    drawingState: drawingState,
    mapOptions: const MapOptions(
      initialCenter: LatLng(51.5, -0.09),
      initialZoom: 13,
    ),
    tileLayer: TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    ),
  );
}
```

This gives you a full map with toolbar, drawing tools, editing handles, info panel, and coordinate display — zero additional setup.

### Option B — Composable layers (full control)

```dart
final drawingState = DrawingState();
final layerKey = GlobalKey<DrawingLayerState>();

FlutterMap(
  options: MapOptions(
    initialCenter: const LatLng(51.5, -0.09),
    initialZoom: 13,
    interactionOptions: InteractionOptions(
      flags: drawingState.shouldAbsorbMapGestures
          ? InteractiveFlag.none
          : InteractiveFlag.all,
    ),
    onTap: (_, point) => layerKey.currentState?.handleTap(point),
    onSecondaryTap: (_, point) =>
        layerKey.currentState?.handleSecondaryTap(point),
  ),
  children: [
    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
    DrawingLayer(key: layerKey, drawingState: drawingState),
    EditableShapeLayer(drawingState: drawingState),
  ],
)
```

> **Important:** When using composable layers, you are responsible for wiring `InteractionOptions` based on `drawingState.shouldAbsorbMapGestures` to lock map pan/zoom during drawing. The `FlutterMapGeometryEditor` does this automatically.

---

## Core

### DrawingMode

An enum that controls the active tool.

| Value | Description |
|-------|-------------|
| `none` | No tool active. Normal map interaction. |
| `polygon` | Tap to place vertices. Finish with right-click or secondary tap. |
| `polyline` | Tap to place vertices. Finish with right-click or secondary tap. |
| `rectangle` | Two taps — opposite corners. |
| `circle` | Tap center, then tap/drag to set radius. |
| `freehand` | Press and drag to draw freely. Auto-simplifies and smooths on release. |
| `select` | Tap shapes to select them. |
| `measure` | Tap points to measure distances and area. |
| `hole` | Draw a hole inside the selected polygon. |

```dart
drawingState.setMode(DrawingMode.polygon);
```

---

### DrawingState

The central state manager. Extends `ChangeNotifier` so it works with Provider, Riverpod, Bloc, or plain `ListenableBuilder`.

#### Constructor

```dart
DrawingState({
  int maxHistoryDepth = 100,        // Max undo steps
  ShapeStyle defaultStyle = ShapeStylePresets.defaultWithStates,
})
```

#### Getters

| Getter | Type | Description |
|--------|------|-------------|
| `shapes` | `List<DrawableShape>` | All committed shapes (unmodifiable). |
| `selectedShape` | `DrawableShape?` | Currently selected shape. |
| `selectedShapeId` | `String?` | ID of the selected shape. |
| `activeMode` | `DrawingMode` | Current drawing mode. |
| `snappingEnabled` | `bool` | Whether snapping is on. |
| `isDrawing` | `bool` | True when any drawing tool is active (not `none`/`select`). |
| `shouldAbsorbMapGestures` | `bool` | True during drawing or shape dragging — use to disable map pan/zoom. |
| `drawingPoints` | `List<LatLng>` | Points being drawn (live preview). |
| `circleCenter` | `LatLng?` | Center point during circle drawing. |
| `canUndo` | `bool` | Whether undo is available. |
| `canRedo` | `bool` | Whether redo is available. |
| `undoRedo` | `UndoRedoManager` | Direct access to the undo/redo manager. |
| `defaultStyle` | `ShapeStyle` | Default style for new shapes. |

#### Mode Management

```dart
// Switch to polygon drawing
drawingState.setMode(DrawingMode.polygon);

// Cancels any in-progress drawing when switching modes.
// Clears selection when leaving select mode.
```

#### Drawing Lifecycle

```dart
// Add point during drawing (typically called by tools, not directly)
drawingState.addDrawingPoint(LatLng(51.5, -0.09));

// Undo last point while drawing
drawingState.undoDrawingPoint();

// Set circle center
drawingState.setCircleCenter(LatLng(51.5, -0.09));

// Finish current drawing → returns the created shape
DrawableShape? shape = drawingState.finishDrawing(style: myStyle);

// Finish circle drawing with specific radius in meters
DrawableShape? circle = drawingState.finishCircleDrawing(500.0);

// Finish drawing a hole inside the selected polygon
bool success = drawingState.finishHoleDrawing();

// Cancel drawing, discard points
drawingState.cancelDrawing();
```

#### Shape CRUD

```dart
// Add a pre-built shape
drawingState.addShape(myPolygon);

// Remove by ID
drawingState.removeShape('shape-uuid');

// Remove the selected shape
drawingState.removeSelected();

// Update a shape (undo-safe)
drawingState.updateShape(oldShape, newShape);

// Duplicate selected with offset
DrawableShape? copy = drawingState.duplicateSelected(
  latOffset: 0.0005,  // ~55m north
  lngOffset: 0.0005,  // ~55m east
);
```

#### Selection

```dart
drawingState.selectShape('shape-uuid');
drawingState.clearSelection();
```

#### Snapping

```dart
drawingState.setSnapping(true);  // Enable snap
drawingState.setSnapping(false); // Disable snap
```

#### Dragging State

```dart
// Call these when dragging a shape to suppress map gestures
drawingState.beginShapeDrag();
drawingState.endShapeDrag();
```

#### Undo / Redo

```dart
drawingState.undo();
drawingState.redo();
```

#### Serialization

```dart
// Save to JSON
List<Map<String, dynamic>> json = drawingState.shapesToJson();

// Load from JSON (replaces all shapes, clears undo history)
drawingState.loadShapesFromJson(jsonList);

// Clear everything
drawingState.clearAll();
```

---

### Shape Models

All shapes extend the sealed class `DrawableShape`. Each has a unique `id` (UUID), a `style`, and optional `metadata`.

#### ShapeType enum

| Value | Shape class |
|-------|-------------|
| `polygon` | `DrawablePolygon` |
| `polyline` | `DrawablePolyline` |
| `circle` | `DrawableCircle` |
| `rectangle` | `DrawableRectangle` |

#### DrawableShape (base)

```dart
// Common properties on all shapes:
shape.id          // String — unique UUID
shape.type        // ShapeType enum
shape.style       // ShapeStyle
shape.metadata    // Map<String, dynamic>
shape.allPoints   // List<LatLng> — all points (center for circles)

// Serialize / deserialize
Map<String, dynamic> json = shape.toJson();
DrawableShape restored = DrawableShape.fromJson(json);
```

#### DrawablePolygon

```dart
DrawablePolygon(
  id: 'my-polygon',
  points: [LatLng(51.5, -0.09), LatLng(51.51, -0.08), LatLng(51.5, -0.07)],
  holes: [                        // Optional holes
    [LatLng(51.503, -0.085), LatLng(51.505, -0.082), LatLng(51.503, -0.079)],
  ],
  style: ShapeStylePresets.zone,
  metadata: {'name': 'Zone A'},
);

polygon.points  // List<LatLng>
polygon.holes   // List<List<LatLng>>

// Copy with changes
final updated = polygon.copyWith(
  points: newPoints,
  holes: newHoles,
  style: newStyle,
  metadata: newMeta,
);
```

#### DrawablePolyline

```dart
DrawablePolyline(
  id: 'my-route',
  points: [LatLng(51.5, -0.09), LatLng(51.51, -0.08)],
  style: ShapeStylePresets.route,
);

polyline.points  // List<LatLng>
```

#### DrawableCircle

```dart
DrawableCircle(
  id: 'my-circle',
  center: LatLng(51.5, -0.09),
  radiusMeters: 200,
);

circle.center        // LatLng
circle.radiusMeters  // double
```

#### DrawableRectangle

```dart
// From 4 corner points
DrawableRectangle(
  id: 'my-rect',
  points: [nw, ne, se, sw],
);

// From 2 opposite corners (auto-generates 4 points)
DrawableRectangle.fromCorners(
  id: 'my-rect',
  corner1: LatLng(51.50, -0.09),
  corner2: LatLng(51.51, -0.08),
);

rect.points  // List<LatLng> — always 4 points (NW, NE, SE, SW)
```

---

### ShapeStyle

Controls the visual appearance of shapes.

#### Constructor

```dart
const ShapeStyle({
  Color fillColor = const Color(0x553388FF),
  Color borderColor = const Color(0xFF3388FF),
  double borderWidth = 2.0,
  double fillOpacity = 0.3,
  StrokePattern strokePattern = const StrokePattern.solid(),
  ShapeStyle? selectedOverride,   // Style applied when shape is selected
  ShapeStyle? hoverOverride,      // Style applied when shape is hovered
})
```

#### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `fillColor` | `Color` | `0x553388FF` | Interior fill color. |
| `borderColor` | `Color` | `0xFF3388FF` | Border/stroke color. |
| `borderWidth` | `double` | `2.0` | Border stroke width in pixels. |
| `fillOpacity` | `double` | `0.3` | Fill opacity (0.0–1.0). |
| `strokePattern` | `StrokePattern` | `solid()` | Stroke pattern (solid, dashed, dotted). |
| `selectedOverride` | `ShapeStyle?` | `null` | Override when selected. |
| `hoverOverride` | `ShapeStyle?` | `null` | Override when hovered. |

#### Methods

```dart
// Resolve style for current state
ShapeStyle resolved = style.resolve(selected: true, hovered: false);

// Get fill color with opacity applied
Color fill = style.effectiveFillColor;

// Copy with overrides
ShapeStyle newStyle = style.copyWith(borderColor: Colors.red);

// Serialize
Map<String, dynamic> json = style.toJson();
ShapeStyle loaded = ShapeStyle.fromJson(json);
```

#### Presets

```dart
ShapeStylePresets.zone               // Blue fill, blue border
ShapeStylePresets.warning            // Red fill, red border
ShapeStylePresets.route              // No fill, blue border
ShapeStylePresets.selected           // Orange border, light yellow fill
ShapeStylePresets.hover              // Light blue highlight
ShapeStylePresets.defaultWithStates  // Default style with selected + hover overrides
```

---

### UndoRedoManager

Command-pattern undo/redo system. Used internally by `DrawingState` but accessible for custom commands.

#### Constructor

```dart
UndoRedoManager({int maxHistoryDepth = 100})
```

#### Properties & Methods

```dart
manager.canUndo     // bool
manager.canRedo     // bool
manager.undoCount   // int — number of undo-able operations
manager.redoCount   // int — number of redo-able operations

manager.execute(command);     // Execute and push to history
manager.undo();               // Returns the undone command, or null
manager.redo();               // Returns the redone command, or null
manager.clear();              // Clear all history
```

#### Built-in Commands

```dart
// Add a shape to a list (undo removes it)
AddShapeCommand(shapes: shapeList, shape: newShape);

// Remove a shape from a list (undo adds it back)
RemoveShapeCommand(shapes: shapeList, shape: targetShape);

// Update a shape in a list (undo reverts to old version)
UpdateShapeCommand(
  shapes: shapeList,
  oldShape: before,
  newShape: after,
  matcher: (a, b) => a.id == b.id,
);
```

#### Custom Commands

```dart
class MyCommand extends UndoableCommand {
  @override String get description => 'My custom operation';
  @override void execute() { /* do it */ }
  @override void undo() { /* reverse it */ }
}

drawingState.undoRedo.execute(MyCommand());
```

---

## Drawing Tools

All drawing tools extend `BaseDrawTool`. They render a preview while drawing and call `DrawingState` methods to finalize shapes.

### Common BaseDrawTool Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `drawingState` | `DrawingState` | required | Shared drawing state. |
| `onDrawingComplete` | `VoidCallback?` | `null` | Called when a shape is finished. |
| `showEdgeLengths` | `bool` | `true` | Show distance labels on edges while drawing. |
| `showAreaPreview` | `bool` | `true` | Show live area calculation during polygon drawing. |
| `autoCloseThreshold` | `double` | `15.0` | Pixels — auto-close polygon when last tap is near first vertex. |

### Common BaseDrawToolState Methods

| Method | Description |
|--------|-------------|
| `handleTap(LatLng)` | Process a map tap. |
| `handleSecondaryTap(LatLng)` | Right-click / two-finger tap — finishes drawing. |
| `handleLongPress(LatLng)` | Long press — finishes drawing. |
| `finishDrawing()` | Finalize the current shape. |
| `cancelDrawing()` | Discard the in-progress drawing. |
| `undoPoint()` | Remove the last placed point. |
| `isNearFirstVertex(camera, point, target)` | Check auto-close proximity. |
| `formatDistance(meters)` | Format distance as human-readable string. |
| `formatArea(sqMeters)` | Format area as human-readable string. |

---

### PolygonDrawTool

Tap-to-place polygon vertices. Right-click or secondary tap to finish.

```dart
PolygonDrawTool(
  drawingState: state,
  previewStyle: ShapeStylePresets.zone,
  minPoints: 3,                 // Minimum vertices required
  showEdgeLengths: true,
  showAreaPreview: true,
  autoCloseThreshold: 15.0,     // Auto-close proximity in pixels
  onDrawingComplete: () => print('Polygon done!'),
)
```

---

### PolylineDrawTool

Tap-to-place polyline vertices.

```dart
PolylineDrawTool(
  drawingState: state,
  previewStyle: ShapeStylePresets.route,
  minPoints: 2,
  showEdgeLengths: true,
  onDrawingComplete: () => print('Polyline done!'),
)
```

---

### RectangleDrawTool

Two taps — opposite corners.

```dart
RectangleDrawTool(
  drawingState: state,
  previewStyle: ShapeStylePresets.zone,
  showEdgeLengths: true,
  onDrawingComplete: () => print('Rectangle done!'),
)
```

---

### CircleDrawTool

First tap = center. Second tap = edge (radius).

```dart
CircleDrawTool(
  drawingState: state,
  previewStyle: ShapeStylePresets.zone,
  onDrawingComplete: () => print('Circle done!'),
)
```

---

### FreehandDrawTool

Press-and-drag to draw freely. On pointer-up: simplifies via Douglas-Peucker, smooths via Chaikin's corner cutting, then finalizes as a polygon (or polyline).

**Map gestures are automatically paused** during freehand drawing when using `FlutterMapGeometryEditor`.

```dart
FreehandDrawTool(
  drawingState: state,
  previewStyle: ShapeStylePresets.zone,
  closeAsPolygon: true,              // true = polygon, false = polyline
  simplificationTolerance: 5.0,      // Douglas-Peucker tolerance in meters (0 = disabled)
  minPoints: 4,                      // Minimum points to keep
  smoothingIterations: 2,            // Chaikin smoothing passes (0 = disabled)
  onDrawingComplete: () => print('Freehand done!'),
)
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `closeAsPolygon` | `bool` | `true` | Auto-close into polygon on release. |
| `simplificationTolerance` | `double` | `5.0` | Douglas-Peucker tolerance (meters). Higher = fewer points. |
| `minPoints` | `int` | `4` | If simplification goes below this, original points are kept. |
| `smoothingIterations` | `int` | `2` | Chaikin corner-cutting passes. Each pass doubles point count but smooths corners. Set to `0` to disable smoothing. |

**How freehand processing works:**
1. **Capture** — Pointer-move events collect raw `LatLng` points
2. **Simplify** — Douglas-Peucker removes redundant points (configurable tolerance)
3. **Smooth** — Chaikin's corner-cutting produces clean, rounded curves (configurable iterations)
4. **Finalize** — Result is saved as a `DrawablePolygon` (or polyline)

---

## Drawing Layer

`DrawingLayer` is the main layer widget placed inside `FlutterMap.children`. It manages the active drawing tool, renders previews, and shows committed shapes.

```dart
final layerKey = GlobalKey<DrawingLayerState>();

DrawingLayer(
  key: layerKey,
  drawingState: state,
  showEdgeLengths: true,
  showAreaPreview: true,
  autoCloseThreshold: 15.0,
  previewStyle: null,                          // Override preview style
  selectedStyle: null,                         // Override selected shape style
  renderCommittedShapes: true,                 // Render finalized shapes
  freehandSimplificationTolerance: 5.0,
  freehandCloseAsPolygon: true,
  onDrawingComplete: () => print('Done!'),
)
```

#### Forwarding Map Events

Wire these from `MapOptions` to the `DrawingLayerState`:

```dart
layerKey.currentState?.handleTap(point);
layerKey.currentState?.handleSecondaryTap(point);
layerKey.currentState?.handleLongPress(point);
layerKey.currentState?.handlePointerHover(point);
layerKey.currentState?.finishDrawing();
layerKey.currentState?.cancelDrawing();
```

---

## Editing

### EditableShapeLayer

Renders vertex handles, edge midpoint handles, and debugging vertex indices for the selected shape. Drag vertices to edit, drag edge midpoints to insert new vertices.

```dart
EditableShapeLayer(
  drawingState: state,
  vertexHandleSize: 14,           // Diameter of vertex handles
  edgeHandleSize: 10,             // Diameter of edge midpoint handles
  vertexHandleColor: Color(0xFF2196F3),   // Blue
  edgeHandleColor: Color(0xFF66BB6A),     // Green
  debugShowVertexIndices: false,  // Show vertex numbers (0, 1, 2...) for debugging
  showEdgeHandles: true,          // Show midpoint handles on edges
  onVertexLongPress: (index) {    // Delete vertex on long-press
    // Remove vertex at index
  },
)
```

### ShapeDragger

Enables whole-shape dragging. Automatically locks map panning during drag.

```dart
ShapeDragger(drawingState: state)
```

When a shape is being dragged, `drawingState.shouldAbsorbMapGestures` returns `true`, which the `FlutterMapGeometryEditor` uses to disable map pan/zoom.

---

## Selection

### SelectionLayer

Handles tap-to-select shapes in `select` mode. Uses point-in-polygon and distance-to-line hit testing.

```dart
SelectionLayer(
  drawingState: state,
  tapToleranceMeters: 20.0,  // How close a tap must be to select a polyline/circle edge
)
```

To select shapes programmatically:

```dart
drawingState.setMode(DrawingMode.select);
drawingState.selectShape('shape-uuid');
drawingState.clearSelection();
```

---

## Snapping

### SnapType

| Type | Description |
|------|-------------|
| `vertex` | Snap to existing shape vertices. |
| `midpoint` | Snap to edge midpoints. |
| `edge` | Snap to nearest point on an edge. |
| `intersection` | Snap to where two edges cross. |
| `grid` | Snap to a configurable coordinate grid. |
| `perpendicular` | Snap at 90° to a nearby edge. |

### SnapConfig

```dart
const SnapConfig({
  bool enabled = true,
  double toleranceMeters = 15.0,       // Max snap distance
  List<SnapType> priorities = const [  // Search order — first match wins
    SnapType.vertex,
    SnapType.midpoint,
    SnapType.edge,
    SnapType.intersection,
    SnapType.grid,
  ],
  double gridSpacing = 0.0001,         // Grid cell size in degrees
})

// Disable snapping
SnapConfig.disabled
```

### SnappingEngine

Static utility — no instance needed.

```dart
SnapResult? result = SnappingEngine.findSnapTarget(
  cursorLatLng,             // Where the cursor/finger is
  drawingState.shapes,      // Shapes to snap against
  SnapConfig(
    enabled: true,
    toleranceMeters: 15.0,
    priorities: [SnapType.vertex, SnapType.edge],
  ),
  excludeShapeId: 'editing-shape-id',  // Don't snap to the shape being edited
);

if (result != null) {
  print('Snapped to ${result.type} at ${result.point}');
  print('Distance: ${result.distance}m');
  print('Source: ${result.sourceShapeId}');
}
```

### SnapResult

```dart
result.type            // SnapType
result.point           // LatLng — the snap target point
result.sourceShapeId   // String? — which shape was snapped to
result.distance        // double — distance in meters from cursor to snap target
```

### SnapIndicatorData

Helper for rendering snap feedback in UI:

```dart
final indicator = SnapIndicatorData(result: snapResult);
indicator.iconLabel  // String like "⊕ vertex" or "⊥ perpendicular"
```

---

## Measurement

### MeasurementState

Manages measurement points and calculations. Extends `ChangeNotifier`.

```dart
final measureState = MeasurementState();
```

| Getter | Type | Description |
|--------|------|-------------|
| `points` | `List<LatLng>` | Measured points. |
| `isEmpty` | `bool` | No points added. |
| `pointCount` | `int` | Number of points. |
| `totalDistanceMeters` | `double` | Total distance along all segments. |
| `areaSquareMeters` | `double` | Enclosed area (≥3 points). |
| `segmentDistances` | `List<double>` | Distance of each individual segment. |

```dart
measureState.addPoint(LatLng(51.5, -0.09));
measureState.undoLastPoint();
measureState.clear();
```

### MeasurementUnit

| Value | Description |
|-------|-------------|
| `metric` | Meters, kilometers, m², km² |
| `imperial` | Feet, miles, ft², mi² |

### MeasurementLayer

Visual overlay showing measurement lines, segment labels, and area.

```dart
MeasurementLayer(
  measurementState: measureState,
  showArea: true,                        // Show area for closed shapes
  unit: MeasurementUnit.metric,
  lineColor: Color(0xFFFF5722),          // Orange-red
  lineWidth: 2.5,
  showSegmentLabels: true,               // Distance on each segment
)
```

---

## Geometry Utilities

`GeometryUtils` is a static-only utility class. No instance needed.

### Point & Polygon Operations

```dart
// Is a point inside a polygon?
bool inside = GeometryUtils.pointInPolygon(point, polygonPoints);

// Bounding box of a set of points
LatLngBounds bounds = GeometryUtils.boundingBox(points);

// Distance between two points (meters, Haversine)
double meters = GeometryUtils.distanceBetween(pointA, pointB);

// Centroid (average center)
LatLng center = GeometryUtils.centroid(points);

// Midpoint of a segment
LatLng mid = GeometryUtils.midpoint(pointA, pointB);
```

### Area & Perimeter

```dart
// Polygon area in square meters (geodesic Shoelace formula)
double area = GeometryUtils.polygonArea(polygonPoints);

// Polygon perimeter in meters
double perimeter = GeometryUtils.polygonPerimeter(polygonPoints);

// Polyline total length in meters
double length = GeometryUtils.polylineLength(polylinePoints);

// Shorthand — works on any DrawableShape
double shapeArea = GeometryUtils.shapeArea(drawable);
double shapePerimeter = GeometryUtils.shapePerimeter(drawable);

// Area in square feet
double sqFt = GeometryUtils.areaInSquareFeet(polygonPoints);

// Area in acres
double acres = GeometryUtils.areaInAcres(polygonPoints);
```

### Path Simplification & Smoothing

Standalone static utilities — usable without any map widget.

```dart
// Douglas-Peucker simplification — reduce point count
List<LatLng> simplified = GeometryUtils.simplifyPath(
  rawPoints,
  tolerance: 5.0,  // meters — higher = fewer points
);

// Chaikin corner-cutting — smooth jagged paths
List<LatLng> smooth = GeometryUtils.smoothPath(
  simplified,
  iterations: 2,   // more iterations = smoother
  closed: true,    // true for polygons, false for polylines
);

// Combine both for freehand cleanup
var points = GeometryUtils.simplifyPath(rawFreehand, tolerance: 5.0);
points = GeometryUtils.smoothPath(points, iterations: 2, closed: true);
```

### Geometry Analysis

```dart
// Self-intersection check
bool selfIntersecting = GeometryUtils.isSelfIntersecting(points);

// Winding order
bool cw = GeometryUtils.isClockwise(points);

// Normalize winding
List<LatLng> cwPoints = GeometryUtils.ensureClockwise(points);
List<LatLng> ccwPoints = GeometryUtils.ensureCounterClockwise(points);
```

### Projection & Fitting

```dart
// Nearest point on a line segment
var result = GeometryUtils.nearestPointOnSegment(point, segA, segB);
LatLng nearest = result.point;
double t = result.t; // 0.0 = at segA, 1.0 = at segB

// Fit map camera to show all shapes
CameraFit fit = GeometryUtils.fitBoundsToShapes(
  drawingState.shapes,
  padding: EdgeInsets.all(50),
);
mapController.fitCamera(fit);
```

---

## GeoJSON Import / Export

`GeoJsonUtils` is a static-only utility class.

### Export

```dart
// Single shape → GeoJSON Feature
Map<String, dynamic> feature = GeoJsonUtils.toGeoJsonFeature(shape);

// All shapes → GeoJSON FeatureCollection
Map<String, dynamic> collection = GeoJsonUtils.toFeatureCollection(shapes);

// To JSON string (with optional pretty-printing)
String json = GeoJsonUtils.toGeoJsonString(shapes, pretty: true);
```

### Import

```dart
// From JSON string → shapes
List<DrawableShape> shapes = GeoJsonUtils.fromGeoJsonString(jsonString);

// From parsed JSON map → shapes
List<DrawableShape> shapes = GeoJsonUtils.fromGeoJson(jsonMap);
```

**Supported GeoJSON types:**
- `Point` (with `radius` property → `DrawableCircle`, otherwise skipped)
- `LineString` → `DrawablePolyline`
- `Polygon` → `DrawablePolygon` (with `shapeType: 'rectangle'` hint → `DrawableRectangle`)
- `MultiPolygon` → Multiple `DrawablePolygon`s
- `Feature` — unwraps to above
- `FeatureCollection` — unwraps all features

**Metadata round-trip:** Shape `metadata` is stored as GeoJSON `properties`. `shapeType` is automatically included to preserve type information (rectangle, circle).

---

## UI Widgets

### FlutterMapGeometryEditor

The all-in-one widget. Wraps `FlutterMap` and integrates all layers, tools, and overlays.

```dart
FlutterMapGeometryEditor(
  drawingState: drawingState,
  measurementState: measurementState,     // Optional
  mapOptions: const MapOptions(
    initialCenter: LatLng(51.5, -0.09),
    initialZoom: 13,
  ),
  tileLayer: TileLayer(urlTemplate: '...'),
  additionalLayers: [                     // Extra layers below drawing layers
    MarkerLayer(markers: myMarkers),
  ],
  showToolbar: true,
  showInfoPanel: true,
  showCoordinateDisplay: true,
  toolbarAlignment: Alignment.centerLeft,
  infoPanelAlignment: Alignment.topRight,
  coordinateDisplayAlignment: Alignment.bottomCenter,
  toolbarModes: [                         // Customize which modes appear in toolbar
    DrawingMode.polygon,
    DrawingMode.freehand,
    DrawingMode.select,
  ],
)
```

**Automatic gesture locking:** When `drawingState.shouldAbsorbMapGestures` is `true` (during freehand drawing, shape dragging, or any active drawing mode), all map interactions (pan, zoom, rotate) are disabled. This prevents accidental map movement while drawing.

---

### DrawingToolbar

A row/column of tool-selection buttons.

```dart
DrawingToolbar(
  drawingState: state,
  direction: Axis.vertical,            // Or Axis.horizontal
  modes: [                             // Which modes to show (null = all)
    DrawingMode.polygon,
    DrawingMode.polyline,
    DrawingMode.freehand,
    DrawingMode.select,
  ],
  showUndoRedo: true,                  // Show undo/redo buttons
  showDelete: true,                    // Show delete button
  padding: EdgeInsets.all(8),
  spacing: 4,
  buttonBuilder: (context, mode, isActive, onTap) {  // Custom button builder
    return IconButton(
      icon: Icon(myIconForMode(mode)),
      color: isActive ? Colors.blue : Colors.grey,
      onPressed: onTap,
    );
  },
)
```

---

### ShapeInfoPanel

Displays area, perimeter, vertex count, and coordinates for the selected shape.

```dart
ShapeInfoPanel(
  drawingState: state,
  showCoordinates: true,     // Show vertex coordinate list
  showMeasurements: true,    // Show area/perimeter
  showMetadata: true,        // Show shape metadata
)
```

---

### CoordinateDisplay

Shows the cursor/pointer latitude and longitude.

```dart
CoordinateDisplay(
  format: 'dd',      // Decimal degrees
  precision: 6,      // Decimal places
)
```

Update position from pointer events:

```dart
final coordKey = GlobalKey<CoordinateDisplayState>();

CoordinateDisplay(key: coordKey);

// In your pointer hover handler:
coordKey.currentState?.updatePosition(latLng);
```

---

## Recipes

### 1. Draw a polygon and export as GeoJSON

```dart
final state = DrawingState();
state.setMode(DrawingMode.polygon);
// ... user draws polygon via taps ...

// After drawing completes:
String geojson = GeoJsonUtils.toGeoJsonString(state.shapes, pretty: true);
```

### 2. Import GeoJSON from API and display on map

```dart
final state = DrawingState();
final response = await http.get(Uri.parse('https://api.example.com/zones'));
final shapes = GeoJsonUtils.fromGeoJsonString(response.body);
for (final shape in shapes) {
  state.addShape(shape);
}
```

### 3. Measure distance between two points

```dart
double meters = GeometryUtils.distanceBetween(
  LatLng(51.5, -0.09),
  LatLng(51.51, -0.08),
);
print('${meters.toStringAsFixed(1)} meters');
```

### 4. Calculate area of a polygon

```dart
double sqMeters = GeometryUtils.polygonArea([
  LatLng(51.50, -0.09),
  LatLng(51.51, -0.09),
  LatLng(51.51, -0.08),
  LatLng(51.50, -0.08),
]);
print('${(sqMeters / 1000000).toStringAsFixed(2)} km²');
```

### 5. Snap to existing shapes while drawing

```dart
// In your drawing loop or point handler:
SnapResult? snap = SnappingEngine.findSnapTarget(
  rawPoint,
  state.shapes,
  SnapConfig(enabled: true, toleranceMeters: 10),
);
final point = snap?.point ?? rawPoint;
state.addDrawingPoint(point);
```

### 6. Custom undo/redo command

```dart
class RecolorCommand extends UndoableCommand {
  final DrawableShape shape;
  final ShapeStyle oldStyle;
  final ShapeStyle newStyle;
  final List<DrawableShape> shapes;

  RecolorCommand(this.shapes, this.shape, this.oldStyle, this.newStyle);

  @override String get description => 'Recolor shape';
  @override void execute() {
    final i = shapes.indexWhere((s) => s.id == shape.id);
    if (i >= 0) shapes[i] = shape.copyWith(style: newStyle);
  }
  @override void undo() {
    final i = shapes.indexWhere((s) => s.id == shape.id);
    if (i >= 0) shapes[i] = shape.copyWith(style: oldStyle);
  }
}
```

### 7. Freehand drawing with custom smoothing

```dart
// More smoothing for very clean shapes
FreehandDrawTool(
  drawingState: state,
  smoothingIterations: 4,           // Extra smooth
  simplificationTolerance: 8.0,     // More aggressive simplification
  closeAsPolygon: true,
)

// No smoothing — keep raw brush strokes
FreehandDrawTool(
  drawingState: state,
  smoothingIterations: 0,           // Disabled
  simplificationTolerance: 2.0,     // Light simplification
  closeAsPolygon: true,
)
```

### 8. Programmatically create shapes

```dart
final state = DrawingState();

state.addShape(DrawablePolygon(
  id: 'park-zone',
  points: [LatLng(51.50, -0.09), LatLng(51.51, -0.09), LatLng(51.51, -0.08)],
  style: ShapeStylePresets.zone,
  metadata: {'name': 'Central Park', 'type': 'zone'},
));

state.addShape(DrawableCircle(
  id: 'radius-500m',
  center: LatLng(51.505, -0.085),
  radiusMeters: 500,
  style: ShapeStylePresets.warning,
));
```

### 9. Save and restore shapes

```dart
// Save
final jsonList = state.shapesToJson();
final encoded = jsonEncode(jsonList);
await prefs.setString('saved_shapes', encoded);

// Restore
final stored = prefs.getString('saved_shapes');
if (stored != null) {
  state.loadShapesFromJson(jsonDecode(stored));
}
```

### 10. Fit map to all shapes

```dart
final fit = GeometryUtils.fitBoundsToShapes(
  state.shapes,
  padding: const EdgeInsets.all(80),
);
mapController.fitCamera(fit);
```

### 11. Custom toolbar with only specific modes

```dart
DrawingToolbar(
  drawingState: state,
  direction: Axis.horizontal,
  modes: [DrawingMode.polygon, DrawingMode.freehand, DrawingMode.select],
  showUndoRedo: true,
  showDelete: true,
)
```

### 12. Draw holes in polygons

```dart
// First select a polygon
state.setMode(DrawingMode.select);
state.selectShape('polygon-id');

// Switch to hole mode
state.setMode(DrawingMode.hole);
// ... user taps points inside the polygon ...

// Finish the hole
state.finishHoleDrawing();
```

---

## API Quick Reference

### Classes at a Glance

| Category | Class | Purpose |
|----------|-------|---------|
| **Core** | `DrawingState` | Central state manager (ChangeNotifier) |
| | `DrawingMode` | Active tool enum (polygon, polyline, etc.) |
| | `DrawableShape` | Sealed base for all shape models |
| | `DrawablePolygon` | Polygon with holes |
| | `DrawablePolyline` | Open polyline |
| | `DrawableCircle` | Circle (center + radius) |
| | `DrawableRectangle` | Axis-aligned rectangle |
| | `ShapeStyle` | Visual style (colors, borders, states) |
| | `ShapeStylePresets` | Pre-built style constants |
| | `UndoRedoManager` | Command-pattern history |
| **Tools** | `PolygonDrawTool` | Tap-to-draw polygon |
| | `PolylineDrawTool` | Tap-to-draw polyline |
| | `RectangleDrawTool` | Two-tap rectangle |
| | `CircleDrawTool` | Center + radius circle |
| | `FreehandDrawTool` | Press-drag freehand (auto-smooth) |
| **Layers** | `DrawingLayer` | Main drawing orchestrator layer |
| | `EditableShapeLayer` | Vertex/edge drag handles |
| | `SelectionLayer` | Tap-to-select hit testing |
| | `MeasurementLayer` | Distance/area measurement overlay |
| **Utils** | `GeometryUtils` | Area, distance, centroid, bbox, PIP, etc. |
| | `GeoJsonUtils` | GeoJSON import/export |
| | `SnappingEngine` | Snap to vertex/edge/grid |
| | `SnapConfig` | Snapping configuration |
| | `SnapResult` | Snap target info |
| **UI** | `FlutterMapGeometryEditor` | All-in-one map + tools wrapper |
| | `DrawingToolbar` | Mode selection toolbar |
| | `ShapeInfoPanel` | Selected shape info display |
| | `CoordinateDisplay` | Cursor lat/lng display |
| **Measurement** | `MeasurementState` | Measurement point manager |
| | `MeasurementUnit` | metric / imperial |

---

*Built with care by [UBXTY – Unboxing Technology](https://ubxty.com)*
