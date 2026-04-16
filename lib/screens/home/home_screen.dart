import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/glass_kit.dart';
import '../../models/session.dart';
import '../../models/exercise.dart';
import '../../services/session_service.dart';
import '../../services/exercise_service.dart';
import '../../services/statistics_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _sessionService = SessionService.instance;
  final _exerciseService = ExerciseService.instance;
  final _stats = StatisticsService.instance;

  bool _loading = true;
  int _currentStreak = 0;
  int _maxStreak = 0;
  Session? _lastSession;
  List<Exercise> _lastExercises = [];
  double _weeklyVolume = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final now = DateTime.now();

    final results = await Future.wait([
      _stats.streaks(),
      _stats.weeklyVolume(now),
      _sessionService.getAll(),
    ]);

    final streaks = results[0] as ({int currentStreak, int maxStreak});
    final sessions = results[2] as List<Session>;
    final lastSession = sessions.isNotEmpty ? sessions.first : null;

    List<Exercise> lastExercises = [];
    if (lastSession != null) {
      final ses =
          await _sessionService.getExercisesForSession(lastSession.id!);
      final exList = await Future.wait(
        ses.map((se) => _exerciseService.getById(se.exerciseId)),
      );
      lastExercises = exList.whereType<Exercise>().toList();
    }

    setState(() {
      _currentStreak = streaks.currentStreak;
      _maxStreak = streaks.maxStreak;
      _weeklyVolume = results[1] as double;
      _lastSession = lastSession;
      _lastExercises = lastExercises;
      _loading = false;
    });
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 18) return 'Buenas tardes';
    return 'Buenas noches';
  }

  String _formatDate(DateTime date) {
    const months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Ayer';
    return '${date.day} ${months[date.month - 1]} · hace $diff días';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _greeting(),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.onBg,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.muted),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                children: [
                  _StreakBanner(
                    streak: _currentStreak,
                    maxStreak: _maxStreak,
                  ),
                  const SizedBox(height: 14),
                  _WeeklyVolumeCard(volume: _weeklyVolume),
                  const SizedBox(height: 14),
                  _LastSessionCard(
                    session: _lastSession,
                    exercises: _lastExercises,
                    formatDate: _formatDate,
                  ),
                ],
              ),
            ),
    );
  }
}

// ── Streak Banner ─────────────────────────────────────────────────────────────

class _StreakBanner extends StatelessWidget {
  const _StreakBanner({required this.streak, required this.maxStreak});

  final int streak;
  final int maxStreak;

  @override
  Widget build(BuildContext context) {
    final active = streak > 0;
    final glowColor = active ? AppColors.accent : AppColors.muted;

    return NeonGlassCard(
      glowColor: glowColor,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Icono con glow
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: glowColor.withValues(alpha: 0.1),
              border: Border.all(
                color: glowColor.withValues(alpha: 0.25),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.2),
                  blurRadius: 16,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Center(
              child: Text(
                active ? '🔥' : '💤',
                style: const TextStyle(fontSize: 26),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active
                      ? '$streak día${streak == 1 ? '' : 's'} de racha'
                      : 'Sin racha activa',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: active ? AppColors.onBg : AppColors.muted,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  active ? '¡No rompas la cadena!' : 'Entrena hoy para comenzar',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.muted.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          // Máxima racha
          if (maxStreak > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$maxStreak',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
                const Text(
                  'récord',
                  style: TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Weekly Volume ─────────────────────────────────────────────────────────────

class _WeeklyVolumeCard extends StatelessWidget {
  const _WeeklyVolumeCard({required this.volume});

  final double volume;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          const NeonIcon(
            icon: Icons.bar_chart_rounded,
            color: AppColors.primary,
            size: 26,
            glowRadius: 12,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Volumen esta semana',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      volume.toStringAsFixed(0),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onBg,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'kg',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Indicador visual
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.primary, AppColors.secondary],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Last Session Card ─────────────────────────────────────────────────────────

class _LastSessionCard extends StatelessWidget {
  const _LastSessionCard({
    required this.session,
    required this.exercises,
    required this.formatDate,
  });

  final Session? session;
  final List<Exercise> exercises;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              NeonIcon(
                icon: Icons.history_rounded,
                color: AppColors.secondary,
                size: 18,
                glowRadius: 8,
              ),
              SizedBox(width: 8),
              Text(
                'Último entreno',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (session == null)
            const Text(
              'Sin sesiones registradas',
              style: TextStyle(color: AppColors.muted, fontSize: 14),
            )
          else ...[
            Text(
              formatDate(session!.date),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.onBg,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 12),
            if (exercises.isEmpty)
              const Text(
                'Sin ejercicios registrados',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: exercises
                    .map((ex) => GlassChip(ex.name, color: AppColors.primary))
                    .toList(),
              ),
          ],
        ],
      ),
    );
  }
}
