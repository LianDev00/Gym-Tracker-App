SPEC-TF v1 — Gym-Tracker: rendimiento de queries y renders

## 0. Metadatos
- Proyecto: Gym-Tracker-App (`C:\Users\LiaN\Desktop\Proyectos\Gym-Tracker-App`)
- Fecha: 2026-10-19
- Stack: Flutter 3.47 (stable) / Dart 3.13, `sqflite ^2.3.3` (SQLite local, sin servidor), Android/iOS. Tests con `flutter_test`, más `sqflite_common_ffi` (se agrega en la fase 1, solo como dev dependency).
- Modelo destino: Claude Code con Sonnet 5.5 por defecto. El reparto por fase está en §6.
- Origen: plan aprobado `~/.claude/plans/zippy-knitting-pinwheel.md`, que evaluó una checklist web de 5 optimizaciones contra este código.
- Rama: `perf/queries-y-renders`, creada desde `chore/tests-y-avisos`.

## 1. Contexto y objetivo
Gym-Tracker es una app personal de registro de gimnasio con SQLite local. A medida que se acumula historial, tres pantallas hacen consultas N+1: el historial hace 1 query por sesión y 1 por ejercicio cada vez que carga o cambia de mes; abrir una sesión hace 1 query por ejercicio; home hace 1 `getById` por ejercicio. Además no existe ningún índice sobre las claves foráneas. La pantalla de sesión llama a `setState` por cada ejercicio y por cada serie al cargar o al agregar una rutina. El historial construye todas sus tarjetas de golpe, y el APK incluye dos PNG que la app no usa en tiempo de ejecución. **Objetivo:** que el número de queries por pantalla sea constante (no dependa del tamaño del historial), un rebuild por operación de carga, una lista perezosa y un bundle más liviano, **sin cambiar ningún comportamiento visible**.

## 2. Alcance y NO-alcance
### Dentro del alcance
- Índices SQLite sobre FKs y fecha, más la migración de BD v7 → v8.
- Dos métodos de lectura por lote y un método de escritura transaccional en `SessionService`.
- Usar esos métodos en `history_screen.dart`, `session_screen.dart` y `home_screen.dart`.
- Un solo `setState` en la carga de sesión y al agregar ejercicio o rutina.
- Lista perezosa (slivers) en el historial.
- Sacar del bundle los PNG que solo usan los generadores, y `cacheWidth` en el logo del splash.
- Tests de los nuevos métodos y de los índices.
### Fuera del alcance (prohibido construir)
- Cualquier caché en memoria de resultados (de servicios, de pantallas o de `ExerciseService.getAll`). La caché de páginas de SQLite basta, y una caché propia trae bugs de invalidación.
- Paginación o carga infinita del historial. La lista perezosa basta por ahora.
- Gestión de estado nueva (Provider, Riverpod, Bloc, `ValueNotifier` por serie, etc.).
- Dividir `session_screen.dart`, `stats_screen.dart` u otros archivos en archivos más chicos.
- Tocar `StatisticsService` o sus queries (ya usan agregados SQL).
- Índice extra en `exercise_muscles`: ya existe, por la restricción `UNIQUE(exercise_id, muscle_group)`.
- Índices en `body_entries`, `body_measurements` o `routines`.
- Arreglar la carrera que existe hoy al cambiar de día mientras carga una sesión.
- Actualizar dependencias de producción, cambiar `pubspec.lock` más allá de lo que agregue la dev dependency, o subir la versión de la app.
- Ejecutar `flutter_launcher_icons` o `flutter_native_splash` (regenerarían recursos nativos; solo cambian sus rutas de entrada).
- Comprimir o redimensionar `logo_GymT.png`.
- Refactors de estilo ("boy scout") fuera de las líneas que esta spec toca.

