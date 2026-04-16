import 'package:flutter/material.dart';
import '../../models/exercise.dart';
import '../../models/muscle_category.dart';
import '../../services/exercise_service.dart';

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  final _service = ExerciseService.instance;
  final _search = TextEditingController();

  List<Exercise> _all = [];
  List<Exercise> _filtered = [];
  MuscleCategory? _selectedCategory;
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
    setState(() => _loading = true);
    final exercises = await _service.getAll();
    setState(() {
      _all = exercises;
      _loading = false;
    });
    _filter();
  }

  void _filter() {
    final q = _search.text.toLowerCase();
    setState(() {
      _filtered = _all.where((e) {
        final matchesQuery = e.name.toLowerCase().contains(q);
        final matchesCategory =
            _selectedCategory == null || e.muscleCategory == _selectedCategory;
        return matchesQuery && matchesCategory;
      }).toList();
    });
  }

  void _selectCategory(MuscleCategory? category) {
    setState(() => _selectedCategory = category);
    _filter();
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (_) => _CreateExerciseDialog(
        onCreated: (exercise) async {
          await _service.insert(exercise);
          await _load();
        },
      ),
    );
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ejercicios'),
        centerTitle: false,
      ),
      body: Column(
        children: [
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
                        onPressed: () {
                          _search.clear();
                          _filter();
                        },
                      )
                    : null,
                isDense: true,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          // Category filter chips
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _FilterChip(
                  label: 'Todos',
                  selected: _selectedCategory == null,
                  onTap: () => _selectCategory(null),
                ),
                ...MuscleCategory.values.map((c) => _FilterChip(
                      label: c.displayName,
                      selected: _selectedCategory == c,
                      onTap: () => _selectCategory(c),
                    )),
              ],
            ),
          ),

          // Count
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(
              children: [
                Text(
                  '${_filtered.length} ejercicio${_filtered.length == 1 ? '' : 's'}',
                  style: TextStyle(color: colors.outline, fontSize: 12),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Text(
                          'Sin resultados',
                          style: TextStyle(color: colors.outline),
                        ),
                      )
                    : _GroupedExerciseList(
                        exercises: _filtered,
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

// ── Grouped exercise list ─────────────────────────────────────────────────────

class _GroupedExerciseList extends StatelessWidget {
  const _GroupedExerciseList(
      {required this.exercises, required this.onDelete});

  final List<Exercise> exercises;
  final void Function(Exercise) onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // Group by category preserving MuscleCategory order
    final grouped = <MuscleCategory, List<Exercise>>{};
    for (final cat in MuscleCategory.values) {
      final items = exercises.where((e) => e.muscleCategory == cat).toList();
      if (items.isNotEmpty) grouped[cat] = items;
    }

    // Build flat list of headers + items
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
        return ListTile(
          title: Text(ex.name),
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
                icon: const Icon(Icons.delete_outline, size: 20),
                color: colors.error,
                onPressed: () => onDelete(ex),
              ),
            ],
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

// ── Filter chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip(
      {required this.label,
      required this.selected,
      required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? colors.onPrimary : colors.onSurface,
          ),
        ),
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

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context);
    widget.onCreated(
      Exercise(name: name, muscleCategory: _category, isCustom: true),
    );
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
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}
