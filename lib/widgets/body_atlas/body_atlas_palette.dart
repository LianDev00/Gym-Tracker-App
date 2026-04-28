import 'package:flutter/painting.dart';

import '../../models/muscle_state.dart';

/// Paleta del atlas anatómico. Inspirada en la paleta esmeralda original
/// del DESIGN.md, ajustada para SVG (no dot-matrix).
class BodyAtlasPalette {
  BodyAtlasPalette._();

  // Estados activos (músculos resaltados)
  static const idle = Color(0xFF064E3B);
  static const recovering = Color(0xFF022C22);
  static const secondary = Color(0xFF059669);
  static const active = Color(0xFF10B981);
  static const dominant = Color(0xFFECFDF5);

  // Estado por defecto: cuerpo "apagado"
  static const dimmed = Color(0xFF1F2937);

  static Color colorForState(MuscleState? state) => switch (state) {
        MuscleState.dominant => dominant,
        MuscleState.active => active,
        MuscleState.secondary => secondary,
        MuscleState.recovering => recovering,
        MuscleState.idle => idle,
        null => dimmed,
      };
}

/// Vista del cuerpo. Coincide 1:1 con `AtlasAsset.musclesFront/Back`.
enum BodyView { front, back }