## 3. Decisiones de arquitectura
| # | Decisión | Porqué | Alternativa descartada y por qué |
|---|---|---|---|
| 1 | Lecturas por lote con `WHERE col IN (?,…)` troceado en grupos de 500 ids, devolviendo `Map<int, List<T>>` que trae **una clave por cada id pedido** (lista vacía si no hay filas) | Las queries pasan a ser constantes; el mapa con todas las claves evita `!`/`??` en cada llamador. 500 queda bajo el límite histórico de 999 variables de SQLite | Un `JOIN` en una sola query que devuelve filas planas: obliga a reagrupar y a mapear columnas con alias en la pantalla, y filtra SQL a la UI |
| 2 | Los métodos uno a uno existentes (`getExercisesForSession`, `getSetsForSessionExercise`) **se mantienen** | Tienen otros usos (`grep` antes de tocarlos); además el test de equivalencia los usa como oráculo | Borrarlos o reimplementarlos sobre el lote: cambia un contrato usado en otras partes sin ganancia |
| 3 | `insertExercisesWithSets` en `SessionService` hace en **una transacción** los inserts de N ejercicios con sus series vacías | Agregar una rutina de 6 ejercicios hoy son 24 escrituras sueltas: si la app muere a la mitad, la sesión queda a medias. La transacción da atomicidad y velocidad. Un solo método sirve para agregar 1 ejercicio y para agregar una rutina | Envolver la transacción en la pantalla: mete `Transaction` de sqflite en la UI y rompe la capa de servicios |
| 4 | Los índices se crean en `_createIndexes(DatabaseExecutor db)`, llamado al final de `_onCreate` y en `if (oldVersion < 8)`, con `CREATE INDEX IF NOT EXISTS` | Un único lugar con el conocimiento de los índices (instalaciones nuevas y migradas quedan iguales); `IF NOT EXISTS` lo vuelve idempotente | Repetir los `CREATE INDEX` en los dos sitios: dos fuentes de verdad que se desincronizan |
| 5 | En la pantalla de sesión, armar la lista local y luego hacer **un** `setState` con todo | Elimina decenas de rebuilds de una pantalla de 1300 líneas; el cambio de código es mínimo y local | `ValueNotifier`/`ListenableBuilder` por ejercicio: es gestión de estado nueva, fuera de alcance |
| 6 | Historial con `CustomScrollView` + `SliverToBoxAdapter` (encabezados) + `SliverList.builder` (tarjetas) | Construye solo las tarjetas visibles; los slivers dicen la estructura sin aritmética de índices; `RefreshIndicator` sigue funcionando sobre `CustomScrollView` | `ListView.builder` con offsets de índice para los 3 encabezados: aritmética frágil |
| 7 | `logo_splash.png` se borra (es idéntico byte a byte a `logo_GymT.png`) y `logo_GymT_padded.png` se mueve a `assets/branding/`, que no está declarado en `flutter: assets:` | Los generadores leen rutas del disco, no del bundle; la app nunca carga esos dos archivos. Se ahorran unos 860 KB | Declarar archivo por archivo en `flutter: assets:`: más frágil cuando se agreguen imágenes |
| 8 | Tests de BD con `sqflite_common_ffi` y `databaseFactory = databaseFactoryFfi` contra el `DatabaseHelper` real | Prueba el esquema y la migración reales sin dispositivo | Mocks del `Database`: probarían la implementación, no el comportamiento |

## 4. Mapa de módulos

### lib/core/constants/db_constants.dart
- Responsabilidad: nombres de tablas y columnas, y versión de la BD.
- Interfaz pública: `static const int dbVersion = 8;` (antes 7). No agregar constantes para nombres de índices; viven solo en `database_helper.dart`.
- Dependencias permitidas: ninguna nueva.
- Esconde: N/A.

### lib/core/database/database_helper.dart
- Responsabilidad: esquema y migraciones de SQLite.
- Interfaz pública: sin cambios. Se agrega el método privado `Future<void> _createIndexes(DatabaseExecutor db)`.
- Dependencias permitidas: `sqflite`, `db_constants.dart` (igual que hoy).
- Esconde: los 4 índices, con estos nombres exactos:
  ```sql
  CREATE INDEX IF NOT EXISTS idx_session_exercises_session ON session_exercises(session_id)
  CREATE INDEX IF NOT EXISTS idx_session_sets_session_exercise ON session_sets(session_exercise_id)
  CREATE INDEX IF NOT EXISTS idx_sessions_date ON sessions(date)
  CREATE INDEX IF NOT EXISTS idx_routine_exercises_routine ON routine_exercises(routine_id)
  ```
  Tablas y columnas siempre vía `DbConstants` (`tSessionExercises`/`cSxSessionId`, `tSessionSets`/`cSsSessionExerciseId`, `tSessions`/`cSeDate`, `tRoutineExercises`/`cReRoutineId`), igual que el DDL actual.
  - `_onCreate`: `await _createIndexes(db);` después de los `CREATE TABLE` y antes de los seeds.
  - `_onUpgrade`: un bloque nuevo al final `if (oldVersion < 8) { await _createIndexes(db); }` con un comentario de una línea con el porqué ("índices sobre FKs: evitan full scans en historial/sesión").

