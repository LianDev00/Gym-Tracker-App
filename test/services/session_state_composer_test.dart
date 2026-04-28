import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/models/exercise.dart';
import 'package:gym_tracker/models/muscle_category.dart';
import 'package:gym_tracker/models/muscle_group.dart';
import 'package:gym_tracker/models/muscle_state.dart';
import 'package:gym_tracker/models/session_set.dart';
import 'package:gym_tracker/services/session_state_composer.dart';

Exercise _ex({
  required int id,
  required String name,
  MuscleCategory category = MuscleCategory.pecho,
  Map<MuscleGroup, MuscleRole> muscles = const {},
}) =>
    Exercise(id: id, name: name, muscleCategory: category, muscles: muscles);

SessionSet _set({int reps = 10, double weight = 50, int setNumber = 1}) =>
    SessionSet(
      sessionExerciseId: 1,
      setNumber: setNumber,
      reps: reps,
      weightKg: weight,
    );

void main() {
  group('resolveSessionState', () {
    test('sesión vacía → mapa vacío', () {
      expect(resolveSessionState(entries: const []), isEmpty);
    });

    test('un ejercicio dominante → ese músculo es dominant', () {
      final result = resolveSessionState(entries: [
        (
          exercise: _ex(
            id: 1,
            name: 'Press banca',
            muscles: const {
              MuscleGroup.chest: MuscleRole.dominant,
              MuscleGroup.triceps: MuscleRole.secondary,
              MuscleGroup.shouldersFront: MuscleRole.secondary,
            },
          ),
          sets: [_set(reps: 10, weight: 80), _set(reps: 8, weight: 80)],
        ),
      ]);

      expect(result[MuscleGroup.chest], MuscleState.dominant);
      expect(result[MuscleGroup.triceps], MuscleState.secondary);
      expect(result[MuscleGroup.shouldersFront], MuscleState.secondary);
      expect(result[MuscleGroup.lats], isNull); // idle implícito
    });

    test('múltiples dominantes → solo uno gana, otros quedan active', () {
      final result = resolveSessionState(entries: [
        (
          exercise: _ex(
            id: 1,
            name: 'Press banca',
            muscles: const {MuscleGroup.chest: MuscleRole.dominant},
          ),
          sets: [_set(reps: 10, weight: 100)], // volumen 1000
        ),
        (
          exercise: _ex(
            id: 2,
            name: 'Curl bíceps',
            muscles: const {MuscleGroup.biceps: MuscleRole.dominant},
          ),
          sets: [_set(reps: 12, weight: 20)], // volumen 240
        ),
      ]);

      expect(result[MuscleGroup.chest], MuscleState.dominant);
      expect(result[MuscleGroup.biceps], MuscleState.active);
    });

    test('mismo músculo como dominant en uno y secondary en otro → dominant gana', () {
      final result = resolveSessionState(entries: [
        (
          exercise: _ex(
            id: 1,
            name: 'Curl bíceps',
            muscles: const {MuscleGroup.biceps: MuscleRole.dominant},
          ),
          sets: [_set(reps: 12, weight: 20)],
        ),
        (
          exercise: _ex(
            id: 2,
            name: 'Remo',
            muscles: const {
              MuscleGroup.lats: MuscleRole.dominant,
              MuscleGroup.biceps: MuscleRole.secondary,
            },
          ),
          sets: [_set(reps: 10, weight: 60)],
        ),
      ]);

      // bíceps NO debe quedar como secondary aunque también aparezca así
      expect(result[MuscleGroup.biceps], isNot(MuscleState.secondary));
      expect(result[MuscleGroup.lats], MuscleState.dominant);
      expect(result[MuscleGroup.biceps], MuscleState.active);
    });

    test('ejercicios con peso 0 (bodyweight) cuentan por # de sets', () {
      final result = resolveSessionState(entries: [
        (
          exercise: _ex(
            id: 1,
            name: 'Plancha',
            category: MuscleCategory.core,
            muscles: const {
              MuscleGroup.abs: MuscleRole.dominant,
              MuscleGroup.obliques: MuscleRole.secondary,
            },
          ),
          sets: [_set(reps: 0, weight: 0), _set(reps: 0, weight: 0)],
        ),
      ]);

      expect(result[MuscleGroup.abs], MuscleState.dominant);
      expect(result[MuscleGroup.obliques], MuscleState.secondary);
    });

    test('ejercicio sin sets no contribuye', () {
      final result = resolveSessionState(entries: [
        (
          exercise: _ex(
            id: 1,
            name: 'Press banca',
            muscles: const {MuscleGroup.chest: MuscleRole.dominant},
          ),
          sets: const [],
        ),
      ]);

      expect(result, isEmpty);
    });

    test('ejercicio sin atribución muscular (cardio) no contribuye', () {
      final result = resolveSessionState(entries: [
        (
          exercise: _ex(
            id: 1,
            name: 'Cinta',
            category: MuscleCategory.cardio,
            muscles: const {},
          ),
          sets: [_set(reps: 30, weight: 0)],
        ),
      ]);

      expect(result, isEmpty);
    });

    test('volumen acumulado decide al dominant winner', () {
      // chest tiene 1 ejercicio fuerte, biceps tiene 2 ejercicios débiles.
      // Si la suma de biceps supera a chest, biceps gana.
      final result = resolveSessionState(entries: [
        (
          exercise: _ex(
            id: 1,
            name: 'Press inclinado',
            muscles: const {MuscleGroup.chest: MuscleRole.dominant},
          ),
          sets: [_set(reps: 10, weight: 50)], // 500
        ),
        (
          exercise: _ex(
            id: 2,
            name: 'Curl barra',
            muscles: const {MuscleGroup.biceps: MuscleRole.dominant},
          ),
          sets: [_set(reps: 10, weight: 30)], // 300
        ),
        (
          exercise: _ex(
            id: 3,
            name: 'Curl mancuernas',
            muscles: const {MuscleGroup.biceps: MuscleRole.dominant},
          ),
          sets: [_set(reps: 12, weight: 25)], // 300, total biceps = 600
        ),
      ]);

      expect(result[MuscleGroup.biceps], MuscleState.dominant);
      expect(result[MuscleGroup.chest], MuscleState.active);
    });

    test('músculo solo como secondary → secondary', () {
      final result = resolveSessionState(entries: [
        (
          exercise: _ex(
            id: 1,
            name: 'Press banca',
            muscles: const {
              MuscleGroup.chest: MuscleRole.dominant,
              MuscleGroup.shouldersFront: MuscleRole.secondary,
            },
          ),
          sets: [_set(reps: 10, weight: 80)],
        ),
      ]);

      expect(result[MuscleGroup.shouldersFront], MuscleState.secondary);
      expect(result.containsKey(MuscleGroup.lats), isFalse);
    });
  });
}
