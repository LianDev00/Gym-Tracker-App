import 'package:flutter/material.dart';
import '../../core/widgets/info_button.dart';
import '../../models/exercise.dart';
import '../../models/muscle_category.dart';
import '../../models/routine.dart';
import '../../models/routine_exercise.dart';
import '../../services/exercise_service.dart';
import '../../services/routine_service.dart';

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  final _service = RoutineService.instance;
  List<Routine> _routines = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final routines = await _service.getAll();
    setState(() {
      _routines = routines;
      _loading = false;
    });
  }

  Future<void> _createRoutine() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _CreateRoutineDialog(),
    );
    if (name == null) return;
    await _service.insert(Routine(name: name));
    await _load();
  }

  Future<void> _deleteRoutine(Routine routine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar rutina'),
        content: Text('¿Eliminar "${routine.name}"?'),
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
    await _service.delete(routine.id!);
    await _load();
  }

  void _openDetail(Routine routine) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RoutineDetailSheet(routine: routine, onChanged: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rutinas'),
        centerTitle: false,
        actions: const [
          InfoButton(text: 'Crea rutinas con ejercicios y objetivos. Luego puedes cargarlas rápidamente en una sesión.'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _routines.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.list_alt, size: 64, color: colors.outline),
                      const SizedBox(height: 16),
                      Text('Sin rutinas',
                          style:
                              TextStyle(color: colors.outline, fontSize: 18)),
                      const SizedBox(height: 8),
                      Text('Crea una plantilla de entrenamiento',
                          style: TextStyle(color: colors.outlineVariant)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: _routines.length,
                  itemBuilder: (_, i) => _RoutineCard(
                    routine: _routines[i],
                    onTap: () => _openDetail(_routines[i]),
                    onDelete: () => _deleteRoutine(_routines[i]),
                  ),
                ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewPaddingOf(context).bottom + 100,
        ),
        child: FloatingActionButton.extended(
          onPressed: _createRoutine,
          icon: const Icon(Icons.add),
          label: const Text('Nueva rutina'),
        ),
      ),
    );
  }
}

// ── Routine card ──────────────────────────────────────────────────────────────

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({
    required this.routine,
    required this.onTap,
    required this.onDelete,
  });
  final Routine routine;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: colors.primaryContainer,
          child: Icon(Icons.fitness_center,
              color: colors.onPrimaryContainer, size: 20),
        ),
        title: Text(routine.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: routine.notes != null
            ? Text(routine.notes!, maxLines: 1, overflow: TextOverflow.ellipsis)
            : const Text('Toca para editar ejercicios',
                style: TextStyle(fontSize: 12)),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: colors.error),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

// ── Create dialog ─────────────────────────────────────────────────────────────

class _CreateRoutineDialog extends StatefulWidget {
  const _CreateRoutineDialog();

  @override
  State<_CreateRoutineDialog> createState() => _CreateRoutineDialogState();
}

class _CreateRoutineDialogState extends State<_CreateRoutineDialog> {
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva rutina'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            border: OutlineInputBorder(),
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Ingresa un nombre' : null,
          onFieldSubmitted: (_) {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _nameCtrl.text.trim());
            }
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _nameCtrl.text.trim());
            }
          },
          child: const Text('Crear'),
        ),
      ],
    );
  }
}

// ── Routine detail sheet ──────────────────────────────────────────────────────

class _RoutineDetailSheet extends StatefulWidget {
  const _RoutineDetailSheet({required this.routine, required this.onChanged});
  final Routine routine;
  final VoidCallback onChanged;

  @override
  State<_RoutineDetailSheet> createState() => _RoutineDetailSheetState();
}

class _RoutineDetailSheetState extends State<_RoutineDetailSheet> {
  final _routineService = RoutineService.instance;
  final _exerciseService = ExerciseService.instance;
  List<({RoutineExercise re, Exercise exercise})> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final reList =
        await _routineService.getExercisesForRoutine(widget.routine.id!);
    final exercises = await _exerciseService.getAll();
    final exerciseMap = {for (final e in exercises) e.id!: e};
    setState(() {
      _items = reList
          .where((re) => exerciseMap.containsKey(re.exerciseId))
          .map((re) => (re: re, exercise: exerciseMap[re.exerciseId]!))
          .toList();
      _loading = false;
    });
  }

  Future<void> _addExercise() async {
    final allExercises = await _exerciseService.getAll();
    if (!mounted) return;
    final exercise = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ExercisePickerSheet(exercises: allExercises),
    );
    if (exercise == null) return;
    await _routineService.insertRoutineExercise(RoutineExercise(
      routineId: widget.routine.id!,
      exerciseId: exercise.id!,
      exerciseOrder: _items.length,
    ));
    await _load();
    widget.onChanged();
  }

  Future<void> _removeExercise(RoutineExercise re) async {
    await _routineService.deleteRoutineExercise(re.id!);
    await _load();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, controller) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.routine.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: colors.outlineVariant),
          // Body
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline,
                              size: 48, color: colors.outline),
                          const SizedBox(height: 12),
                          Text('Sin ejercicios',
                              style: TextStyle(color: colors.outline)),
                          const SizedBox(height: 8),
                          FilledButton.tonal(
                            onPressed: _addExercise,
                            child: const Text('Agregar ejercicio'),
                          ),
                        ],
                      )
                    : ListView.builder(
                        controller: controller,
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: _items.length,
                        itemBuilder: (_, i) {
                          final item = _items[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: colors.primaryContainer,
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                    color: colors.onPrimaryContainer,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(item.exercise.name),
                            subtitle: Text(
                              item.exercise.muscleCategory.displayName,
                              style: TextStyle(
                                  color: colors.outline, fontSize: 12),
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.remove_circle_outline,
                                  color: colors.error),
                              onPressed: () => _removeExercise(item.re),
                            ),
                          );
                        },
                      ),
          ),
          if (!_loading && _items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _addExercise,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar ejercicio'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Exercise picker sheet ─────────────────────────────────────────────────────

class _ExercisePickerSheet extends StatefulWidget {
  const _ExercisePickerSheet({required this.exercises});
  final List<Exercise> exercises;

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  String _query = '';

  List<Exercise> get _filtered => widget.exercises
      .where((e) => e.name.toLowerCase().contains(_query.toLowerCase()))
      .toList();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, controller) => Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Buscar ejercicio...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _GroupedPickerList(
              exercises: _filtered,
              scrollController: controller,
              onSelected: (e) => Navigator.pop(context, e),
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
      final list = exercises.where((e) => e.muscleCategory == cat).toList();
      if (list.isNotEmpty) grouped[cat] = list;
    }
    final items = <_Item>[];
    for (final entry in grouped.entries) {
      items.add(_Item.header(entry.key));
      items.addAll(entry.value.map(_Item.exercise));
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        if (item.isHeader) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(children: [
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
              Expanded(child: Divider(color: colors.outlineVariant)),
            ]),
          );
        }
        return ListTile(
          title: Text(item.exercise!.name),
          trailing: item.exercise!.isCustom
              ? Icon(Icons.person_outline, color: colors.outline, size: 18)
              : null,
          onTap: () => onSelected(item.exercise!),
        );
      },
    );
  }
}

class _Item {
  _Item.header(this.category) : exercise = null;
  _Item.exercise(this.exercise) : category = null;
  final MuscleCategory? category;
  final Exercise? exercise;
  bool get isHeader => category != null;
}
