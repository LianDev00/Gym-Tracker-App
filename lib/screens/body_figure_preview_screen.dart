import 'package:flutter/material.dart';

import '../models/muscle_group.dart';
import '../models/muscle_state.dart';
import '../widgets/body_figure/body_figure.dart';

/// Pantalla de iteración visual para `BodyFigure`.
///
/// Permite forzar el estado de cada [MuscleGroup] y alternar vista/género para
/// validar el pipeline antes de pulir polígonos región por región.
class BodyFigurePreviewScreen extends StatefulWidget {
  const BodyFigurePreviewScreen({super.key});

  @override
  State<BodyFigurePreviewScreen> createState() =>
      _BodyFigurePreviewScreenState();
}

class _BodyFigurePreviewScreenState extends State<BodyFigurePreviewScreen> {
  final Map<MuscleGroup, MuscleState> _states = {
    MuscleGroup.chest: MuscleState.dominant,
  };
  BodyView _view = BodyView.front;
  FigureGender _gender = FigureGender.male;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Body Figure — Preview')),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                SegmentedButton<BodyView>(
                  segments: const [
                    ButtonSegment(value: BodyView.front, label: Text('Frente')),
                    ButtonSegment(value: BodyView.back, label: Text('Espalda')),
                  ],
                  selected: {_view},
                  onSelectionChanged: (s) => setState(() => _view = s.first),
                ),
                SegmentedButton<FigureGender>(
                  segments: const [
                    ButtonSegment(value: FigureGender.male, label: Text('M')),
                    ButtonSegment(value: FigureGender.female, label: Text('F')),
                  ],
                  selected: {_gender},
                  onSelectionChanged: (s) => setState(() => _gender = s.first),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: BodyFigure(
                  view: _view,
                  gender: _gender,
                  states: _states,
                ),
              ),
            ),
            const Divider(height: 1),
            SizedBox(
              height: 220,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  for (final group in MuscleGroup.values)
                    _StateRow(
                      group: group,
                      current: _states[group],
                      onChanged: (state) => setState(() {
                        if (state == null) {
                          _states.remove(group);
                        } else {
                          _states[group] = state;
                        }
                      }),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StateRow extends StatelessWidget {
  const _StateRow({
    required this.group,
    required this.current,
    required this.onChanged,
  });

  final MuscleGroup group;
  final MuscleState? current;
  final ValueChanged<MuscleState?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(group.displayName,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: Wrap(
              spacing: 4,
              children: [
                _chip('off', null),
                for (final s in MuscleState.values) _chip(s.name, s),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, MuscleState? value) {
    final selected = current == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: selected,
      onSelected: (_) => onChanged(value),
      visualDensity: VisualDensity.compact,
    );
  }
}
