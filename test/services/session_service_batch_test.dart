import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/constants/db_constants.dart';
import 'package:gym_tracker/core/database/database_helper.dart';
import 'package:gym_tracker/models/session.dart';
import 'package:gym_tracker/models/session_exercise.dart';
import 'package:gym_tracker/models/session_set.dart';
import 'package:gym_tracker/services/session_service.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory
        .deleteDatabase(join(await getDatabasesPath(), DbConstants.dbName));
  });

  group('esquema', () {
    test('user_version es 8', () async {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.rawQuery('PRAGMA user_version');
      expect(rows.first.values.first, 8);
    });

    test('existen los 4 índices sobre FKs y fecha', () async {
      final db = await DatabaseHelper.instance.database;
      Future<Set<String>> indexesOf(String table) async {
        final rows = await db.rawQuery('PRAGMA index_list($table)');
        return {for (final r in rows) r['name'] as String};
      }

      expect(await indexesOf(DbConstants.tSessionExercises),
          contains('idx_session_exercises_session'));
      expect(await indexesOf(DbConstants.tSessionSets),
          contains('idx_session_sets_session_exercise'));
      expect(await indexesOf(DbConstants.tSessions),
          contains('idx_sessions_date'));
      expect(await indexesOf(DbConstants.tRoutineExercises),
          contains('idx_routine_exercises_routine'));
    });
  });

  group('lecturas por lote', () {
    final service = SessionService.instance;
    final sessionIds = <int>[];
    final seIds = <int>[];

    // Siembra determinista: 50 sesiones, 0-4 ejercicios c/u, 0-4 series c/u.
    setUpAll(() async {
      for (var i = 0; i < 50; i++) {
        final session = await service.insert(Session(date: DateTime(2026, 1, 1 + i)));
        sessionIds.add(session.id!);
        // Orden de inserción invertido para que exercise_order != id.
        final exerciseCount = i % 5;
        for (var j = exerciseCount - 1; j >= 0; j--) {
          final se = await service.insertSessionExercise(SessionExercise(
            sessionId: session.id!,
            exerciseId: 1 + (i + j) % 10,
            exerciseOrder: j,
          ));
          seIds.add(se.id!);
          for (var n = (i + j) % 5; n >= 1; n--) {
            await service.insertSet(SessionSet(
              sessionExerciseId: se.id!,
              setNumber: n,
              reps: n * 2,
              weightKg: 10.0 * n,
            ));
          }
        }
      }
    });

    test('ejercicios: igual a getExercisesForSession por cada id', () async {
      final batch = await service.getExercisesForSessions(sessionIds);
      expect(batch.keys.toSet(), sessionIds.toSet());
      for (final id in sessionIds) {
        final single = await service.getExercisesForSession(id);
        expect([for (final se in batch[id]!) se.toMap()],
            [for (final se in single) se.toMap()]);
      }
    });

    test('series: igual a getSetsForSessionExercise por cada id', () async {
      final batch = await service.getSetsForSessionExercises(seIds);
      expect(batch.keys.toSet(), seIds.toSet());
      for (final id in seIds) {
        final single = await service.getSetsForSessionExercise(id);
        expect([for (final s in batch[id]!) s.toMap()],
            [for (final s in single) s.toMap()]);
      }
    });

    test('lote vacío devuelve {}', () async {
      expect(await service.getExercisesForSessions([]), isEmpty);
      expect(await service.getSetsForSessionExercises([]), isEmpty);
    });

    test('ids sin filas e ids duplicados', () async {
      final withoutExercises = sessionIds.first; // i = 0 → 0 ejercicios
      final batch = await service.getExercisesForSessions(
          [withoutExercises, 999999, sessionIds[1], sessionIds[1]]);
      expect(batch.keys.toSet(), {withoutExercises, 999999, sessionIds[1]});
      expect(batch[withoutExercises], isEmpty);
      expect(batch[999999], isEmpty);
      expect(batch[sessionIds[1]], hasLength(1));
    });

    test('1200 ids cruzan el troceo sin "too many SQL variables"', () async {
      final ids = [...sessionIds, for (var i = 0; i < 1150; i++) 100000 + i];
      final exercises = await service.getExercisesForSessions(ids);
      expect(exercises, hasLength(1200));
      final sets = await service
          .getSetsForSessionExercises([...seIds, for (var i = 0; i < 1200; i++) 100000 + i]);
      expect(sets, hasLength(seIds.length + 1200));
      expect(sets.values.expand((l) => l), isNotEmpty);
    });
  });

  group('insertExercisesWithSets', () {
    final service = SessionService.instance;

    Future<int> count(String table) async {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
      return rows.first['c'] as int;
    }

    test('inserta en orden, con exercise_order y setNumber correctos', () async {
      final session = await service.insert(Session(date: DateTime(2026, 6, 1)));
      final result = await service.insertExercisesWithSets(
        sessionId: session.id!,
        exerciseIds: [3, 1, 2],
        startOrder: 5,
        setsPerExercise: 3,
      );

      expect([for (final r in result) r.sessionExercise.exerciseId], [3, 1, 2]);
      expect([for (final r in result) r.sessionExercise.exerciseOrder], [5, 6, 7]);
      for (final r in result) {
        expect(r.sessionExercise.id, isNotNull);
        expect([for (final s in r.sets) s.setNumber], [1, 2, 3]);
        expect(r.sets.every((s) => s.id != null), isTrue);
        expect(
            [for (final s in await service.getSetsForSessionExercise(r.sessionExercise.id!)) s.toMap()],
            [for (final s in r.sets) s.toMap()]);
      }
      expect(
          [for (final se in await service.getExercisesForSession(session.id!)) se.toMap()],
          [for (final r in result) r.sessionExercise.toMap()]);
    });

    test('es atómico: un exerciseId inválido no deja filas', () async {
      final session = await service.insert(Session(date: DateTime(2026, 6, 2)));
      final exercisesBefore = await count(DbConstants.tSessionExercises);
      final setsBefore = await count(DbConstants.tSessionSets);

      await expectLater(
        service.insertExercisesWithSets(
          sessionId: session.id!,
          exerciseIds: [1, 999999, 2],
          startOrder: 0,
          setsPerExercise: 3,
        ),
        throwsA(anything),
      );

      expect(await count(DbConstants.tSessionExercises), exercisesBefore);
      expect(await count(DbConstants.tSessionSets), setsBefore);
    });
  });
}
