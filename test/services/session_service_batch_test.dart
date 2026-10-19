import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/constants/db_constants.dart';
import 'package:gym_tracker/core/database/database_helper.dart';
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
}
