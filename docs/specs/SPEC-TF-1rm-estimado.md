SPEC-TF v1 — Gym-Tracker: 1RM estimado en "Progreso por ejercicio"

## 0. Metadatos
- Proyecto: Gym-Tracker-App
- Fecha: 2026-10-19
- Stack: Flutter 3.47 / Dart 3.13, `sqflite`, `fl_chart ^0.69.0` (ya instalado). Tests con `flutter_test`.
- Modelo destino: Haiku 4.5 (la spec es cerrada y mecánica).
- Origen: revisión de visualización.
- Rama/worktree: `feat/1rm-estimado` en `..\Gym-Tracker-worktrees\1rm`.

## 1. Contexto y objetivo
La sección "Progreso por ejercicio" de `lib/screens/stats/stats_screen.dart` grafica el **peso máximo** por día (`StatisticsService.maxWeightHistory`). Así, un día de 70 kg × 12 aparece como retroceso frente a uno de 75 kg × 3, aunque fue más fuerza. **Objetivo:** agregar un selector "Peso máx. / 1RM est." que cambia la gráfica y los chips a la **repetición máxima estimada** (fórmula de Epley), calculada por día.

## 2. Alcance y NO-alcance
### Dentro del alcance
- Una función pura de Epley con tests.
- Un método de historial de 1RM por día en `StatisticsService`.
- El selector en la tarjeta de progreso, y la gráfica y los chips según la métrica elegida.
### Fuera del alcance (prohibido construir)
- Otras fórmulas (Brzycki, Lombardi…) o elegir la fórmula.
- Usar el 1RM en "Récords Personales", el aviso de récord, Home o el historial.
- Recordar la métrica elegida entre aperturas (persistencia).
- 1RM para ejercicios de peso corporal (sin peso no hay 1RM; siguen las reglas actuales: `weight_kg IS NOT NULL`).
- Tocar `session_screen.dart`, `session_service.dart`, `history_screen.dart`, `home_screen.dart`, `export_service.dart`, `pubspec.yaml` o `android/`.
- Cambiar el estilo de la gráfica (colores, ejes, tooltip) más allá de lo necesario para el nuevo tipo de datos.
- Agregar dependencias.

## 3. Decisiones de arquitectura
| # | Decisión | Porqué | Alternativa descartada y por qué |
|---|---|---|---|
| 1 | Epley: `1RM = peso × (1 + reps / 30)`; con `reps == 1` el 1RM es el peso; con `reps < 1` o `reps > 12`, `null` (la serie se ignora) | Epley es el estándar y el más simple; por encima de ~12 reps la estimación se vuelve poco fiable | Incluir series de 20 reps: infla el 1RM con trabajo de resistencia |
| 2 | Función pura en `lib/core/utils/one_rep_max.dart` | Es lógica de dominio sin E/S: se testea sin BD ni Flutter | Calcularlo en SQL: menos legible y no testeable aislado |
| 3 | `estimatedOneRepMaxHistory` trae las series en SQL y agrupa por día en Dart (máximo 1RM por día) | Reusa la función pura; una query | Una query por día: N+1 |
| 4 | La gráfica pasa a recibir puntos genéricos `List<({DateTime date, double kg})>`; la pantalla mapea cada fuente | Un solo widget de gráfica para las dos métricas, sin campos con nombre falso (`maxWeightKg` con un 1RM) | Duplicar `_WeightLineChart`: dos widgets casi iguales |
| 5 | Selector con `SegmentedButton<_ProgressMetric>` (Material 3, nativo) y `enum _ProgressMetric { maxWeight, oneRepMax }` privado | Estado ilegal irrepresentable (no hay bools sueltos); widget nativo, sin dependencias | `ToggleButtons` o dos chips manuales: más código |

## 4. Mapa de módulos

### lib/core/utils/one_rep_max.dart (nuevo)
```dart
/// Repetición máxima estimada (Epley). Devuelve null si [reps] está fuera
/// de 1..12, rango donde la fórmula deja de ser fiable.
double? epleyOneRepMax(double weightKg, int reps) {
  if (reps < 1 || reps > 12) return null;
  if (reps == 1) return weightKg;
  return weightKg * (1 + reps / 30);
}
```
Exactamente esto (el comentario incluido). Sin otras funciones.

