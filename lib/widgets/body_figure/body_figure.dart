import 'package:flutter/material.dart';

import '../../models/muscle_group.dart';
import '../../models/muscle_state.dart';
import 'body_figure_painter.dart';
import 'body_mask.dart';

export 'body_mask.dart' show BodyView, FigureGender;

/// Figura anatómica dot-matrix.
///
/// Driven 100% por el `Map<MuscleGroup, MuscleState>` pasado en `states` —
/// nunca lee `MuscleCategory` ni el modelo `Exercise` directamente.
///
/// Phase C: solo `chest` tiene polígono real; el resto del cuerpo aparece
/// como dots `idle` mientras se itera el arte por región.
class BodyFigure extends StatefulWidget {
  const BodyFigure({
    super.key,
    this.view = BodyView.front,
    this.gender = FigureGender.male,
    required this.states,
    this.onRegionTap,
  });

  final BodyView view;
  final FigureGender gender;
  final Map<MuscleGroup, MuscleState> states;

  /// Callback al tocar una región. Phase D conectará el hit testing.
  final ValueChanged<MuscleGroup>? onRegionTap;

  @override
  State<BodyFigure> createState() => _BodyFigureState();
}

class _BodyFigureState extends State<BodyFigure>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mask = BodyMask.forView(widget.view, widget.gender);
    return AspectRatio(
      aspectRatio: 0.5,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) => CustomPaint(
          painter: BodyFigurePainter(
            mask: mask,
            states: widget.states,
            pulse: _pulse.value,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}
