import 'package:flutter/painting.dart';

import '../../models/muscle_state.dart';

/// Paleta dedicada del módulo `body_figure`. Aislada de [AppColors] global
/// porque el DESIGN.md de la figura especifica una paleta emerald distinta
/// del cyan/púrpura de la app.
class BodyFigurePalette {
  BodyFigurePalette._();

  // Muscle-state palette (DESIGN.md)
  static const idle = Color(0xFF064E3B);
  static const recovering = Color(0xFF022C22);
  static const secondary = Color(0xFF059669);
  static const active = Color(0xFF10B981);
  static const dominant = Color(0xFFECFDF5);
  static const silhouetteOutline = Color(0xFF065F46);

  /// Color base para un dot según el estado de su región.
  /// `null` (dot fuera de cualquier región) → `idle` con opacidad reducida.
  static Color colorForState(MuscleState? state) => switch (state) {
        MuscleState.dominant => dominant,
        MuscleState.active => active,
        MuscleState.secondary => secondary,
        MuscleState.recovering => recovering,
        MuscleState.idle => idle,
        null => idle,
      };

  /// Opacidad base por estado. `idle` queda atenuado para que el ojo se vaya
  /// a las regiones activas.
  static double baseOpacityForState(MuscleState? state) => switch (state) {
        MuscleState.dominant => 1.0,
        MuscleState.active => 0.95,
        MuscleState.secondary => 0.85,
        MuscleState.recovering => 0.55,
        MuscleState.idle => 0.40,
        null => 0.30,
      };

  /// Amplitud del breathing pulse por estado.
  /// `dominant` pulsa más fuerte (±25%); el resto sigue el global ±10%.
  static double pulseAmplitudeForState(MuscleState? state) =>
      state == MuscleState.dominant ? 0.25 : 0.10;
}
