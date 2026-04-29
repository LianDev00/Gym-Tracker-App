import 'package:flutter/material.dart';
import '../../core/widgets/info_button.dart';
import '../../models/exercise.dart';
import '../../models/muscle_category.dart';
import '../../models/muscle_group.dart';
import '../../models/muscle_state.dart';
import '../../services/exercise_service.dart';
import '../../widgets/body_atlas/body_atlas_palette.dart';
import '../../widgets/body_atlas/muscle_atlas.dart';
import '../../widgets/dialogs/exercise_form_dialog.dart';

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  final _service = ExerciseService.instance;
  final _search = TextEditingController();

  List<Exercise> _all = [];
  bool _loading = true;

  BodyView _view = BodyView.front;
  MuscleGroup? _selectedMuscle;
  int? _selectedExerciseId;

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final exercises = await _service.getAll();
    setState(() {
      _all = exercises;
      _loading = false;
    });
  }

  void _onTapMuscle(MuscleGroup group) {
    setState(() {
      _selectedExerciseId = null;
      _selectedMuscle = _selectedMuscle == group ? null : group;
    });
  }

  void _onTapExercise(Exercise ex) {
    setState(() {
      _selectedExerciseId = _selectedExerciseId == ex.id ? null : ex.id;
    });
  }

  Map<MuscleGroup, MuscleState> _atlasStates() {
    if (_selectedExerciseId != null) {
      final ex = _all.firstWhere(
        (e) => e.id == _selectedExerciseId,
        orElse: () =>
            const Exercise(name: '', muscleCategory: MuscleCategory.cardio),
      );
      return {
        for (final entry in ex.muscles.entries)
          entry.key: switch (entry.value) {
            MuscleRole.dominant => MuscleState.dominant,
            MuscleRole.secondary => MuscleState.secondary,
          }
      };
    }
    if (_selectedMuscle != null) {
      return {_selectedMuscle!: MuscleState.active};
    }
    return const {};
  }

  List<Exercise> _filteredExercises() {
    final q = _search.text.toLowerCase();
    return _all.where((e) {
      final matchesQuery = e.name.toLowerCase().contains(q);
      final matchesMuscle =
          _selectedMuscle == null || e.muscles.containsKey(_selectedMuscle);
      return matchesQuery && matchesMuscle;
    }).toList();
  }

  Future<void> _showCreateDialog() async {
    final result = await showDialog<Exercise>(
      context: context,
      builder: (_) => const ExerciseFormDialog(),
    );
    if (result != null) await _load();
  }

  Future<void> _showEditDialog(Exercise exercise) async {
    final result = await showDialog<Exercise>(
      context: context,
      builder: (_) => ExerciseFormDialog(initial: exercise),
    );
    if (result != null) await _load();
  }

  Future<void> _deleteExercise(Exercise exercise) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar ejercicio'),
        content: Text('¿Eliminar "${exercise.name}"?'),
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
    await _service.delete(exercise.id!);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final filtered = _filteredExercises();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ejercicios'),
        centerTitle: false,
        actions: const [
          InfoButton(
              text:
                  'Toca un músculo para filtrar ejercicios; toca un ejercicio para ver qué músculos trabaja.'),
        ],
      ),
      body: Column(
        children: [
          // Atlas anatómico
          _AtlasSection(
            view: _view,
            states: _atlasStates(),
            onTapMuscle: _onTapMuscle,
            onToggleView: (v) => setState(() => _view = v),
          ),

          const Divider(height: 1),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Buscar ejercicio...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _search.clear(),
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          // Active muscle filter pill
          if (_selectedMuscle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: InputChip(
                  label: Text('Músculo: ${_selectedMuscle!.displayName}'),
                  onDeleted: () => setState(() => _selectedMuscle = null),
                  deleteIcon: const Icon(Icons.close, size: 16),
                ),
              ),
            ),

          // Count
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(
              children: [
                Text(
                  '${filtered.length} ejercicio${filtered.length == 1 ? '' : 's'}',
                  style: TextStyle(color: colors.outline, fontSize: 12),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Text(
                          'Sin resultados',
                          style: TextStyle(color: colors.outline),
                        ),
                      )
                    : _GroupedExerciseList(
                        exercises: filtered,
                        selectedExerciseId: _selectedExerciseId,
                        onTap: _onTapExercise,
                        onEdit: _showEditDialog,
                        onDelete: _deleteExercise,
                      ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewPaddingOf(context).bottom + 100,
        ),
        child: FloatingActionButton(
          onPressed: _showCreateDialog,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

// ── Atlas section ─────────────────────────────────────────────────────────────

class _AtlasSection extends StatelessWidget {
  const _AtlasSection({
    required this.view,
    required this.states,
    required this.onTapMuscle,
    required this.onToggleView,
  });

  final BodyView view;
  final Map<MuscleGroup, MuscleState> states;
  final ValueChanged<MuscleGroup> onTapMuscle;
  final ValueChanged<BodyView> onToggleView;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: Column(
        children: [
          const SizedBox(height: 6),
          SegmentedButton<BodyView>(
            segments: const [
              ButtonSegment(value: BodyView.front, label: Text('Frente')),
              ButtonSegment(value: BodyView.back, label: Text('Espalda')),
            ],
            selected: {view},
            onSelectionChanged: (s) => onToggleView(s.first),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: MuscleAtlas(
                view: view,
                states: states,
                onTapGroup: onTapMuscle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Grouped exercise list ─────────────────────────────────────────────────────

class _GroupedExerciseList extends StatelessWidget {
  const _GroupedExerciseList({
    required this.exercises,
    required this.selectedExerciseId,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Exercise> exercises;
  final int? selectedExerciseId;
  final void Function(Exercise) onTap;
  final void Function(Exercise) onEdit;
  final void Function(Exercise) onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final grouped = <MuscleCategory, List<Exercise>>{};
    for (final cat in MuscleCategory.values) {
      final items = exercises.where((e) => e.muscleCategory == cat).toList();
      if (items.isNotEmpty) grouped[cat] = items;
    }

    final items = <_ListItem>[];
    for (final entry in grouped.entries) {
      items.add(_ListItem.header(entry.key));
      for (final ex in entry.value) {
        items.add(_ListItem.exercise(ex));
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        if (item.isHeader) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
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
        final isSelected = ex.id == selectedExerciseId;
        return Container(
          color: isSelected
              ? BodyAtlasPalette.active.withValues(alpha: 0.12)
              : null,
          child: ListTile(
            onTap: () => onTap(ex),
            title: Text(
              ex.name,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? BodyAtlasPalette.active : null,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (ex.isCustom)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Chip(
                      label: const Text('Custom'),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      labelStyle: TextStyle(
                          fontSize: 10, color: colors.onPrimaryContainer),
                      backgroundColor: colors.primaryContainer,
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  color: colors.primary,
                  onPressed: () => onEdit(ex),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: colors.error,
                  onPressed: () => onDelete(ex),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ListItem {
  _ListItem.header(this.category)
      : isHeader = true,
        exercise = null;
  _ListItem.exercise(this.exercise)
      : isHeader = false,
        category = null;

  final bool isHeader;
  final MuscleCategory? category;
  final Exercise? exercise;
}

