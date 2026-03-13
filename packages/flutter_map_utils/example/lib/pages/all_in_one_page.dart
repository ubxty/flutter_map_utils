import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_utils/flutter_map_utils.dart';
import 'package:latlong2/latlong.dart';

/// Demonstrates the FlutterMapGeometryEditor all-in-one widget
/// with every feature composed together in a single call.
class AllInOnePage extends StatefulWidget {
  const AllInOnePage({super.key});

  @override
  State<AllInOnePage> createState() => _AllInOnePageState();
}

class _AllInOnePageState extends State<AllInOnePage> {
  final _drawingState = DrawingState();
  final _measureState = MeasurementState();

  @override
  void dispose() {
    _drawingState.dispose();
    _measureState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All-in-One Editor'),
        centerTitle: true,
      ),
      body: FlutterMapGeometryEditor(
        drawingState: _drawingState,
        measurementState: _measureState,
        mapOptions: const MapOptions(
          initialCenter: LatLng(51.509, -0.128),
          initialZoom: 14,
        ),
        tileLayer: TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        ),
        showToolbar: true,
        showInfoPanel: true,
        showCoordinateDisplay: true,
      ),
    );
  }
}
