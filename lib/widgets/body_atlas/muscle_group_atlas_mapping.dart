import 'package:flutter_body_atlas/flutter_body_atlas.dart' as atlas;

import '../../models/muscle_group.dart';

/// Mapeo entre nuestro [MuscleGroup] (granularidad gym) y los músculos
/// anatómicos del paquete `flutter_body_atlas`. Cada grupo nuestro se
/// pinta resaltando uno o varios elementos SVG del atlas.
///
/// `lowerBack` y `midBack` no tienen contraparte exacta en el atlas v0.1.4
/// (el paquete no expone erector spinae ni romboides directos). Para el
/// midBack usamos `infraspinatus` como aproximación visual; lowerBack queda
/// vacío hasta que el paquete lo exponga.
const Map<MuscleGroup, List<atlas.Muscle>> muscleGroupAtlasMapping = {
  MuscleGroup.chest: [
    atlas.Muscle.pectoralisMajorLeft,
    atlas.Muscle.pectoralisMajorRight,
  ],
  MuscleGroup.shouldersFront: [
    atlas.Muscle.anteriorDeltoidLeft,
    atlas.Muscle.anteriorDeltoidRight,
  ],
  MuscleGroup.shouldersLateral: [
    atlas.Muscle.lateralDeltoidLeft,
    atlas.Muscle.lateralDeltoidRight,
  ],
  MuscleGroup.shouldersRear: [
    atlas.Muscle.posteriorDeltoidLeft,
    atlas.Muscle.posteriorDeltoidRight,
  ],
  MuscleGroup.biceps: [
    atlas.Muscle.bicepsBrachiiCaputBreveLeft,
    atlas.Muscle.bicepsBrachiiCaputBreveRight,
    atlas.Muscle.bicepsBrachiiCaputLongumLeft,
    atlas.Muscle.bicepsBrachiiCaputLongumRight,
  ],
  MuscleGroup.triceps: [
    atlas.Muscle.tricepsBrachiiCaputLateraleLeft,
    atlas.Muscle.tricepsBrachiiCaputLateraleRight,
    atlas.Muscle.tricepsBrachiiCaputLongumLeft,
    atlas.Muscle.tricepsBrachiiCaputLongumRight,
    atlas.Muscle.tricepsBrachiiCaputMedialeLeft,
    atlas.Muscle.tricepsBrachiiCaputMedialeRight,
  ],
  MuscleGroup.forearms: [
    atlas.Muscle.brachioradialisLeft,
    atlas.Muscle.brachioradialisRight,
    atlas.Muscle.extensorDigitorumLeft,
    atlas.Muscle.extensorDigitorumRight,
    atlas.Muscle.extensorCarpiUlnarisLeft,
    atlas.Muscle.extensorCarpiUlnarisRight,
    atlas.Muscle.extensorCarpiRadialisLongusLeft,
    atlas.Muscle.extensorCarpiRadialisLongusRight,
    atlas.Muscle.flexorCarpiUlnarisLeft,
    atlas.Muscle.flexorCarpiUlnarisRight,
    atlas.Muscle.flexorCarpiRadialisLeft,
    atlas.Muscle.flexorCarpiRadialisRight,
    atlas.Muscle.flexorDigitorumSuperficialisLeft,
    atlas.Muscle.flexorDigitorumSuperficialisRight,
    atlas.Muscle.palmarisLongusLeft,
    atlas.Muscle.palmarisLongusRight,
    atlas.Muscle.pronatorTeresLeft,
    atlas.Muscle.pronatorTeresRight,
    atlas.Muscle.pronatorQuadratusLeft,
    atlas.Muscle.pronatorQuadratusRight,
    atlas.Muscle.anconeusLeft,
    atlas.Muscle.anconeusRight,
  ],
  MuscleGroup.abs: [
    atlas.Muscle.rectusAbdominis1,
    atlas.Muscle.rectusAbdominis2Left,
    atlas.Muscle.rectusAbdominis2Right,
    atlas.Muscle.rectusAbdominis3Left,
    atlas.Muscle.rectusAbdominis3Right,
    atlas.Muscle.rectusAbdominis4Left,
    atlas.Muscle.rectusAbdominis4Right,
  ],
  MuscleGroup.obliques: [
    atlas.Muscle.externalObliqueLeft,
    atlas.Muscle.externalObliqueRight,
    atlas.Muscle.externalOblique1Left,
    atlas.Muscle.externalOblique1Right,
    atlas.Muscle.externalOblique2Left,
    atlas.Muscle.externalOblique2Right,
    atlas.Muscle.externalOblique3Left,
    atlas.Muscle.externalOblique3Right,
    atlas.Muscle.externalOblique4Left,
    atlas.Muscle.externalOblique4Right,
    atlas.Muscle.externalOblique5Left,
    atlas.Muscle.externalOblique5Right,
    atlas.Muscle.externalOblique6Left,
    atlas.Muscle.externalOblique6Right,
    atlas.Muscle.externalOblique7Left,
    atlas.Muscle.externalOblique7Right,
    atlas.Muscle.externalOblique8Left,
    atlas.Muscle.externalOblique8Right,
  ],
  MuscleGroup.traps: [
    atlas.Muscle.trapeziusUpperLeft,
    atlas.Muscle.trapeziusUpperRight,
    atlas.Muscle.trapeziusMiddleLeft,
    atlas.Muscle.trapeziusMiddleRight,
    atlas.Muscle.trapeziusLowerLeft,
    atlas.Muscle.trapeziusLowerRight,
  ],
  MuscleGroup.lats: [
    atlas.Muscle.latissimusDorsiLeft,
    atlas.Muscle.latissimusDorsiRight,
  ],
  MuscleGroup.midBack: [
    atlas.Muscle.infraspinatusLeft,
    atlas.Muscle.infraspinatusRight,
  ],
  MuscleGroup.lowerBack: <atlas.Muscle>[],
  MuscleGroup.quads: [
    atlas.Muscle.rectusFemorisLeft,
    atlas.Muscle.rectusFemorisRight,
    atlas.Muscle.vastusLateralisLeft,
    atlas.Muscle.vastusLateralisRight,
    atlas.Muscle.vastusMedialisLeft,
    atlas.Muscle.vastusMedialisRight,
    atlas.Muscle.sartorisLeft,
    atlas.Muscle.sartorisRight,
  ],
  MuscleGroup.adductors: [
    atlas.Muscle.adductorMagnusLeft,
    atlas.Muscle.adductorMagnusRight,
    atlas.Muscle.adductorLongusLeft,
    atlas.Muscle.adductorLongusRight,
    atlas.Muscle.pectineusLeft,
    atlas.Muscle.pectineusRight,
    atlas.Muscle.gracilisLeft,
    atlas.Muscle.gracilisRight,
  ],
  MuscleGroup.hamstrings: [
    atlas.Muscle.bicepsFemorisLeft,
    atlas.Muscle.bicepsFemorisRight,
    atlas.Muscle.semitendinosusLeft,
    atlas.Muscle.semitendinosusRight,
    atlas.Muscle.semimembranosus1Left,
    atlas.Muscle.semimembranosus1Right,
    atlas.Muscle.semimembranosus2Left,
    atlas.Muscle.semimembranosus2Right,
  ],
  MuscleGroup.glutes: [
    atlas.Muscle.gluteusMaximusLeft,
    atlas.Muscle.gluteusMaximusRight,
    atlas.Muscle.gluteusMedius1Left,
    atlas.Muscle.gluteusMedius1Right,
    atlas.Muscle.gluteusMedius2Left,
    atlas.Muscle.gluteusMedius2Right,
  ],
  MuscleGroup.calves: [
    atlas.Muscle.gastrocnemiusLeft,
    atlas.Muscle.gastrocnemiusRight,
    atlas.Muscle.tibialisAnteriorLeft,
    atlas.Muscle.tibialisAnteriorRight,
    atlas.Muscle.fibularisLongusLeft,
    atlas.Muscle.fibularisLongusRight,
  ],
};

/// Mapeo inverso: dado un `atlas.Muscle`, devuelve a qué [MuscleGroup]
/// nuestro pertenece (si alguno). Usado por hit-testing del atlas para
/// traducir taps en SVG paths a callbacks de dominio.
final Map<atlas.Muscle, MuscleGroup> atlasMuscleToGroup = (() {
  final map = <atlas.Muscle, MuscleGroup>{};
  for (final entry in muscleGroupAtlasMapping.entries) {
    for (final muscle in entry.value) {
      map[muscle] = entry.key;
    }
  }
  return map;
})();
