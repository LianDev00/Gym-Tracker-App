import 'package:sqflite/sqflite.dart';

import '../core/constants/db_constants.dart';
import '../core/database/database_helper.dart';
import '../models/routine.dart';
import '../models/routine_exercise.dart';
import '../models/session.dart';
import '../models/session_exercise.dart';

class RoutineService {
  RoutineService._();
  static final RoutineService instance = RoutineService._();

  Future<Database> get _db => DatabaseHelper.instance.database;

  // ── Rutinas ───────────────────────────────────────────────────────────────────

  Future<List<Routine>> getAll() async {
    final db = await _db;
    final rows = await db.query(DbConstants.tRoutines, orderBy: DbConstants.cRoName);
    return rows.map(Routine.fromMap).toList();
  }

  Future<Routine?> getById(int id) async {
    final db = await _db;
    final rows = await db.query(
      DbConstants.tRoutines,
      where: '${DbConstants.cRoId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Routine.fromMap(rows.first);
  }

  Future<Routine> insert(Routine routine) async {
    final db = await _db;
    final id = await db.insert(DbConstants.tRoutines, routine.toMap());
    return routine.copyWith(id: id);
  }

  Future<void> update(Routine routine) async {
    assert(routine.id != null);
    final db = await _db;
    await db.update(
      DbConstants.tRoutines,
      routine.toMap(),
      where: '${DbConstants.cRoId} = ?',
      whereArgs: [routine.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete(
      DbConstants.tRoutines,
      where: '${DbConstants.cRoId} = ?',
      whereArgs: [id],
    );
  }

  // ── Ejercicios de rutina ──────────────────────────────────────────────────────

  Future<List<RoutineExercise>> getExercisesForRoutine(int routineId) async {
    final db = await _db;
    final rows = await db.query(
      DbConstants.tRoutineExercises,
      where: '${DbConstants.cReRoutineId} = ?',
      whereArgs: [routineId],
      orderBy: DbConstants.cReOrder,
    );
    return rows.map(RoutineExercise.fromMap).toList();
  }

  Future<RoutineExercise> insertRoutineExercise(RoutineExercise re) async {
    final db = await _db;
    final id = await db.insert(DbConstants.tRoutineExercises, re.toMap());
    return re.copyWith(id: id);
  }

  Future<void> deleteRoutineExercise(int id) async {
    final db = await _db;
    await db.delete(
      DbConstants.tRoutineExercises,
      where: '${DbConstants.cReId} = ?',
      whereArgs: [id],
    );
  }

  /// Crea una nueva sesión pre-poblada a partir de una rutina.
  /// Inserta la sesión y los [SessionExercise] correspondientes; las series
  /// se registran manualmente durante el entrenamiento.
  Future<Session> startSessionFromRoutine(int routineId) async {
    final routine = await getById(routineId);
    assert(routine != null, 'Routine $routineId not found');

    final db = await _db;
    final exercises = await getExercisesForRoutine(routineId);

    late Session session;

    await db.transaction((txn) async {
      final sessionId = await txn.insert(DbConstants.tSessions, {
        DbConstants.cSeDate: DateTime.now().toIso8601String(),
        DbConstants.cSeRoutineId: routineId,
      });
      session = Session(id: sessionId, date: DateTime.now(), routineId: routineId);

      for (final re in exercises) {
        await txn.insert(DbConstants.tSessionExercises, SessionExercise(
          sessionId: sessionId,
          exerciseId: re.exerciseId,
          exerciseOrder: re.exerciseOrder,
        ).toMap());
      }
    });

    return session;
  }
}
