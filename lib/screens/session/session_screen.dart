import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/widgets/info_button.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/glass_kit.dart';
import '../../models/exercise.dart';
import '../../models/muscle_category.dart';
import '../../models/routine.dart';
import '../../models/session.dart';
import '../../models/session_exercise.dart';
import '../../models/session_set.dart';
import '../../services/exercise_service.dart';
import '../../services/routine_service.dart';
import '../../services/session_notifier.dart';
import '../../services/session_service.dart';

// ── Data holders ──────────────────────────────────────────────────────────────

class _ExerciseEntry {
  _ExerciseEntry({required this.exercise, required this.sessionExerciseId});
  final Exercise exercise;
  final int sessionExerciseId;
  final List<_SetEntry> sets = [];
}

class _SetEntry {
  _SetEntry({this.id, required this.setNumber});
  int? id;
  final int setNumber;
  final TextEditingController weightCtrl = TextEditingController();
  final TextEditingController repsCtrl = TextEditingController();
  final TextEditingController rirCtrl = TextEditingController();
  Timer? _debounce;

  double? get weight => double.tryParse(weightCtrl.text.replaceAll(',', '.'));
  int? get reps => int.tryParse(repsCtrl.text);
  int? get rir => int.tryParse(rirCtrl.text);

  void dispose() {
    _debounce?.cancel();
    weightCtrl.dispose();
    repsCtrl.dispose();
    rirCtrl.dispose();
  }
}