### lib/services/session_service.dart
- Responsabilidad: acceso a datos de sesiones, ejercicios de sesión y series.
- Interfaz pública (se **agregan** los tres métodos; nada existente cambia):
  ```dart
  /// Ejercicios de varias sesiones en pocas queries (evita N+1).
  /// Devuelve una clave por cada id de [sessionIds] (lista vacía si no tiene),
  /// cada lista en el mismo orden que [getExercisesForSession].
  Future<Map<int, List<SessionExercise>>> getExercisesForSessions(List<int> sessionIds);

  /// Series de varios ejercicios de sesión en pocas queries (evita N+1).
  /// Misma garantía de claves y orden que [getSetsForSessionExercise].
  Future<Map<int, List<SessionSet>>> getSetsForSessionExercises(List<int> sessionExerciseIds);

  /// Inserta en UNA transacción un SessionExercise por cada id de [exerciseIds]
  /// (exercise_order = startOrder, startOrder+1, …) y, para cada uno,
  /// [setsPerExercise] series vacías numeradas 1..setsPerExercise.
  /// Devuelve los registros insertados (con id) en el mismo orden de [exerciseIds].
  Future<List<({SessionExercise sessionExercise, List<SessionSet> sets})>>
      insertExercisesWithSets({
    required int sessionId,
    required List<int> exerciseIds,
    required int startOrder,
    required int setsPerExercise,
  });
  ```
- Detalle de implementación obligatorio:
  - Lote vacío → devolver `{}` sin tocar la BD. Ids duplicados en la entrada → deduplicar antes de consultar.
  - Troceo: `for (var i = 0; i < ids.length; i += 500) ids.sublist(i, min(i + 500, ids.length))`. Placeholders con `List.filled(chunk.length, '?').join(',')`.
  - `orderBy`: el mismo que el método uno a uno (`DbConstants.cSxOrder` y `DbConstants.cSsSetNumber`). La agrupación recorre las filas en el orden devuelto y hace `map[key]!.add(...)`, así cada lista conserva el orden.
  - Mapa inicializado con `{for (final id in uniqueIds) id: <T>[]}`.
  - `insertExercisesWithSets`: `db.transaction((txn) async { … txn.insert … })`, usando `SessionExercise.copyWith(id:)` y `SessionSet.copyWith(id:)` como hoy. `assert(setsPerExercise >= 0)`.
  - Una constante privada `static const _inChunkSize = 500;` con el comentario `// límite histórico de SQLite: 999 variables por statement`.
- Dependencias permitidas: `sqflite`, `dart:math` (`min`), `db_constants.dart`, `database_helper.dart` y los modelos actuales.
- Esconde: el troceo, la agrupación y la transacción.

### lib/screens/history/history_screen.dart
- Responsabilidad: mostrar la racha, el calendario y la lista de sesiones.
- Cambios:
  1. En `_load()`, reemplazar el bloque `Future.wait(sessions.map(...))` por:
     ```dart
     final seBySession = await _sessionService
         .getExercisesForSessions([for (final s in sessions) s.id!]);
     final setsBySe = await _sessionService.getSetsForSessionExercises(
         [for (final list in seBySession.values) for (final se in list) se.id!]);
     final summaries = [
       for (final session in sessions)
         _SessionSummary(
           session: session,
           exerciseData: [
             for (final se in seBySession[session.id!]!)
               _ExerciseData(
                 name: exerciseMap[se.exerciseId]?.name ?? '?',
                 sets: setsBySe[se.id!]!
                     .map((s) => _SetData(weightKg: s.weightKg, reps: s.reps, rir: s.rir))
                     .where((s) => s.hasData)
                     .toList(),
               ),
           ],
         ),
     ];
     ```
     El resto de `_load` (racha, días del mes, `setState`) queda igual.
  2. En `build`, reemplazar el `ListView(children: …)` dentro del `RefreshIndicator` por un `CustomScrollView` con: `SliverToBoxAdapter` para `_StreakBanner`, `_CalendarCard` y el título "Sesiones" (los tres en una `Column` o en tres adapters, da igual); después, `SliverToBoxAdapter(child: _EmptyState())` si `_summaries.isEmpty`, o `SliverList.builder(itemCount: _summaries.length, itemBuilder: …_SessionCard…)`; al final, `SliverPadding(padding: EdgeInsets.only(bottom: 100), sliver: SliverToBoxAdapter(child: SizedBox(height: 24)))`. Se mantienen los mismos widgets, márgenes y callbacks (`onDelete: () => _deleteSession(s.session)`), y `physics: const AlwaysScrollableScrollPhysics()` para que el pull-to-refresh funcione con la lista vacía.
