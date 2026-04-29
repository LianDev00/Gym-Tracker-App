# Gym Tracker

Aplicación móvil de seguimiento de entrenamiento desarrollada en Flutter. Permite registrar sesiones de gimnasio día a día, consultar el historial completo con detalle de series, y analizar el progreso mediante estadísticas basadas en volumen y RIR.

<p align="center">
  <img src="https://github.com/user-attachments/assets/ae1bdd1c-6063-4d53-ac08-b562567aa03f" height="500" alt="Demo de la app">
</p>

---

## Tecnologías

| Tecnología | Versión | Uso |
|---|---|---|
| [Flutter](https://flutter.dev) | SDK ≥ 3.0 | Framework principal (UI + lógica) |
| [Dart](https://dart.dev) | ≥ 3.0 | Lenguaje de programación |
| [sqflite](https://pub.dev/packages/sqflite) | ^2.3.3 | Base de datos SQLite local |
| [fl_chart](https://pub.dev/packages/fl_chart) | ^0.69.0 | Gráficas de línea (progreso y volumen) |
| [path_provider](https://pub.dev/packages/path_provider) | ^2.1.4 | Acceso al sistema de archivos del dispositivo |
| [path](https://pub.dev/packages/path) | ^1.9.0 | Manejo de rutas de archivos |
| [flutter_native_splash](https://pub.dev/packages/flutter_native_splash) | ^2.4.3 | Pantalla de carga nativa |
| [flutter_launcher_icons](https://pub.dev/packages/flutter_launcher_icons) | ^0.14.3 | Generación de íconos de la app |
| [flutter_body_atlas](https://pub.dev/packages/flutter_body_atlas) | ^0.1.4 | Atlas anatómico SVG interactivo (highlight, tap, hover por músculo) |

---

## Arquitectura

El proyecto sigue una arquitectura en capas simple y directa:

```
lib/
├── core/
│   ├── constants/
│   │   └── db_constants.dart       # Nombres de tablas y columnas (única fuente de verdad)
│   ├── database/
│   │   └── database_helper.dart    # Singleton SQLite: onCreate, onUpgrade, seed
│   └── theme/
│       ├── app_theme.dart          # Tema oscuro, colores, tipografía
│       └── glass_kit.dart          # Widgets reutilizables: GlassCard, NeonIcon, etc.
│
├── models/                         # Entidades de dominio (inmutables, con copyWith/toMap/fromMap)
│   ├── session.dart
│   ├── session_exercise.dart
│   ├── session_set.dart
│   ├── exercise.dart               # Incluye atribución granular Map<MuscleGroup, MuscleRole>
│   ├── routine.dart
│   ├── routine_exercise.dart
│   ├── body_entry.dart
│   ├── body_measurement.dart
│   ├── muscle_category.dart        # Agrupación coarse para listas (pecho, espalda, etc.)
│   ├── muscle_group.dart           # Granularidad anatómica para la figura corporal
│   └── muscle_state.dart           # Estados visuales (idle/recovering/secondary/active/dominant)
│
├── services/                       # Acceso a datos (singletons, operaciones CRUD y queries)
│   ├── session_service.dart        # CRUD de Session, SessionExercise y SessionSet
│   ├── statistics_service.dart     # Queries agregadas de solo lectura
│   ├── session_state_composer.dart # Función pura: deriva MuscleState por sesión
│   ├── exercise_service.dart       # CRUD + persistencia transaccional de exercise_muscles
│   ├── routine_service.dart
│   ├── body_service.dart
│   ├── export_service.dart
│   └── session_notifier.dart       # ValueNotifier para comunicación entre pantallas
│
├── widgets/
│   ├── body_atlas/                 # Atlas anatómico SVG interactivo
│   │   ├── muscle_atlas.dart       # Widget principal (dim por defecto, tap → callback)
│   │   ├── muscle_group_atlas_mapping.dart  # MuscleGroup ↔ atlas.Muscle (bidireccional)
│   │   └── body_atlas_palette.dart # Paleta esmeralda + enum BodyView
│   └── dialogs/
│       └── exercise_form_dialog.dart  # Crear/editar ejercicio con asignación muscular
│
├── screens/                        # Una carpeta por pantalla
│   ├── home/
│   ├── session/
│   ├── history/
│   ├── exercises/                  # Atlas + lista bidireccional
│   ├── routines/
│   ├── body/
│   └── stats/
│
└── main.dart                       # Punto de entrada + navegación principal
```

### Modelo de datos

La jerarquía de entrenamiento tiene tres niveles:

```
Session  (fecha, hora)
 └── SessionExercise  (ejercicio + orden)
      └── SessionSet  (peso, reps, RIR, número de serie)
```

La sesión es la **fuente de verdad**. El historial y las estadísticas leen directamente desde las sesiones registradas. Las eliminaciones usan `ON DELETE CASCADE` para mantener integridad referencial.

Adicionalmente, cada `Exercise` tiene una atribución muscular granular en una tabla join:

```
Exercise  ⇄  MuscleGroup  (con MuscleRole: dominant | secondary)
```

Esto desacopla la categoría amplia (`MuscleCategory.pecho`) de los grupos finos que la figura anatómica necesita pintar (`MuscleGroup.chest`, `shouldersFront`, etc.). El servicio carga y guarda la atribución de forma transaccional.

### Flujo principal

```
Sesión → Agregar ejercicio o rutina
       → Auto-guardado por serie (debounce 600 ms)
       → Historial (lectura)
       → Stats (análisis)
```

---

## Características

### Sesión
- Selector de días de la semana; cada día tiene su estado independiente.
- Auto-guardado: cualquier cambio en peso, reps o RIR se guarda automáticamente 600 ms después de escribir.
- Al volver a un día anterior, los datos se restauran exactamente como se dejaron.
- Hora real registrada al crear la sesión.
- Agregar ejercicios individuales o cargar una rutina completa — en ambos casos se generan **3 series por defecto** para acelerar el flujo.
- Crear nuevos ejercicios personalizados desde el picker (con asignación muscular incluida).

### Historial
- Calendario mensual con días entrenados marcados.
- Racha de días consecutivos.
- Cada sesión es expandible y muestra el detalle completo: ejercicio → tabla de series con peso, reps y RIR.

### Estadísticas
- **Resumen**: racha actual y máxima, volumen semanal con porcentaje de cambio vs. semana anterior, volumen mensual, series efectivas (RIR ≤ 3) y músculo más trabajado.
- **Volumen por Sesión**: gráfica de línea con el volumen de todas las sesiones + tabla de las últimas 5.
- **Músculos esta Semana**: barras de progreso por grupo muscular según volumen levantado.
- **Progreso por Ejercicio**: gráfica del peso máximo histórico por ejercicio.
- **Récords Personales**: top 10 pesos máximos por ejercicio con fecha.

### Ejercicios
- **Atlas anatómico interactivo** en la parte superior: el cuerpo se ve apagado por defecto y los músculos se iluminan al interactuar.
- Toggle frente / espalda.
- **Filtrado bidireccional**:
  - Tocar un músculo del atlas filtra la lista de ejercicios que lo trabajan.
  - Tocar un ejercicio de la lista ilumina sus músculos en el atlas (Principal → tono claro intenso, Apoyo → tono medio).
- **Crear o editar ejercicios** con asignación granular: cada `MuscleGroup` puede marcarse como **Principal** (motor del movimiento) o **Apoyo** (sinergista). El editor reemplaza la atribución completa al guardar (transaccional).
- Biblioteca de ejercicios predefinidos pre-asignados a los músculos correspondientes.

### Rutinas
- Rutinas reutilizables que se pueden cargar directamente en una sesión (con 3 series por ejercicio).

### Cuerpo
- Registro de peso corporal e historial de medidas.

---

## Instalación

### Requisitos previos

- [Flutter](https://docs.flutter.dev/get-started/install) instalado y en `PATH`
- Android SDK (para Android) o Xcode (para iOS)
- Un dispositivo físico o emulador

Verificar que el entorno esté listo:

```bash
flutter doctor
```

### Clonar y ejecutar

```bash
# 1. Clonar el repositorio
git clone https://github.com/LianDev00/Gym-Tracker-App.git
cd gym-tracker

# 2. Instalar dependencias
flutter pub get

# 3. Ejecutar en modo desarrollo
flutter run

# 4. Compilar release para Android
flutter build apk --release
```

### Generar ícono y splash (opcional)

Solo necesario si se modifican los assets en `pubspec.yaml`:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

---

## Modo de uso

### 1. Registrar una sesión

1. Ir a la pestaña **Sesión**.
2. Seleccionar el día de la semana en la barra superior.
3. Tocar **+ Agregar** y elegir:
   - **Ejercicio individual** → seleccionar de la lista o crear uno nuevo.
   - **Cargar rutina** → agregar todos los ejercicios de una rutina guardada.
4. Por cada ejercicio se crean automáticamente **3 series**. Ingresar **peso (kg)**, **reps** y **RIR** en cada una.
5. Tocar **Agregar serie** para sumar series adicionales, o el botón ✕ para borrar series sobrantes.
6. Los datos se guardan solos; no hay botón de guardar.

### 2. Navegar entre días

- Tocar cualquier día en la barra L–M–M–J–V–S–D.
- Al cambiar de día los datos del día anterior se conservan.
- Al volver, los datos se restauran automáticamente.

### 3. Consultar el Historial

- Ir a **Historial**.
- Tocar cualquier sesión para expandirla y ver el detalle de cada ejercicio y serie.
- Navegar el calendario con las flechas para ver meses anteriores.

### 4. Ver Estadísticas

- Ir a **Stats**.
- La pantalla muestra cinco secciones: Resumen, Volumen por Sesión, Músculos esta Semana, Progreso por Ejercicio y Récords Personales.
- En **Progreso por Ejercicio**, seleccionar el ejercicio del dropdown para ver su gráfica de evolución de peso.

### 5. Crear rutinas

1. Ir a **Rutinas** → **+**.
2. Nombrar la rutina y agregar ejercicios con series y reps objetivo.
3. Al registrar una sesión, seleccionar **Cargar rutina** para importar todos los ejercicios de golpe.

### 6. Explorar y editar ejercicios

1. Ir a **Ejercicios**.
2. Tocar un músculo en el atlas para filtrar la lista a los ejercicios que lo trabajan.
3. Tocar un ejercicio de la lista para iluminar en el atlas todos los músculos que involucra (Principal vs. Apoyo se distinguen por color).
4. Tocar el ícono de **lápiz** ✎ junto a cualquier ejercicio para editar nombre, categoría y la asignación granular de músculos.
5. Tocar **+** para crear un ejercicio personalizado nuevo, definiendo desde el inicio los músculos que trabaja.

---

## Estructura de la base de datos

```sql
exercises        (id, name, muscle_category, is_custom)
exercise_muscles (id, exercise_id → CASCADE, muscle_group, role,
                  UNIQUE(exercise_id, muscle_group))
sessions         (id, date, duration_seconds, notes, routine_id)
session_exercises(id, session_id → CASCADE, exercise_id, exercise_order)
session_sets     (id, session_exercise_id → CASCADE, set_number, reps, weight_kg, rir, rpe)
routines         (id, name, notes)
routine_exercises(id, routine_id → CASCADE, exercise_id, exercise_order, target_sets, target_reps, target_weight_kg)
body_entries     (id, date, weight_kg, height_cm, notes)
body_measurements(id, body_entry_id → CASCADE, measurement_type, value_cm)
```

La base de datos se crea automáticamente en el primer arranque con un conjunto de ejercicios predefinidos. Las migraciones se gestionan en `DatabaseHelper._onUpgrade`.

---

## Versión

**1.3.0+7**

---

## Créditos

- **Atlas anatómico SVG**: paquete [`flutter_body_atlas`](https://pub.dev/packages/flutter_body_atlas) — código bajo BSD 3-Clause; assets SVG por **Ryan Graves**, licenciados bajo [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
