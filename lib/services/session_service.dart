import 'package:sqflite/sqflite.dart';

import '../core/constants/db_constants.dart';
import '../core/database/database_helper.dart';
import '../models/session.dart';
import '../models/session_exercise.dart';
import '../models/session_set.dart';

class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  Future<Database> get _db => DatabaseHelper.instance.database;

  // ── Sesiones ──────────────────────────────────────────────────────────────────

  Future<List<Session>> getAll() async {
    final db = await _db;
    final rows = await db.query(
      DbConstants.tSessions,
      orderBy: '${DbConstants.cSeDate} DESC',
    );
    return rows.map(Session.fromMap).toList();
  }

  Future<Session?> getSessionForDate(DateTime date) async {
    final db = await _db;
    final from = DateTime(date.year, date.month, date.day).toIso8601String();
    final to = DateTime(date.year, date.month, date.day + 1).toIso8601String();
    final rows = await db.query(
      DbConstants.tSessions,
      where: '${DbConstants.cSeDate} >= ? AND ${DbConstants.cSeDate} < ?',
      whereArgs: [from, to],
      limit: 1,
    );
    return rows.isEmpty ? null : Session.fromMap(rows.first);
  }

  Future<Session?> getById(int id) async {
    final db = await _db;
    final rows = await db.query(
      DbConstants.tSessions,
      where: '${DbConstants.cSeId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Session.fromMap(rows.first);
  }

  /// Días con sesión registrada en un mes dado (para el calendario).
  Future<List<DateTime>> getDaysWithSessionInMonth(int year, int month) async {
    final db = await _db;
    final from = DateTime(year, month, 1).toIso8601String();
    final to = DateTime(year, month + 1, 1).toIso8601String();
    final rows = await db.query(
      DbConstants.tSessions,
      columns: [DbConstants.cSeDate],
      where: '${DbConstants.cSeDate} >= ? AND ${DbConstants.cSeDate} < ?',
      whereArgs: [from, to],
    );
    return rows
        .map((r) => DateTime.parse(r[DbConstants.cSeDate] as String))
        .toList();
  }

  /// Weekdays (1=Lun … 7=Dom) que tienen sesión en el rango [from, to).
  Future<Set<int>> getSessionWeekdaysInRange(DateTime from, DateTime to) async {
    final db = await _db;
    final rows = await db.query(
      DbConstants.tSessions,
      columns: [DbConstants.cSeDate],
      where: '${DbConstants.cSeDate} >= ? AND ${DbConstants.cSeDate} < ?',
      whereArgs: [from.toIso8601String(), to.toIso8601String()],
    );
    return rows
        .map((r) => DateTime.parse(r[DbConstants.cSeDate] as String).weekday)
        .toSet();
  }

  Future<Session> insert(Session session) async {
    final db = await _db;
    final id = await db.insert(DbConstants.tSessions, session.toMap());
    return session.copyWith(id: id);
  }

  Future<void> update(Session session) async {
    assert(session.id != null);
    final db = await _db;
    await db.update(
      DbConstants.tSessions,
      session.toMap(),
      where: '${DbConstants.cSeId} = ?',
      whereArgs: [session.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await _db;
    // ON DELETE CASCADE elimina session_exercises y session_sets automáticamente
    await db.delete(
      DbConstants.tSessions,
      where: '${DbConstants.cSeId} = ?',
      whereArgs: [id],
    );
  }

  // ── Session exercises ─────────────────────────────────────────────────────────

  Future<List<SessionExercise>> getExercisesForSession(int sessionId) async {
    final db = await _db;
    final rows = await db.query(
      DbConstants.tSessionExercises,
      where: '${DbConstants.cSxSessionId} = ?',
      whereArgs: [sessionId],
      orderBy: DbConstants.cSxOrder,
    );
    return rows.map(SessionExercise.fromMap).toList();
  }

  Future<SessionExercise> insertSessionExercise(SessionExercise se) async {
    final db = await _db;
    final id = await db.insert(DbConstants.tSessionExercises, se.toMap());
    return se.copyWith(id: id);
  }

  Future<void> deleteSessionExercise(int id) async {
    final db = await _db;
    await db.delete(
      DbConstants.tSessionExercises,
      where: '${DbConstants.cSxId} = ?',
      whereArgs: [id],
    );
  }

  // ── Session sets ──────────────────────────────────────────────────────────────

  Future<List<SessionSet>> getSetsForSessionExercise(int sessionExerciseId) async {
    final db = await _db;
    final rows = await db.query(
      DbConstants.tSessionSets,
      where: '${DbConstants.cSsSessionExerciseId} = ?',
      whereArgs: [sessionExerciseId],
      orderBy: DbConstants.cSsSetNumber,
    );
    return rows.map(SessionSet.fromMap).toList();
  }

  Future<SessionSet> insertSet(SessionSet set) async {
    final db = await _db;
    final id = await db.insert(DbConstants.tSessionSets, set.toMap());
    return set.copyWith(id: id);
  }

  Future<void> updateSet(SessionSet set) async {
    assert(set.id != null);
    final db = await _db;
    await db.update(
      DbConstants.tSessionSets,
      set.toMap(),
      where: '${DbConstants.cSsId} = ?',
      whereArgs: [set.id],
    );
  }

  Future<void> deleteSet(int id) async {
    final db = await _db;
    await db.delete(
      DbConstants.tSessionSets,
      where: '${DbConstants.cSsId} = ?',
      whereArgs: [id],
    );
  }
}
