import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../core/constants/db_constants.dart';
import '../core/database/database_helper.dart';

/// Exporta e importa todos los datos como un único archivo JSON.
class ExportService {
  ExportService._();
  static final ExportService instance = ExportService._();

  Future<Database> get _db => DatabaseHelper.instance.database;

  /// Exporta toda la base de datos a JSON y escribe el archivo en el
  /// directorio de documentos. Devuelve la ruta del archivo generado.
  Future<String> exportToJson() async {
    final db = await _db;

    final data = {
      DbConstants.tExercises: await db.query(DbConstants.tExercises),
      DbConstants.tSessions: await db.query(DbConstants.tSessions),
      DbConstants.tSessionExercises: await db.query(DbConstants.tSessionExercises),
      DbConstants.tSessionSets: await db.query(DbConstants.tSessionSets),
      DbConstants.tRoutines: await db.query(DbConstants.tRoutines),
      DbConstants.tRoutineExercises: await db.query(DbConstants.tRoutineExercises),
      DbConstants.tBodyEntries: await db.query(DbConstants.tBodyEntries),
      DbConstants.tBodyMeasurements: await db.query(DbConstants.tBodyMeasurements),
    };

    final json = const JsonEncoder.withIndent('  ').convert(data);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/gym_tracker_backup.json');
    await file.writeAsString(json);
    return file.path;
  }

  /// Importa datos desde un archivo JSON previamente exportado.
  /// Limpia todas las tablas antes de insertar (reemplaza todo).
  Future<void> importFromJson(String filePath) async {
    final file = File(filePath);
    final json = await file.readAsString();
    final data = jsonDecode(json) as Map<String, dynamic>;

    final db = await _db;

    await db.transaction((txn) async {
      // Orden de borrado para respetar las foreign keys
      for (final table in [
        DbConstants.tBodyMeasurements,
        DbConstants.tBodyEntries,
        DbConstants.tSessionSets,
        DbConstants.tSessionExercises,
        DbConstants.tSessions,
        DbConstants.tRoutineExercises,
        DbConstants.tRoutines,
        DbConstants.tExercises,
      ]) {
        await txn.delete(table);
      }

      // Orden de inserción respetando las foreign keys
      for (final table in [
        DbConstants.tExercises,
        DbConstants.tRoutines,
        DbConstants.tRoutineExercises,
        DbConstants.tSessions,
        DbConstants.tSessionExercises,
        DbConstants.tSessionSets,
        DbConstants.tBodyEntries,
        DbConstants.tBodyMeasurements,
      ]) {
        final rows = data[table] as List<dynamic>? ?? [];
        for (final row in rows) {
          await txn.insert(
            table,
            Map<String, dynamic>.from(row as Map),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }
}
