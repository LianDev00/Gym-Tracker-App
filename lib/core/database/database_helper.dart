import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../constants/db_constants.dart';

/// Singleton que gestiona la conexión y creación de la base de datos SQLite.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, DbConstants.dbName);
    return openDatabase(
      path,
      version: DbConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE ${DbConstants.tBodyEntries} ADD COLUMN ${DbConstants.cBeHeightCm} REAL',
      );
    }
    if (oldVersion < 3) {
      // Dispositivos instalados frescos en v2 no tienen height_cm (bug en _createBodyEntries).
      final cols = await db.rawQuery('PRAGMA table_info(${DbConstants.tBodyEntries})');
      final hasHeight = cols.any((c) => c['name'] == DbConstants.cBeHeightCm);
      if (!hasHeight) {
        await db.execute(
          'ALTER TABLE ${DbConstants.tBodyEntries} ADD COLUMN ${DbConstants.cBeHeightCm} REAL',
        );
      }
    }
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE ${DbConstants.tSessionSets} ADD COLUMN ${DbConstants.cSsRpe} INTEGER',
      );
      await db.execute(
        'ALTER TABLE ${DbConstants.tSessionSets} ADD COLUMN ${DbConstants.cSsRir} INTEGER',
      );
    }
  }

  /// Activa las foreign keys de SQLite (desactivadas por defecto).
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(_createExercises);
    await db.execute(_createSessions);
    await db.execute(_createSessionExercises);
    await db.execute(_createSessionSets);
    await db.execute(_createRoutines);
    await db.execute(_createRoutineExercises);
    await db.execute(_createBodyEntries);
    await db.execute(_createBodyMeasurements);
    await _seedDefaultExercises(db);
  }

  // ── DDL ───────────────────────────────────────────────────────────────────────

  static const _createExercises = '''
    CREATE TABLE ${DbConstants.tExercises} (
      ${DbConstants.cExId}             INTEGER PRIMARY KEY AUTOINCREMENT,
      ${DbConstants.cExName}           TEXT    NOT NULL,
      ${DbConstants.cExMuscleCategory} TEXT    NOT NULL,
      ${DbConstants.cExIsCustom}       INTEGER NOT NULL DEFAULT 0
    )
  ''';

  static const _createSessions = '''
    CREATE TABLE ${DbConstants.tSessions} (
      ${DbConstants.cSeId}              INTEGER PRIMARY KEY AUTOINCREMENT,
      ${DbConstants.cSeDate}            TEXT    NOT NULL,
      ${DbConstants.cSeDurationSeconds} INTEGER,
      ${DbConstants.cSeNotes}           TEXT,
      ${DbConstants.cSeRoutineId}       INTEGER
        REFERENCES ${DbConstants.tRoutines}(${DbConstants.cRoId})
        ON DELETE SET NULL
    )
  ''';

  static const _createSessionExercises = '''
    CREATE TABLE ${DbConstants.tSessionExercises} (
      ${DbConstants.cSxId}         INTEGER PRIMARY KEY AUTOINCREMENT,
      ${DbConstants.cSxSessionId}  INTEGER NOT NULL
        REFERENCES ${DbConstants.tSessions}(${DbConstants.cSeId})
        ON DELETE CASCADE,
      ${DbConstants.cSxExerciseId} INTEGER NOT NULL
        REFERENCES ${DbConstants.tExercises}(${DbConstants.cExId}),
      ${DbConstants.cSxOrder}      INTEGER NOT NULL DEFAULT 0
    )
  ''';

  static const _createSessionSets = '''
    CREATE TABLE ${DbConstants.tSessionSets} (
      ${DbConstants.cSsId}                INTEGER PRIMARY KEY AUTOINCREMENT,
      ${DbConstants.cSsSessionExerciseId} INTEGER NOT NULL
        REFERENCES ${DbConstants.tSessionExercises}(${DbConstants.cSxId})
        ON DELETE CASCADE,
      ${DbConstants.cSsSetNumber}         INTEGER NOT NULL,
      ${DbConstants.cSsReps}              INTEGER,
      ${DbConstants.cSsWeightKg}          REAL,
      ${DbConstants.cSsRestSeconds}       INTEGER,
      ${DbConstants.cSsRpe}               INTEGER,
      ${DbConstants.cSsRir}               INTEGER
    )
  ''';

  static const _createRoutines = '''
    CREATE TABLE ${DbConstants.tRoutines} (
      ${DbConstants.cRoId}    INTEGER PRIMARY KEY AUTOINCREMENT,
      ${DbConstants.cRoName}  TEXT NOT NULL,
      ${DbConstants.cRoNotes} TEXT
    )
  ''';

  static const _createRoutineExercises = '''
    CREATE TABLE ${DbConstants.tRoutineExercises} (
      ${DbConstants.cReId}            INTEGER PRIMARY KEY AUTOINCREMENT,
      ${DbConstants.cReRoutineId}     INTEGER NOT NULL
        REFERENCES ${DbConstants.tRoutines}(${DbConstants.cRoId})
        ON DELETE CASCADE,
      ${DbConstants.cReExerciseId}    INTEGER NOT NULL
        REFERENCES ${DbConstants.tExercises}(${DbConstants.cExId}),
      ${DbConstants.cReOrder}         INTEGER NOT NULL DEFAULT 0,
      ${DbConstants.cReTargetSets}    INTEGER,
      ${DbConstants.cReTargetReps}    INTEGER,
      ${DbConstants.cReTargetWeightKg} REAL
    )
  ''';

  static const _createBodyEntries = '''
    CREATE TABLE ${DbConstants.tBodyEntries} (
      ${DbConstants.cBeId}        INTEGER PRIMARY KEY AUTOINCREMENT,
      ${DbConstants.cBeDate}      TEXT NOT NULL,
      ${DbConstants.cBeWeightKg}  REAL,
      ${DbConstants.cBeHeightCm}  REAL,
      ${DbConstants.cBeNotes}     TEXT
    )
  ''';

  static const _createBodyMeasurements = '''
    CREATE TABLE ${DbConstants.tBodyMeasurements} (
      ${DbConstants.cBmId}          INTEGER PRIMARY KEY AUTOINCREMENT,
      ${DbConstants.cBmBodyEntryId} INTEGER NOT NULL
        REFERENCES ${DbConstants.tBodyEntries}(${DbConstants.cBeId})
        ON DELETE CASCADE,
      ${DbConstants.cBmType}        TEXT NOT NULL,
      ${DbConstants.cBmValueCm}     REAL NOT NULL
    )
  ''';

  // ── Seed: ejercicios predefinidos ─────────────────────────────────────────────

  Future<void> _seedDefaultExercises(Database db) async {
    const exercises = [
      // Pecho
      ('Press banca', 'pecho'),
      ('Press inclinado', 'pecho'),
      ('Aperturas con mancuernas', 'pecho'),
      ('Fondos en paralelas', 'pecho'),
      // Espalda
      ('Dominadas', 'espalda'),
      ('Remo con barra', 'espalda'),
      ('Jalón al pecho', 'espalda'),
      ('Remo con mancuerna', 'espalda'),
      // Hombros
      ('Press militar', 'hombros'),
      ('Elevaciones laterales', 'hombros'),
      ('Elevaciones frontales', 'hombros'),
      // Bíceps
      ('Curl con barra', 'biceps'),
      ('Curl con mancuernas', 'biceps'),
      ('Curl martillo', 'biceps'),
      // Tríceps
      ('Extensión tríceps polea', 'triceps'),
      ('Press francés', 'triceps'),
      ('Fondos en banco', 'triceps'),
      // Piernas
      ('Sentadilla', 'piernas'),
      ('Prensa de piernas', 'piernas'),
      ('Extensión de cuádriceps', 'piernas'),
      ('Curl femoral', 'piernas'),
      // Glúteos
      ('Hip thrust', 'gluteos'),
      ('Peso muerto rumano', 'gluteos'),
      // Core
      ('Plancha', 'core'),
      ('Crunch abdominal', 'core'),
      ('Rueda abdominal', 'core'),
      // Cardio
      ('Correr', 'cardio'),
      ('Bicicleta estática', 'cardio'),
      ('Saltar la cuerda', 'cardio'),
    ];

    final batch = db.batch();
    for (final (name, category) in exercises) {
      batch.insert(DbConstants.tExercises, {
        DbConstants.cExName: name,
        DbConstants.cExMuscleCategory: category,
        DbConstants.cExIsCustom: 0,
      });
    }
    await batch.commit(noResult: true);
  }
}
