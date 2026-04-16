import '../core/constants/db_constants.dart';

/// Una serie individual dentro de un ejercicio de sesión.
/// Ejemplo: Serie 2 → 10 reps × 80 kg, 90 s descanso.
class SessionSet {
  const SessionSet({
    this.id,
    required this.sessionExerciseId,
    required this.setNumber,
    this.reps,
    this.weightKg,
    this.restSeconds,
    this.rpe,
    this.rir,
  });

  final int? id;
  final int sessionExerciseId;
  final int setNumber;
  final int? reps;
  final double? weightKg;
  final int? restSeconds;
  /// RPE (Rating of Perceived Exertion): esfuerzo percibido, escala 1–10.
  final int? rpe;
  /// RIR (Reps in Reserve): repeticiones en reserva antes del fallo.
  final int? rir;

  /// Volumen de esta serie: reps × peso.
  double get volume => (reps ?? 0) * (weightKg ?? 0);

  SessionSet copyWith({
    int? id,
    int? sessionExerciseId,
    int? setNumber,
    int? reps,
    double? weightKg,
    int? restSeconds,
    int? rpe,
    int? rir,
  }) =>
      SessionSet(
        id: id ?? this.id,
        sessionExerciseId: sessionExerciseId ?? this.sessionExerciseId,
        setNumber: setNumber ?? this.setNumber,
        reps: reps ?? this.reps,
        weightKg: weightKg ?? this.weightKg,
        restSeconds: restSeconds ?? this.restSeconds,
        rpe: rpe ?? this.rpe,
        rir: rir ?? this.rir,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) DbConstants.cSsId: id,
        DbConstants.cSsSessionExerciseId: sessionExerciseId,
        DbConstants.cSsSetNumber: setNumber,
        DbConstants.cSsReps: reps,
        DbConstants.cSsWeightKg: weightKg,
        DbConstants.cSsRestSeconds: restSeconds,
        DbConstants.cSsRpe: rpe,
        DbConstants.cSsRir: rir,
      };

  factory SessionSet.fromMap(Map<String, dynamic> map) => SessionSet(
        id: map[DbConstants.cSsId] as int?,
        sessionExerciseId: map[DbConstants.cSsSessionExerciseId] as int,
        setNumber: map[DbConstants.cSsSetNumber] as int,
        reps: map[DbConstants.cSsReps] as int?,
        weightKg: map[DbConstants.cSsWeightKg] as double?,
        restSeconds: map[DbConstants.cSsRestSeconds] as int?,
        rpe: map[DbConstants.cSsRpe] as int?,
        rir: map[DbConstants.cSsRir] as int?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SessionSet && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SessionSet(set: $setNumber, reps: $reps, weight: ${weightKg}kg, rpe: $rpe, rir: $rir)';
}