### lib/services/statistics_service.dart
- Se **agrega** después de `maxWeightHistory`:
  ```dart
  /// 1RM estimado (Epley) máximo por día para un ejercicio, en orden cronológico.
  /// Ignora series sin peso o con reps fuera de 1..12.
  Future<List<({DateTime date, double oneRepMaxKg})>> estimatedOneRepMaxHistory(
    int exerciseId,
  ) async
  ```
- SQL (mismo estilo y mismos `JOIN` que `maxWeightHistory`, con `DbConstants`):
  `SELECT s.date, ss.weight_kg, ss.reps FROM session_sets ss JOIN session_exercises sx … JOIN sessions s … WHERE sx.exercise_id = ? AND ss.weight_kg IS NOT NULL AND ss.reps IS NOT NULL ORDER BY s.date`.
- Agrupar en Dart por día calendario (`DateTime(d.year, d.month, d.day)`), quedarse con el máximo `epleyOneRepMax` no nulo de cada día y omitir los días sin ningún valor. `date` = el `DateTime` de la primera fila del día (igual que `maxWeightHistory`, que usa la fecha de la fila agrupada). Usar un `Map<DateTime, …>` y luego ordenar por fecha.
- Nada existente cambia.

### lib/screens/stats/stats_screen.dart
1. `enum _ProgressMetric { maxWeight, oneRepMax }`, a nivel archivo y privado.
2. En el State: `_ProgressMetric _progressMetric = _ProgressMetric.maxWeight;` y `List<({DateTime date, double oneRepMaxKg})> _exerciseOneRepMax = [];`.
3. `_loadExerciseHistory(exercise)`: carga **ambas** historias con `Future.wait` y las asigna en el mismo `setState`.
4. `_ExerciseProgressCard` (hoy en la línea ~818, instanciada en la ~221) reemplaza `history` por `required this.points` (`List<({DateTime date, double kg})>`), `required this.metric` (`_ProgressMetric`) y `required this.onMetricChanged` (`void Function(_ProgressMetric)`). `best` y `last` se calculan sobre `points` y `.kg`. El State construye `points` así:
   - `maxWeight` → `[for (final h in _exerciseHistory) (date: h.date, kg: h.maxWeightKg)]`
   - `oneRepMax` → `[for (final h in _exerciseOneRepMax) (date: h.date, kg: h.oneRepMaxKg)]`
5. Dentro de la tarjeta, después del `DropdownButtonFormField` y del `SizedBox(height: 16)`, un `SegmentedButton<_ProgressMetric>` con los segmentos `ButtonSegment(value: maxWeight, label: Text('Peso máx.'))` y `ButtonSegment(value: oneRepMax, label: Text('1RM est.'))`, `selected: {metric}` y `onSelectionChanged: (s) => onMetricChanged(s.first)`, seguido de `SizedBox(height: 12)`.
6. Chips: con `maxWeight`, igual que hoy (`'Máx. …'`, `'Último …'`); con `oneRepMax`, `'1RM máx. …'` y `'1RM último …'`. Mismo formato `toStringAsFixed(1)` y `kg`.
7. Mensajes vacíos: si `points.isEmpty`, se mantiene `'Sin datos para este ejercicio'`. Con `oneRepMax` y sin puntos, el mensaje es `'Sin series de 1 a 12 reps con peso'`.
8. `_WeightLineChart`: cambia su parámetro a `final List<({DateTime date, double kg})> points;` y usa `.kg` donde hoy usa `.maxWeightKg`. Ningún otro cambio visual. Renombrar la clase a `_ProgressLineChart` (ya no grafica solo peso).

### test/core/one_rep_max_test.dart (nuevo)
- `epleyOneRepMax(100, 1) == 100`
- `epleyOneRepMax(100, 10)` ≈ `133.33` (`closeTo(133.333, 0.001)`)
- `epleyOneRepMax(80, 12)` ≈ `112.0`
- `epleyOneRepMax(80, 0) == null`, `epleyOneRepMax(80, 13) == null`, `epleyOneRepMax(80, -1) == null`

