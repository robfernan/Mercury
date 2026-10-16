import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../theme/mercury_theme.dart';

/// Modal dialog providing real-time vector canvas drawing with Wacom stylus pressure tracking
class WacomCanvasModal extends ConsumerStatefulWidget {
  const WacomCanvasModal({super.key});

  @override
  ConsumerState<WacomCanvasModal> createState() => _WacomCanvasModalState();
}

class _WacomCanvasModalState extends ConsumerState<WacomCanvasModal> {
  List<CanvasStrokePoint> _currentStrokePoints = [];
  double _lastPressure = 0.5;

  static const _palette = [
    Color(0xFF7C6CF2), // Violet
    Color(0xFF3DD68C), // Emerald
    Color(0xFF3FA7D6), // Cyber Blue
    Color(0xFFE5537A), // Hot Pink
    Color(0xFFE8A33D), // Amber
    Color(0xFFFFFFFF), // White
  ];

  @override
  Widget build(BuildContext context) {
    final canvasService = ref.watch(wacomCanvasServiceProvider);
    final strokes = canvasService.strokes;

    return Dialog(
      backgroundColor: MercuryColors.surfaceRaised,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: MercuryColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 720),
        child: Column(
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: MercuryColors.border)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.draw_rounded, color: MercuryColors.accent, size: 22),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Wacom MobileStudio Live Canvas',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          color: MercuryColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Wacom Pro Pen 2 8192-level EMR pressure sensitivity · Collaborative vector stream',
                        style: TextStyle(
                          fontSize: 12,
                          color: MercuryColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Brush Size Selector
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: MercuryColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: MercuryColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Size: ',
                          style: TextStyle(fontSize: 12, color: MercuryColors.textMuted),
                        ),
                        Text(
                          '${canvasService.brushSize.toStringAsFixed(1)}px',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Undo Stroke',
                    icon: const Icon(Icons.undo_rounded, size: 20),
                    onPressed: () => setState(() => canvasService.undo()),
                  ),
                  IconButton(
                    tooltip: 'Clear Canvas',
                    icon: const Icon(Icons.delete_sweep_rounded, size: 20, color: MercuryColors.danger),
                    onPressed: () => setState(() => canvasService.clearCanvas()),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Canvas Drawing Surface
            Expanded(
              child: Stack(
                children: [
                  // Drawing Surface
                  Container(
                    color: const Color(0xFF101216),
                    width: double.infinity,
                    height: double.infinity,
                    child: Listener(
                      onPointerDown: (e) {
                        final p = e.pressure == 0.0 ? 0.5 : e.pressure;
                        _lastPressure = p;
                        _currentStrokePoints = [
                          CanvasStrokePoint(
                            offset: e.localPosition,
                            pressure: p,
                            timestamp: DateTime.now().millisecondsSinceEpoch,
                          ),
                        ];
                        setState(() {});
                      },
                      onPointerMove: (e) {
                        final p = e.pressure == 0.0 ? 0.5 : e.pressure;
                        _lastPressure = p;
                        _currentStrokePoints.add(
                          CanvasStrokePoint(
                            offset: e.localPosition,
                            pressure: p,
                            timestamp: DateTime.now().millisecondsSinceEpoch,
                          ),
                        );
                        setState(() {});
                      },
                      onPointerUp: (e) {
                        if (_currentStrokePoints.isNotEmpty) {
                          canvasService.addStroke(
                            VectorStroke(
                              id: 'stroke_${DateTime.now().millisecondsSinceEpoch}',
                              authorPeerId: canvasService.localPeerId,
                              authorName: canvasService.localAuthorName,
                              color: canvasService.activeColor,
                              baseWidth: canvasService.brushSize,
                              points: List.unmodifiable(_currentStrokePoints),
                            ),
                          );
                          _currentStrokePoints = [];
                          setState(() {});
                        }
                      },
                      child: CustomPaint(
                        painter: _VectorCanvasPainter(
                          strokes: strokes,
                          activePoints: _currentStrokePoints,
                          activeColor: canvasService.activeColor,
                          activeBaseWidth: canvasService.brushSize,
                        ),
                        size: Size.infinite,
                      ),
                    ),
                  ),

                  // Palette Toolbar overlay
                  Positioned(
                    left: 16,
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: MercuryColors.surfaceRaised.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: MercuryColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final color in _palette)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: InkWell(
                                onTap: () => setState(() => canvasService.setColor(color)),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: canvasService.activeColor == color
                                          ? Colors.white
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          Container(
                            height: 20,
                            width: 1,
                            color: MercuryColors.border,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'EMR: ${(_lastPressure * 8192).round()} / 8192',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: MercuryColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VectorCanvasPainter extends CustomPainter {
  const _VectorCanvasPainter({
    required this.strokes,
    required this.activePoints,
    required this.activeColor,
    required this.activeBaseWidth,
  });

  final List<VectorStroke> strokes;
  final List<CanvasStrokePoint> activePoints;
  final Color activeColor;
  final double activeBaseWidth;

  @override
  void paint(Canvas canvas, Size size) {
    // Render completed strokes
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      _paintPoints(canvas, stroke.points, stroke.color, stroke.baseWidth);
    }

    // Render active drawing stroke
    if (activePoints.isNotEmpty) {
      _paintPoints(canvas, activePoints, activeColor, activeBaseWidth);
    }
  }

  void _paintPoints(
    Canvas canvas,
    List<CanvasStrokePoint> points,
    Color color,
    double baseWidth,
  ) {
    if (points.length < 2) {
      if (points.isNotEmpty) {
        final p = points.first;
        final paint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        canvas.drawCircle(p.offset, (baseWidth * p.pressure).clamp(1.0, 20.0), paint);
      }
      return;
    }

    for (var i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final strokeWidth = (baseWidth * ((p1.pressure + p2.pressure) / 2)).clamp(1.0, 24.0);

      final paint = Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      canvas.drawLine(p1.offset, p2.offset, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _VectorCanvasPainter oldDelegate) => true;
}
