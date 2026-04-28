import 'package:flutter/material.dart';
import 'package:flutter_body_atlas/flutter_body_atlas.dart' as atlas;

import '../../models/muscle_group.dart';
import 'body_atlas_palette.dart';
import 'muscle_group_atlas_mapping.dart';

/// Mini renderizado de un único [MuscleGroup]. Pinta el resto del cuerpo
/// como transparente y solo deja visible el grupo indicado, en color de
/// estado dominante. Pensado para incrustar en filas pequeñas (ej. cada
/// set de un ejercicio en `SessionScreen`).
///
/// El bounding box sigue siendo el del cuerpo completo del atlas, así que
/// el músculo se ve a escala dentro del box (no recortado al músculo).
class MuscleMiniView extends StatelessWidget {
  const MuscleMiniView({
    super.key,
    required this.group,
    this.color,
  });

  final MuscleGroup group;

  /// Color del músculo iluminado. Si `null`, usa `BodyAtlasPalette.dominant`.
  final Color? color;

  BodyView get _view =>
      group.visibleFront ? BodyView.front : BodyView.back;

  @override
  Widget build(BuildContext context) {
    final highlight = color ?? BodyAtlasPalette.dominant;
    final colorMapping = <atlas.MuscleInfo, Color?>{};

    for (final info in atlas.MuscleCatalog.all) {
      colorMapping[info] = Colors.transparent;
    }

    final muscles = muscleGroupAtlasMapping[group] ?? const [];
    for (final m in muscles) {
      final info = atlas.MuscleCatalog.byMuscle[m];
      if (info != null) colorMapping[info] = highlight;
    }

    return atlas.BodyAtlasView<atlas.MuscleInfo>(
      view: _view == BodyView.front
          ? atlas.AtlasAsset.musclesFront
          : atlas.AtlasAsset.musclesBack,
      resolver: const atlas.MuscleResolver(),
      colorMapping: colorMapping,
    );
  }
}
