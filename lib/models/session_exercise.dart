import '../core/constants/db_constants.dart';

/// Representa un ejercicio realizado dentro de una sesión de entrenamiento.
/// Un [SessionExercise] agrupa varios [SessionSet].
class SessionExercise {
  const SessionExercise({
    this.id,
    required this.sessionId,
    required this.exerciseId,
    this.exerciseOrder = 0,
  });

  final int? id;
  final int sessionId;
  final int exerciseId;
  final int exerciseOrder;

  SessionExercise copyWith({
    int? id,
    int? sessionId,
    int? exerciseId,
    int? exerciseOrder,
  }) =>
      SessionExercise(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        exerciseId: exerciseId ?? this.exerciseId,
        exerciseOrder: exerciseOrder ?? this.exerciseOrder,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) DbConstants.cSxId: id,
        DbConstants.cSxSessionId: sessionId,
        DbConstants.cSxExerciseId: exerciseId,
        DbConstants.cSxOrder: exerciseOrder,
      };

  factory SessionExercise.fromMap(Map<String, dynamic> map) => SessionExercise(
        id: map[DbConstants.cSxId] as int?,
        sessionId: map[DbConstants.cSxSessionId] as int,
        exerciseId: map[DbConstants.cSxExerciseId] as int,
        exerciseOrder: map[DbConstants.cSxOrder] as int? ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SessionExercise && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
