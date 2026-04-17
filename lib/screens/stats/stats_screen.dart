import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/widgets/info_button.dart';
import '../../models/exercise.dart';
import '../../models/muscle_category.dart';
import '../../services/exercise_service.dart';
import '../../services/statistics_service.dart';

String _fmtKg(double v) {
  final n = v.round();
  final s = n.toString();
  final start = s.length % 3;
  final buf = StringBuffer();
  if (start > 0) buf.write(s.substring(0, start));
  for (int i = start; i < s.length; i += 3) {
    if (i > 0) buf.write(',');
    buf.write(s.substring(i, i + 3));
  }
  return '$buf kg';
}

String _muscleDisplayName(String key) {
  for (final cat in MuscleCategory.values) {
    if (cat.name == key) return cat.displayName;
  }
  return key;
}

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _stats = StatisticsService.instance;
  final _exerciseService = ExerciseService.instance;

  bool _loading = true;

  // Resumen
  double _weekVolume = 0;
  double _monthVolume = 0;
  int _currentStreak = 0;
  int _maxStreak = 0;
  String? _weekMuscle;
  int _effectiveSets = 0;
  ({double thisWeek, double lastWeek}) _weekComparison = (thisWeek: 0, lastWeek: 0);
  ({double? thisWeek, double? lastWeek}) _rirComparison = (thisWeek: null, lastWeek: null);
  ({int thisWeek, int lastWeek}) _effSetsComparison = (thisWeek: 0, lastWeek: 0);

  // Historial combinado volumen + RIR por sesión
  List<({DateTime date, int sessionId, double volume, double? avgRir, int effectiveSets})>
      _sessionHistory = [];

  // Insights
  List<({String exerciseName, int deltaReps, double weightKg})> _repsProgress = [];
  List<({String muscleKey, double thisVol, double lastVol, double? thisRir, double? lastRir})>
      _muscleFatigue = [];

  // Por ejercicio
  List<Exercise> _exercises = [];
  Exercise? _selectedExercise;
  List<({DateTime date, double maxWeightKg})> _exerciseHistory = [];

  // Récords personales
  List<({int exerciseId, String exerciseName, double maxWeightKg, DateTime date})> _prs = [];

  // Volumen por grupo muscular (semana actual)
  Map<String, double> _muscleVolume = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final nextMonday = monday.add(const Duration(days: 7));

    final results = await Future.wait([
      _stats.weeklyVolume(now),
      _stats.monthlyVolume(now),
      _stats.streaks(),
      _stats.mostWorkedMuscle(monday, nextMonday),
      _stats.effectiveSets(monday, nextMonday),
      _stats.weekComparison(now),
      _stats.sessionVolumeAndRirHistory(),
      _exerciseService.getAll(),
      _stats.personalRecords(),
      _stats.volumeByMuscle(monday, nextMonday),
      _stats.weeklyRirComparison(now),
      _stats.weeklyEffectiveSetsComparison(now),
      _stats.recentRepsProgress(),
      _stats.weeklyMuscleFatigue(now),
    ]);

    final s = results[2] as ({int currentStreak, int maxStreak});
    final exercises = results[7] as List<Exercise>;

    setState(() {
      _weekVolume = results[0] as double;
      _monthVolume = results[1] as double;
      _currentStreak = s.currentStreak;
      _maxStreak = s.maxStreak;
      _weekMuscle = results[3] as String?;
      _effectiveSets = results[4] as int;
      _weekComparison = results[5] as ({double thisWeek, double lastWeek});
      _sessionHistory = results[6] as List<
          ({DateTime date, int sessionId, double volume, double? avgRir, int effectiveSets})>;
      _exercises = exercises;
      _prs = results[8]
          as List<({int exerciseId, String exerciseName, double maxWeightKg, DateTime date})>;
      _muscleVolume = results[9] as Map<String, double>;
      _rirComparison = results[10] as ({double? thisWeek, double? lastWeek});
      _effSetsComparison = results[11] as ({int thisWeek, int lastWeek});
      _repsProgress = results[12]
          as List<({String exerciseName, int deltaReps, double weightKg})>;
      _muscleFatigue = results[13] as List<
          ({String muscleKey, double thisVol, double lastVol, double? thisRir, double? lastRir})>;
      _loading = false;
    });

    if (exercises.isNotEmpty && _selectedExercise == null) {
      await _loadExerciseHistory(exercises.first);
    }
  }

  Future<void> _loadExerciseHistory(Exercise exercise) async {
    final history = await _stats.maxWeightHistory(exercise.id!);
    setState(() {
      _selectedExercise = exercise;
      _exerciseHistory = history;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas'),
        centerTitle: false,
        actions: [
          const InfoButton(text: 'Analiza tu progreso: volumen, músculos trabajados, evolución y récords personales.'),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                children: [
                  // ── 1. Insights automáticos (elemento principal) ──────────
                  const _SectionHeader(
                      icon: Icons.insights, title: 'Tu Progreso'),
                  const SizedBox(height: 8),
                  _InsightsCard(
                    weekComparison: _weekComparison,
                    rirComparison: _rirComparison,
                    effSetsComparison: _effSetsComparison,
                    repsProgress: _repsProgress,
                    muscleFatigue: _muscleFatigue,
                    currentStreak: _currentStreak,
                  ),

                  const SizedBox(height: 20),

                  // ── 2. Resumen ────────────────────────────────────────────
                  const _SectionHeader(icon: Icons.bar_chart, title: 'Resumen'),
                  const SizedBox(height: 8),
                  _SummaryCard(
                    weekVolume: _weekVolume,
                    monthVolume: _monthVolume,
                    currentStreak: _currentStreak,
                    maxStreak: _maxStreak,
                    weekMuscle: _weekMuscle,
                    effectiveSets: _effectiveSets,
                    weekComparison: _weekComparison,
                    rirComparison: _rirComparison,
                  ),

                  const SizedBox(height: 20),

                  // ── 3. Volumen + RIR por sesión ───────────────────────────
                  const _SectionHeader(
                      icon: Icons.show_chart, title: 'Volumen e Intensidad'),
                  const SizedBox(height: 8),
                  _VolumeRirCard(history: _sessionHistory),

                  const SizedBox(height: 20),

                  // ── 3. Volumen por grupo muscular (semana) ────────────────
                  const _SectionHeader(
                      icon: Icons.accessibility_new, title: 'Músculos esta Semana'),
                  const SizedBox(height: 8),
                  _MuscleVolumeCard(muscleVolume: _muscleVolume),

                  const SizedBox(height: 20),

                  // ── 4. Progreso por ejercicio ─────────────────────────────
                  const _SectionHeader(
                      icon: Icons.fitness_center, title: 'Progreso por Ejercicio'),
                  const SizedBox(height: 8),
                  _ExerciseProgressCard(
                    exercises: _exercises,
                    selected: _selectedExercise,
                    history: _exerciseHistory,
                    onExerciseChanged: _loadExerciseHistory,
                  ),

                  const SizedBox(height: 20),

                  // ── 5. Récords personales ─────────────────────────────────
                  const _SectionHeader(
                      icon: Icons.emoji_events, title: 'Récords Personales'),
                  const SizedBox(height: 8),
                  _PersonalRecordsCard(prs: _prs),

                  const SizedBox(height: 12),
                ],
              ),
            ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.primary),
        const SizedBox(width: 6),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: colors.primary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: colors.outlineVariant)),
      ],
    );
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.weekVolume,
    required this.monthVolume,
    required this.currentStreak,
    required this.maxStreak,
    required this.weekMuscle,
    required this.effectiveSets,
    required this.weekComparison,
    required this.rirComparison,
  });

  final double weekVolume;
  final double monthVolume;
  final int currentStreak;
  final int maxStreak;
  final String? weekMuscle;
  final int effectiveSets;
  final ({double thisWeek, double lastWeek}) weekComparison;
  final ({double? thisWeek, double? lastWeek}) rirComparison;

  String _fmtVol(double v) => _fmtKg(v);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final weekDiff = weekComparison.lastWeek == 0
        ? null
        : ((weekComparison.thisWeek - weekComparison.lastWeek) /
                weekComparison.lastWeek *
                100)
            .toStringAsFixed(0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Racha
            Row(
              children: [
                Text(currentStreak > 0 ? '🔥' : '💤',
                    style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Racha actual',
                          style: TextStyle(fontSize: 11, color: colors.outline)),
                      Text(
                        '$currentStreak ${currentStreak == 1 ? 'día' : 'días'} seguidos',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Máxima',
                        style: TextStyle(fontSize: 11, color: colors.outline)),
                    Text('$maxStreak días',
                        style: TextStyle(
                            color: colors.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),

            const Divider(height: 24),

            // Volumen semana / mes
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Volumen semana',
                    value: _fmtVol(weekVolume),
                    icon: Icons.calendar_view_week,
                    colors: colors,
                    suffix: weekDiff != null
                        ? (weekComparison.thisWeek >= weekComparison.lastWeek
                            ? '+$weekDiff%'
                            : '$weekDiff%')
                        : null,
                    suffixColor: weekDiff != null
                        ? (weekComparison.thisWeek >= weekComparison.lastWeek
                            ? Colors.green
                            : colors.error)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    label: 'Volumen mes',
                    value: _fmtVol(monthVolume),
                    icon: Icons.calendar_month,
                    colors: colors,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Series efectivas y músculo top
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Series efectivas',
                    value: '$effectiveSets',
                    icon: Icons.local_fire_department,
                    colors: colors,
                    subtitle: 'RIR ≤ 3 esta semana',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    label: 'Top músculo',
                    value: weekMuscle ?? '—',
                    icon: Icons.accessibility_new,
                    colors: colors,
                    subtitle: 'mayor volumen',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // RIR promedio con comparación
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'RIR promedio',
                    value: rirComparison.thisWeek == null
                        ? '—'
                        : rirComparison.thisWeek!.toStringAsFixed(1),
                    icon: Icons.bolt,
                    colors: colors,
                    subtitle: rirComparison.lastWeek == null
                        ? 'esta semana'
                        : 'vs ${rirComparison.lastWeek!.toStringAsFixed(1)} sem. ant.',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            Text(
              'Volumen = peso × reps × series',
              style: TextStyle(fontSize: 10, color: colors.outlineVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.colors,
    this.subtitle,
    this.suffix,
    this.suffixColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final ColorScheme colors;
  final String? subtitle;
  final String? suffix;
  final Color? suffixColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: colors.primary),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(fontSize: 11, color: colors.outline)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (suffix != null) ...[
                const SizedBox(width: 4),
                Text(suffix!,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: suffixColor ?? colors.primary)),
              ],
            ],
          ),
          if (subtitle != null)
            Text(subtitle!,
                style: TextStyle(fontSize: 10, color: colors.outline)),
        ],
      ),
    );
  }
}

