SPEC-TF v1 — Gym-Tracker: "la última vez" y aviso de récord en la sesión

## 0. Metadatos
- Proyecto: Gym-Tracker-App
- Fecha: 2026-10-19
- Stack: Flutter 3.47 / Dart 3.13, `sqflite`. Tests con `flutter_test` + `sqflite_common_ffi` (ya instalado).
- Modelo destino: Sonnet 5.5.
- Origen: revisión de UX. Al registrar una serie, el usuario no ve qué hizo la vez anterior ni sabe si está batiendo su récord.
- Rama/worktree: `feat/ultima-vez-records` en `..\Gym-Tracker-worktrees\ultima-vez`.

## 1. Contexto y objetivo
En la pantalla de sesión (`lib/screens/session/session_screen.dart`), cada ejercicio muestra filas de series con peso, reps y RIR vacíos (hint `0`). Lo primero que un usuario quiere saber en el gimnasio es qué levantó la última vez. **Objetivo:** (1) mostrar bajo cada ejercicio las series de la última sesión anterior en que se registró con datos; (2) usar esos valores como *hint* (texto gris, no valor real) en las series correspondientes; (3) marcar con un trofeo la serie cuyo peso supera el máximo histórico del ejercicio, y avisar con un SnackBar la primera vez en la sesión.

## 2. Alcance y NO-alcance
### Dentro del alcance
- Dos lecturas por lote nuevas en `SessionService`.
- Borrar el método muerto `ExerciseService.getLastSetForExercise`.
- La línea "Última vez", los hints, el trofeo y el SnackBar en `session_screen.dart`.
- Tests de las dos lecturas.
### Fuera del alcance (prohibido construir)
- Prellenar los valores (escribir en los controllers): las series vacías significan "no hecho" y las estadísticas dependen de eso. Solo hints.
- Récords por reps, por volumen o por 1RM: el récord es **peso máximo**, igual que la sección "Récords Personales" existente.
- Récord en ejercicios de peso corporal (`isBodyweight`): no aplica.
- Animaciones, confeti, sonidos o vibración.
- Persistir que un récord "ya se avisó" entre aperturas de la pantalla.
- Tocar `statistics_service.dart`, `stats_screen.dart`, `history_screen.dart`, `home_screen.dart`, `export_service.dart`, `pubspec.yaml` o `android/`.
- Reorganizar `session_screen.dart` en varios archivos.
- Agregar dependencias.

## 3. Decisiones de arquitectura
| # | Decisión | Porqué | Alternativa descartada y por qué |
|---|---|---|---|
| 1 | Las consultas nuevas van en `SessionService`, con lote por ids de ejercicio | Son lecturas del historial de sesiones; con lote, abrir una sesión cuesta 2 queries fijas. Además `statistics_service.dart` lo está modificando otra rama en paralelo | Un método por ejercicio: reintroduce el N+1 que se acaba de quitar |
| 2 | "Última vez" = la sesión con **fecha máxima anterior al día de la sesión actual** que tenga al menos una serie con datos (peso o reps) para ese ejercicio | Ignora sesiones donde el ejercicio se agregó pero no se hizo; usa la fecha (no el id) porque se pueden crear sesiones de días pasados | `MAX(id)`: falla si el usuario registra hoy algo de la semana pasada |
| 3 | Récord = `peso > máximo histórico del ejercicio excluyendo la sesión actual`, y solo si ese máximo existe y la serie tiene `reps > 0` | El primer registro de un ejercicio no es "récord"; un peso sin reps no cuenta. Es consistente con `personalRecords()` | Comparar contra el máximo incluyendo la sesión actual: la serie se compararía consigo misma |
| 4 | Trofeo con `ListenableBuilder` sobre los controllers de **esa** fila | Se redibuja solo el ícono al teclear, no la pantalla (coherente con la optimización de renders) | `setState` en cada tecla: rebuild de toda la pantalla de 1300 líneas |
| 5 | SnackBar en el callback de autoguardado (debounce de 600 ms), una vez por ejercicio por apertura (`entry.recordAnnounced`) | No interrumpe al usuario mientras escribe; no se repite por cada serie | SnackBar en cada pulsación: spam |
| 6 | Hints por posición: la serie `n` usa la serie `n` de la última vez | Simple y predecible | Hint de la mejor serie en todas: menos útil para replicar la sesión |