### test/services/one_rep_max_history_test.dart (nuevo)
- `setUpAll`: `sqfliteFfiInit(); databaseFactory = databaseFactoryFfi; await databaseFactory.setDatabasesPath((await Directory.systemTemp.createTemp('gym_1rm_test_')).path);` (la carpeta propia evita choques con otros tests en paralelo).
- Escenario con el ejercicio id 1 (viene del seed), usando `SessionService` para sembrar:
  - Día 2026-02-01: (100×1), (90×5), (60×20) → máximo = 105.0 (90×5); 100×1 = 100; 60×20 se ignora.
  - Día 2026-02-03: solo (50×15) → el día se omite.
  - Día 2026-02-05: (80×10) → 106.667.
  - Una serie con `reps` nulo y una con `weight_kg` nulo → ignoradas.
- Esperado: 2 puntos, en orden, con fechas 01 y 05 y valores `closeTo(105.0, 0.001)` y `closeTo(106.667, 0.001)`.

## 5. Contratos y tipos clave
- `epleyOneRepMax` es pura y total: nunca lanza; devuelve `null` fuera de rango.
- `estimatedOneRepMaxHistory` está ordenado por fecha ascendente, con un punto por día calendario y sin días vacíos.
- Errores: no se captura nada nuevo.

## 6. Orden de construcción
| Fase | Carril | Qué se construye | Modelo | Archivos propios | Cómo se verifica al terminar |
|---|---|---|---|---|---|
| 1 | — | `one_rep_max.dart` + `test/core/one_rep_max_test.dart` | Haiku | esos 2 archivos | `flutter test test/core` en verde |
| 2 | — | `estimatedOneRepMaxHistory` + su test | Haiku | `lib/services/statistics_service.dart`, `test/services/one_rep_max_history_test.dart` | `flutter test` en verde |
| 3 | — | UI: enum, estado, selector, chips, `_ProgressLineChart` | Haiku | `lib/screens/stats/stats_screen.dart` | `flutter analyze` sin issues; `flutter test` en verde |

Un commit por fase (`feat: función de 1RM estimado (Epley)`, `feat: historial de 1RM estimado por día`, `feat: selector Peso máx / 1RM est. en progreso`), más el trailer de coautoría del entorno. **No hacer push.**

Nota de entorno: Flutter no está en el PATH de los shells nuevos. Usa PowerShell con `$env:Path += ';C:\Users\LiaN\dev\flutter\bin'`.

## 7. Criterios de aceptación
- [ ] Los 6 casos de `one_rep_max_test.dart` pasan.
- [ ] El test de historial devuelve exactamente los 2 puntos esperados.
- [ ] `maxWeightHistory` y `personalRecords` no cambiaron (`git diff` solo agrega en `statistics_service.dart`).
- [ ] `grep -n "maxWeightKg" lib/screens/stats/stats_screen.dart` solo aparece en el mapeo de `_exerciseHistory` a `points` y en los chips de `maxWeight`, no en el widget de la gráfica.
- [ ] `flutter analyze` sin issues y `flutter test` en verde.
- [ ] Prueba manual (la hace el usuario después de integrar): en Stats, cambiar entre "Peso máx." y "1RM est." cambia la gráfica y los chips.

## 8. Anti-instrucciones (NO hacer)
- NO agregar dependencias.
- NO crear clases, servicios ni archivos fuera de los listados.
- NO modificar `maxWeightHistory`, `personalRecords` ni ningún otro método existente del servicio.
- NO cambiar colores, ejes, tooltips ni tamaños de la gráfica.
- NO usar bools para la métrica: usar `_ProgressMetric`.
- NO tocar archivos fuera de los listados en §6.
- NO hacer push.

## 9. Escalación
Si una decisión no está cubierta por esta spec: NO improvises arquitectura.
- Decisión grande: detente y pregunta.
- Decisión menor: resuélvela de la forma más simple y márcala `// TODO-ARQUITECTO: [decisión + propuesta]`.
- Al reportar, lista los `TODO-ARQUITECTO` y los `TF-TECHO`.