- Dependencias permitidas: las actuales.
- Esconde: N/A.

### lib/screens/session/session_screen.dart
- Responsabilidad: registrar la sesión del día seleccionado.
- Cambios:
  1. `_loadExistingSession`: conservar el primer `setState` (limpiar y asignar `_sessionId`, para que la UI muestre el vacío al cambiar de día). Luego:
     - `seList` (igual que hoy), `exerciseMap` (igual), `setsBySe = await _sessionService.getSetsForSessionExercises([for (final se in seList) se.id!])`.
     - Armar `final loaded = <_ExerciseEntry>[];` recorriendo `seList` y construyendo cada `_ExerciseEntry` con sus `_SetEntry` (texto de controllers y `_setupListeners` igual que hoy), **sin `setState`**.
     - Ejercicio sin series en BD: insertar la serie vacía con `_sessionService.insertSet(SessionSet(sessionExerciseId: se.id!, setNumber: 1))` y agregarla a `entry.sets` localmente. Este es el comportamiento actual de `_addSet`, pero sin su `setState`.
     - Al final: `if (!mounted) { for (final e in loaded) for (final s in e.sets) s.dispose(); return; }` y luego `setState(() => _entries.addAll(loaded));` y `_loadWeekSessions();`.
  2. `_addExercise(Exercise exercise)` y `_addRoutine(Routine routine)` usan un helper privado nuevo:
     ```dart
     Future<void> _addExercises(List<Exercise> exercises) async
     ```
     que llama `_ensureSession()`, luego `insertExercisesWithSets(sessionId: …, exerciseIds: [for (final e in exercises) e.id!], startOrder: _entries.length, setsPerExercise: 3)`, construye los `_ExerciseEntry`/`_SetEntry` (con `_setupListeners`) y hace **un** `setState(() => _entries.addAll(nuevos))`. `_addExercise(e)` pasa a ser `_addExercises([e])`. `_addRoutine` arma la lista filtrando los `exerciseMap[re.exerciseId]` nulos, igual que hoy, y llama `_addExercises(lista)` una sola vez (si la lista está vacía, retorna sin crear la sesión).
     - La constante `3` lleva el comentario `// 3 series por defecto (decisión de producto, ver README)`.
  3. `_addSet` (el botón "agregar serie") **no cambia**.
- Dependencias permitidas: las actuales.
- Esconde: N/A.

### lib/screens/home/home_screen.dart
- Cambio: en el bloque de `lastSession`, reemplazar `Future.wait(ses.map((se) => _exerciseService.getById(se.exerciseId)))` por `final exerciseMap = {for (final e in await _exerciseService.getAll()) e.id!: e};` y `lastExercises = [for (final se in ses) if (exerciseMap[se.exerciseId] case final e?) e];`. Mismo resultado y mismo orden.

### lib/screens/splash/splash_screen.dart
- Cambio: en el `Image.asset('assets/images/logo_GymT.png', …)` agregar `cacheWidth: (160 * MediaQuery.devicePixelRatioOf(context)).round(),`. No agregar `cacheHeight` (se conserva la proporción).

### pubspec.yaml y assets/
- `git rm assets/images/logo_splash.png`.
- `git mv assets/images/logo_GymT_padded.png assets/branding/logo_GymT_padded.png`.
- En `pubspec.yaml`:
  - `flutter_launcher_icons.adaptive_icon_foreground` → `assets/branding/logo_GymT_padded.png`.
  - `flutter_native_splash.image` e `image_dark` → `assets/images/logo_GymT.png`.
  - `flutter_native_splash.android_12.image` e `image_dark` → `assets/branding/logo_GymT_padded.png`.
  - `flutter: assets:` sigue siendo solo `- assets/images/`.
  - En `dev_dependencies`: `sqflite_common_ffi` (lo agrega la fase 1 con `flutter pub add --dev sqflite_common_ffi`).

