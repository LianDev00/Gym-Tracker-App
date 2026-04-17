import 'package:flutter/material.dart';
import '../../core/widgets/info_button.dart';
import '../../models/session.dart';
import '../../services/exercise_service.dart';
import '../../services/session_service.dart';

// ── Data holders ──────────────────────────────────────────────────────────────

class _SetData {
  const _SetData({this.weightKg, this.reps, this.rir});
  final double? weightKg;
  final int? reps;
  final int? rir;

  bool get hasData => weightKg != null || reps != null;
}

class _ExerciseData {
  const _ExerciseData({required this.name, required this.sets});
  final String name;
  final List<_SetData> sets;
}

class _SessionSummary {
  const _SessionSummary({required this.session, required this.exerciseData});
  final Session session;
  final List<_ExerciseData> exerciseData;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _sessionService = SessionService.instance;
  final _exerciseService = ExerciseService.instance;

  List<_SessionSummary> _summaries = [];
  Set<String> _activeDays = {};
  DateTime _calendarMonth = DateTime.now();
  int _streak = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final sessions = await _sessionService.getAll();

    final allDayKeys = sessions.map((s) => _dayKey(s.date)).toSet();

    final monthDays = await _sessionService.getDaysWithSessionInMonth(
      _calendarMonth.year,
      _calendarMonth.month,
    );

