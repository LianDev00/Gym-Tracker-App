# Gym Tracker

Aplicación móvil de seguimiento de entrenamiento desarrollada en Flutter. Permite registrar sesiones de gimnasio día a día, consultar el historial completo con detalle de series, y analizar el progreso mediante estadísticas basadas en volumen y RIR.

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
│   ├── exercise.dart
│   ├── routine.dart
│   ├── routine_exercise.dart
│   ├── body_entry.dart
│   ├── body_measurement.dart
│   └── muscle_category.dart
│
├── services/                       # Acceso a datos (singletons, operaciones CRUD y queries)
│   ├── session_service.dart        # CRUD de Session, SessionExercise y SessionSet
│   ├── statistics_service.dart     # Queries agregadas de solo lectura
│   ├── exercise_service.dart
│   ├── routine_service.dart
│   ├── body_service.dart
│   ├── export_service.dart
│   └── session_notifier.dart       # ValueNotifier para comunicación entre pantallas
│
├── screens/                        # Una carpeta por pantalla
│   ├── home/
│   ├── session/
│   ├── history/
│   ├── exercises/
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
- Agregar ejercicios individuales o cargar una rutina completa.
- Crear nuevos ejercicios personalizados desde el picker.

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

### Ejercicios y Rutinas
- Biblioteca de ejercicios predefinidos agrupados por grupo muscular.
- Creación de ejercicios personalizados.
- Rutinas reutilizables que se pueden cargar directamente en una sesión.

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
4. Por cada ejercicio se crea automáticamente la primera serie. Ingresar **peso (kg)**, **reps** y **RIR**.
5. Tocar **Agregar serie** para sumar más series al ejercicio.
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

---

## Estructura de la base de datos

```sql
exercises        (id, name, muscle_category, is_custom)
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

**1.2.0+4**
