SPEC-TF v1 — Gym-Tracker: actualización del toolchain Android

## 0. Metadatos
- Proyecto: Gym-Tracker-App
- Fecha: 2026-10-19
- Stack: Flutter 3.47.7 / Dart 3.13, Android (Gradle Kotlin DSL `*.gradle.kts`). Las builds usan el JDK 21 configurado con `flutter config --jdk-dir`.
- Modelo destino: Sonnet 5.5.
- Origen: avisos de `flutter run` ("Flutter support for your project's Gradle/AGP/Kotlin version will soon be dropped").
- Rama/worktree: `chore/android-toolchain` en `..\Gym-Tracker-worktrees\android-toolchain`.

## 1. Contexto y objetivo
El proyecto compila con Gradle 8.14, AGP 8.11.1 y Kotlin 2.2.20. Flutter 3.47 avisa de que pronto dejará de soportar esas versiones y pide Gradle ≥ 9.1.0, AGP ≥ 9.0.1 y Kotlin ≥ 2.3.20. Además, el migrador de Flutter agregó dos líneas a `android/gradle.properties` que nunca se commitearon. **Objetivo:** subir las tres versiones con el cambio mínimo para que `flutter build apk --debug` compile sin esos avisos y la app se comporte igual.

## 2. Alcance y NO-alcance
### Dentro del alcance
- Versión del wrapper de Gradle, del plugin AGP y del plugin de Kotlin.
- Las dos líneas del migrador en `gradle.properties`.
- Migrar `kotlinOptions` a `compilerOptions` si la nueva versión de Kotlin lo exige.
### Fuera del alcance (prohibido construir)
- Adoptar el "built-in Kotlin" o el "new DSL" de AGP 9: las dos flags se quedan en `false`.
- Cambiar `compileSdk`, `minSdk`, `targetSdk`, `ndkVersion`, el `applicationId` o la firma.
- Cambiar `sourceCompatibility`/`jvmTarget` (siguen en 17).
- Tocar `lib/`, `test/`, `pubspec.yaml`, `pubspec.lock`, `ios/` o cualquier archivo fuera de `android/`.
- Agregar repositorios Maven, plugins de Gradle u opciones de `gradle.properties` que no estén en esta spec.
- Bajar o subir `org.gradle.jvmargs`.

## 3. Decisiones de arquitectura
| # | Decisión | Porqué | Alternativa descartada y por qué |
|---|---|---|---|
| 1 | Versiones exactas: Gradle **9.1.0**, AGP **9.0.1** y Kotlin **2.3.20** | Son las mínimas que pide Flutter; minimizan el riesgo de incompatibilidad con los plugins (`sqflite`, notificaciones, `file_picker`) | La "última" de cada una: más superficie de cambio sin necesidad |
| 2 | Mantener `android.builtInKotlin=false` y `android.newDsl=false` | El migrador de Flutter las puso para que AGP 9 acepte el DSL actual del proyecto y de los plugins | Adoptar el DSL nuevo: reescritura del build y riesgo con plugins de terceros |
| 3 | Usar la distribución `-all` del wrapper | Es la que usa hoy el proyecto (consistencia) | `-bin`: cambio cosmético sin beneficio |

## 4. Mapa de módulos
### android/gradle/wrapper/gradle-wrapper.properties
- Cambio: `distributionUrl=https\://services.gradle.org/distributions/gradle-9.1.0-all.zip`.
### android/settings.gradle.kts
- Cambio: `id("com.android.application") version "9.0.1" apply false` y `id("org.jetbrains.kotlin.android") version "2.3.20" apply false`.
### android/gradle.properties
- El archivo final debe ser exactamente:
  ```properties
  org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G -XX:ReservedCodeCacheSize=512m -XX:+HeapDumpOnOutOfMemoryError
  android.useAndroidX=true
  # This builtInKotlin flag was added automatically by Flutter migrator
  android.builtInKotlin=false
  # This newDsl flag was added automatically by Flutter migrator
  android.newDsl=false
  ```
### android/app/build.gradle.kts
- **Solo si** la build falla o avisa de que `kotlinOptions` está obsoleto: reemplazar el bloque `kotlinOptions { jvmTarget = JavaVersion.VERSION_17.toString() }` por este bloque, a nivel raíz del archivo (fuera de `android { }`):
  ```kotlin
  kotlin {
      compilerOptions {
          jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
      }
  }
  ```
  Ningún otro cambio en este archivo.

## 5. Contratos y tipos clave
N/A: no hay contratos de código. El contrato es la build: `flutter build apk --debug` termina con `✓ Built build\app\outputs\flutter-apk\app-debug.apk`, y la salida no contiene "will soon be dropped".

## 6. Orden de construcción
| Fase | Carril | Qué se construye | Modelo | Archivos propios | Cómo se verifica al terminar |
|---|---|---|---|---|---|
| 1 | — | Wrapper, AGP, Kotlin y `gradle.properties` | Sonnet | `android/gradle/wrapper/gradle-wrapper.properties`, `android/settings.gradle.kts`, `android/gradle.properties` | `flutter pub get`, luego `flutter build apk --debug 2>&1`: compila, y `Select-String "will soon be dropped"` sobre la salida no devuelve nada |
| 2 | — | Solo si la fase 1 falla por `kotlinOptions`: migración a `compilerOptions` | Sonnet | `android/app/build.gradle.kts` | Misma verificación que la fase 1; `flutter analyze` y `flutter test` siguen en verde |

Un solo commit al final: `chore: Gradle 9.1, AGP 9.0.1 y Kotlin 2.3.20` (más el trailer de coautoría del entorno). **No hacer push.**

Nota de entorno: Flutter no está en el PATH de los shells nuevos. Usa PowerShell con `$env:Path += ';C:\Users\LiaN\dev\flutter\bin'`. La primera build descarga Gradle 9.1 y puede tardar más de 5 minutos: usa timeouts largos.

## 7. Criterios de aceptación
- [ ] `flutter build apk --debug` compila el APK.
- [ ] La salida de la build no contiene "will soon be dropped" para Gradle, AGP ni Kotlin.
- [ ] `flutter analyze` sin issues; `flutter test` en verde.
- [ ] `git diff --stat main` solo muestra archivos dentro de `android/`.

## 8. Anti-instrucciones (NO hacer)
- NO agregar dependencias, plugins de Gradle ni repositorios.
- NO cambiar a `true` las flags `builtInKotlin`/`newDsl`.
- NO usar `--android-skip-build-dependency-validation` para silenciar los avisos.
- NO tocar nada fuera de `android/`.
- NO cambiar el JDK con el que compila Flutter (`flutter config --jdk-dir`) ni instalar otro JDK.
- NO borrar cachés globales (`~/.gradle`, el SDK de Android). Si una descarga queda corrupta, dilo en el reporte.
- NO hacer push.

## 9. Escalación
Si una decisión no está cubierta por esta spec: NO improvises arquitectura.
- Si la build falla por un plugin de terceros incompatible con AGP 9 o Kotlin 2.3 (ej. `flutter_local_notifications`, `sqflite`), **detente y reporta el error completo**: actualizar plugins es una decisión de arquitectura.
- Decisión menor: resuélvela de la forma más simple y márcala `// TODO-ARQUITECTO: [decisión + propuesta]`.
- Al reportar, lista los `TODO-ARQUITECTO`.