### test/services/session_service_batch_test.dart (nuevo)
- Responsabilidad: verificar índices, lotes y transacción contra SQLite real (ffi).
- Setup: `sqfliteFfiInit(); databaseFactory = databaseFactoryFfi;` en `setUpAll`. Antes de la primera apertura, `await databaseFactory.deleteDatabase(join(await getDatabasesPath(), DbConstants.dbName));`. Se usa siempre `DatabaseHelper.instance` y `SessionService.instance` (los singletons reales).
- Siembra: 50 sesiones (`SessionService.insert`), cada una con de 0 a 4 ejercicios (`insertSessionExercise`, `exerciseOrder` = índice único dentro de la sesión, `exerciseId` de 1 a 10, que existen por el seed), cada uno con de 0 a 4 series (`insertSet`, `setNumber` 1..n). Usar un patrón determinista basado en el índice (ej. `i % 5`), **no `Random`**.

## 5. Contratos y tipos clave
- **Garantía de claves:** para todo id `x` en la entrada, `result.containsKey(x)` es verdadero. Los llamadores **pueden** usar `result[x]!`.
- **Garantía de orden:** `result[x]` es igual, elemento por elemento (comparando `toMap()`), a `getExercisesForSession(x)` / `getSetsForSessionExercise(x)`.
- **Transaccionalidad:** si cualquier insert de `insertExercisesWithSets` falla, la excepción de sqflite se propaga sin capturar y no queda ninguna fila insertada de esa llamada. No se captura nada en el servicio ni en la pantalla, igual que hoy, donde los errores de BD tampoco se capturan.
- **Tipo de retorno de escritura:** el record `({SessionExercise sessionExercise, List<SessionSet> sets})`. No crear una clase para esto.
- **Esquema:** `PRAGMA user_version` = 8 tras abrir. Los cuatro índices de §4 existen tanto en instalación nueva como en migración desde la v7.

## 6. Orden de construcción
| Fase | Carril | Qué se construye | Modelo | Archivos propios | Cómo se verifica al terminar |
|---|---|---|---|---|---|
| 1 | — | Dev dependency `sqflite_common_ffi`; `dbVersion = 8`; `_createIndexes` en `_onCreate` y `_onUpgrade`; test "índices existen" (`PRAGMA index_list` sobre las 4 tablas) y "user_version == 8" | Haiku | `db_constants.dart`, `database_helper.dart`, `pubspec.yaml`, `pubspec.lock`, `test/services/session_service_batch_test.dart` | `flutter test` en verde; `flutter analyze` sin issues. **Si ffi no carga SQLite en Windows (falta `sqlite3.dll`), detente y escala; no agregues otra dependencia.** |
| 2 | — | `getExercisesForSessions`, `getSetsForSessionExercises` y sus tests: equivalencia con los métodos uno a uno sobre la siembra de 50 sesiones; lote vacío → `{}`; ids sin filas → lista vacía; ids duplicados; lote de 1200 ids existentes o inexistentes (cruza el troceo) | Sonnet | `session_service.dart`, el test | `flutter test` en verde |
| 3 | — | `insertExercisesWithSets` y sus tests: orden de retorno, `exercise_order` consecutivo desde `startOrder`, `setNumber` 1..n; atomicidad (un `exerciseId` inexistente como `999999` con FKs activas debe lanzar, y el conteo de filas de `session_exercises` y `session_sets` queda igual) | Sonnet | `session_service.dart`, el test | `flutter test` en verde |
| 4 | — | `history_screen.dart` (lote + slivers) y `home_screen.dart` | Sonnet | esos dos archivos | `flutter analyze` sin issues; `flutter test` en verde |
| 5 | — | `session_screen.dart` (`_loadExistingSession` con un `setState`; `_addExercises`) | Sonnet | `session_screen.dart` | `flutter analyze` sin issues; `grep -c setState` baja respecto a hoy (18) |
| 6 | — | Assets y `cacheWidth` | Haiku | `pubspec.yaml`, `assets/`, `splash_screen.dart` | `flutter analyze` sin issues; `ls assets/images` muestra solo `logo_GymT.png`; las rutas del pubspec existen en disco |