## 4. Mapa de módulos

### lib/services/session_service.dart
- Se **agregan** (nada existente cambia):
  ```dart
  /// Series con datos de la última sesión ANTERIOR a [before] (comparando por
  /// fecha) en que se registró cada ejercicio. Una clave por cada id de
  /// [exerciseIds] (lista vacía si no hay historial), ordenadas por
  /// session_exercise y número de serie.
  Future<Map<int, List<SessionSet>>> getLastPerformance(
    List<int> exerciseIds, {
    required DateTime before,
  });

  /// Peso máximo histórico por ejercicio, excluyendo la sesión [excludeSessionId].
  /// Solo contiene claves de ejercicios con al menos un peso registrado.
  Future<Map<int, double>> getMaxWeights(
    List<int> exerciseIds, {
    required int excludeSessionId,
  });
  ```
- Ids vacíos → `{}` sin consultar. Ids deduplicados. `assert(ids.length <= _inChunkSize)` con el comentario `// una sesión no tiene cientos de ejercicios; sin troceo`. `_inChunkSize` ya existe en la clase.
- `getLastPerformance`: `before` se normaliza al inicio del día, `DateTime(before.year, before.month, before.day).toIso8601String()`. SQL (con `DbConstants` para todos los nombres y `?` para los valores; `<ids>` = placeholders):
  ```sql
  SELECT sx.exercise_id AS ex_id, ss.*
  FROM session_sets ss
  JOIN session_exercises sx ON ss.session_exercise_id = sx.id
  JOIN sessions s ON sx.session_id = s.id
  WHERE sx.exercise_id IN (<ids>)
    AND (ss.weight_kg IS NOT NULL OR ss.reps IS NOT NULL)
    AND s.date = (
      SELECT MAX(s2.date)
      FROM sessions s2
      JOIN session_exercises sx2 ON sx2.session_id = s2.id
      JOIN session_sets ss2 ON ss2.session_exercise_id = sx2.id
      WHERE sx2.exercise_id = sx.exercise_id
        AND s2.date < ?
        AND (ss2.weight_kg IS NOT NULL OR ss2.reps IS NOT NULL)
    )
  ORDER BY sx.exercise_id, sx.id, ss.set_number
  ```
  `whereArgs: [...ids, beforeIso]`. Agrupar con `row['ex_id'] as int` y `SessionSet.fromMap(row)`. El mapa se inicializa con todas las claves, igual que en `getExercisesForSessions`.
- `getMaxWeights`:
  ```sql
  SELECT sx.exercise_id AS ex_id, MAX(ss.weight_kg) AS max_w
  FROM session_sets ss
  JOIN session_exercises sx ON ss.session_exercise_id = sx.id
  WHERE sx.exercise_id IN (<ids>) AND sx.session_id != ? AND ss.weight_kg IS NOT NULL
  GROUP BY sx.exercise_id
  ```
  Devuelve `{ex_id: (max_w as num).toDouble()}`.

### lib/services/exercise_service.dart
- Borrar `getLastSetForExercise` y su comentario. Antes, confirmar con `grep -rn getLastSetForExercise lib test` que no se usa. Si quedan imports sin uso, quitarlos.

### lib/screens/session/session_screen.dart
1. `_ExerciseEntry` gana dos campos y un flag:
   ```dart
   List<SessionSet> previousSets = const [];
   double? previousMaxWeightKg;
   bool recordAnnounced = false;
   ```
