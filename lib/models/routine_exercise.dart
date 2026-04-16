import '../core/constants/db_constants.dart';

/// Ejercicio dentro de una plantilla de rutina, con objetivos opcionales.
class RoutineExercise {
  const RoutineExercise({
    this.id,
    required this.routineId,
    required this.exerciseId,
    this.exerciseOrder = 0,
    this.targetSets,
    this.targetReps,
    this.targetWeightKg,
  });

  final int? id;
  final int routineId;
  final int exerciseId;
  final int exerciseOrder;
  final int? targetSets;
  final int? targetReps;
  final double? targetWeightKg;

  RoutineExercise copyWith({
    int? id,
    int? routineId,
    int? exerciseId,
    int? exerciseOrder,
    int? targetSets,
    int? targetReps,
    double? targetWeightKg,
  }) =>
      RoutineExercise(
        id: id ?? this.id,
        routineId: routineId ?? this.routineId,
        exerciseId: exerciseId ?? this.exerciseId,
        exerciseOrder: exerciseOrder ?? this.exerciseOrder,
        targetSets: targetSets ?? this.targetSets,
        targetReps: targetReps ?? this.targetReps,
        targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) DbConstants.cReId: id,
        DbConstants.cReRoutineId: routineId,
        DbConstants.cReExerciseId: exerciseId,
        DbConstants.cReOrder: exerciseOrder,
        DbConstants.cReTargetSets: targetSets,
        DbConstants.cReTargetReps: targetReps,
        DbConstants.cReTargetWeightKg: targetWeightKg,
      };

  factory RoutineExercise.fromMap(Map<String, dynamic> map) => RoutineExercise(
        id: map[DbConstants.cReId] as int?,
        routineId: map[DbConstants.cReRoutineId] as int,
        exerciseId: map[DbConstants.cReExerciseId] as int,
        exerciseOrder: map[DbConstants.cReOrder] as int? ?? 0,
        targetSets: map[DbConstants.cReTargetSets] as int?,
        targetReps: map[DbConstants.cReTargetReps] as int?,
        targetWeightKg: map[DbConstants.cReTargetWeightKg] as double?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is RoutineExercise && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
