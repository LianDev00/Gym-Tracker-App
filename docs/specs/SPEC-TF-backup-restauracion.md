SPEC-TF v1 — Gym-Tracker: backup y restauración

## 0. Metadatos
- Proyecto: Gym-Tracker-App
- Fecha: 2026-10-19
- Stack: Flutter 3.47 / Dart 3.13, `sqflite`. Dependencia nueva: `file_picker` (la agrega la fase 2 con `flutter pub add file_picker`). Tests con `flutter_test` + `sqflite_common_ffi` (ya en dev_dependencies).
- Modelo destino: Sonnet 5.5.
- Origen: revisión de UX. `ExportService` existe, pero ninguna pantalla lo usa.
- Rama/worktree: `feat/backup` en `..\Gym-Tracker-worktrees\backup`.

## 1. Contexto y objetivo
Todos los datos de la app viven solo en el SQLite local: perder o formatear el celular, o desinstalar la app, borra todo el historial. Existe `lib/services/export_service.dart`, pero tiene tres defectos: (1) no exporta la tabla `exercise_muscles` y al importar la vacía (por el `ON DELETE CASCADE` desde `exercises`), así que se pierden las asignaciones musculares; (2) escribe el archivo en el directorio privado de la app, que el usuario no puede ver y que se borra al desinstalar; (3) no hay UI. **Objetivo:** que el usuario pueda exportar un backup completo a un archivo donde él elija (Descargas, Drive, etc.) y restaurarlo después, sin perder datos y sin dejar la BD a medias si el archivo es inválido.

## 2. Alcance y NO-alcance
### Dentro del alcance
- Corregir y rehacer `ExportService` como serialización pura de la BD (string JSON ↔ BD), con versión de esquema y validación.
- Una pantalla de backup accesible desde Home, con "Exportar" y "Restaurar".
- Guardar y elegir el archivo con `file_picker` (el diálogo nativo del sistema).
- Tests de ida y vuelta, de rechazo y de atomicidad.
### Fuera del alcance (prohibido construir)
- Backup automático o programado, recordatorios de backup o la fecha del "último backup".
- Sincronización en la nube, cuentas de usuario o integraciones con Google Drive (el diálogo del sistema ya permite elegir Drive).
- Cifrado o contraseña del backup.
- Restauración parcial o fusión de datos (solo se reemplaza todo).
- Migrar backups de otras versiones de esquema: un backup con `schemaVersion` distinto se rechaza.
- Compatibilidad con el formato JSON viejo de `exportToJson()`: nadie pudo acceder a esos archivos.
- Compartir con `share_plus` u otros paquetes de compartir.
- Tocar `session_screen.dart`, `stats_screen.dart`, `statistics_service.dart`, `session_service.dart` o `android/`.
- Ejecutar `flutter build apk` (la build Android la valida el Arquitecto al integrar, para no correr dos Gradle a la vez en una máquina de 16 GB).

