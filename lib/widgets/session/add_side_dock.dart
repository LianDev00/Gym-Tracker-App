import 'package:flutter/material.dart';

/// Dock lateral minimalista anclado al borde derecho, solo para agregar
/// un ejercicio o cargar una rutina.
///
/// Estados:
/// - **Colapsado**: solo asoma una pestaña delgada con un icono "+".
/// - **Expandido**: se desliza para mostrar dos acciones discretas
///   (Ejercicio, Rutina).
///
/// Interacción: tap en la pestaña → alterna expandido/colapsado.
/// Tap en una acción → la ejecuta y colapsa. Tap fuera → colapsa.
///
/// El estilo es intencionalmente sobrio (superficie neutra, sin degradados
/// llamativos) para no competir con el contenido de la sesión.
class AddSideDock extends StatefulWidget {
  const AddSideDock({
    super.key,
    required this.onAddExercise,
    required this.onAddRoutine,
  });

  final VoidCallback onAddExercise;
  final VoidCallback onAddRoutine;

  @override
  State<AddSideDock> createState() => _AddSideDockState();
}

class _AddSideDockState extends State<AddSideDock>
    with SingleTickerProviderStateMixin {
  static const double _peekWidth = 26;
  static const double _expandedWidth = 132;
  static const double _dockHeight = 104;

  late final AnimationController _ctrl;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    // value = 1.0 → colapsado (trasladado fuera). 0.0 → expandido.
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() => _expanded ? _collapse() : _expand();

  void _expand() {
    setState(() => _expanded = true);
    _ctrl.reverse();
  }

  void _collapse() {
    if (!_expanded) return;
    setState(() => _expanded = false);
    _ctrl.forward();
  }

  void _run(VoidCallback action) {
    _collapse();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final topOffset = media.size.height * 0.5 - _dockHeight / 2;

    return Stack(
      children: [
        // Capa para detectar tap fuera del dock cuando está expandido.
        if (_expanded)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _collapse,
            ),
          ),
        Positioned(
          right: 0,
          top: topOffset,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, child) {
              final dx = _ctrl.value * (_expandedWidth - _peekWidth);
              return Transform.translate(
                offset: Offset(dx, 0),
                child: child,
              );
            },
            child: _buildDock(context),
          ),
        ),
      ],
    );
  }

  Widget _buildDock(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: _expandedWidth,
        height: _dockHeight,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh.withValues(alpha: 0.96),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            bottomLeft: Radius.circular(14),
          ),
          border: Border(
            top: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
            left: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
            bottom: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(-2, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildPeekHandle(colors),
            Expanded(child: _buildActions()),
          ],
        ),
      ),
    );
  }

  Widget _buildPeekHandle(ColorScheme colors) {
    return InkWell(
      onTap: _toggle,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(14),
        bottomLeft: Radius.circular(14),
      ),
      child: SizedBox(
        width: _peekWidth,
        height: _dockHeight,
        child: Center(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) => Transform.rotate(
              // colapsado → "+" ; expandido → "›" (invita a cerrar).
              angle: (1 - _ctrl.value) * 0.785398, // hasta 45° hacia "x"
              child: Icon(
                Icons.add,
                color: colors.onSurfaceVariant,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _DockAction(
          icon: Icons.fitness_center_rounded,
          label: 'Ejercicio',
          onTap: () => _run(widget.onAddExercise),
        ),
        const SizedBox(height: 6),
        _DockAction(
          icon: Icons.calendar_month_rounded,
          label: 'Rutina',
          onTap: () => _run(widget.onAddRoutine),
        ),
      ],
    );
  }
}

class _DockAction extends StatelessWidget {
  const _DockAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: colors.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
