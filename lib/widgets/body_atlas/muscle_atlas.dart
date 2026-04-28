import 'package:flutter/material.dart';
import 'package:flutter_body_atlas/flutter_body_atlas.dart' as atlas;

import '../../models/muscle_group.dart';
import '../../models/muscle_state.dart';
import 'body_atlas_palette.dart';
import 'muscle_group_atlas_mapping.dart';

/// Atlas anatómico interactivo. Por defecto el cuerpo se ve "apagado"
/// (tono uniforme oscuro). Cualquier [MuscleGroup] presente en [states]
/// se ilumina con el color correspondiente del [BodyAtlasPalette].
///
/// Soporta interacción: al tocar un músculo del SVG, se invoca
/// [onTapGroup] con el [MuscleGroup] resuelto a partir del mapeo inverso.
/// Si el músculo tocado no pertenece a ningún grupo conocido, no se
/// invoca el callback.
///
/// Atribución (CC BY 4.0): SVG de `flutter_body_atlas`, autoría de
/// Ryan Graves.
class MuscleAtlas extends StatelessWidget {
  const MuscleAtlas({
    super.key,
    required this.view,
    this.states = const {},
    this.onTapGroup,
  });

  final BodyView view;
  final Map<MuscleGroup, MuscleState> states;
  final ValueChanged<MuscleGroup>? onTapGroup;

  @override
  Widget build(BuildContext context) {
    final colorMapping = <atlas.MuscleInfo, Color?>{};

    // 1) Pintar TODO el cuerpo en color "apagado" — base.
    for (final info in atlas.MuscleCatalog.all) {
      colorMapping[info] = BodyAtlasPalette.dimmed;
    }

    // 2) Sobrescribir con colores activos para los grupos seleccionados.
    for (final entry in states.entries) {
      final color = BodyAtlasPalette.colorForState(entry.value);
      final muscles = muscleGroupAtlasMapping[entry.key] ?? const [];
      for (final muscle in muscles) {
        final info = atlas.MuscleCatalog.byMuscle[muscle];
        if (info != null) colorMapping[info] = color;
      }
    }

    return atlas.BodyAtlasView<atlas.MuscleInfo>(
      view: view == BodyView.front
          ? atlas.AtlasAsset.musclesFront
          : atlas.AtlasAsset.musclesBack,
      resolver: const atlas.MuscleResolver(),
      colorMapping: colorMapping,
      onTapElement: onTapGroup == null
          ? null
          : (info) {
              final group = atlasMuscleToGroup[info.muscle];
              if (group != null) onTapGroup!(group);
            },
    );
  }
}