Un commit por fase, en formato Conventional Commits en español (`perf:`, `test:`, `chore:`), con el trailer de coautoría que indique el entorno. **No hacer push.**

## 7. Criterios de aceptación
- [ ] Dada una BD nueva, al abrirla `PRAGMA user_version` es 8 y existen los 4 índices con los nombres de §4.
- [ ] Revisión de código: `_onUpgrade` tiene un bloque `if (oldVersion < 8)` que llama `_createIndexes`, y todo `CREATE INDEX` usa `IF NOT EXISTS`. (No se testea automáticamente: `_onUpgrade` es privado y el singleton no se puede reabrir; se cubre con la prueba manual de migración de abajo.)
- [ ] Dadas 50 sesiones sembradas, `getExercisesForSessions(todos los ids)` devuelve, para cada id, exactamente la misma lista (`toMap`) que `getExercisesForSession(id)`. Lo mismo para las series.
- [ ] Dado un lote de 1200 ids, los métodos por lote no lanzan errores de "too many SQL variables".
- [ ] Dada una lista vacía, los métodos por lote devuelven `{}`.
- [ ] Dado un `exerciseId` inválido en medio de `insertExercisesWithSets`, se lanza la excepción y el conteo de filas no cambia.
- [ ] `history_screen.dart` no contiene llamadas a `getExercisesForSession(` ni a `getSetsForSessionExercise(`, y no usa `ListView(` con `children:` para la lista de sesiones.
- [ ] En `session_screen.dart`, `_loadExistingSession` contiene exactamente 2 `setState` (limpiar y cargar), y `_addRoutine` no tiene bucles con `await _addExercise`.
- [ ] `home_screen.dart` no llama a `getById(` dentro de un `map`.
- [ ] `assets/images/` contiene solo `logo_GymT.png`; `assets/branding/logo_GymT_padded.png` existe; todas las rutas de imagen en `pubspec.yaml` existen.
- [ ] `flutter analyze` no reporta ningún problema y `flutter test` pasa entero (los 9 tests previos más los nuevos).
- [ ] Prueba manual en dispositivo (la hace el usuario; el Constructor solo la lista en su reporte): historial y cambio de mes; abrir una sesión pasada con datos; agregar un ejercicio; agregar una rutina; borrar una sesión desde el historial; pull-to-refresh con el historial vacío; splash; e instalar sobre la versión anterior (BD v7 con datos) para verificar que la migración conserva todo.

## 8. Anti-instrucciones (NO hacer)
- NO agregar dependencias fuera de `sqflite_common_ffi` (dev).
- NO crear capas, patrones o abstracciones fuera del mapa de módulos: ni repositorios, ni interfaces de servicio, ni clases para el record de retorno, ni helpers genéricos de "batch query" reutilizables entre servicios. Si parece hacer falta → `TODO-ARQUITECTO`.
- NO usar herencia.
- NO capturar excepciones en los métodos nuevos ni en las pantallas tocadas.
- NO implementar nada de la lista "Fuera del alcance" (especialmente caché, paginación y gestión de estado).
- NO borrar ni modificar `getExercisesForSession`, `getSetsForSessionExercise`, `insertSet`, `insertSessionExercise` ni `_addSet`.
- NO cambiar textos, estilos, márgenes, colores ni el orden visual de ningún widget.
- NO usar `Random` en los tests; la siembra es determinista.
- NO usar `rawQuery` con ids interpolados en el string: siempre `?` + `whereArgs`.
- NO poner los nombres de tabla/columna como literales: usar `DbConstants`.
- NO ejecutar los generadores de íconos o splash ni tocar `android/`, `ios/` o `web/`.
- NO hacer push ni abrir un PR.

## 9. Escalación
Si una decisión no está cubierta por esta spec: NO improvises arquitectura.
- Decisión grande (afecta módulos, contratos o dependencias): detente y pregunta al usuario.
- Decisión menor (nombre interno, detalle local): resuélvela de la forma más simple y márcala en el código como `// TODO-ARQUITECTO: [decisión + tu propuesta]`.
- Al reportar el trabajo terminado, lista todos los `TODO-ARQUITECTO` y los `TF-TECHO`.
- Los `TODO-ARQUITECTO` los resuelve el Arquitecto, no un Constructor más capaz.
