import '../core/constants/db_constants.dart';
import 'muscle_category.dart';

class Exercise {
  const Exercise({
    this.id,
    required this.name,
    required this.muscleCategory,
    this.isCustom = false,
  });

  final int? id;
  final String name;
  final MuscleCategory muscleCategory;
  final bool isCustom;

  Exercise copyWith({
    int? id,
    String? name,
    MuscleCategory? muscleCategory,
    bool? isCustom,
  }) =>
      Exercise(
        id: id ?? this.id,
        name: name ?? this.name,
        muscleCategory: muscleCategory ?? this.muscleCategory,
        isCustom: isCustom ?? this.isCustom,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) DbConstants.cExId: id,
        DbConstants.cExName: name,
        DbConstants.cExMuscleCategory: muscleCategory.name,
        DbConstants.cExIsCustom: isCustom ? 1 : 0,
      };

  factory Exercise.fromMap(Map<String, dynamic> map) => Exercise(
        id: map[DbConstants.cExId] as int?,
        name: map[DbConstants.cExName] as String,
        muscleCategory:
            MuscleCategory.fromString(map[DbConstants.cExMuscleCategory] as String),
        isCustom: (map[DbConstants.cExIsCustom] as int) == 1,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Exercise && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Exercise(id: $id, name: $name, category: ${muscleCategory.name})';
}
