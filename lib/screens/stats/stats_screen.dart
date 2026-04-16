import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../models/exercise.dart';
import '../../models/muscle_category.dart';
import '../../services/exercise_service.dart';
import '../../services/statistics_service.dart';

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

  // Historial de volumen por sesión
  List<({DateTime date, double totalVolume, int sessionId})> _sessionHistory = [];

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
      _stats.sessionVolumeHistory(),
      _exerciseService.getAll(),
      _stats.personalRecords(),
      _stats.volumeByMuscle(monday, nextMonday),
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
      _sessionHistory = results[6]
          as List<({DateTime date, double totalVolume, int sessionId})>;
      _exercises = exercises;
      _prs = results[8]
          as List<({int exerciseId, String exerciseName, double maxWeightKg, DateTime date})>;
      _muscleVolume = results[9] as Map<String, double>;
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
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                children: [
                  // ── 1. Resumen ────────────────────────────────────────────
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
                  ),

                  const SizedBox(height: 20),

                  // ── 2. Historial de volumen ───────────────────────────────
                  const _SectionHeader(
                      icon: Icons.show_chart, title: 'Volumen por Sesión'),
                  const SizedBox(height: 8),
                  _SessionVolumeCard(history: _sessionHistory),

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
  });

  final double weekVolume;
  final double monthVolume;
  final int currentStreak;
  final int maxStreak;
  final String? weekMuscle;
  final int effectiveSets;
  final ({double thisWeek, double lastWeek}) weekComparison;

  String _fmtVol(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)} t';
    return '${v.toStringAsFixed(0)} kg';
  }

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

class _SessionVolumeCard extends StatelessWidget {
  const _SessionVolumeCard({required this.history});
  final List<({DateTime date, double totalVolume, int sessionId})> history;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final withVolume = history.where((h) => h.totalVolume > 0).toList();

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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _MiniChip('${history.length} sesiones', colors),
                const SizedBox(width: 6),
                if (withVolume.isNotEmpty)
                  _MiniChip(
                    'Prom. ${_fmtVol(withVolume.map((h) => h.totalVolume).reduce((a, b) => a + b) / withVolume.length)}',
                    colors,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (withVolume.length >= 2)
              SizedBox(
                height: 180,
                child: _VolumeLineChart(data: withVolume, colors: colors),
              )
            else
              Center(
                child: Text(
                  'Registra más sesiones con peso para ver la gráfica',
                  style: TextStyle(color: colors.outlineVariant, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
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
                        Text(
                          h.totalVolume > 0 ? _fmtVol(h.totalVolume) : 'Sin peso',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: h.totalVolume > 0
                                ? colors.primary
                                : colors.outline,
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

  String _fmtVol(double v) => '${v.toStringAsFixed(0)} kg';
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
            final name = _muscleName(e.key);
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

  String _muscleName(String key) {
    // Intenta encontrar el MuscleCategory correspondiente por nombre
    for (final cat in MuscleCategory.values) {
      if (cat.name == key) return cat.displayName;
    }
    return key;
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

class _VolumeLineChart extends StatelessWidget {
  const _VolumeLineChart({required this.data, required this.colors});
  final List<({DateTime date, double totalVolume, int sessionId})> data;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final spots = data
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.totalVolume))
        .toList();
    final values = data.map((d) => d.totalVolume);
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final yPad = (maxY - minY) * 0.2 + 10;

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
              reservedSize: 48,
              getTitlesWidget: (v, _) {
                final label = v >= 1000
                    ? '${(v / 1000).toStringAsFixed(0)}k'
                    : v.toStringAsFixed(0);
                return Text(label,
                    style: TextStyle(fontSize: 10, color: colors.outline));
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (data.length / 4).ceilToDouble().clamp(1, 9999),
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= data.length) return const SizedBox();
                final d = data[i].date;
                return Text('${d.day}/${d.month}',
                    style: TextStyle(fontSize: 10, color: colors.outline));
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        minY: (minY - yPad).clamp(0, double.infinity),
        maxY: maxY + yPad,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((s) {
              final i = s.x.toInt();
              final d = data[i].date;
              return LineTooltipItem(
                '${d.day}/${d.month}\n${s.y.toStringAsFixed(0)} kg',
                TextStyle(color: colors.onSurface, fontSize: 11),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: colors.primary,
            barWidth: 2.5,
            dotData: FlDotData(
              getDotPainter: (_, __, ___, ____) =>
                  FlDotCirclePainter(radius: 3.5, color: colors.primary, strokeWidth: 0),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: colors.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
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
