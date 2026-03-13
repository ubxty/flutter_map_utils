import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';

/// Displays the current cursor coordinates on the map.
///
/// Listen to pointer hover events and update the displayed coordinate.
class CoordinateDisplay extends StatefulWidget {
  /// Coordinate format: 'dd' (decimal degrees), 'dms' (degrees/minutes/seconds).
  final String format;

  /// Number of decimal places for DD format.
  final int precision;

  const CoordinateDisplay({
    super.key,
    this.format = 'dd',
    this.precision = 6,
  });

  @override
  State<CoordinateDisplay> createState() => CoordinateDisplayState();
}

class CoordinateDisplayState extends State<CoordinateDisplay> {
  LatLng? _currentLatLng;

  /// Call this from your pointer hover handler.
  void updatePosition(LatLng? position) {
    if (_currentLatLng != position) {
      setState(() => _currentLatLng = position);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = _currentLatLng != null
        ? _formatCoordinate(_currentLatLng!)
        : '—';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xE6333333),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 11,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  String _formatCoordinate(LatLng point) {
    if (widget.format == 'dms') {
      return '${_toDMS(point.latitude, 'N', 'S')}  '
          '${_toDMS(point.longitude, 'E', 'W')}';
    }
    return '${point.latitude.toStringAsFixed(widget.precision)}, '
        '${point.longitude.toStringAsFixed(widget.precision)}';
  }

  String _toDMS(double value, String pos, String neg) {
    final dir = value >= 0 ? pos : neg;
    final abs = value.abs();
    final deg = abs.floor();
    final minFull = (abs - deg) * 60;
    final min = minFull.floor();
    final sec = (minFull - min) * 60;
    return '$deg°${min.toString().padLeft(2, '0')}\'${sec.toStringAsFixed(1).padLeft(4, '0')}"$dir';
  }
}
