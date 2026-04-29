import 'package:flutter/material.dart';

import '../../models/exercise.dart';
import '../../models/muscle_category.dart';
import '../../models/muscle_group.dart';
import '../../services/exercise_service.dart';

/// Diálogo unificado de creación y edición de [Exercise].
///
/// - Si [initial] es `null`, modo creación → inserta y devuelve el [Exercise]
///   resultante por `Navigator.pop`.
/// - Si [initial] no es `null`, modo edición → actualiza y devuelve el
///   [Exercise] modificado.
///
/// Persistencia interna: usa `ExerciseService.instance` directamente.
/// Cancelar devuelve `null`.
class ExerciseFormDialog extends StatefulWidget {
  const ExerciseFormDialog({super.key, this.initial});

  final Exercise? initial;

  @override
  State<ExerciseFormDialog> createState() => _ExerciseFormDialogState();
}

class _ExerciseFormDialogState extends State<ExerciseFormDialog> {
  late final TextEditingController _nameCtrl;
  late MuscleCategory _category;
  late Map<MuscleGroup, MuscleRole> _muscles;
  bool _saving = false;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameCtrl = TextEditingController(text: initial?.name ?? '');
    _category = initial?.muscleCategory ?? MuscleCategory.pecho;
    _muscles = Map.of(initial?.muscles ?? const <MuscleGroup, MuscleRole>{});
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);

    final service = ExerciseService.instance;
    Exercise result;
    if (_isEdit) {
      final updated = widget.initial!.copyWith(
        name: name,
        muscleCategory: _category,
        muscles: _muscles,
      );
      await service.update(updated);
      result = updated;
    } else {
      result = await service.insert(Exercise(
        name: name,
        muscleCategory: _category,
        isCustom: true,
        muscles: _muscles,
      ));
    }
    if (mounted) Navigator.pop(context, result);
  }

  void _setRole(MuscleGroup group, MuscleRole? role) {
    setState(() {
      if (role == null) {
        _muscles.remove(group);
      } else {
        _muscles[group] = role;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.85;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEdit ? 'Editar ejercicio' : 'Nuevo ejercicio',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                autofocus: !_isEdit,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<MuscleCategory>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  border: OutlineInputBorder(),
                ),
                items: MuscleCategory.values
                    .map((c) => DropdownMenuItem(
                        value: c, child: Text(c.displayName)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Músculos involucrados',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Define qué grupos trabaja este ejercicio. Principal = motor del movimiento; Apoyo = sinergista.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final group in MuscleGroup.values)
                        _MuscleRow(
                          group: group,
                          role: _muscles[group],
                          onChanged: (role) => _setRole(group, role),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isEdit ? 'Guardar' : 'Crear'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MuscleRow extends StatelessWidget {
  const _MuscleRow({
    required this.group,
    required this.role,
    required this.onChanged,
  });

  final MuscleGroup group;
  final MuscleRole? role;
  final ValueChanged<MuscleRole?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              group.displayName,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          _chip('—', null),
          const SizedBox(width: 4),
          _chip('Principal', MuscleRole.dominant),
          const SizedBox(width: 4),
          _chip('Apoyo', MuscleRole.secondary),
        ],
      ),
    );
  }

  Widget _chip(String label, MuscleRole? value) {
    final selected = role == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: selected,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      onSelected: (_) => onChanged(value),
    );
  }
}
