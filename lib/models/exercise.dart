import '../core/constants/db_constants.dart';
import 'muscle_category.dart';
import 'muscle_group.dart';

class Exercise {
  const Exercise({
    this.id,
    required this.name,
    required this.muscleCategory,
    this.isCustom = false,
    this.isBodyweight = false,
    this.muscles = const {},
  });

  final int? id;
  final String name;
  final MuscleCategory muscleCategory;
  final bool isCustom;

  /// `true` si el ejercicio se realiza con peso corporal (lagartijas, dominadas,
  /// fondos, etc.) y por tanto **no** debe pedir kilos por set. El volumen se
  /// imputa luego en estadísticas multiplicando reps × último peso corporal
  /// registrado al momento de la sesión.
  final bool isBodyweight;

  /// Atribución granular del ejercicio a uno o más [MuscleGroup] con su [MuscleRole].
  /// Persistido en la tabla join `exercise_muscles`, no en la fila de `exercises`.
  /// `ExerciseService` lo carga y guarda automáticamente.
  final Map<MuscleGroup, MuscleRole> muscles;

  Exercise copyWith({
    int? id,
    String? name,
    MuscleCategory? muscleCategory,
    bool? isCustom,
    bool? isBodyweight,
    Map<MuscleGroup, MuscleRole>? muscles,
  }) =>
      Exercise(
        id: id ?? this.id,
        name: name ?? this.name,
        muscleCategory: muscleCategory ?? this.muscleCategory,
        isCustom: isCustom ?? this.isCustom,
        isBodyweight: isBodyweight ?? this.isBodyweight,
        muscles: muscles ?? this.muscles,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) DbConstants.cExId: id,
        DbConstants.cExName: name,
        DbConstants.cExMuscleCategory: muscleCategory.name,
        DbConstants.cExIsCustom: isCustom ? 1 : 0,
        DbConstants.cExIsBodyweight: isBodyweight ? 1 : 0,
      };

  factory Exercise.fromMap(Map<String, dynamic> map) => Exercise(
        id: map[DbConstants.cExId] as int?,
        name: map[DbConstants.cExName] as String,
        muscleCategory:
            MuscleCategory.fromString(map[DbConstants.cExMuscleCategory] as String),
        isCustom: (map[DbConstants.cExIsCustom] as int) == 1,
        isBodyweight:
            (map[DbConstants.cExIsBodyweight] as int? ?? 0) == 1,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Exercise && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Exercise(id: $id, name: $name, category: ${muscleCategory.name})';
}
