import 'package:sqflite/sqflite.dart';

import '../core/constants/db_constants.dart';
import '../core/database/database_helper.dart';
import '../models/body_entry.dart';
import '../models/body_measurement.dart';
import '../models/measurement_type.dart';

class BodyService {
  BodyService._();
  static final BodyService instance = BodyService._();

  Future<Database> get _db => DatabaseHelper.instance.database;

  // ── Body entries ──────────────────────────────────────────────────────────────

  Future<List<BodyEntry>> getAll() async {
    final db = await _db;
    final rows = await db.query(
      DbConstants.tBodyEntries,
      orderBy: '${DbConstants.cBeDate} DESC',
    );
    return rows.map(BodyEntry.fromMap).toList();
  }

  Future<BodyEntry?> getById(int id) async {
    final db = await _db;
    final rows = await db.query(
      DbConstants.tBodyEntries,
      where: '${DbConstants.cBeId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : BodyEntry.fromMap(rows.first);
  }

  Future<BodyEntry> insert(BodyEntry entry) async {
    final db = await _db;
    final id = await db.insert(DbConstants.tBodyEntries, entry.toMap());
    return entry.copyWith(id: id);
  }

  Future<void> update(BodyEntry entry) async {
    assert(entry.id != null);
    final db = await _db;
    await db.update(
      DbConstants.tBodyEntries,
      entry.toMap(),
      where: '${DbConstants.cBeId} = ?',
      whereArgs: [entry.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete(
      DbConstants.tBodyEntries,
      where: '${DbConstants.cBeId} = ?',
      whereArgs: [id],
    );
  }

  // ── Body measurements ─────────────────────────────────────────────────────────

  Future<List<BodyMeasurement>> getMeasurementsForEntry(int bodyEntryId) async {
    final db = await _db;
    final rows = await db.query(
      DbConstants.tBodyMeasurements,
      where: '${DbConstants.cBmBodyEntryId} = ?',
      whereArgs: [bodyEntryId],
    );
    return rows.map(BodyMeasurement.fromMap).toList();
  }

  Future<BodyMeasurement> insertMeasurement(BodyMeasurement m) async {
    final db = await _db;
    final id = await db.insert(DbConstants.tBodyMeasurements, m.toMap());
    return m.copyWith(id: id);
  }

  Future<void> deleteMeasurement(int id) async {
    final db = await _db;
    await db.delete(
      DbConstants.tBodyMeasurements,
      where: '${DbConstants.cBmId} = ?',
      whereArgs: [id],
    );
  }

  /// Historial de peso corporal ordenado por fecha (para la gráfica).
  Future<List<({DateTime date, double weightKg})>> getWeightHistory() async {
    final db = await _db;
    final rows = await db.query(
      DbConstants.tBodyEntries,
      columns: [DbConstants.cBeDate, DbConstants.cBeWeightKg],
      where: '${DbConstants.cBeWeightKg} IS NOT NULL',
      orderBy: DbConstants.cBeDate,
    );
    return rows
        .map((r) => (
              date: DateTime.parse(r[DbConstants.cBeDate] as String),
              weightKg: r[DbConstants.cBeWeightKg] as double,
            ))
        .toList();
  }

  /// Historial de una medida específica (para graficar evolución).
  Future<List<({DateTime date, double valueCm})>> getMeasurementHistory(
    MeasurementType type,
  ) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT be.${DbConstants.cBeDate}, bm.${DbConstants.cBmValueCm}
      FROM ${DbConstants.tBodyMeasurements} bm
      JOIN ${DbConstants.tBodyEntries} be
        ON bm.${DbConstants.cBmBodyEntryId} = be.${DbConstants.cBeId}
      WHERE bm.${DbConstants.cBmType} = ?
      ORDER BY be.${DbConstants.cBeDate}
    ''', [type.name]);
    return rows
        .map((r) => (
              date: DateTime.parse(r[DbConstants.cBeDate] as String),
              valueCm: r[DbConstants.cBmValueCm] as double,
            ))
        .toList();
  }
}
