import 'dart:async';
import 'package:flutter/material.dart';

/// Point along a stylus pen stroke with Wacom Pro Pen 2 / EMR pressure level (0.0 to 1.0).
class CanvasStrokePoint {
  const CanvasStrokePoint({
    required this.offset,
    required this.pressure,
    required this.timestamp,
  });

  final Offset offset;
  final double pressure; // 0.0 to 1.0 (8192 levels mapped)
  final int timestamp;
}

/// Vector stroke drawn on the collaborative canvas.
class VectorStroke {
  const VectorStroke({
    required this.id,
    required this.authorPeerId,
    required this.authorName,
    required this.color,
    required this.baseWidth,
    required this.points,
  });

  final String id;
  final String authorPeerId;
  final String authorName;
  final Color color;
  final double baseWidth;
  final List<CanvasStrokePoint> points;

  VectorStroke copyWith({
    String? id,
    String? authorPeerId,
    String? authorName,
    Color? color,
    double? baseWidth,
    List<CanvasStrokePoint>? points,
  }) {
    return VectorStroke(
      id: id ?? this.id,
      authorPeerId: authorPeerId ?? this.authorPeerId,
      authorName: authorName ?? this.authorName,
      color: color ?? this.color,
      baseWidth: baseWidth ?? this.baseWidth,
      points: points ?? this.points,
    );
  }
}

/// Collaborative vector canvas state manager for Wacom MobileStudio & stylus devices.
class WacomCanvasService {
  WacomCanvasService({
    required this.localPeerId,
    required this.localAuthorName,
  });

  final String localPeerId;
  final String localAuthorName;

  final List<VectorStroke> _strokes = [];
  final _strokesController = StreamController<List<VectorStroke>>.broadcast();
  Stream<List<VectorStroke>> get strokesStream => _strokesController.stream;
  List<VectorStroke> get strokes => List.unmodifiable(_strokes);

  Color _activeColor = const Color(0xFF7C6CF2);
  Color get activeColor => _activeColor;

  double _brushSize = 3.5;
  double get brushSize => _brushSize;

  void setColor(Color color) => _activeColor = color;
  void setBrushSize(double size) => _brushSize = size;

  void addStroke(VectorStroke stroke) {
    _strokes.add(stroke);
    _strokesController.add(strokes);
  }

  void clearCanvas() {
    _strokes.clear();
    _strokesController.add(strokes);
  }

  void undo() {
    if (_strokes.isNotEmpty) {
      _strokes.removeLast();
      _strokesController.add(strokes);
    }
  }

  void dispose() {
    _strokesController.close();
  }
}