## 3. Decisiones de arquitectura
| # | Decisión | Porqué | Alternativa descartada y por qué |
|---|---|---|---|
| 1 | `BackupService` trabaja con **strings**, no con archivos: `buildBackupJson()` / `restoreFromJson(String)`. La E/S de archivos vive en la pantalla | Núcleo testeable sin sistema de archivos ni plugins; el plugin queda en el borde | Que el servicio llame a `file_picker`: acopla el servicio a un plugin de UI y lo vuelve intesteable |
| 2 | `file_picker` para guardar (`saveFile` con `bytes`) y abrir (`pickFiles` con `withData: true`) | Una sola dependencia cubre las dos direcciones con el diálogo nativo (SAF en Android); el usuario elige Descargas, Drive, etc. | `share_plus` + `file_picker`: dos dependencias. Escribir en Descargas a mano: requiere permisos y difiere por versión de Android |
| 3 | Formato con envoltorio: `{"app":"gym_tracker","schemaVersion":<int>,"exportedAt":"<iso8601>","tables":{<tabla>:[filas]}}` | Permite rechazar archivos ajenos o de otra versión **antes** de tocar la BD | JSON plano de tablas (el formato actual): no se puede validar la versión |
| 4 | Validar todo el documento antes de abrir la transacción, y restaurar dentro de **una** transacción | Un archivo inválido nunca borra datos; un fallo a mitad hace rollback | Validar durante la inserción: el error llega después de borrar |
| 5 | Renombrar `ExportService` → `BackupService` (archivo `backup_service.dart`) | El nuevo contrato es backup/restore de strings; el nombre viejo miente sobre lo que hace | Mantener el nombre: confunde con el contrato viejo basado en archivos |
| 6 | Tras restaurar, `Navigator.pushAndRemoveUntil` a una `MainNavigation` nueva | Las pantallas viven en un `IndexedStack` y no recargan solas; recrear la navegación hace que todas vuelvan a leer la BD | Notificadores globales de "datos cambiados" en cada pantalla: toca todas las pantallas (fuera de alcance) |
| 7 | En los tests, cada archivo usa una carpeta temporal propia para la BD (`databaseFactory.setDatabasesPath`) | `flutter test` corre los archivos en paralelo y `DatabaseHelper` usa un nombre fijo: sin esto, los tests se pisan | `--concurrency=1`: hace más lenta toda la suite y depende de que alguien recuerde el flag |

## 4. Mapa de módulos

### lib/services/backup_service.dart (reemplaza a export_service.dart)
- Responsabilidad: serializar y deserializar la BD completa.
- Interfaz pública:
  ```dart
  /// Error de formato o de versión del backup. [message] se muestra al usuario.
  class BackupFormatException implements Exception {
    const BackupFormatException(this.message);
    final String message;
    @override
    String toString() => 'BackupFormatException: $message';
  }

  class BackupService {
    BackupService._();
    static final BackupService instance = BackupService._();

    /// JSON con todas las tablas de usuario y metadatos de versión.
    Future<String> buildBackupJson();

    /// Valida [json] completo y, si es válido, reemplaza TODOS los datos en una
    /// transacción. Lanza [BackupFormatException] sin tocar la BD si el
    /// documento no es un backup de esta app o es de otra versión de esquema.
    Future<void> restoreFromJson(String json);
  }
  ```
- Tablas, en **orden de inserción** (FK-safe). El orden de borrado es el inverso:
  `tExercises, tExerciseMuscles, tRoutines, tRoutineExercises, tSessions, tSessionExercises, tSessionSets, tBodyEntries, tBodyMeasurements`. Definirlo una sola vez como `static const _tablesInInsertOrder = [...]` y usar `.reversed` para borrar.
- Validación (en orden; cada fallo lanza `BackupFormatException` con un mensaje en español para el usuario):
  1. `jsonDecode` falla → "El archivo no es un JSON válido." (capturar `FormatException` y relanzar como `BackupFormatException`).
  2. La raíz no es `Map` o `app != 'gym_tracker'` → "El archivo no es un backup de Gym Tracker."
  3. `schemaVersion != DbConstants.dbVersion` → "Backup de otra versión de la app (esquema X, se esperaba Y)."
  4. `tables` no es `Map`, falta alguna de las 9 tablas, alguna no es `List` o alguna fila no es `Map` → "El backup está incompleto o dañado."
- `buildBackupJson`: `JsonEncoder.withIndent('  ')`; `exportedAt = DateTime.now().toIso8601String()`.
- `restoreFromJson`: dentro de `db.transaction`, borrar en orden inverso e insertar con `txn.insert(table, Map<String, Object?>.from(row))` **sin** `conflictAlgorithm` (después del borrado no puede haber conflictos; si los hay, el archivo está dañado y debe fallar). Las excepciones de sqflite se propagan sin capturar (rollback).
- Dependencias permitidas: `dart:convert`, `sqflite`, `db_constants.dart`, `database_helper.dart`.
- Esconde: el formato, el orden FK y la validación.
- `lib/services/export_service.dart` se **borra** (`git rm`). Antes, confirmar con `grep -rn ExportService lib test` que no tiene usos.

