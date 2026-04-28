import 'package:flutter/material.dart';

import '../../models/muscle_group.dart';
import '../../models/muscle_state.dart';
import 'body_figure_palette.dart';
import 'body_mask.dart';

/// CustomPainter del dot-matrix anatómico.
///
/// Pipeline:
/// 1. Escala el polígono de la silueta y de cada región al tamaño del canvas.
/// 2. Genera un grid regular de dots cubriendo el bounding box de la silueta.
/// 3. Por cada dot: point-in-polygon contra la silueta → descarta si está fuera.
/// 4. Si está dentro, busca la primera región que lo contenga → toma el estado.
/// 5. Color = paleta por estado, modulado por el breathing pulse.
class BodyFigurePainter extends CustomPainter {
  BodyFigurePainter({
    required this.mask,
    required this.states,
    required this.pulse,
    this.dotSpacing = 7.0,
    this.dotRadius = 1.6,
    super.repaint,
  });

  final BodyMask mask;
  final Map<MuscleGroup, MuscleState> states;

  /// Valor en [0..1] del breathing pulse — el widget pasa `controller.value`.
  final double pulse;

  final double dotSpacing;
  final double dotRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final silhouette = _scale(mask.silhouette, size);
    final scaledRegions = <MuscleGroup, List<Offset>>{
      for (final entry in mask.regions.entries)
        entry.key: _scale(entry.value, size),
    };
    final bounds = _bounds(silhouette);

    final paint = Paint()..style = PaintingStyle.fill;

    // Pulse: 0..1 desde AnimationController. Centramos en 0 (-0.5..+0.5)
    // y duplicamos para usar como factor signed en [-1..+1].
    final signedPulse = (pulse - 0.5) * 2;

    for (var y = bounds.top; y <= bounds.bottom; y += dotSpacing) {
      for (var x = bounds.left; x <= bounds.right; x += dotSpacing) {
        final dot = Offset(x, y);
        if (!_pointInPolygon(dot, silhouette)) continue;

        MuscleGroup? region;
        for (final entry in scaledRegions.entries) {
          if (_pointInPolygon(dot, entry.value)) {
            region = entry.key;
            break;
          }
        }
        final state = region != null ? states[region] : null;

        final baseColor = BodyFigurePalette.colorForState(state);
        final baseOpacity = BodyFigurePalette.baseOpacityForState(state);
        final amplitude = BodyFigurePalette.pulseAmplitudeForState(state);
        final modulated = (baseOpacity * (1 + signedPulse * amplitude))
            .clamp(0.0, 1.0);

        paint.color = baseColor.withValues(alpha: modulated);
        canvas.drawCircle(dot, dotRadius, paint);
      }
    }

    _strokeOutline(canvas, silhouette);
  }

  void _strokeOutline(Canvas canvas, List<Offset> silhouette) {
    final path = Path()..moveTo(silhouette.first.dx, silhouette.first.dy);
    for (final p in silhouette.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = BodyFigurePalette.silhouetteOutline.withValues(alpha: 0.4);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant BodyFigurePainter old) =>
      old.pulse != pulse ||
      old.mask != mask ||
      !_mapEquals(old.states, states);
}

bool _mapEquals(Map<MuscleGroup, MuscleState> a, Map<MuscleGroup, MuscleState> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

List<Offset> _scale(List<Offset> normalized, Size size) => [
      for (final p in normalized) Offset(p.dx * size.width, p.dy * size.height),
    ];

Rect _bounds(List<Offset> polygon) {
  var minX = polygon.first.dx, maxX = polygon.first.dx;
  var minY = polygon.first.dy, maxY = polygon.first.dy;
  for (final p in polygon) {
    if (p.dx < minX) minX = p.dx;
    if (p.dx > maxX) maxX = p.dx;
    if (p.dy < minY) minY = p.dy;
    if (p.dy > maxY) maxY = p.dy;
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

/// Ray casting estándar — devuelve true si el punto está dentro del polígono.
bool _pointInPolygon(Offset point, List<Offset> polygon) {
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final a = polygon[i];
    final b = polygon[j];
    final intersects = ((a.dy > point.dy) != (b.dy > point.dy)) &&
        (point.dx < (b.dx - a.dx) * (point.dy - a.dy) / (b.dy - a.dy) + a.dx);
    if (intersects) inside = !inside;
  }
  return inside;
}
