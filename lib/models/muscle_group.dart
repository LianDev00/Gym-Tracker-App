import 'muscle_category.dart';

/// Grupos musculares granulares — drive la figura anatómica y la atribución
/// por ejercicio. Paralelo (no reemplazo) de [MuscleCategory], que sigue
/// usándose para agrupar listas en la UI.
enum MuscleGroup {
  chest,
  shouldersFront,
  shouldersLateral,
  shouldersRear,
  biceps,
  triceps,
  forearms,
  abs,
  obliques,
  traps,
  lats,
  midBack,
  lowerBack,
  quads,
  adductors,
  hamstrings,
  glutes,
  calves;

  String get displayName => switch (this) {
        MuscleGroup.chest => 'Pecho',
        MuscleGroup.shouldersFront => 'Hombro frontal',
        MuscleGroup.shouldersLateral => 'Hombro lateral',
        MuscleGroup.shouldersRear => 'Hombro posterior',
        MuscleGroup.biceps => 'Bíceps',
        MuscleGroup.triceps => 'Tríceps',
        MuscleGroup.forearms => 'Antebrazos',
        MuscleGroup.abs => 'Abdomen',
        MuscleGroup.obliques => 'Oblicuos',
        MuscleGroup.traps => 'Trapecios',
        MuscleGroup.lats => 'Dorsales',
        MuscleGroup.midBack => 'Espalda media',
        MuscleGroup.lowerBack => 'Lumbares',
        MuscleGroup.quads => 'Cuádriceps',
        MuscleGroup.adductors => 'Aductores',
        MuscleGroup.hamstrings => 'Femorales',
        MuscleGroup.glutes => 'Glúteos',
        MuscleGroup.calves => 'Pantorrillas',
      };

  bool get visibleFront => switch (this) {
        MuscleGroup.chest ||
        MuscleGroup.shouldersFront ||
        MuscleGroup.shouldersLateral ||
        MuscleGroup.biceps ||
        MuscleGroup.forearms ||
        MuscleGroup.abs ||
        MuscleGroup.obliques ||
        MuscleGroup.traps ||
        MuscleGroup.quads ||
        MuscleGroup.adductors ||
        MuscleGroup.calves =>
          true,
        _ => false,
      };

  bool get visibleBack => switch (this) {
        MuscleGroup.shouldersLateral ||
        MuscleGroup.shouldersRear ||
        MuscleGroup.triceps ||
        MuscleGroup.forearms ||
        MuscleGroup.traps ||
        MuscleGroup.lats ||
        MuscleGroup.midBack ||
        MuscleGroup.lowerBack ||
        MuscleGroup.hamstrings ||
        MuscleGroup.glutes ||
        MuscleGroup.calves =>
          true,
        _ => false,
      };

  static MuscleGroup fromString(String value) =>
      MuscleGroup.values.firstWhere(
        (e) => e.name == value,
        orElse: () => MuscleGroup.chest,
      );
}

/// Rol con que un ejercicio trabaja un [MuscleGroup].
/// `dominant` = músculo principal del movimiento.
/// `secondary` = músculo de apoyo / sinergista.
enum MuscleRole {
  dominant,
  secondary;

  static MuscleRole fromString(String value) =>
      MuscleRole.values.firstWhere(
        (e) => e.name == value,
        orElse: () => MuscleRole.secondary,
      );
}

/// Mapeo coarse → granular. Usado cuando la UI agrupa por [MuscleCategory]
/// pero la figura necesita saber qué regiones pintar.
extension MuscleCategoryRollup on MuscleCategory {
  List<MuscleGroup> get muscleGroups => switch (this) {
        MuscleCategory.pecho => const [MuscleGroup.chest],
        MuscleCategory.espalda => const [
            MuscleGroup.lats,
            MuscleGroup.midBack,
            MuscleGroup.lowerBack,
            MuscleGroup.traps,
          ],
        MuscleCategory.hombros => const [
            MuscleGroup.shouldersFront,
            MuscleGroup.shouldersLateral,
            MuscleGroup.shouldersRear,
          ],
        MuscleCategory.biceps => const [
            MuscleGroup.biceps,
            MuscleGroup.forearms,
          ],
        MuscleCategory.triceps => const [
            MuscleGroup.triceps,
            MuscleGroup.forearms,
          ],
        MuscleCategory.piernas => const [
            MuscleGroup.quads,
            MuscleGroup.hamstrings,
            MuscleGroup.adductors,
            MuscleGroup.calves,
          ],
        MuscleCategory.gluteos => const [MuscleGroup.glutes],
        MuscleCategory.core => const [
            MuscleGroup.abs,
            MuscleGroup.obliques,
            MuscleGroup.lowerBack,
          ],
        MuscleCategory.cardio => const [],
      };
}