### lib/screens/backup/backup_screen.dart (nuevo)
- Responsabilidad: la UI de exportar y restaurar, y la E/S de archivos.
- Interfaz pública: `class BackupScreen extends StatefulWidget { const BackupScreen({super.key}); }`
- Contenido: `Scaffold` con `AppBar(title: Text('Backup'))` y un cuerpo con dos `GlassCard` (de `core/theme/glass_kit.dart`), igual que las demás pantallas:
  1. **Exportar**: texto "Guarda una copia de todos tus datos en un archivo." y un `NeonButton(label: 'Exportar backup', icon: Icons.upload_file_rounded)`. Al tocarlo: `json = await BackupService.instance.buildBackupJson()` y luego `await FilePicker.platform.saveFile(dialogTitle: 'Guardar backup', fileName: 'gym_tracker_backup_${yyyy-MM-dd}.json', type: FileType.custom, allowedExtensions: ['json'], bytes: utf8.encode(json))`. Si devuelve `null` (el usuario canceló), no mostrar nada; si no, `SnackBar('Backup guardado')`. Formatear la fecha con `DateFormat('yyyy-MM-dd')` de `intl` (ya instalada).
  2. **Restaurar**: texto "Reemplaza TODOS tus datos actuales por los del archivo." y un `NeonButton(label: 'Restaurar backup', icon: Icons.restore_rounded, color: <color de error del tema>)`. Al tocarlo: `pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true)`; si se cancela, no hacer nada. Luego mostrar un `AlertDialog` de confirmación ("¿Reemplazar todos tus datos? Esta acción no se puede deshacer.", con "Cancelar" y un `FilledButton` "Restaurar"). Si se confirma: `restoreFromJson(utf8.decode(file.bytes!))`, y después `Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const MainNavigation()), (_) => false)` y `SnackBar('Datos restaurados')`.
- Errores: capturar **solo** `BackupFormatException` y mostrarla en un `SnackBar` con `e.message`. Cualquier otra excepción se propaga (no tragar). Mientras una operación corre, `_busy = true` y ambos handlers retornan de inmediato si `_busy` es verdadero. `NeonButton.onPressed` no acepta `null`, así que no se le pasa `null`: se pone el guard al inicio del handler y se envuelve el `try` en `finally { if (mounted) setState(() => _busy = false); }`.
- `if (!mounted) return;` después de cada `await` antes de usar `context`.
- Dependencias permitidas: `dart:convert`, `flutter/material`, `file_picker`, `intl`, `backup_service.dart`, `core/theme/*`, `../../main.dart` (solo por `MainNavigation`).

### lib/screens/home/home_screen.dart
- Cambio único: en `AppBar.actions`, **antes** del `IconButton` de refrescar, agregar `IconButton(icon: const Icon(Icons.settings_backup_restore_rounded, color: AppColors.muted), tooltip: 'Backup', onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BackupScreen())))`.

### pubspec.yaml / pubspec.lock
- Solo lo que agregue `flutter pub add file_picker`.

### test/services/backup_service_test.dart (nuevo)
- `setUpAll`: `sqfliteFfiInit(); databaseFactory = databaseFactoryFfi; final dir = await Directory.systemTemp.createTemp('gym_backup_test_'); await databaseFactory.setDatabasesPath(dir.path);`.
- Siembra con los servicios existentes: 1 ejercicio custom con 2 músculos (`ExerciseService` y su método de músculos; ver la firma real en `exercise_service.dart`), 1 rutina con 2 ejercicios (`RoutineService`), 3 sesiones con ejercicios y series (`SessionService`), 1 `body_entry`. Si un servicio de siembra no existe para alguna tabla, insertar con `db.insert`.
- Helper del test: `Future<Map<String, List<Map<String, Object?>>>> dumpAll()`, que hace `db.query(t, orderBy: 'id')` para las 9 tablas. Las 9 tablas tienen PK `id`: verificarlo en el DDL; si alguna no la tiene, `TODO-ARQUITECTO`.