2. `_fmtDouble` pasa de método de `_SessionScreenState` a **función top-level privada** del archivo, con la misma firma y el mismo comentario, para usarla desde los widgets. Las llamadas existentes no cambian de forma.
3. Nuevo método privado en el State:
   ```dart
   /// Carga "última vez" y máximo histórico para [entries] (2 queries).
   Future<void> _attachHistory(List<_ExerciseEntry> entries, int sessionId) async
   ```
   que llama a `getLastPerformance(ids, before: _selectedDate)` y `getMaxWeights(ids, excludeSessionId: sessionId)` y asigna `previousSets` y `previousMaxWeightKg` a cada entry. **No** llama `setState`: lo llaman los métodos de abajo antes de su propio `setState`.
   - En `_loadExistingSession`: `await _attachHistory(loaded, sessionId)` justo antes del bloque `if (!mounted)`.
   - En `_addExercises`: `await _attachHistory(newEntries, sessionId)` justo antes de `setState(() => _entries.addAll(newEntries))`.
4. `_ExerciseCard`: debajo de la fila de chips (después de los `GlassChip`), si `entry.previousSets.isNotEmpty`, un `Padding(top: 6)` con `Text('Última vez: $resumen', style: TextStyle(fontSize: 12, color: AppColors.muted))`, donde `resumen` = series unidas con `' · '`. Cada serie se muestra como `'${_fmtDouble(w)}×$reps'` si hay peso y reps, `'${_fmtDouble(w)} kg'` si solo hay peso, o `'×$reps'` si solo hay reps (siempre así en peso corporal). `maxLines: 2`, `overflow: TextOverflow.ellipsis`.
5. `_SetRow` recibe dos parámetros nuevos, `SessionSet? previous` (la serie de la última vez con la misma posición: `entry.previousSets.elementAtOrNull(index)`) y `double? previousMaxWeightKg`:
   - Hint del peso: `previous?.weightKg != null ? _fmtDouble(previous!.weightKg!) : '0'`. Hint de reps: `previous?.reps?.toString() ?? '0'`. Hint de RIR: `previous?.rir?.toString() ?? '-'`.
   - Trofeo: entre el campo RIR y el botón de borrar, un `SizedBox(width: 24, child: ListenableBuilder(listenable: Listenable.merge([setEntry.weightCtrl, setEntry.repsCtrl]), builder: (_, __) => _isRecord(...) ? const Icon(Icons.emoji_events_rounded, size: 18, color: Color(0xFFFFC107)) : const SizedBox.shrink()))`. Para mantener la alineación, el encabezado de columnas de `_ExerciseCard` agrega un `SizedBox(width: 24)` en la misma posición.
   - En peso corporal no se muestra el trofeo (`isBodyweight` → `SizedBox(width: 24)` vacío).
6. Función top-level pura del archivo, para que la UI y el SnackBar usen la misma regla:
   ```dart
   /// Récord = peso estrictamente mayor al máximo histórico, con reps > 0.
   /// Sin historial no hay récord (el primer registro no cuenta).
   bool _isRecord({required double? weight, required int? reps, required double? previousMax}) =>
       weight != null && previousMax != null && (reps ?? 0) > 0 && weight > previousMax;
   ```
7. SnackBar: en `_setupListeners`, dentro del callback del `Timer` (después de `updateSet`), si `!entry.recordAnnounced && !entry.exercise.isBodyweight && _isRecord(weight: setEntry.weight, reps: setEntry.reps, previousMax: entry.previousMaxWeightKg)` y `mounted`: `entry.recordAnnounced = true;` y `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🏆 ¡Nuevo récord en ${entry.exercise.name}: ${_fmtDouble(setEntry.weight!)} kg!')))`.

### test/services/session_history_test.dart (nuevo)
- `setUpAll`: `sqfliteFfiInit(); databaseFactory = databaseFactoryFfi;` más una carpeta temporal propia: `await databaseFactory.setDatabasesPath((await Directory.systemTemp.createTemp('gym_history_test_')).path);` (sin esto, se pisa con otros archivos de test en paralelo).
- Escenario determinista, con el ejercicio A = id 1 y B = id 2 (vienen del seed):
  - S1 (2026-01-05): A con series (80×8), (80×7).
  - S2 (2026-01-10): A con series vacías (sin peso ni reps) → debe ignorarse.
  - S3 (2026-01-12): B con (40×10); A no aparece.
  - S4 (2026-01-15, "actual"): A con (85×5).
