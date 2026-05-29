import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../constants/db_constants.dart';
import '../../models/muscle_group.dart';

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
    if (oldVersion < 5) {
      await db.execute(
        'ALTER TABLE ${DbConstants.tSessions} ADD COLUMN ${DbConstants.cSeIsRestDay} INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 6) {
      await db.execute(_createExerciseMuscles);
      await _seedExerciseMuscles(db);
    }
    if (oldVersion < 7) {
      await db.execute(
        'ALTER TABLE ${DbConstants.tExercises} ADD COLUMN ${DbConstants.cExIsBodyweight} INTEGER NOT NULL DEFAULT 0',
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
    await db.execute(_createExerciseMuscles);
    await _seedDefaultExercises(db);
    await _seedExerciseMuscles(db);
  }

  // ── DDL ───────────────────────────────────────────────────────────────────────

  static const _createExercises = '''
    CREATE TABLE ${DbConstants.tExercises} (
      ${DbConstants.cExId}             INTEGER PRIMARY KEY AUTOINCREMENT,
      ${DbConstants.cExName}           TEXT    NOT NULL,
      ${DbConstants.cExMuscleCategory} TEXT    NOT NULL,
      ${DbConstants.cExIsCustom}       INTEGER NOT NULL DEFAULT 0,
      ${DbConstants.cExIsBodyweight}   INTEGER NOT NULL DEFAULT 0
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
        ON DELETE SET NULL,
      ${DbConstants.cSeIsRestDay}       INTEGER NOT NULL DEFAULT 0
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

  static const _createExerciseMuscles = '''
    CREATE TABLE ${DbConstants.tExerciseMuscles} (
      ${DbConstants.cEmId}          INTEGER PRIMARY KEY AUTOINCREMENT,
      ${DbConstants.cEmExerciseId}  INTEGER NOT NULL
        REFERENCES ${DbConstants.tExercises}(${DbConstants.cExId})
        ON DELETE CASCADE,
      ${DbConstants.cEmMuscleGroup} TEXT NOT NULL,
      ${DbConstants.cEmRole}        TEXT NOT NULL,
      UNIQUE(${DbConstants.cEmExerciseId}, ${DbConstants.cEmMuscleGroup})
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

  // ── Seed: atribución muscular granular ───────────────────────────────────────

  /// Inserta filas en `exercise_muscles` para cada ejercicio preset cuya
  /// definición exista en [_presetExerciseMuscles]. Busca por nombre, así que
  /// si un usuario renombró un preset antes de la migración v6, queda sin
  /// músculos atribuidos (los puede agregar a mano luego).
  Future<void> _seedExerciseMuscles(Database db) async {
    final rows = await db.query(
      DbConstants.tExercises,
      columns: [DbConstants.cExId, DbConstants.cExName],
    );
    final nameToId = <String, int>{
      for (final r in rows)
        r[DbConstants.cExName] as String: r[DbConstants.cExId] as int,
    };

    final batch = db.batch();
    for (final entry in _presetExerciseMuscles.entries) {
      final exId = nameToId[entry.key];
      if (exId == null) continue;
      for (final muscleEntry in entry.value.entries) {
        batch.insert(DbConstants.tExerciseMuscles, {
          DbConstants.cEmExerciseId: exId,
          DbConstants.cEmMuscleGroup: muscleEntry.key.name,
          DbConstants.cEmRole: muscleEntry.value.name,
        });
      }
    }
    await batch.commit(noResult: true);
  }

  /// Atribución muscular para los ejercicios preset definidos en
  /// [_seedDefaultExercises]. La clave es el nombre del ejercicio.
  /// Cardio queda fuera — no pinta regiones del cuerpo.
  static final Map<String, Map<MuscleGroup, MuscleRole>>
      _presetExerciseMuscles = {
    // Pecho
    'Press banca': {
      MuscleGroup.chest: MuscleRole.dominant,
      MuscleGroup.shouldersFront: MuscleRole.secondary,
      MuscleGroup.triceps: MuscleRole.secondary,
    },
    'Press inclinado': {
      MuscleGroup.chest: MuscleRole.dominant,
      MuscleGroup.shouldersFront: MuscleRole.secondary,
      MuscleGroup.triceps: MuscleRole.secondary,
    },
    'Aperturas con mancuernas': {
      MuscleGroup.chest: MuscleRole.dominant,
      MuscleGroup.shouldersFront: MuscleRole.secondary,
    },
    'Fondos en paralelas': {
      MuscleGroup.chest: MuscleRole.dominant,
      MuscleGroup.triceps: MuscleRole.secondary,
      MuscleGroup.shouldersFront: MuscleRole.secondary,
    },
    // Espalda
    'Dominadas': {
      MuscleGroup.lats: MuscleRole.dominant,
      MuscleGroup.biceps: MuscleRole.secondary,
      MuscleGroup.midBack: MuscleRole.secondary,
      MuscleGroup.shouldersRear: MuscleRole.secondary,
    },
    'Remo con barra': {
      MuscleGroup.midBack: MuscleRole.dominant,
      MuscleGroup.lats: MuscleRole.secondary,
      MuscleGroup.biceps: MuscleRole.secondary,
      MuscleGroup.shouldersRear: MuscleRole.secondary,
    },
    'Jalón al pecho': {
      MuscleGroup.lats: MuscleRole.dominant,
      MuscleGroup.biceps: MuscleRole.secondary,
      MuscleGroup.midBack: MuscleRole.secondary,
    },
    'Remo con mancuerna': {
      MuscleGroup.midBack: MuscleRole.dominant,
      MuscleGroup.lats: MuscleRole.secondary,
      MuscleGroup.biceps: MuscleRole.secondary,
    },
    // Hombros
    'Press militar': {
      MuscleGroup.shouldersFront: MuscleRole.dominant,
      MuscleGroup.shouldersLateral: MuscleRole.secondary,
      MuscleGroup.triceps: MuscleRole.secondary,
      MuscleGroup.traps: MuscleRole.secondary,
    },
    'Elevaciones laterales': {
      MuscleGroup.shouldersLateral: MuscleRole.dominant,
      MuscleGroup.shouldersFront: MuscleRole.secondary,
      MuscleGroup.traps: MuscleRole.secondary,
    },
    'Elevaciones frontales': {
      MuscleGroup.shouldersFront: MuscleRole.dominant,
      MuscleGroup.shouldersLateral: MuscleRole.secondary,
    },
    // Bíceps
    'Curl con barra': {
      MuscleGroup.biceps: MuscleRole.dominant,
      MuscleGroup.forearms: MuscleRole.secondary,
    },
    'Curl con mancuernas': {
      MuscleGroup.biceps: MuscleRole.dominant,
      MuscleGroup.forearms: MuscleRole.secondary,
    },
    'Curl martillo': {
      MuscleGroup.biceps: MuscleRole.dominant,
      MuscleGroup.forearms: MuscleRole.secondary,
    },
    // Tríceps
    'Extensión tríceps polea': {
      MuscleGroup.triceps: MuscleRole.dominant,
      MuscleGroup.forearms: MuscleRole.secondary,
    },
    'Press francés': {
      MuscleGroup.triceps: MuscleRole.dominant,
      MuscleGroup.forearms: MuscleRole.secondary,
    },
    'Fondos en banco': {
      MuscleGroup.triceps: MuscleRole.dominant,
      MuscleGroup.chest: MuscleRole.secondary,
      MuscleGroup.shouldersFront: MuscleRole.secondary,
    },
    // Piernas
    'Sentadilla': {
      MuscleGroup.quads: MuscleRole.dominant,
      MuscleGroup.glutes: MuscleRole.secondary,
      MuscleGroup.hamstrings: MuscleRole.secondary,
      MuscleGroup.lowerBack: MuscleRole.secondary,
    },
    'Prensa de piernas': {
      MuscleGroup.quads: MuscleRole.dominant,
      MuscleGroup.glutes: MuscleRole.secondary,
      MuscleGroup.hamstrings: MuscleRole.secondary,
    },
    'Extensión de cuádriceps': {
      MuscleGroup.quads: MuscleRole.dominant,
    },
    'Curl femoral': {
      MuscleGroup.hamstrings: MuscleRole.dominant,
    },
    // Glúteos
    'Hip thrust': {
      MuscleGroup.glutes: MuscleRole.dominant,
      MuscleGroup.hamstrings: MuscleRole.secondary,
    },
    'Peso muerto rumano': {
      MuscleGroup.hamstrings: MuscleRole.dominant,
      MuscleGroup.glutes: MuscleRole.secondary,
      MuscleGroup.lowerBack: MuscleRole.secondary,
    },
    // Core
    'Plancha': {
      MuscleGroup.abs: MuscleRole.dominant,
      MuscleGroup.obliques: MuscleRole.secondary,
      MuscleGroup.lowerBack: MuscleRole.secondary,
    },
    'Crunch abdominal': {
      MuscleGroup.abs: MuscleRole.dominant,
    },
    'Rueda abdominal': {
      MuscleGroup.abs: MuscleRole.dominant,
      MuscleGroup.obliques: MuscleRole.secondary,
    },
    // Cardio — sin atribución (la figura queda en idle/recovering).
  };
}
