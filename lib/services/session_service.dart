import 'dart:math';

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

  // límite histórico de SQLite: 999 variables por statement
  static const _inChunkSize = 500;

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
  /// Incluye descansos. Usa [getRestDaysInMonth] para distinguirlos.
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

  /// Subconjunto de [getDaysWithSessionInMonth] que son días de descanso.
  Future<List<DateTime>> getRestDaysInMonth(int year, int month) async {
    final db = await _db;
    final from = DateTime(year, month, 1).toIso8601String();
    final to = DateTime(year, month + 1, 1).toIso8601String();
    final rows = await db.query(
      DbConstants.tSessions,
      columns: [DbConstants.cSeDate],
      where:
          '${DbConstants.cSeDate} >= ? AND ${DbConstants.cSeDate} < ? AND ${DbConstants.cSeIsRestDay} = 1',
      whereArgs: [from, to],
    );
    return rows
        .map((r) => DateTime.parse(r[DbConstants.cSeDate] as String))
        .toList();
  }

  /// Weekdays (1=Lun … 7=Dom) que tienen sesión en el rango [from, to).
  /// Incluye descansos. Usa [getRestWeekdaysInRange] para distinguirlos.
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

  /// Weekdays que son días de descanso en el rango [from, to).
  Future<Set<int>> getRestWeekdaysInRange(DateTime from, DateTime to) async {
    final db = await _db;
    final rows = await db.query(
      DbConstants.tSessions,
      columns: [DbConstants.cSeDate],
      where:
          '${DbConstants.cSeDate} >= ? AND ${DbConstants.cSeDate} < ? AND ${DbConstants.cSeIsRestDay} = 1',
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

  /// Ejercicios de varias sesiones en pocas queries (evita N+1).
  /// Devuelve una clave por cada id de [sessionIds] (lista vacía si no tiene),
  /// cada lista en el mismo orden que [getExercisesForSession].
  Future<Map<int, List<SessionExercise>>> getExercisesForSessions(
      List<int> sessionIds) async {
    final ids = sessionIds.toSet().toList();
    final result = {for (final id in ids) id: <SessionExercise>[]};
    if (ids.isEmpty) return result;
    final db = await _db;
    for (var i = 0; i < ids.length; i += _inChunkSize) {
      final chunk = ids.sublist(i, min(i + _inChunkSize, ids.length));
      final rows = await db.query(
        DbConstants.tSessionExercises,
        where:
            '${DbConstants.cSxSessionId} IN (${List.filled(chunk.length, '?').join(',')})',
        whereArgs: chunk,
        orderBy: DbConstants.cSxOrder,
      );
      for (final row in rows) {
        final se = SessionExercise.fromMap(row);
        result[se.sessionId]!.add(se);
      }
    }
    return result;
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

  /// Persiste el nuevo orden de los ejercicios de una sesión.
  /// [orderedIds] son los ids de [SessionExercise] en su orden final;
  /// cada uno recibe como `exercise_order` su índice en la lista.
  Future<void> updateSessionExerciseOrder(List<int> orderedIds) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (var i = 0; i < orderedIds.length; i++) {
        await txn.update(
          DbConstants.tSessionExercises,
          {DbConstants.cSxOrder: i},
          where: '${DbConstants.cSxId} = ?',
          whereArgs: [orderedIds[i]],
        );
      }
    });
  }

  /// Inserta en UNA transacción un SessionExercise por cada id de [exerciseIds]
  /// (exercise_order = startOrder, startOrder+1, …) y, para cada uno,
  /// [setsPerExercise] series vacías numeradas 1..setsPerExercise.
  /// Devuelve los registros insertados (con id) en el mismo orden de [exerciseIds].
  Future<List<({SessionExercise sessionExercise, List<SessionSet> sets})>>
      insertExercisesWithSets({
    required int sessionId,
    required List<int> exerciseIds,
    required int startOrder,
    required int setsPerExercise,
  }) async {
    assert(setsPerExercise >= 0);
    final db = await _db;
    return db.transaction((txn) async {
      final inserted =
          <({SessionExercise sessionExercise, List<SessionSet> sets})>[];
      for (var i = 0; i < exerciseIds.length; i++) {
        var se = SessionExercise(
          sessionId: sessionId,
          exerciseId: exerciseIds[i],
          exerciseOrder: startOrder + i,
        );
        se = se.copyWith(
            id: await txn.insert(DbConstants.tSessionExercises, se.toMap()));
        final sets = <SessionSet>[];
        for (var n = 1; n <= setsPerExercise; n++) {
          final set = SessionSet(sessionExerciseId: se.id!, setNumber: n);
          sets.add(set.copyWith(
              id: await txn.insert(DbConstants.tSessionSets, set.toMap())));
        }
        inserted.add((sessionExercise: se, sets: sets));
      }
      return inserted;
    });
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

  /// Series de varios ejercicios de sesión en pocas queries (evita N+1).
  /// Misma garantía de claves y orden que [getSetsForSessionExercise].
  Future<Map<int, List<SessionSet>>> getSetsForSessionExercises(
      List<int> sessionExerciseIds) async {
    final ids = sessionExerciseIds.toSet().toList();
    final result = {for (final id in ids) id: <SessionSet>[]};
    if (ids.isEmpty) return result;
    final db = await _db;
    for (var i = 0; i < ids.length; i += _inChunkSize) {
      final chunk = ids.sublist(i, min(i + _inChunkSize, ids.length));
      final rows = await db.query(
        DbConstants.tSessionSets,
        where:
            '${DbConstants.cSsSessionExerciseId} IN (${List.filled(chunk.length, '?').join(',')})',
        whereArgs: chunk,
        orderBy: DbConstants.cSsSetNumber,
      );
      for (final row in rows) {
        final set = SessionSet.fromMap(row);
        result[set.sessionExerciseId]!.add(set);
      }
    }
    return result;
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
