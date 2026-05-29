import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Dock lateral colapsable anclado al borde derecho de la pantalla.
///
/// Estados:
/// - **Colapsado**: solo asoma una pestaña de 24 px con un chevron.
/// - **Expandido**: se desliza para mostrar los botones de acción
///   (timer, agregar).
///
/// Interacción: primer tap en la pestaña → expande. Tap en un botón →
/// ejecuta su acción y colapsa. Tap en cualquier punto fuera del dock →
/// colapsa.
class SessionSideDock extends StatefulWidget {
  const SessionSideDock({
    super.key,
    required this.onTimerTap,
    required this.onAddTap,
  });

  final VoidCallback onTimerTap;
  final VoidCallback onAddTap;

  @override
  State<SessionSideDock> createState() => _SessionSideDockState();
}

class _SessionSideDockState extends State<SessionSideDock>
    with SingleTickerProviderStateMixin {
  static const double _peekWidth = 24;
  static const double _expandedWidth = 64;
  static const double _dockHeight = 150;

  late final AnimationController _ctrl;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    // value = 1.0 → colapsado (trasladado fuera). 0.0 → expandido.
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_expanded) {
      _collapse();
    } else {
      _expand();
    }
  }

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
    final topOffset = media.size.height * 0.45 - _dockHeight / 2;

    return Stack(
      children: [
        // Overlay para detectar tap fuera del dock cuando está expandido.
        if (_expanded)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _collapse,
              child: const SizedBox.shrink(),
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
            child: _buildDock(),
          ),
        ),
      ],
    );
  }

  Widget _buildDock() {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: _expandedWidth,
        height: _dockHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withValues(alpha: 0.92),
              AppColors.secondary.withValues(alpha: 0.85),
            ],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            bottomLeft: Radius.circular(18),
          ),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
            left: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(-2, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildPeekHandle(),
            Expanded(child: _buildActions()),
          ],
        ),
      ),
    );
  }

  Widget _buildPeekHandle() {
    return InkWell(
      onTap: _toggle,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(18),
        bottomLeft: Radius.circular(18),
      ),
      child: SizedBox(
        width: _peekWidth,
        height: _dockHeight,
        child: Center(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) => Transform.rotate(
              // 0 → ‹ (apunta a la izquierda, invita a expandir hacia la izquierda).
              // π → › (apunta a la derecha, invita a colapsar de vuelta).
              angle: (1 - _ctrl.value) * 3.14159,
              child: const Icon(
                Icons.chevron_left,
                color: Colors.white,
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
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _DockButton(
          icon: Icons.timer_outlined,
          tooltip: 'Temporizador de descanso',
          onTap: () => _run(widget.onTimerTap),
        ),
        _DockButton(
          icon: Icons.add,
          tooltip: 'Agregar',
          onTap: () => _run(widget.onAddTap),
        ),
      ],
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}