## 5. Contratos y tipos clave
- **Ida y vuelta:** `dumpAll()` después de `restoreFromJson(await buildBackupJson())` es igual a `dumpAll()` antes, incluso si entre medio se borraron o agregaron datos.
- **Atomicidad:** si `restoreFromJson` lanza (por formato o por sqflite), `dumpAll()` queda igual que antes de llamarlo.
- **Errores:** `BackupFormatException` es el único tipo que la UI captura y muestra. Las excepciones de sqflite o del plugin se propagan.

## 6. Orden de construcción
| Fase | Carril | Qué se construye | Modelo | Archivos propios | Cómo se verifica al terminar |
|---|---|---|---|---|---|
| 1 | — | `backup_service.dart` + `BackupFormatException` + tests (ida y vuelta, `exercise_muscles` incluida, los 4 rechazos sin tocar la BD, atomicidad con una fila corrupta como `{"id": "x"}` en `session_sets`); `git rm export_service.dart` | Sonnet | `lib/services/backup_service.dart`, `lib/services/export_service.dart`, `test/services/backup_service_test.dart` | `flutter test` en verde; `flutter analyze` sin issues |
| 2 | — | `flutter pub add file_picker`; `backup_screen.dart`; botón en Home | Sonnet | `pubspec.yaml`, `pubspec.lock`, `lib/screens/backup/backup_screen.dart`, `lib/screens/home/home_screen.dart` | `flutter analyze` sin issues; `flutter test` en verde |

Un commit por fase: `feat: BackupService con versión de esquema y exercise_muscles` y `feat: pantalla de backup y restauración`, más el trailer de coautoría del entorno. **No hacer push.**

Nota de entorno: Flutter no está en el PATH de los shells nuevos. Usa PowerShell con `$env:Path += ';C:\Users\LiaN\dev\flutter\bin'`.

## 7. Criterios de aceptación
- [ ] Ida y vuelta: el test compara las 9 tablas, incluida `exercise_muscles`, y pasa.
- [ ] Archivo no-JSON, `app` distinto, `schemaVersion` distinto y tabla faltante: cada uno lanza `BackupFormatException` con su mensaje y la BD no cambia (test).
- [ ] Una fila corrupta en una tabla tardía (`session_sets`) hace rollback completo (test).
- [ ] `export_service.dart` ya no existe y `grep -rn ExportService lib test` no devuelve nada.
- [ ] Home tiene el botón "Backup" que abre `BackupScreen`.
- [ ] `flutter analyze` sin issues y `flutter test` en verde.
- [ ] Prueba manual (la hace el usuario después de integrar): exportar a Descargas, borrar una sesión, restaurar, y ver la sesión de vuelta en historial y estadísticas.

## 8. Anti-instrucciones (NO hacer)
- NO agregar dependencias fuera de `file_picker`.
- NO pedir permisos de almacenamiento ni tocar `AndroidManifest.xml`: `file_picker` con SAF no los necesita.
- NO crear repositorios, interfaces, DTOs ni clases de modelo para el backup: son `Map`s de filas.
- NO usar `ConflictAlgorithm.replace` en la restauración.
- NO capturar `Exception`/`Object` genéricos en la pantalla: solo `BackupFormatException`.
- NO tocar archivos fuera de los listados en §6.
- NO ejecutar `flutter build apk`.
- NO hacer push.

## 9. Escalación
Si una decisión no está cubierta por esta spec: NO improvises arquitectura.
- Si la API de `file_picker` instalada difiere de la descrita (ej. `saveFile` sin parámetro `bytes`), detente y reporta la firma real: es una decisión de borde.
- Decisión menor: resuélvela de la forma más simple y márcala `// TODO-ARQUITECTO: [decisión + propuesta]`.
- Al reportar, lista los `TODO-ARQUITECTO` y los `TF-TECHO`.