    // Streak
    final today = DateTime.now();
    int streak = 0;
    DateTime cursor = DateTime(today.year, today.month, today.day);
    while (allDayKeys.contains(_dayKey(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    // Cargar ejercicios y sets completos para cada sesión
    final allExercises = await _exerciseService.getAll();
    final exerciseMap = {for (final e in allExercises) e.id!: e};

    final summaries = await Future.wait(
      sessions.map((session) async {
        final seList = await _sessionService.getExercisesForSession(session.id!);
        final exerciseData = <_ExerciseData>[];

        for (final se in seList) {
          final exercise = exerciseMap[se.exerciseId];
          final name = exercise?.name ?? '?';
          final dbSets = await _sessionService.getSetsForSessionExercise(se.id!);
          final sets = dbSets
              .map((s) => _SetData(weightKg: s.weightKg, reps: s.reps, rir: s.rir))
              .where((s) => s.hasData)
              .toList();
          exerciseData.add(_ExerciseData(name: name, sets: sets));
        }

        return _SessionSummary(session: session, exerciseData: exerciseData);
      }),
    );

    setState(() {
      _summaries = summaries;
      _activeDays = monthDays.map(_dayKey).toSet();
      _streak = streak;
      _loading = false;
    });
  }

  Future<void> _changeMonth(int delta) async {
    final newMonth = DateTime(
      _calendarMonth.year,
      _calendarMonth.month + delta,
    );
    _calendarMonth = newMonth;
    final monthDays = await _sessionService.getDaysWithSessionInMonth(
      newMonth.year,
      newMonth.month,
    );
    setState(() => _activeDays = monthDays.map(_dayKey).toSet());
  }

  Future<void> _deleteSession(Session session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar sesión'),
        content: const Text('¿Eliminar esta sesión y todos sus datos?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _sessionService.delete(session.id!);
    await _load();
  }

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        centerTitle: false,
        actions: [
          const InfoButton(text: 'Revisa tus sesiones pasadas. Toca una para ver ejercicios y series en detalle.'),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  _StreakBanner(streak: _streak),
                  _CalendarCard(
                    month: _calendarMonth,
                    activeDays: _activeDays,
                    onPrevMonth: () => _changeMonth(-1),
                    onNextMonth: () => _changeMonth(1),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text('Sesiones',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  if (_summaries.isEmpty)
                    _EmptyState()
                  else
                    ..._summaries.map((s) => _SessionCard(
                          summary: s,
                          onDelete: () => _deleteSession(s.session),
                        )),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

// ── Streak banner ─────────────────────────────────────────────────────────────

class _StreakBanner extends StatelessWidget {
  const _StreakBanner({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: streak > 0 ? colors.primaryContainer : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text(
            streak > 0 ? '🔥' : '💤',
            style: const TextStyle(fontSize: 32),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                streak > 0 ? '$streak día${streak == 1 ? '' : 's'} seguidos' : 'Sin racha activa',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: streak > 0 ? colors.onPrimaryContainer : colors.onSurface,
                ),
              ),
              Text(
                streak > 0 ? '¡Sigue así!' : 'Entrena hoy para empezar',
                style: TextStyle(
                  fontSize: 13,
                  color: streak > 0
                      ? colors.onPrimaryContainer.withValues(alpha: 0.7)
                      : colors.outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Calendar card ─────────────────────────────────────────────────────────────

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.month,
    required this.activeDays,
    required this.onPrevMonth,
    required this.onNextMonth,
  });

  final DateTime month;
  final Set<String> activeDays;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;

  static const _weekDays = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  static const _monthNames = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  String _dayKey(int year, int m, int d) =>
      '$year-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final today = DateTime.now();

    final firstDay = DateTime(month.year, month.month, 1);
    final startOffset = (firstDay.weekday - 1) % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: onPrevMonth,
                ),
                Text(
                  '${_monthNames[month.month - 1]} ${month.year}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: onNextMonth,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: _weekDays
                  .map((d) => Expanded(
                        child: Text(d,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12,
                                color: colors.outline,
                                fontWeight: FontWeight.bold)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
              ),
              itemCount: startOffset + daysInMonth,
              itemBuilder: (_, index) {
                if (index < startOffset) return const SizedBox();
                final day = index - startOffset + 1;
                final key = _dayKey(month.year, month.month, day);
                final isActive = activeDays.contains(key);
                final isToday = today.year == month.year &&
                    today.month == month.month &&
                    today.day == day;

                return Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isActive
                        ? colors.primary
                        : isToday
                            ? colors.surfaceContainerHighest
                            : Colors.transparent,
                    shape: BoxShape.circle,
                    border: isToday && !isActive
                        ? Border.all(color: colors.primary, width: 1.5)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isActive || isToday
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isActive
                            ? colors.onPrimary
                            : colors.onSurface,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Session card ──────────────────────────────────────────────────────────────

class _SessionCard extends StatefulWidget {
  const _SessionCard({required this.summary, required this.onDelete});
  final _SessionSummary summary;
  final VoidCallback onDelete;

  @override
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard> {
  bool _expanded = false;

  String _formatDate(DateTime date) {
    const months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(sessionDay).inDays;
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Ayer';
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(DateTime date) {
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _fmtWeight(double v) =>
      v == v.truncateToDouble() ? '${v.toInt()} kg' : '$v kg';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final session = widget.summary.session;
    final exerciseData = widget.summary.exerciseData;
    final totalExercises = exerciseData.length;
    final totalSets = exerciseData.fold(0, (sum, e) => sum + e.sets.length);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────────
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 15, color: colors.primary),
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(session.date),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                            fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      Text(_formatTime(session.date),
                          style: TextStyle(color: colors.outline, fontSize: 12)),
                      const Spacer(),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: colors.outline,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: widget.onDelete,
                        color: colors.error,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _InfoChip(
                        icon: Icons.fitness_center,
                        label: '$totalExercises ejercicio${totalExercises == 1 ? '' : 's'}',
                        colors: colors,
                      ),
                      const SizedBox(width: 6),
                      _InfoChip(
                        icon: Icons.format_list_numbered,
                        label: '$totalSets series',
                        colors: colors,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Detalle de ejercicios (expandible) ────────────────────────────
          if (_expanded) ...[
            Divider(height: 1, color: colors.outlineVariant.withValues(alpha: 0.4)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: exerciseData.isEmpty
                  ? Text('Sin ejercicios',
                      style: TextStyle(color: colors.outline, fontSize: 13))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: exerciseData
                          .map((ex) => _ExerciseDetail(
                                exerciseData: ex,
                                colors: colors,
                                fmtWeight: _fmtWeight,
                              ))
                          .toList(),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Exercise detail (dentro del card expandido) ───────────────────────────────

class _ExerciseDetail extends StatelessWidget {
  const _ExerciseDetail({
    required this.exerciseData,
    required this.colors,
    required this.fmtWeight,
  });

  final _ExerciseData exerciseData;
  final ColorScheme colors;
  final String Function(double) fmtWeight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            exerciseData.name,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          if (exerciseData.sets.isEmpty)
            Text('Sin series registradas',
                style: TextStyle(color: colors.outline, fontSize: 12))
          else
            // Header
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text('#',
                            style: TextStyle(
                                fontSize: 11,
                                color: colors.outline,
                                fontWeight: FontWeight.bold)),
                      ),
                      Expanded(
                        child: Text('Peso',
                            style: TextStyle(
                                fontSize: 11,
                                color: colors.outline,
                                fontWeight: FontWeight.bold)),
                      ),
                      SizedBox(
                        width: 50,
                        child: Text('Reps',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 11,
                                color: colors.outline,
                                fontWeight: FontWeight.bold)),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text('RIR',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 11,
                                color: colors.outline,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                ...exerciseData.sets.asMap().entries.map((e) {
                  final i = e.key;
                  final s = e.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text('${i + 1}',
                              style: TextStyle(
                                  fontSize: 12, color: colors.outline)),
                        ),
                        Expanded(
                          child: Text(
                            s.weightKg != null ? fmtWeight(s.weightKg!) : '—',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        SizedBox(
                          width: 50,
                          child: Text(
                            s.reps != null ? '${s.reps}' : '—',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: Text(
                            s.rir != null ? '${s.rir}' : '—',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Info chip ─────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, required this.colors});
  final IconData icon;
  final String label;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: colors.outline),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 11, color: colors.onSurface)),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 48, color: colors.outline),
          const SizedBox(height: 12),
          Text('Sin sesiones registradas',
              style: TextStyle(color: colors.outline)),
        ],
      ),
    );
  }
}
