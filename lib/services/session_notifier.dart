import 'package:flutter/foundation.dart';

/// Notifica a SessionScreen cuando se inicia una sesión desde otra pantalla
/// (p.ej. al pulsar "Iniciar" en RoutinesScreen).
///
/// Uso:
///   - Emisor: `pendingSessionNotifier.value = session.id;`
///   - Receptor: escucha con `.addListener` y consume poniendo el valor a null.
final ValueNotifier<int?> pendingSessionNotifier = ValueNotifier<int?>(null);
