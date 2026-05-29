import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../services/notification_service.dart';

/// Bottom sheet con cuenta regresiva para descansos entre series.
/// Presets de 1/2/3/5 min, controles de pausa/reset y ajustes ±30 s.
/// Vibración al terminar (sin sonido para no depender de assets).
class RestTimerSheet extends StatefulWidget {
  const RestTimerSheet({super.key});

  @override
  State<RestTimerSheet> createState() => _RestTimerSheetState();
}

class _RestTimerSheetState extends State<RestTimerSheet> {
  static const _presets = [
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 3),
    Duration(minutes: 5),
  ];

  Duration _total = const Duration(minutes: 3);
  Duration _remaining = const Duration(minutes: 3);
  Timer? _ticker;
  bool _running = false;
  bool _finished = false;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _setPreset(Duration d) {
    _ticker?.cancel();
    NotificationService.instance.cancelRestTimerEnd();
    setState(() {
      _total = d;
      _remaining = d;
      _running = false;
      _finished = false;
    });
  }

  Future<void> _start() async {
    if (_running) return;
    // Pedimos permiso la primera vez. Si lo deniegan seguimos con el timer
    // in-app — solo perderán la notificación cuando salgan de la app.
    await NotificationService.instance.requestPermissionIfNeeded();
    // Programamos la notificación nativa para el instante exacto en que el
    // contador llega a 0. Si el usuario pausa/resetea, la cancelamos.
    await NotificationService.instance.scheduleRestTimerEnd(_remaining);
    if (!mounted) return;
    setState(() {
      _running = true;
      _finished = false;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining.inSeconds <= 1) {
        _onFinish();
      } else {
        setState(() => _remaining -= const Duration(seconds: 1));
      }
    });
  }

  void _pause() {
    _ticker?.cancel();
    NotificationService.instance.cancelRestTimerEnd();
    setState(() => _running = false);
  }

  void _reset() {
    _ticker?.cancel();
    NotificationService.instance.cancelRestTimerEnd();
    setState(() {
      _running = false;
      _finished = false;
      _remaining = _total;
    });
  }

  void _adjust(Duration delta) {
    final next = _remaining + delta;
    if (next.isNegative) return;
    setState(() {
      _remaining = next;
      if (_remaining > _total) _total = _remaining;
    });
    // Si está corriendo, reprogramar la notificación para el nuevo tiempo.
    if (_running) {
      NotificationService.instance.scheduleRestTimerEnd(_remaining);
    }
  }

  void _onFinish() {
    _ticker?.cancel();
    // NO cancelamos la notificación: dejamos que el sistema dispare el sonido
    // del canal (que sí es audible). El in-app solo aporta la vibración táctil
    // mientras el aviso del SO llega — ambos suceden casi en el mismo instante.
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 220), HapticFeedback.heavyImpact);
    Future.delayed(const Duration(milliseconds: 440), HapticFeedback.heavyImpact);
    setState(() {
      _running = false;
      _remaining = Duration.zero;
      _finished = true;
    });
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _total.inSeconds == 0
        ? 0.0
        : (_total.inSeconds - _remaining.inSeconds) / _total.inSeconds;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 12,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Descanso',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final d in _presets)
                  ChoiceChip(
                    label: Text('${d.inMinutes} min'),
                    selected: _total == d,
                    onSelected: (_) => _setPreset(d),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      strokeWidth: 8,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation(
                        _finished ? Colors.greenAccent : AppColors.primary,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _fmt(_remaining),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (_finished)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            '¡Listo!',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _running || _finished
                      ? () => _adjust(const Duration(seconds: -30))
                      : null,
                  icon: const Icon(Icons.remove, size: 16),
                  label: const Text('30s'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _running || _finished
                      ? () => _adjust(const Duration(seconds: 30))
                      : null,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('30s'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_running && !_finished)
                  FilledButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Iniciar'),
                    onPressed: _start,
                  ),
                if (_running)
                  FilledButton.icon(
                    icon: const Icon(Icons.pause),
                    label: const Text('Pausar'),
                    onPressed: _pause,
                  ),
                if (_finished)
                  FilledButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reiniciar'),
                    onPressed: () {
                      _reset();
                      _start();
                    },
                  ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reset'),
                  onPressed: _reset,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void showRestTimerSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    showDragHandle: false,
    isScrollControlled: true,
    builder: (_) => const RestTimerSheet(),
  );
}
