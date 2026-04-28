import 'package:flutter/painting.dart';

import '../../models/muscle_group.dart';

/// Vista de la figura: frente o espalda.
enum BodyView { front, back }

/// Variante de silueta. Comparten taxonomía y region IDs; solo cambian
/// proporciones y outline.
enum FigureGender { male, female }

/// Datos geométricos de la figura: silueta global + polígonos por región.
///
/// Coordenadas en espacio NORMALIZADO `[0..1] × [0..1]` (origen top-left).
/// El painter las escala al canvas en runtime.
///
/// Estado actual (Phase C — pipeline mínimo):
/// - Silueta humanoide básica para vista frontal.
/// - Solo `chest` tiene polígono real. El resto de regiones quedan fuera de
///   `regions` y los dots dentro de la silueta caen como `idle` implícito.
/// - `back` y `female` reusan los datos de `front+male` mientras se itera el
///   pipeline; la diferenciación llega en Phase D.
class BodyMask {
  const BodyMask({
    required this.silhouette,
    required this.regions,
  });

  /// Polígono cerrado de la silueta. CCW. Solo se renderizan dots dentro.
  final List<Offset> silhouette;

  /// Polígonos por región muscular. Un dot dentro de la silueta se colorea
  /// según el estado de la primera región que lo contenga (orden de iteración).
  /// Regiones ausentes del map se asumen no-renderizables en esta vista.
  final Map<MuscleGroup, List<Offset>> regions;

  /// Selector de mask por (vista, género). Phase C: todos delegan a
  /// `_frontMaleScaffold` hasta que se itere arte por variante.
  static BodyMask forView(BodyView view, FigureGender gender) =>
      _buildFrontMaleScaffold();
}

/// Silueta humanoide simple en coordenadas normalizadas.
///
/// Se construye espejando una mitad izquierda (x ≤ 0.5) sobre el eje x = 0.5
/// para garantizar simetría exacta. Los vértices van de arriba (cabeza) hacia
/// abajo (pies) por el costado izquierdo del personaje vista frontal —
/// es decir, lado derecho del lector.
const _halfPerimeterLeft = <Offset>[
  // Cabeza
  Offset(0.50, 0.020), // top centro (vértice de espejado)
  Offset(0.45, 0.030),
  Offset(0.42, 0.075),
  Offset(0.43, 0.115),
  Offset(0.46, 0.140), // mandíbula
  // Cuello
  Offset(0.46, 0.170),
  // Hombro
  Offset(0.40, 0.190),
  Offset(0.30, 0.210),
  Offset(0.24, 0.235), // hombro outer
  // Brazo (lateral)
  Offset(0.21, 0.300), // bíceps outer
  Offset(0.19, 0.420), // codo outer
  Offset(0.20, 0.540), // antebrazo outer
  Offset(0.22, 0.625), // muñeca
  Offset(0.25, 0.640), // mano outer
  // Brazo (interno) — sube hacia axila
  Offset(0.28, 0.620),
  Offset(0.30, 0.540),
  Offset(0.32, 0.420),
  Offset(0.33, 0.300),
  Offset(0.36, 0.230), // axila
  // Torso
  Offset(0.38, 0.330), // costado pectoral
  Offset(0.39, 0.430), // costado torso
  Offset(0.39, 0.540), // cintura
  Offset(0.40, 0.610), // cadera outer
  // Pierna
  Offset(0.38, 0.700), // muslo outer
  Offset(0.37, 0.820), // rodilla outer
  Offset(0.38, 0.920), // pantorrilla outer
  Offset(0.40, 0.970), // tobillo
  Offset(0.43, 0.985), // pie outer
  Offset(0.48, 0.985), // pie inner
  // Entrepierna
  Offset(0.49, 0.620),
  Offset(0.50, 0.610), // centro abajo torso (vértice de espejado)
];

List<Offset> _buildSymmetricSilhouette() {
  const left = _halfPerimeterLeft;
  // Espejar: para cada punto en orden inverso (saltando los vértices del eje
  // de simetría que ya están en la lista izquierda), generar (1 - x, y).
  final mirrored = <Offset>[];
  for (var i = left.length - 1; i >= 0; i--) {
    final p = left[i];
    if (p.dx == 0.50) continue; // skip puntos sobre el eje de espejo
    mirrored.add(Offset(1 - p.dx, p.dy));
  }
  return [...left, ...mirrored];
}

BodyMask? _frontMaleCache;
BodyMask _buildFrontMaleScaffold() {
  return _frontMaleCache ??= BodyMask(
    silhouette: _buildSymmetricSilhouette(),
    regions: const {
      // Phase C: única región pulida. Trapezoide pectoral en el torso.
      MuscleGroup.chest: [
        Offset(0.40, 0.230),
        Offset(0.60, 0.230),
        Offset(0.60, 0.330),
        Offset(0.40, 0.330),
      ],
    },
  );
}
