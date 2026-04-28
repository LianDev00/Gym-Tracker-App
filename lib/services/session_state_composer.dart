import '../models/exercise.dart';
import '../models/muscle_group.dart';
import '../models/muscle_state.dart';
import '../models/session_set.dart';

/// Una entrada de sesión: un ejercicio con sus series registradas.
/// Tipo `record` (Dart 3+) — sin clase wrapper.
typedef SessionEntry = ({Exercise exercise, List<SessionSet> sets});

/// Estado por músculo derivado de las series de UNA sesión.
///
/// Reglas de derivación (sin historial; `recovering` queda fuera de scope):
///   1. Por cada entry calcula un `score` = volumen (reps × peso) sumado de
///      todas las series. Si el volumen total es cero (ej. ejercicios de peso
///      corporal o cardio), cae a `sets.length` para que el ejercicio cuente.
///   2. Acumula el score por (MuscleGroup, MuscleRole) según la atribución
///      en `exercise.muscles`.
///   3. Estado final por grupo:
///      - `dominant`: el grupo con mayor score acumulado como rol dominante
///        (único; en empate gana el primero en orden de iteración).
///      - `active`: cualquier otro grupo con score dominante > 0.
///      - `secondary`: aparece solo como rol secundario (score secundario > 0).
///      - omitido del mapa: no fue trabajado → el caller asume `idle`.
///
/// Función pura: misma entrada → misma salida, sin I/O ni dependencias.
Map<MuscleGroup, MuscleState> resolveSessionState({
  required Iterable<SessionEntry> entries,
}) {
  final dominantScore = <MuscleGroup, double>{};
  final secondaryScore = <MuscleGroup, double>{};

  for (final entry in entries) {
    final score = _entryScore(entry.sets);
    if (score == 0) continue;

    entry.exercise.muscles.forEach((group, role) {
      final bucket = role == MuscleRole.dominant ? dominantScore : secondaryScore;
      bucket[group] = (bucket[group] ?? 0) + score;
    });
  }

  MuscleGroup? topDominant;
  double topDominantScore = 0;
  dominantScore.forEach((group, score) {
    if (score > topDominantScore) {
      topDominantScore = score;
      topDominant = group;
    }
  });

  final result = <MuscleGroup, MuscleState>{};
  for (final group in dominantScore.keys) {
    result[group] = group == topDominant ? MuscleState.dominant : MuscleState.active;
  }
  for (final group in secondaryScore.keys) {
    result.putIfAbsent(group, () => MuscleState.secondary);
  }
  return result;
}

double _entryScore(List<SessionSet> sets) {
  if (sets.isEmpty) return 0;
  var volume = 0.0;
  for (final s in sets) {
    volume += s.volume;
  }
  return volume > 0 ? volume : sets.length.toDouble();
}
