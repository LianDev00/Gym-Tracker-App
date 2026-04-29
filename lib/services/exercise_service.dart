import 'package:sqflite/sqflite.dart';

import '../core/constants/db_constants.dart';
import '../core/database/database_helper.dart';
import '../models/exercise.dart';
import '../models/muscle_category.dart';
import '../models/muscle_group.dart';
import '../models/session_set.dart';

class ExerciseService {
  ExerciseService._();
  static final ExerciseService instance = ExerciseService._();

  Future<Database> get _db => DatabaseHelper.instance.database;

  /// Devuelve todos los ejercicios (con sus músculos atribuidos), opcionalmente
  /// filtrados por categoría. Carga eager: una query a `exercises` y otra a
  /// `exercise_muscles` con un IN — barato para volúmenes esperados.
  Future<List<Exercise>> getAll({MuscleCategory? category}) async {
    final db = await _db;
    final rows = await db.query(
      DbConstants.tExercises,
      where: category != null ? '${DbConstants.cExMuscleCategory} = ?' : null,
      whereArgs: category != null ? [category.name] : null,
      orderBy: DbConstants.cExName,
    );
    final exercises = rows.map(Exercise.fromMap).toList();
    if (exercises.isEmpty) return exercises;

    final ids = exercises.map((e) => e.id).whereType<int>().toList();
    final musclesById = await _loadMusclesBulk(db, ids);
    return [
      for (final e in exercises)
        e.copyWith(muscles: musclesById[e.id] ?? const {}),
    ];
  }

  Future<Exercise?> getById(int id) async {
    final db = await _db;
    final rows = await db.query(
      DbConstants.tExercises,
      where: '${DbConstants.cExId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final exercise = Exercise.fromMap(rows.first);
    final muscles = await _loadMuscles(db, id);
    return exercise.copyWith(muscles: muscles);
  }

  Future<Exercise> insert(Exercise exercise) async {
    final db = await _db;
    late final int id;
    await db.transaction((txn) async {
      id = await txn.insert(DbConstants.tExercises, exercise.toMap());
      await _writeMuscles(txn, id, exercise.muscles);
    });
    return exercise.copyWith(id: id);
  }

  Future<void> update(Exercise exercise) async {
    assert(exercise.id != null, 'Cannot update an exercise without id');
    final db = await _db;
    await db.transaction((txn) async {
      await txn.update(
        DbConstants.tExercises,
        exercise.toMap(),
        where: '${DbConstants.cExId} = ?',
        whereArgs: [exercise.id],
      );
      // Replace muscles entirely — más simple que diff.
      await txn.delete(
        DbConstants.tExerciseMuscles,
        where: '${DbConstants.cEmExerciseId} = ?',
        whereArgs: [exercise.id],
      );
      await _writeMuscles(txn, exercise.id!, exercise.muscles);
    });
  }

  Future<void> delete(int id) async {
    final db = await _db;
    // Las filas de exercise_muscles caen por FK CASCADE.
    await db.delete(
      DbConstants.tExercises,
      where: '${DbConstants.cExId} = ?',
      whereArgs: [id],
    );
  }

  // ── Helpers internos: persistencia de músculos ───────────────────────────────

  Future<Map<MuscleGroup, MuscleRole>> _loadMuscles(
    Database db,
    int exerciseId,
  ) async {
    final rows = await db.query(
      DbConstants.tExerciseMuscles,
      where: '${DbConstants.cEmExerciseId} = ?',
      whereArgs: [exerciseId],
    );
    return {
      for (final row in rows)
        MuscleGroup.fromString(row[DbConstants.cEmMuscleGroup] as String):
            MuscleRole.fromString(row[DbConstants.cEmRole] as String),
    };
  }

  Future<Map<int, Map<MuscleGroup, MuscleRole>>> _loadMusclesBulk(
    Database db,
    List<int> exerciseIds,
  ) async {
    if (exerciseIds.isEmpty) return const {};
    final placeholders = List.filled(exerciseIds.length, '?').join(',');
    final rows = await db.query(
      DbConstants.tExerciseMuscles,
      where: '${DbConstants.cEmExerciseId} IN ($placeholders)',
      whereArgs: exerciseIds,
    );
    final result = <int, Map<MuscleGroup, MuscleRole>>{};
    for (final row in rows) {
      final exId = row[DbConstants.cEmExerciseId] as int;
      final group =
          MuscleGroup.fromString(row[DbConstants.cEmMuscleGroup] as String);
      final role = MuscleRole.fromString(row[DbConstants.cEmRole] as String);
      result.putIfAbsent(exId, () => {})[group] = role;
    }
    return result;
  }

  Future<void> _writeMuscles(
    DatabaseExecutor txn,
    int exerciseId,
    Map<MuscleGroup, MuscleRole> muscles,
  ) async {
    for (final entry in muscles.entries) {
      await txn.insert(DbConstants.tExerciseMuscles, {
        DbConstants.cEmExerciseId: exerciseId,
        DbConstants.cEmMuscleGroup: entry.key.name,
        DbConstants.cEmRole: entry.value.name,
      });
    }
  }

  /// Devuelve el último [SessionSet] registrado para un ejercicio dado.
  /// Útil para mostrar "última vez: 10 reps × 80 kg" al registrar.
  Future<SessionSet?> getLastSetForExercise(int exerciseId) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT ss.*
      FROM ${DbConstants.tSessionSets} ss
      JOIN ${DbConstants.tSessionExercises} sx
        ON ss.${DbConstants.cSsSessionExerciseId} = sx.${DbConstants.cSxId}
      JOIN ${DbConstants.tSessions} s
        ON sx.${DbConstants.cSxSessionId} = s.${DbConstants.cSeId}
      WHERE sx.${DbConstants.cSxExerciseId} = ?
      ORDER BY s.${DbConstants.cSeDate} DESC, ss.${DbConstants.cSsSetNumber} DESC
      LIMIT 1
    ''', [exerciseId]);
    return rows.isEmpty ? null : SessionSet.fromMap(rows.first);
  }
}