- Casos:
  - `getLastPerformance([1, 2, 3], before: 2026-01-15 14:00)` → A = las dos series de S1 en orden; B = la serie de S3; 3 = lista vacía.
  - `getLastPerformance([1], before: 2026-01-05)` → A vacío (no hay nada antes).
  - `getMaxWeights([1, 2, 3], excludeSessionId: S4)` → `{1: 80.0, 2: 40.0}` (sin clave 3; el 85 de S4 excluido).
  - Lista vacía → `{}` en ambos.
- Test de `_isRecord`: es privada, así que **no se testea directamente**. La regla queda cubierta por la revisión del criterio de §7 (no exponerla solo para testear).

## 5. Contratos y tipos clave
- `getLastPerformance` siempre trae todas las claves pedidas; `getMaxWeights` solo las que tienen historial (ausencia = sin récord posible).
- Los hints nunca escriben en los controllers: un `TextField` con hint sigue vacío y no dispara el autoguardado.
- Errores: no se captura nada nuevo; las excepciones de sqflite se propagan igual que hoy.

## 6. Orden de construcción
| Fase | Carril | Qué se construye | Modelo | Archivos propios | Cómo se verifica al terminar |
|---|---|---|---|---|---|
| 1 | — | `getLastPerformance`, `getMaxWeights` y sus tests; borrar `getLastSetForExercise` | Sonnet | `lib/services/session_service.dart`, `lib/services/exercise_service.dart`, `test/services/session_history_test.dart` | `flutter test` en verde; `flutter analyze` sin issues |
| 2 | — | UI: campos de `_ExerciseEntry`, `_fmtDouble` top-level, `_attachHistory`, la línea "Última vez", los hints, el trofeo y el SnackBar | Sonnet | `lib/screens/session/session_screen.dart` | `flutter analyze` sin issues; `flutter test` en verde |

Un commit por fase: `feat: lecturas de última vez y peso máximo por lote` y `feat: última vez, hints y aviso de récord en la sesión`, más el trailer de coautoría del entorno. **No hacer push.**

Nota de entorno: Flutter no está en el PATH de los shells nuevos. Usa PowerShell con `$env:Path += ';C:\Users\LiaN\dev\flutter\bin'`.

## 7. Criterios de aceptación
- [ ] Los 4 casos de test de §4 pasan.
- [ ] `grep -rn getLastSetForExercise lib test` no devuelve nada.
- [ ] Abrir una sesión hace exactamente 2 queries adicionales (`getLastPerformance` y `getMaxWeights`), no una por ejercicio (revisión de código).
- [ ] Ningún controller se escribe con valores de la última vez (revisión: no hay `.text =` con `previous`).
- [ ] `_isRecord` es la única definición de la regla, y la usan el trofeo y el SnackBar.
- [ ] Un ejercicio de peso corporal muestra "Última vez" con reps, pero nunca trofeo ni SnackBar.
- [ ] `flutter analyze` sin issues y `flutter test` en verde.
- [ ] Prueba manual (la hace el usuario después de integrar): una sesión de hoy con un ejercicio hecho antes muestra "Última vez" y hints grises; escribir un peso mayor al máximo muestra el trofeo y, a los 0,6 s, el SnackBar una sola vez.

## 8. Anti-instrucciones (NO hacer)
- NO prellenar valores, solo hints.
- NO agregar dependencias.
- NO crear clases nuevas para "performance" o "record": se usan `SessionSet`, `double` y los campos de `_ExerciseEntry`.
- NO hacer pública `_isRecord` ni moverla a otro archivo para testearla.
- NO llamar `setState` desde `_attachHistory` ni por pulsación de tecla.
- NO tocar archivos fuera de los listados en §6.
- NO cambiar textos, estilos ni comportamiento existentes de la pantalla de sesión, salvo lo descrito.
- NO hacer push.

## 9. Escalación
Si una decisión no está cubierta por esta spec: NO improvises arquitectura.
- Decisión grande (afecta módulos, contratos o dependencias): detente y pregunta.
- Decisión menor: resuélvela de la forma más simple y márcala `// TODO-ARQUITECTO: [decisión + propuesta]`.
- Al reportar, lista los `TODO-ARQUITECTO` y los `TF-TECHO`.
