import 'package:sqflite/sqflite.dart';

import '../core/constants/db_constants.dart';
import '../core/database/database_helper.dart';
import '../models/exercise.dart';
import '../models/muscle_category.dart';
import '../models/session_set.dart';

class ExerciseService {
  ExerciseService._();
  static final ExerciseService instance = ExerciseService._();

  Future<Database> get _db => DatabaseHelper.instance.database;

  /// Devuelve todos los ejercicios, opcionalmente filtrados por categoría.
  Future<List<Exercise>> getAll({MuscleCategory? category}) async {
    final db = await _db;
    final rows = await db.query(
      DbConstants.tExercises,
      where: category != null ? '${DbConstants.cExMuscleCategory} = ?' : null,
      whereArgs: category != null ? [category.name] : null,
      orderBy: DbConstants.cExName,
    );
    return rows.map(Exercise.fromMap).toList();
  }

  Future<Exercise?> getById(int id) async {
    final db = await _db;
    final rows = await db.query(
      DbConstants.tExercises,
      where: '${DbConstants.cExId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Exercise.fromMap(rows.first);
  }

  Future<Exercise> insert(Exercise exercise) async {
    final db = await _db;
    final id = await db.insert(DbConstants.tExercises, exercise.toMap());
    return exercise.copyWith(id: id);
  }

  Future<void> update(Exercise exercise) async {
    assert(exercise.id != null, 'Cannot update an exercise without id');
    final db = await _db;
    await db.update(
      DbConstants.tExercises,
      exercise.toMap(),
      where: '${DbConstants.cExId} = ?',
      whereArgs: [exercise.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete(
      DbConstants.tExercises,
      where: '${DbConstants.cExId} = ?',
      whereArgs: [id],
    );
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