// ── Session volume card ───────────────────────────────────────────────────────

class _VolumeRirCard extends StatelessWidget {
  const _VolumeRirCard({required this.history});
  final List<({DateTime date, int sessionId, double volume, double? avgRir, int effectiveSets})>
      history;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final withVolume = history.where((h) => h.volume > 0).toList();
    final withRir = history.where((h) => h.avgRir != null).toList();

    if (history.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text('Sin sesiones registradas',
                style: TextStyle(color: colors.outline)),
          ),
        ),
      );
    }

    final avgVol = withVolume.isEmpty
        ? 0.0
        : withVolume.map((h) => h.volume).reduce((a, b) => a + b) / withVolume.length;
    final avgRir = withRir.isEmpty
        ? null
        : withRir.map((h) => h.avgRir!).reduce((a, b) => a + b) / withRir.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _MiniChip('${history.length} sesiones', colors),
                if (withVolume.isNotEmpty)
                  _MiniChip('Prom. ${_fmtKg(avgVol)}', colors),
                if (avgRir != null)
                  _MiniChip('RIR prom. ${avgRir.toStringAsFixed(1)}', colors),
              ],
            ),
            const SizedBox(height: 12),
            if (withVolume.length >= 2)
              SizedBox(
                height: 200,
                child: _VolumeRirChart(data: withVolume, colors: colors),
              )
            else
              Center(
                child: Text(
                  'Registra más sesiones con peso para ver la gráfica',
                  style: TextStyle(color: colors.outlineVariant, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Más volumen con mismo RIR = progreso · RIR bajando sin subir reps/peso = fatiga',
              style: TextStyle(fontSize: 10, color: colors.outlineVariant),
              textAlign: TextAlign.center,
            ),
            if (history.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Últimas sesiones',
                  style: TextStyle(
                      fontSize: 12,
                      color: colors.outline,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              ...history.reversed.take(5).map((h) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Text(_fmtDate(h.date),
                            style: const TextStyle(fontSize: 13)),
                        const Spacer(),
                        if (h.avgRir != null) ...[
                          Text('RIR ${h.avgRir!.toStringAsFixed(1)}',
                              style: const TextStyle(fontSize: 12, color: Colors.orange)),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          h.volume > 0 ? _fmtKg(h.volume) : 'Sin peso',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: h.volume > 0 ? colors.primary : colors.outline,
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

class _MiniChip extends StatelessWidget {
  const _MiniChip(this.label, this.colors);
  final String label;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: colors.onSurface)),
    );
  }
}

// ── Muscle volume card ────────────────────────────────────────────────────────

class _MuscleVolumeCard extends StatelessWidget {
  const _MuscleVolumeCard({required this.muscleVolume});
  final Map<String, double> muscleVolume;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (muscleVolume.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text(
              'Registra entrenamientos con peso esta semana',
              style: TextStyle(color: colors.outline),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final maxVol = muscleVolume.values.reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: muscleVolume.entries.map((e) {
            final ratio = e.value / maxVol;
            // Traduce muscle_category key → nombre mostrable
            final name = _muscleDisplayName(e.key);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name,
                            style: const TextStyle(fontSize: 12)),
                      ),
                      Text(
                        '${e.value.toStringAsFixed(0)} kg',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 8,
                      backgroundColor: colors.surfaceContainerHighest,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(colors.primary),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

}

// ── Exercise progress card ────────────────────────────────────────────────────

class _ExerciseProgressCard extends StatelessWidget {
  const _ExerciseProgressCard({
    required this.exercises,
    required this.selected,
    required this.history,
    required this.onExerciseChanged,
  });
  final List<Exercise> exercises;
  final Exercise? selected;
  final List<({DateTime date, double maxWeightKg})> history;
  final void Function(Exercise) onExerciseChanged;

  static List<DropdownMenuItem<Exercise>> _buildItems(
      List<Exercise> exercises, ColorScheme colors) {
    final grouped = <MuscleCategory, List<Exercise>>{};
    for (final cat in MuscleCategory.values) {
      final items = exercises.where((e) => e.muscleCategory == cat).toList();
      if (items.isNotEmpty) grouped[cat] = items;
    }
    final result = <DropdownMenuItem<Exercise>>[];
    for (final entry in grouped.entries) {
      result.add(DropdownMenuItem<Exercise>(
        enabled: false,
        child: Text(
          entry.key.displayName.toUpperCase(),
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: colors.primary,
              letterSpacing: 1.2),
        ),
      ));
      for (final ex in entry.value) {
        result.add(DropdownMenuItem<Exercise>(
          value: ex,
          child: Padding(
              padding: const EdgeInsets.only(left: 8), child: Text(ex.name)),
        ));
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (exercises.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text('Sin ejercicios',
                style: TextStyle(color: colors.outline)),
          ),
        ),
      );
    }

    final best = history.isEmpty
        ? null
        : history.map((h) => h.maxWeightKg).reduce((a, b) => a > b ? a : b);
    final last = history.isEmpty ? null : history.last;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<Exercise>(
              initialValue: selected,
              decoration: const InputDecoration(
                labelText: 'Ejercicio',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: _buildItems(exercises, colors),
              onChanged: (e) { if (e != null) onExerciseChanged(e); },
            ),
            const SizedBox(height: 16),
            if (selected == null)
              Center(child: Text('Selecciona un ejercicio',
                  style: TextStyle(color: colors.outline)))
            else if (history.isEmpty)
              Center(child: Text('Sin datos para este ejercicio',
                  style: TextStyle(color: colors.outline)))
            else ...[
              Row(
                children: [
                  _MiniChip('Máx. ${best!.toStringAsFixed(1)} kg', colors),
                  const SizedBox(width: 6),
                  _MiniChip('Último ${last!.maxWeightKg.toStringAsFixed(1)} kg', colors),
                ],
              ),
              const SizedBox(height: 16),
              if (history.length >= 2)
                SizedBox(
                  height: 180,
                  child: _WeightLineChart(history: history, colors: colors),
                )
              else
                Center(
                  child: Text(
                    'Registra al menos 2 sesiones para ver la gráfica',
                    style: TextStyle(color: colors.outlineVariant, fontSize: 12),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Personal records card ─────────────────────────────────────────────────────

class _PersonalRecordsCard extends StatelessWidget {
  const _PersonalRecordsCard({required this.prs});
  final List<({int exerciseId, String exerciseName, double maxWeightKg, DateTime date})> prs;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (prs.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text(
              'Registra series con peso para ver tus récords',
              style: TextStyle(color: colors.outline),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: prs.asMap().entries.map((entry) {
            final i = entry.key;
            final pr = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '#${i + 1}',
                      style: TextStyle(
                          fontSize: 12,
                          color: i == 0 ? Colors.amber : colors.outline,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      pr.exerciseName,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${pr.maxWeightKg.toStringAsFixed(pr.maxWeightKg == pr.maxWeightKg.truncateToDouble() ? 0 : 1)} kg',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                            fontSize: 14),
                      ),
                      Text(
                        '${pr.date.day}/${pr.date.month}/${pr.date.year}',
                        style: TextStyle(fontSize: 10, color: colors.outline),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Volume line chart ─────────────────────────────────────────────────────────

class _VolumeRirChart extends StatelessWidget {
  const _VolumeRirChart({required this.data, required this.colors});
  final List<({DateTime date, int sessionId, double volume, double? avgRir, int effectiveSets})>
      data;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    const double leftReserved = 48;
    const double rightReserved = 28;
    const double bottomReserved = 24;
    const rirColor = Colors.orange;

    final volumeSpots = data
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.volume))
        .toList();
    final rirSpots = <FlSpot>[];
    for (final e in data.asMap().entries) {
      final r = e.value.avgRir;
      if (r != null) rirSpots.add(FlSpot(e.key.toDouble(), r));
    }

    final values = data.map((d) => d.volume);
    final minVol = values.reduce((a, b) => a < b ? a : b);
    final maxVol = values.reduce((a, b) => a > b ? a : b);
    final yPad = (maxVol - minVol) * 0.2 + 10;
    const minX = 0.0;
    final maxX = (data.length - 1).toDouble();

    return Column(
      children: [
        // Leyenda
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendDot(color: colors.primary, label: 'Volumen (kg)'),
            const SizedBox(width: 14),
            const _LegendDot(color: rirColor, label: 'RIR promedio'),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Stack(
            children: [
              // Capa 1: volumen con eje izquierdo
              LineChart(
                LineChartData(
                  minX: minX,
                  maxX: maxX,
                  minY: (minVol - yPad).clamp(0, double.infinity),
                  maxY: maxVol + yPad,
                  gridData: FlGridData(
                    show: true,
                    getDrawingHorizontalLine: (v) => FlLine(
                        color: colors.outlineVariant.withValues(alpha: 0.3),
                        strokeWidth: 1),
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(
                            showTitles: false, reservedSize: rightReserved)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: leftReserved,
                        getTitlesWidget: (v, _) {
                          final label = v >= 1000
                              ? '${(v / 1000).toStringAsFixed(0)}k'
                              : v.toStringAsFixed(0);
                          return Text(label,
                              style: TextStyle(
                                  fontSize: 10, color: colors.outline));
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: bottomReserved,
                        interval:
                            (data.length / 4).ceilToDouble().clamp(1, 9999),
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= data.length) {
                            return const SizedBox();
                          }
                          final d = data[i].date;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('${d.day}/${d.month}',
                                style: TextStyle(
                                    fontSize: 10, color: colors.outline)),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => spots.map((s) {
                        final i = s.x.toInt();
                        final d = data[i].date;
                        final rir = data[i].avgRir;
                        final rirLine = rir == null
                            ? ''
                            : '\nRIR ${rir.toStringAsFixed(1)}';
                        return LineTooltipItem(
                          '${d.day}/${d.month}\n${s.y.toStringAsFixed(0)} kg$rirLine',
                          TextStyle(color: colors.onSurface, fontSize: 11),
                        );
                      }).toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: volumeSpots,
                      isCurved: true,
                      color: colors.primary,
                      barWidth: 2.5,
                      dotData: FlDotData(
                        getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                            radius: 3.5,
                            color: colors.primary,
                            strokeWidth: 0),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: colors.primary.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
              // Capa 2: RIR con eje derecho
              if (rirSpots.length >= 2)
                IgnorePointer(
                  child: LineChart(
                    LineChartData(
                      minX: minX,
                      maxX: maxX,
                      minY: 0,
                      maxY: 10,
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(
                            sideTitles: SideTitles(
                                showTitles: false, reservedSize: leftReserved)),
                        bottomTitles: const AxisTitles(
                            sideTitles: SideTitles(
                                showTitles: false,
                                reservedSize: bottomReserved)),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: rightReserved,
                            interval: 2,
                            getTitlesWidget: (v, _) => Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(v.toInt().toString(),
                                  style: const TextStyle(
                                      fontSize: 10, color: rirColor)),
                            ),
                          ),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: rirSpots,
                          isCurved: true,
                          color: rirColor,
                          barWidth: 2,
                          dashArray: const [6, 4],
                          dotData: FlDotData(
                            getDotPainter: (_, __, ___, ____) =>
                                FlDotCirclePainter(
                                    radius: 2.5,
                                    color: rirColor,
                                    strokeWidth: 0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

// ── Weight line chart ─────────────────────────────────────────────────────────

class _WeightLineChart extends StatelessWidget {
  const _WeightLineChart({required this.history, required this.colors});
  final List<({DateTime date, double maxWeightKg})> history;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final spots = history
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.maxWeightKg))
        .toList();
    final values = history.map((h) => h.maxWeightKg);
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final yPad = (maxY - minY) * 0.2 + 5;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: colors.outlineVariant.withValues(alpha: 0.3), strokeWidth: 1),
          drawVerticalLine: false,
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (v, _) => Text(
                '${v.toStringAsFixed(0)}kg',
                style: TextStyle(fontSize: 10, color: colors.outline),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (history.length / 4).ceilToDouble().clamp(1, 9999),
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= history.length) return const SizedBox();
                final d = history[i].date;
                return Text('${d.day}/${d.month}',
                    style: TextStyle(fontSize: 10, color: colors.outline));
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        minY: minY - yPad,
        maxY: maxY + yPad,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((s) {
              final i = s.x.toInt();
              final d = history[i].date;
              return LineTooltipItem(
                '${d.day}/${d.month}\n${s.y.toStringAsFixed(1)} kg',
                TextStyle(color: colors.onSurface, fontSize: 11),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: colors.secondary,
            barWidth: 2.5,
            dotData: FlDotData(
              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 3.5, color: colors.secondary, strokeWidth: 0),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: colors.secondary.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Insights card ─────────────────────────────────────────────────────────────

enum _InsightTone { positive, neutral, warning }

class _Insight {
  const _Insight(this.icon, this.text, this.tone);
  final IconData icon;
  final String text;
  final _InsightTone tone;
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({
    required this.weekComparison,
    required this.rirComparison,
    required this.effSetsComparison,
    required this.repsProgress,
    required this.muscleFatigue,
    required this.currentStreak,
  });

  final ({double thisWeek, double lastWeek}) weekComparison;
  final ({double? thisWeek, double? lastWeek}) rirComparison;
  final ({int thisWeek, int lastWeek}) effSetsComparison;
  final List<({String exerciseName, int deltaReps, double weightKg})> repsProgress;
  final List<({String muscleKey, double thisVol, double lastVol, double? thisRir, double? lastRir})>
      muscleFatigue;
  final int currentStreak;

  List<_Insight> _buildInsights() {
    final out = <_Insight>[];

    // 1. Rep PRs — señal más fuerte de progreso
    for (final p in repsProgress.take(2)) {
      final kgLabel = p.weightKg == p.weightKg.truncateToDouble()
          ? p.weightKg.toStringAsFixed(0)
          : p.weightKg.toStringAsFixed(1);
      out.add(_Insight(
        Icons.trending_up,
        '+${p.deltaReps} reps en ${p.exerciseName} ($kgLabel kg)',
        _InsightTone.positive,
      ));
    }

    // 2. Cambio % de volumen semanal
    if (weekComparison.lastWeek > 0) {
      final pct = ((weekComparison.thisWeek - weekComparison.lastWeek) /
              weekComparison.lastWeek *
              100)
          .round();
      if (pct >= 5) {
        out.add(_Insight(
            Icons.stacked_bar_chart, '+$pct% volumen esta semana', _InsightTone.positive));
      } else if (pct <= -10) {
        out.add(_Insight(
            Icons.stacked_bar_chart, '$pct% volumen vs semana pasada', _InsightTone.warning));
      }
    }

    // 3. Fatiga por grupo muscular (RIR cae ≥1 y volumen no subió)
    for (final m in muscleFatigue) {
      final tr = m.thisRir;
      final lr = m.lastRir;
      if (tr == null || lr == null) continue;
      if (lr - tr >= 1.0 && m.thisVol <= m.lastVol * 1.05) {
        out.add(_Insight(
          Icons.warning_amber_rounded,
          'Fatiga detectada en ${_muscleDisplayName(m.muscleKey)}',
          _InsightTone.warning,
        ));
      }
    }

    // 4. Cambio de intensidad (RIR)
    final tr = rirComparison.thisWeek;
    final lr = rirComparison.lastWeek;
    if (tr != null && lr != null) {
      final delta = tr - lr;
      if (delta <= -0.8) {
        out.add(const _Insight(
            Icons.local_fire_department,
            'Entrenamiento más intenso que la semana pasada',
            _InsightTone.positive));
      } else if (delta >= 0.8) {
        out.add(const _Insight(
            Icons.nightlight_round,
            'Entrenamiento menos intenso esta semana',
            _InsightTone.neutral));
      }
    }

    // 5. Series efectivas
    final ds = effSetsComparison.thisWeek - effSetsComparison.lastWeek;
    if (ds >= 3) {
      out.add(_Insight(
          Icons.check_circle_outline,
          '+$ds series efectivas vs semana pasada',
          _InsightTone.positive));
    } else if (ds <= -3 && effSetsComparison.lastWeek > 0) {
      out.add(_Insight(
          Icons.remove_circle_outline,
          '$ds series efectivas vs semana pasada',
          _InsightTone.warning));
    }

    // 6. Racha
    if (currentStreak >= 3) {
      out.add(_Insight(Icons.local_fire_department,
          'Racha de $currentStreak días — consistencia fuerte', _InsightTone.positive));
    }

    return out.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final insights = _buildInsights();

    if (insights.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text(
              'Registra más sesiones para ver insights automáticos',
              style: TextStyle(color: colors.outline),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: insights
              .map((i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _InsightTile(insight: i, colors: colors),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({required this.insight, required this.colors});
  final _Insight insight;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (insight.tone) {
      _InsightTone.positive => (Colors.green.withValues(alpha: 0.12), Colors.green.shade700),
      _InsightTone.warning => (colors.error.withValues(alpha: 0.12), colors.error),
      _InsightTone.neutral => (colors.surfaceContainerHighest, colors.onSurface),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(insight.icon, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              insight.text,
              style: TextStyle(
                  fontSize: 13, color: fg, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
