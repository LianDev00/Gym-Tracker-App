import '../core/constants/db_constants.dart';
import '../core/database/database_helper.dart';

/// Consultas de estadísticas agregadas.
/// Todas las operaciones son de solo lectura.
class StatisticsService {
  StatisticsService._();
  static final StatisticsService instance = StatisticsService._();

  // ── Volumen ───────────────────────────────────────────────────────────────────

  /// Volumen total (reps × peso) en la semana que contiene [date].
  Future<double> weeklyVolume(DateTime date) async {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    final sunday = monday.add(const Duration(days: 7));
    return _volumeBetween(monday, sunday);
  }

  /// Volumen total en el mes de [date].
  Future<double> monthlyVolume(DateTime date) async {
    final from = DateTime(date.year, date.month, 1);
    final to = DateTime(date.year, date.month + 1, 1);
    return _volumeBetween(from, to);
  }

  Future<double> _volumeBetween(DateTime from, DateTime to) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(ss.${DbConstants.cSsReps} * ss.${DbConstants.cSsWeightKg}), 0) AS volume
      FROM ${DbConstants.tSessionSets} ss
      JOIN ${DbConstants.tSessionExercises} sx
        ON ss.${DbConstants.cSsSessionExerciseId} = sx.${DbConstants.cSxId}
      JOIN ${DbConstants.tSessions} s
        ON sx.${DbConstants.cSxSessionId} = s.${DbConstants.cSeId}
      WHERE s.${DbConstants.cSeDate} >= ? AND s.${DbConstants.cSeDate} < ?
        AND ss.${DbConstants.cSsReps} IS NOT NULL
        AND ss.${DbConstants.cSsWeightKg} IS NOT NULL
    ''', [from.toIso8601String(), to.toIso8601String()]);
    return (result.first['volume'] as num).toDouble();
  }

  // ── Comparación semanal ───────────────────────────────────────────────────────

  /// Devuelve el volumen de esta semana y de la semana anterior.
  Future<({double thisWeek, double lastWeek})> weekComparison(DateTime now) async {
    final thisMonday = now.subtract(Duration(days: now.weekday - 1));
    final lastMonday = thisMonday.subtract(const Duration(days: 7));
    final thisWeekVol = await _volumeBetween(
      thisMonday,
      thisMonday.add(const Duration(days: 7)),
    );
    final lastWeekVol = await _volumeBetween(
      lastMonday,
      lastMonday.add(const Duration(days: 7)),
    );
    return (thisWeek: thisWeekVol, lastWeek: lastWeekVol);
  }

  // ── Series efectivas ──────────────────────────────────────────────────────────

  /// Cuenta series con RIR ≤ 3 (series efectivas) en el rango dado.
  Future<int> effectiveSets(DateTime from, DateTime to) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) AS count
      FROM ${DbConstants.tSessionSets} ss
      JOIN ${DbConstants.tSessionExercises} sx
        ON ss.${DbConstants.cSsSessionExerciseId} = sx.${DbConstants.cSxId}
      JOIN ${DbConstants.tSessions} s
        ON sx.${DbConstants.cSxSessionId} = s.${DbConstants.cSeId}
      WHERE s.${DbConstants.cSeDate} >= ? AND s.${DbConstants.cSeDate} < ?
        AND ss.${DbConstants.cSsRir} IS NOT NULL
        AND ss.${DbConstants.cSsRir} <= 3
    ''', [from.toIso8601String(), to.toIso8601String()]);
    return (result.first['count'] as int?) ?? 0;
  }

  // ── Progreso por ejercicio ────────────────────────────────────────────────────

  /// Peso máximo levantado por sesión para un ejercicio dado (para la gráfica).
  Future<List<({DateTime date, double maxWeightKg})>> maxWeightHistory(
    int exerciseId,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT s.${DbConstants.cSeDate}, MAX(ss.${DbConstants.cSsWeightKg}) AS max_weight
      FROM ${DbConstants.tSessionSets} ss
      JOIN ${DbConstants.tSessionExercises} sx
        ON ss.${DbConstants.cSsSessionExerciseId} = sx.${DbConstants.cSxId}
      JOIN ${DbConstants.tSessions} s
        ON sx.${DbConstants.cSxSessionId} = s.${DbConstants.cSeId}
      WHERE sx.${DbConstants.cSxExerciseId} = ?
        AND ss.${DbConstants.cSsWeightKg} IS NOT NULL
      GROUP BY DATE(s.${DbConstants.cSeDate})
      ORDER BY s.${DbConstants.cSeDate}
    ''', [exerciseId]);
    return rows
        .map((r) => (
              date: DateTime.parse(r[DbConstants.cSeDate] as String),
              maxWeightKg: (r['max_weight'] as num).toDouble(),
            ))
        .toList();
  }

  // ── Récords personales ────────────────────────────────────────────────────────

  /// Top 10 ejercicios por peso máximo registrado.
  Future<List<({int exerciseId, String exerciseName, double maxWeightKg, DateTime date})>>
      personalRecords() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT sx.${DbConstants.cSxExerciseId},
             e.${DbConstants.cExName},
             MAX(ss.${DbConstants.cSsWeightKg}) AS max_weight,
             s.${DbConstants.cSeDate}
      FROM ${DbConstants.tSessionSets} ss
      JOIN ${DbConstants.tSessionExercises} sx
        ON ss.${DbConstants.cSsSessionExerciseId} = sx.${DbConstants.cSxId}
      JOIN ${DbConstants.tSessions} s
        ON sx.${DbConstants.cSxSessionId} = s.${DbConstants.cSeId}
      JOIN ${DbConstants.tExercises} e
        ON sx.${DbConstants.cSxExerciseId} = e.${DbConstants.cExId}
      WHERE ss.${DbConstants.cSsWeightKg} IS NOT NULL
      GROUP BY sx.${DbConstants.cSxExerciseId}
      ORDER BY max_weight DESC
      LIMIT 10
    ''');
    return rows
        .map((r) => (
              exerciseId: r[DbConstants.cSxExerciseId] as int,
              exerciseName: r[DbConstants.cExName] as String,
              maxWeightKg: (r['max_weight'] as num).toDouble(),
              date: DateTime.parse(r[DbConstants.cSeDate] as String),
            ))
        .toList();
  }

  // ── Volumen por grupo muscular ────────────────────────────────────────────────

  /// Volumen (reps × peso) por categoría muscular en el rango dado.
  Future<Map<String, double>> volumeByMuscle(DateTime from, DateTime to) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT e.${DbConstants.cExMuscleCategory},
             COALESCE(SUM(ss.${DbConstants.cSsReps} * ss.${DbConstants.cSsWeightKg}), 0) AS volume
      FROM ${DbConstants.tSessionSets} ss
      JOIN ${DbConstants.tSessionExercises} sx
        ON ss.${DbConstants.cSsSessionExerciseId} = sx.${DbConstants.cSxId}
      JOIN ${DbConstants.tSessions} s
        ON sx.${DbConstants.cSxSessionId} = s.${DbConstants.cSeId}
      JOIN ${DbConstants.tExercises} e
        ON sx.${DbConstants.cSxExerciseId} = e.${DbConstants.cExId}
      WHERE s.${DbConstants.cSeDate} >= ? AND s.${DbConstants.cSeDate} < ?
        AND ss.${DbConstants.cSsReps} IS NOT NULL
        AND ss.${DbConstants.cSsWeightKg} IS NOT NULL
      GROUP BY e.${DbConstants.cExMuscleCategory}
      ORDER BY volume DESC
    ''', [from.toIso8601String(), to.toIso8601String()]);
    return {
      for (final r in rows)
        r[DbConstants.cExMuscleCategory] as String:
            (r['volume'] as num).toDouble()
    };
  }

  // ── Historial de volumen por sesión ───────────────────────────────────────────

  /// Volumen total por sesión, en orden cronológico (todas las sesiones).
  Future<List<({DateTime date, double totalVolume, int sessionId})>>
      sessionVolumeHistory() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT s.${DbConstants.cSeDate},
             s.${DbConstants.cSeId},
             COALESCE(SUM(
               CASE WHEN ss.${DbConstants.cSsReps} IS NOT NULL
                    AND ss.${DbConstants.cSsWeightKg} IS NOT NULL
               THEN ss.${DbConstants.cSsReps} * ss.${DbConstants.cSsWeightKg}
               ELSE 0 END
             ), 0) AS total_volume
      FROM ${DbConstants.tSessions} s
      LEFT JOIN ${DbConstants.tSessionExercises} sx
        ON sx.${DbConstants.cSxSessionId} = s.${DbConstants.cSeId}
      LEFT JOIN ${DbConstants.tSessionSets} ss
        ON ss.${DbConstants.cSsSessionExerciseId} = sx.${DbConstants.cSxId}
      GROUP BY s.${DbConstants.cSeId}
      ORDER BY s.${DbConstants.cSeDate}
    ''');
    return rows
        .map((r) => (
              date: DateTime.parse(r[DbConstants.cSeDate] as String),
              totalVolume: (r['total_volume'] as num).toDouble(),
              sessionId: r[DbConstants.cSeId] as int,
            ))
        .toList();
  }

  // ── Rachas ────────────────────────────────────────────────────────────────────

  /// Devuelve [currentStreak] y [maxStreak] de días consecutivos entrenados.
  Future<({int currentStreak, int maxStreak})> streaks() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT DISTINCT DATE(${DbConstants.cSeDate}) AS day
      FROM ${DbConstants.tSessions}
      ORDER BY day
    ''');

    if (rows.isEmpty) return (currentStreak: 0, maxStreak: 0);

    final days = rows
        .map((r) => DateTime.parse(r['day'] as String))
        .toList();

    int max = 1, streak = 1;
    for (int i = 1; i < days.length; i++) {
      final diff = days[i].difference(days[i - 1]).inDays;
      if (diff == 1) {
        streak++;
        if (streak > max) max = streak;
      } else if (diff > 1) {
        streak = 1;
      }
    }

    final today = DateTime.now();
    final lastDay = days.last;
    final diffToToday = DateTime(today.year, today.month, today.day)
        .difference(DateTime(lastDay.year, lastDay.month, lastDay.day))
        .inDays;
    final current = diffToToday <= 1 ? streak : 0;

    return (currentStreak: current, maxStreak: max);
  }

  // ── Historial combinado volumen + RIR por sesión ──────────────────────────────

  /// Por sesión: volumen total, RIR promedio y series efectivas (RIR ≤ 3).
  Future<List<({DateTime date, int sessionId, double volume, double? avgRir, int effectiveSets})>>
      sessionVolumeAndRirHistory() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT s.${DbConstants.cSeDate},
             s.${DbConstants.cSeId},
             COALESCE(SUM(
               CASE WHEN ss.${DbConstants.cSsReps} IS NOT NULL
                    AND ss.${DbConstants.cSsWeightKg} IS NOT NULL
               THEN ss.${DbConstants.cSsReps} * ss.${DbConstants.cSsWeightKg}
               ELSE 0 END
             ), 0) AS volume,
             AVG(ss.${DbConstants.cSsRir}) AS avg_rir,
             SUM(CASE WHEN ss.${DbConstants.cSsRir} IS NOT NULL
                      AND ss.${DbConstants.cSsRir} <= 3
                 THEN 1 ELSE 0 END) AS effective_sets
      FROM ${DbConstants.tSessions} s
      LEFT JOIN ${DbConstants.tSessionExercises} sx
        ON sx.${DbConstants.cSxSessionId} = s.${DbConstants.cSeId}
      LEFT JOIN ${DbConstants.tSessionSets} ss
        ON ss.${DbConstants.cSsSessionExerciseId} = sx.${DbConstants.cSxId}
      GROUP BY s.${DbConstants.cSeId}
      ORDER BY s.${DbConstants.cSeDate}
    ''');
    return rows.map((r) {
      final avg = r['avg_rir'];
      return (
        date: DateTime.parse(r[DbConstants.cSeDate] as String),
        sessionId: r[DbConstants.cSeId] as int,
        volume: (r['volume'] as num).toDouble(),
        avgRir: avg == null ? null : (avg as num).toDouble(),
        effectiveSets: (r['effective_sets'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  // ── Comparación semanal RIR ───────────────────────────────────────────────────

  /// RIR promedio de esta semana vs la anterior.
  Future<({double? thisWeek, double? lastWeek})> weeklyRirComparison(DateTime now) async {
    final thisMonday = now.subtract(Duration(days: now.weekday - 1));
    final lastMonday = thisMonday.subtract(const Duration(days: 7));
    final thisRir = await _avgRirBetween(thisMonday, thisMonday.add(const Duration(days: 7)));
    final lastRir = await _avgRirBetween(lastMonday, lastMonday.add(const Duration(days: 7)));
    return (thisWeek: thisRir, lastWeek: lastRir);
  }

  Future<double?> _avgRirBetween(DateTime from, DateTime to) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery('''
      SELECT AVG(ss.${DbConstants.cSsRir}) AS avg_rir
      FROM ${DbConstants.tSessionSets} ss
      JOIN ${DbConstants.tSessionExercises} sx
        ON ss.${DbConstants.cSsSessionExerciseId} = sx.${DbConstants.cSxId}
      JOIN ${DbConstants.tSessions} s
        ON sx.${DbConstants.cSxSessionId} = s.${DbConstants.cSeId}
      WHERE s.${DbConstants.cSeDate} >= ? AND s.${DbConstants.cSeDate} < ?
        AND ss.${DbConstants.cSsRir} IS NOT NULL
    ''', [from.toIso8601String(), to.toIso8601String()]);
    final v = result.first['avg_rir'];
    return v == null ? null : (v as num).toDouble();
  }

  // ── Comparación semanal series efectivas ──────────────────────────────────────

  Future<({int thisWeek, int lastWeek})> weeklyEffectiveSetsComparison(DateTime now) async {
    final thisMonday = now.subtract(Duration(days: now.weekday - 1));
    final lastMonday = thisMonday.subtract(const Duration(days: 7));
    final thisCount = await effectiveSets(thisMonday, thisMonday.add(const Duration(days: 7)));
    final lastCount = await effectiveSets(lastMonday, lastMonday.add(const Duration(days: 7)));
    return (thisWeek: thisCount, lastWeek: lastCount);
  }

  // ── Progreso reciente de reps por ejercicio ───────────────────────────────────

  /// Detecta ejercicios donde en la última sesión se hicieron más reps
  /// que en la sesión anterior al mismo peso máximo trabajado.
  Future<List<({String exerciseName, int deltaReps, double weightKg})>>
      recentRepsProgress({int limit = 3}) async {
    final db = await DatabaseHelper.instance.database;
    // Top set (reps máx al peso máx) de las 2 últimas sesiones por ejercicio
    final rows = await db.rawQuery('''
      SELECT e.${DbConstants.cExName} AS name,
             sx.${DbConstants.cSxExerciseId} AS exercise_id,
             s.${DbConstants.cSeDate} AS date,
             MAX(ss.${DbConstants.cSsWeightKg}) AS max_weight,
             MAX(ss.${DbConstants.cSsReps}) AS max_reps
      FROM ${DbConstants.tSessionSets} ss
      JOIN ${DbConstants.tSessionExercises} sx
        ON ss.${DbConstants.cSsSessionExerciseId} = sx.${DbConstants.cSxId}
      JOIN ${DbConstants.tSessions} s
        ON sx.${DbConstants.cSxSessionId} = s.${DbConstants.cSeId}
      JOIN ${DbConstants.tExercises} e
        ON sx.${DbConstants.cSxExerciseId} = e.${DbConstants.cExId}
      WHERE ss.${DbConstants.cSsReps} IS NOT NULL
        AND ss.${DbConstants.cSsWeightKg} IS NOT NULL
      GROUP BY sx.${DbConstants.cSxExerciseId}, s.${DbConstants.cSeId}
      ORDER BY sx.${DbConstants.cSxExerciseId}, s.${DbConstants.cSeDate} DESC
    ''');

    final byExercise = <int, List<Map<String, Object?>>>{};
    for (final r in rows) {
      final id = r['exercise_id'] as int;
      byExercise.putIfAbsent(id, () => []).add(r);
    }

    final insights = <({String exerciseName, int deltaReps, double weightKg})>[];
    for (final list in byExercise.values) {
      if (list.length < 2) continue;
      final latest = list[0];
      final prev = list[1];
      final latestW = (latest['max_weight'] as num).toDouble();
      final prevW = (prev['max_weight'] as num).toDouble();
      if (latestW != prevW) continue;
      final latestR = (latest['max_reps'] as num).toInt();
      final prevR = (prev['max_reps'] as num).toInt();
      final delta = latestR - prevR;
      if (delta <= 0) continue;
      insights.add((
        exerciseName: latest['name'] as String,
        deltaReps: delta,
        weightKg: latestW,
      ));
    }
    insights.sort((a, b) => b.deltaReps.compareTo(a.deltaReps));
    return insights.take(limit).toList();
  }

  // ── Fatiga por grupo muscular ─────────────────────────────────────────────────

  /// Por categoría muscular: volumen y RIR promedio en esta semana vs la anterior.
  /// El consumidor decide qué es fatiga (RIR ↓ sin aumento de volumen).
  Future<List<({String muscleKey, double thisVol, double lastVol, double? thisRir, double? lastRir})>>
      weeklyMuscleFatigue(DateTime now) async {
    final thisMonday = now.subtract(Duration(days: now.weekday - 1));
    final lastMonday = thisMonday.subtract(const Duration(days: 7));
    final thisEnd = thisMonday.add(const Duration(days: 7));
    final lastEnd = lastMonday.add(const Duration(days: 7));

    final thisData = await _muscleAggregates(thisMonday, thisEnd);
    final lastData = await _muscleAggregates(lastMonday, lastEnd);

    final keys = {...thisData.keys, ...lastData.keys};
    return keys.map((k) {
      final t = thisData[k];
      final l = lastData[k];
      return (
        muscleKey: k,
        thisVol: t?.volume ?? 0,
        lastVol: l?.volume ?? 0,
        thisRir: t?.avgRir,
        lastRir: l?.avgRir,
      );
    }).toList();
  }

  Future<Map<String, ({double volume, double? avgRir})>> _muscleAggregates(
      DateTime from, DateTime to) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT e.${DbConstants.cExMuscleCategory} AS mk,
             COALESCE(SUM(ss.${DbConstants.cSsReps} * ss.${DbConstants.cSsWeightKg}), 0) AS volume,
             AVG(ss.${DbConstants.cSsRir}) AS avg_rir
      FROM ${DbConstants.tSessionSets} ss
      JOIN ${DbConstants.tSessionExercises} sx
        ON ss.${DbConstants.cSsSessionExerciseId} = sx.${DbConstants.cSxId}
      JOIN ${DbConstants.tSessions} s
        ON sx.${DbConstants.cSxSessionId} = s.${DbConstants.cSeId}
      JOIN ${DbConstants.tExercises} e
        ON sx.${DbConstants.cSxExerciseId} = e.${DbConstants.cExId}
      WHERE s.${DbConstants.cSeDate} >= ? AND s.${DbConstants.cSeDate} < ?
      GROUP BY e.${DbConstants.cExMuscleCategory}
    ''', [from.toIso8601String(), to.toIso8601String()]);
    return {
      for (final r in rows)
        r['mk'] as String: (
          volume: (r['volume'] as num).toDouble(),
          avgRir: r['avg_rir'] == null ? null : (r['avg_rir'] as num).toDouble(),
        )
    };
  }

  // ── Músculo más trabajado ─────────────────────────────────────────────────────

  /// Categoría muscular con mayor volumen en el rango dado.
  Future<String?> mostWorkedMuscle(DateTime from, DateTime to) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT e.${DbConstants.cExMuscleCategory},
             SUM(ss.${DbConstants.cSsReps} * ss.${DbConstants.cSsWeightKg}) AS volume
      FROM ${DbConstants.tSessionSets} ss
      JOIN ${DbConstants.tSessionExercises} sx
        ON ss.${DbConstants.cSsSessionExerciseId} = sx.${DbConstants.cSxId}
      JOIN ${DbConstants.tSessions} s
        ON sx.${DbConstants.cSxSessionId} = s.${DbConstants.cSeId}
      JOIN ${DbConstants.tExercises} e
        ON sx.${DbConstants.cSxExerciseId} = e.${DbConstants.cExId}
      WHERE s.${DbConstants.cSeDate} >= ? AND s.${DbConstants.cSeDate} < ?
        AND ss.${DbConstants.cSsReps} IS NOT NULL
        AND ss.${DbConstants.cSsWeightKg} IS NOT NULL
      GROUP BY e.${DbConstants.cExMuscleCategory}
      ORDER BY volume DESC
      LIMIT 1
    ''', [from.toIso8601String(), to.toIso8601String()]);
    return rows.isEmpty ? null : rows.first[DbConstants.cExMuscleCategory] as String?;
  }
}