// ── Main screen ───────────────────────────────────────────────────────────────

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  int? _sessionId;
  final List<_ExerciseEntry> _entries = [];
  final _sessionService = SessionService.instance;
  final _exerciseService = ExerciseService.instance;

  late DateTime _selectedDate = _today();
  Set<int> _sessionWeekdays = {};

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _loadWeekSessions();
    pendingSessionNotifier.addListener(_onPendingSession);
  }

  Future<void> _loadWeekSessions() async {
    final monday = _today().subtract(Duration(days: _today().weekday - 1));
    final days = await _sessionService.getSessionWeekdaysInRange(
      monday,
      monday.add(const Duration(days: 7)),
    );
    if (mounted) setState(() => _sessionWeekdays = days);
  }

  Future<void> _selectDay(DateTime date) async {
    // Descartar entradas del día actual
    for (final e in _entries) {
      for (final s in e.sets) { s.dispose(); }
    }
    setState(() {
      _selectedDate = date;
      _entries.clear();
      _sessionId = null;
    });

    // Cargar la sesión propia de ese día (si existe)
    final session = await _sessionService.getSessionForDate(date);
    if (session != null && mounted) {
      await _loadExistingSession(session.id!);
    }
  }

  @override
  void dispose() {
    pendingSessionNotifier.removeListener(_onPendingSession);
    for (final entry in _entries) {
      for (final set in entry.sets) {
        set.dispose();
      }
    }
    super.dispose();
  }

  void _onPendingSession() {
    final id = pendingSessionNotifier.value;
    if (id != null && mounted) {
      pendingSessionNotifier.value = null; // consumir
      _loadExistingSession(id);
    }
  }

  // Adjunta auto-save listeners a un set. Reutilizado por _addSet y _loadExistingSession.
  void _setupListeners(_ExerciseEntry entry, _SetEntry setEntry) {
    void onChanged() {
      setEntry._debounce?.cancel();
      setEntry._debounce = Timer(const Duration(milliseconds: 600), () {
        if (setEntry.id != null) {
          _sessionService.updateSet(SessionSet(
            id: setEntry.id,
            sessionExerciseId: entry.sessionExerciseId,
            setNumber: setEntry.setNumber,
            weightKg: setEntry.weight,
            reps: setEntry.reps,
            rir: setEntry.rir,
          ));
        }
      });
    }
    setEntry.weightCtrl.addListener(onChanged);
    setEntry.repsCtrl.addListener(onChanged);
    setEntry.rirCtrl.addListener(onChanged);
  }

  // Formatea un double evitando decimales innecesarios (80.0 → "80", 82.5 → "82.5").
  String _fmtDouble(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

  Future<void> _loadExistingSession(int sessionId) async {
    for (final e in _entries) {
      for (final s in e.sets) { s.dispose(); }
    }
    setState(() {
      _entries.clear();
      _sessionId = sessionId;
    });

    final seList = await _sessionService.getExercisesForSession(sessionId);
    final allExercises = await _exerciseService.getAll();
    final exerciseMap = {for (final e in allExercises) e.id!: e};

    for (final se in seList) {
      final exercise = exerciseMap[se.exerciseId];
      if (exercise == null) continue;
      final entry = _ExerciseEntry(exercise: exercise, sessionExerciseId: se.id!);
      if (mounted) setState(() => _entries.add(entry));

      final existingSets = await _sessionService.getSetsForSessionExercise(se.id!);
      if (existingSets.isEmpty) {
        // Ejercicio sin series → crear la primera vacía
        await _addSet(entry);
      } else {
        // Restaurar sets con sus valores guardados
        for (final dbSet in existingSets) {
          final setEntry = _SetEntry(id: dbSet.id, setNumber: dbSet.setNumber);
          if (dbSet.weightKg != null) setEntry.weightCtrl.text = _fmtDouble(dbSet.weightKg!);
          if (dbSet.reps != null) setEntry.repsCtrl.text = '${dbSet.reps}';
          if (dbSet.rir != null) setEntry.rirCtrl.text = '${dbSet.rir}';
          _setupListeners(entry, setEntry);
          if (mounted) setState(() => entry.sets.add(setEntry));
        }
      }
    }

    if (mounted) _loadWeekSessions();
  }

  Future<int> _ensureSession() async {
    if (_sessionId != null) return _sessionId!;
    final now = DateTime.now();
    final date = DateTime(
      _selectedDate.year, _selectedDate.month, _selectedDate.day,
      now.hour, now.minute, now.second,
    );
    final session = await _sessionService.insert(Session(date: date));
    setState(() => _sessionId = session.id);
    _loadWeekSessions();
    return session.id!;
  }

  Future<void> _addExercise(Exercise exercise) async {
    final sessionId = await _ensureSession();
    final se = await _sessionService.insertSessionExercise(
      SessionExercise(
        sessionId: sessionId,
        exerciseId: exercise.id!,
        exerciseOrder: _entries.length,
      ),
    );
    final entry = _ExerciseEntry(exercise: exercise, sessionExerciseId: se.id!);
    setState(() => _entries.add(entry));
    await _addSet(entry);
  }

  Future<void> _addSet(_ExerciseEntry entry) async {
    final set = await _sessionService.insertSet(
      SessionSet(
        sessionExerciseId: entry.sessionExerciseId,
        setNumber: entry.sets.length + 1,
      ),
    );
    final setEntry = _SetEntry(id: set.id, setNumber: set.setNumber);
    _setupListeners(entry, setEntry);
    setState(() => entry.sets.add(setEntry));
  }

  Future<void> _removeExercise(_ExerciseEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar ejercicio'),
        content: Text('¿Eliminar ${entry.exercise.name} y todas sus series?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _sessionService.deleteSessionExercise(entry.sessionExerciseId);
    for (final set in entry.sets) {
      set.dispose();
    }
    setState(() => _entries.remove(entry));
  }

  Future<void> _removeSet(_ExerciseEntry entry, _SetEntry set) async {
    if (set.id != null) await _sessionService.deleteSet(set.id!);
    set.dispose();
    setState(() => entry.sets.remove(set));
  }

  void _showExercisePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ExercisePickerSheet(
        parentContext: context,
        onSelected: (exercise) => _addExercise(exercise),
      ),
    );
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ListTile(
            leading: const NeonIcon(icon: Icons.fitness_center_rounded),
            title: const Text('Ejercicio individual'),
            subtitle: const Text('Selecciona un ejercicio de la lista'),
            onTap: () {
              Navigator.pop(ctx);
              _showExercisePicker();
            },
          ),
          ListTile(
            leading: const NeonIcon(
              icon: Icons.calendar_month_rounded,
              color: AppColors.secondary,
            ),
            title: const Text('Cargar rutina'),
            subtitle: const Text('Agrega todos los ejercicios de una rutina'),
            onTap: () {
              Navigator.pop(ctx);
              _showRoutinePicker();
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Future<void> _showRoutinePicker() async {
    final routines = await RoutineService.instance.getAll();
    if (!mounted) return;
    if (routines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay rutinas guardadas. Crea una en la pestaña Rutinas.'),
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _RoutinePickerSheet(
        routines: routines,
        onSelected: (routine) {
          Navigator.pop(ctx);
          _addRoutine(routine);
        },
      ),
    );
  }

  Future<void> _addRoutine(Routine routine) async {
    final reList = await RoutineService.instance.getExercisesForRoutine(routine.id!);
    final allExercises = await _exerciseService.getAll();
    final exerciseMap = {for (final e in allExercises) e.id!: e};
    for (final re in reList) {
      final exercise = exerciseMap[re.exerciseId];
      if (exercise != null) {
        await _addExercise(exercise);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final isToday = _selectedDate == _today();
    final dayNames = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    final titleText = isToday ? 'Sesión de hoy' : 'Sesión del ${dayNames[_selectedDate.weekday - 1]}';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(titleText),
        centerTitle: false,
        actions: const [
          InfoButton(text: 'Registra tus entrenamientos por día. Agrega ejercicios o carga una rutina. Los datos se guardan automáticamente.'),
        ],
      ),
      body: Column(
        children: [
          _WeekBar(
            selectedDate: _selectedDate,
            sessionWeekdays: _sessionWeekdays,
            onDaySelected: _selectDay,
          ),
          Divider(height: 1, color: colors.outlineVariant.withValues(alpha: 0.3)),
          Expanded(
            child: _entries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fitness_center, size: 64, color: colors.outline),
                        const SizedBox(height: 16),
                        Text('Sin ejercicios',
                            style: TextStyle(color: colors.outline, fontSize: 18)),
                        const SizedBox(height: 8),
                        Text('Toca + para agregar un ejercicio',
                            style: TextStyle(color: colors.outlineVariant)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: _entries.length,
                    itemBuilder: (_, i) => _ExerciseCard(
                      entry: _entries[i],
                      onAddSet: () => _addSet(_entries[i]),
                      onRemoveExercise: () => _removeExercise(_entries[i]),
                      onRemoveSet: (set) => _removeSet(_entries[i], set),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewPaddingOf(context).bottom + 100,
        ),
        child: FloatingActionButton.extended(
          onPressed: _showAddOptions,
          icon: const Icon(Icons.add),
          label: const Text('Agregar'),
        ),
      ),
    );
  }
}

// ── Exercise card ─────────────────────────────────────────────────────────────

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.entry,
    required this.onAddSet,
    required this.onRemoveExercise,
    required this.onRemoveSet,
  });

  final _ExerciseEntry entry;
  final VoidCallback onAddSet;
  final VoidCallback onRemoveExercise;
  final void Function(_SetEntry) onRemoveSet;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withValues(alpha: 0.07),
              Colors.white.withValues(alpha: 0.02),
            ],
          ),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.18),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.07),
              blurRadius: 14,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.exercise.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      GlassChip(entry.exercise.muscleCategory.displayName),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onRemoveExercise,
                  color: colors.error,
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Column headers
            if (entry.sets.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    SizedBox(width: 32),
                    Expanded(
                      child: Text('Peso (kg)',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center),
                    ),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text('Reps',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center),
                    ),
                    SizedBox(width: 4),
                    SizedBox(
                      width: 44,
                      child: Text('RIR',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center),
                    ),
                    SizedBox(width: 32),
                  ],
                ),
              ),

            // Set rows
            ...entry.sets.asMap().entries.map(
                  (e) => _SetRow(
                    index: e.key,
                    setEntry: e.value,
                    onRemove: () => onRemoveSet(e.value),
                  ),
                ),

            const SizedBox(height: 8),

            // Add set button
            NeonButton(
              label: 'Agregar serie',
              icon: Icons.add,
              onPressed: onAddSet,
              expand: true,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Set row ───────────────────────────────────────────────────────────────────

class _SetRow extends StatelessWidget {
  const _SetRow(
      {required this.index,
      required this.setEntry,
      required this.onRemove});

  final int index;
  final _SetEntry setEntry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '${index + 1}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: _SetField(
              controller: setEntry.weightCtrl,
              hint: '0',
              isDecimal: true,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _SetField(
              controller: setEntry.repsCtrl,
              hint: '0',
              isDecimal: false,
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 44,
            child: _SetField(
              controller: setEntry.rirCtrl,
              hint: '-',
              isDecimal: false,
            ),
          ),
          SizedBox(
            width: 32,
            child: IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: onRemove,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

class _SetField extends StatelessWidget {
  const _SetField(
      {required this.controller,
      required this.hint,
      required this.isDecimal});

  final TextEditingController controller;
  final String hint;
  final bool isDecimal;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textAlign: TextAlign.center,
      keyboardType: isDecimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// ── Exercise picker sheet ─────────────────────────────────────────────────────

class _ExercisePickerSheet extends StatefulWidget {
  const _ExercisePickerSheet(
      {required this.parentContext, required this.onSelected});
  final BuildContext parentContext;
  final void Function(Exercise) onSelected;

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  final _search = TextEditingController();
  List<Exercise> _all = [];
  List<Exercise> _filtered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(_filter);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final exercises = await ExerciseService.instance.getAll();
    setState(() {
      _all = exercises;
      _filtered = exercises;
      _loading = false;
    });
  }

  void _filter() {
    final q = _search.text.toLowerCase();
    setState(() {
      _filtered =
          _all.where((e) => e.name.toLowerCase().contains(q)).toList();
    });
  }

  void _showCreateDialog() {
    final onSelected = widget.onSelected;
    Navigator.pop(context);
    showDialog(
      context: widget.parentContext,
      builder: (_) => _CreateExerciseDialog(onCreated: onSelected),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: colors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title + create button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('Seleccionar ejercicio',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton.icon(
                  onPressed: _showCreateDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Crear nuevo'),
                ),
              ],
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Buscar...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Text('Sin resultados',
                            style: TextStyle(color: colors.outline)))
                    : _GroupedPickerList(
                        exercises: _filtered,
                        scrollController: scrollController,
                        onSelected: (ex) {
                          Navigator.pop(context);
                          widget.onSelected(ex);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Grouped picker list ───────────────────────────────────────────────────────

class _GroupedPickerList extends StatelessWidget {
  const _GroupedPickerList({
    required this.exercises,
    required this.scrollController,
    required this.onSelected,
  });

  final List<Exercise> exercises;
  final ScrollController scrollController;
  final void Function(Exercise) onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final grouped = <MuscleCategory, List<Exercise>>{};
    for (final cat in MuscleCategory.values) {
      final items = exercises.where((e) => e.muscleCategory == cat).toList();
      if (items.isNotEmpty) grouped[cat] = items;
    }

    final items = <_PickerItem>[];
    for (final entry in grouped.entries) {
      items.add(_PickerItem.header(entry.key));
      for (final ex in entry.value) {
        items.add(_PickerItem.exercise(ex));
      }
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        if (item.isHeader) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text(
                  item.category!.displayName.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Divider(color: colors.outlineVariant, height: 1),
                ),
              ],
            ),
          );
        }

        final ex = item.exercise!;
        return ListTile(
          title: Text(ex.name),
          trailing: ex.isCustom
              ? Icon(Icons.person_outline, size: 16, color: colors.outline)
              : null,
          onTap: () => onSelected(ex),
        );
      },
    );
  }
}

class _PickerItem {
  _PickerItem.header(this.category)
      : isHeader = true,
        exercise = null;
  _PickerItem.exercise(this.exercise)
      : isHeader = false,
        category = null;

  final bool isHeader;
  final MuscleCategory? category;
  final Exercise? exercise;
}

// ── Routine picker sheet ──────────────────────────────────────────────────────

class _RoutinePickerSheet extends StatelessWidget {
  const _RoutinePickerSheet({
    required this.routines,
    required this.onSelected,
  });

  final List<Routine> routines;
  final void Function(Routine) onSelected;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.45,
      maxChildSize: 0.8,
      builder: (_, controller) => Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: NeonText(
                'Seleccionar rutina',
                fontSize: 16,
                colors: [AppColors.secondary, AppColors.primary],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: controller,
              itemCount: routines.length,
              itemBuilder: (_, i) {
                final r = routines[i];
                return ListTile(
                  leading: const NeonIcon(
                    icon: Icons.calendar_month_rounded,
                    color: AppColors.secondary,
                  ),
                  title: Text(r.name),
                  subtitle: r.notes != null
                      ? Text(r.notes!, style: const TextStyle(fontSize: 12))
                      : null,
                  onTap: () => onSelected(r),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Create exercise dialog ────────────────────────────────────────────────────

class _CreateExerciseDialog extends StatefulWidget {
  const _CreateExerciseDialog({required this.onCreated});
  final void Function(Exercise) onCreated;

  @override
  State<_CreateExerciseDialog> createState() => _CreateExerciseDialogState();
}

class _CreateExerciseDialogState extends State<_CreateExerciseDialog> {
  final _nameCtrl = TextEditingController();
  MuscleCategory _category = MuscleCategory.pecho;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final exercise = await ExerciseService.instance.insert(
      Exercise(name: name, muscleCategory: _category, isCustom: true),
    );
    if (mounted) {
      Navigator.pop(context);
      widget.onCreated(exercise);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo ejercicio'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<MuscleCategory>(
            initialValue: _category,
            decoration: const InputDecoration(
              labelText: 'Grupo muscular',
              border: OutlineInputBorder(),
            ),
            items: MuscleCategory.values
                .map((c) => DropdownMenuItem(
                    value: c, child: Text(c.displayName)))
                .toList(),
            onChanged: (v) => setState(() => _category = v!),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

// ── Week bar ──────────────────────────────────────────────────────────────────

class _WeekBar extends StatelessWidget {
  const _WeekBar({
    required this.selectedDate,
    required this.sessionWeekdays,
    required this.onDaySelected,
  });

  final DateTime selectedDate;
  final Set<int> sessionWeekdays;
  final void Function(DateTime) onDaySelected;

  static const _labels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final today = _today();
    final monday = today.subtract(Duration(days: today.weekday - 1));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(7, (i) {
          final day = monday.add(Duration(days: i));
          final isToday = day == today;
          final isSelected = day == selectedDate;
          final hasSession = sessionWeekdays.contains(i + 1);

          Color bgColor;
          Color textColor;
          Border? border;

          if (isSelected) {
            bgColor = colors.primary;
            textColor = colors.onPrimary;
          } else if (hasSession) {
            bgColor = colors.primaryContainer;
            textColor = colors.onPrimaryContainer;
          } else {
            bgColor = Colors.transparent;
            textColor = isToday ? colors.primary : colors.onSurface;
          }

          if (isToday && !isSelected) {
            border = Border.all(color: colors.primary, width: 1.5);
          }

          return GestureDetector(
            onTap: () => onDaySelected(day),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _labels[i],
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected ? colors.primary : colors.outline,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: bgColor,
                    border: border,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: (isSelected || isToday) ? FontWeight.bold : FontWeight.normal,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
