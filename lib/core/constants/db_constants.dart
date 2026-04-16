/// Nombres de tablas y columnas de la base de datos.
/// Centralizar aquí evita typos y facilita refactors.
abstract final class DbConstants {
  // ── Base de datos ────────────────────────────────────────────────────────────
  static const String dbName = 'gym_tracker.db';
  static const int dbVersion = 4;

  // ── Tabla: exercises ─────────────────────────────────────────────────────────
  static const String tExercises = 'exercises';
  static const String cExId = 'id';
  static const String cExName = 'name';
  static const String cExMuscleCategory = 'muscle_category';
  static const String cExIsCustom = 'is_custom';

  // ── Tabla: sessions ──────────────────────────────────────────────────────────
  static const String tSessions = 'sessions';
  static const String cSeId = 'id';
  static const String cSeDate = 'date';
  static const String cSeDurationSeconds = 'duration_seconds';
  static const String cSeNotes = 'notes';
  static const String cSeRoutineId = 'routine_id';

  // ── Tabla: session_exercises ─────────────────────────────────────────────────
  static const String tSessionExercises = 'session_exercises';
  static const String cSxId = 'id';
  static const String cSxSessionId = 'session_id';
  static const String cSxExerciseId = 'exercise_id';
  static const String cSxOrder = 'exercise_order';

  // ── Tabla: session_sets ──────────────────────────────────────────────────────
  static const String tSessionSets = 'session_sets';
  static const String cSsId = 'id';
  static const String cSsSessionExerciseId = 'session_exercise_id';
  static const String cSsSetNumber = 'set_number';
  static const String cSsReps = 'reps';
  static const String cSsWeightKg = 'weight_kg';
  static const String cSsRestSeconds = 'rest_seconds';
  static const String cSsRpe = 'rpe';
  static const String cSsRir = 'rir';

  // ── Tabla: routines ──────────────────────────────────────────────────────────
  static const String tRoutines = 'routines';
  static const String cRoId = 'id';
  static const String cRoName = 'name';
  static const String cRoNotes = 'notes';

  // ── Tabla: routine_exercises ─────────────────────────────────────────────────
  static const String tRoutineExercises = 'routine_exercises';
  static const String cReId = 'id';
  static const String cReRoutineId = 'routine_id';
  static const String cReExerciseId = 'exercise_id';
  static const String cReOrder = 'exercise_order';
  static const String cReTargetSets = 'target_sets';
  static const String cReTargetReps = 'target_reps';
  static const String cReTargetWeightKg = 'target_weight_kg';

  // ── Tabla: body_entries ──────────────────────────────────────────────────────
  static const String tBodyEntries = 'body_entries';
  static const String cBeId = 'id';
  static const String cBeDate = 'date';
  static const String cBeWeightKg = 'weight_kg';
  static const String cBeHeightCm = 'height_cm';
  static const String cBeNotes = 'notes';

  // ── Tabla: body_measurements ─────────────────────────────────────────────────
  static const String tBodyMeasurements = 'body_measurements';
  static const String cBmId = 'id';
  static const String cBmBodyEntryId = 'body_entry_id';
  static const String cBmType = 'measurement_type';
  static const String cBmValueCm = 'value_cm';
}
