enum MuscleCategory {
  pecho,
  espalda,
  hombros,
  biceps,
  triceps,
  piernas,
  gluteos,
  core,
  cardio;

  String get displayName => switch (this) {
        MuscleCategory.pecho => 'Pecho',
        MuscleCategory.espalda => 'Espalda',
        MuscleCategory.hombros => 'Hombros',
        MuscleCategory.biceps => 'Bíceps',
        MuscleCategory.triceps => 'Tríceps',
        MuscleCategory.piernas => 'Piernas',
        MuscleCategory.gluteos => 'Glúteos',
        MuscleCategory.core => 'Core',
        MuscleCategory.cardio => 'Cardio',
      };

  static MuscleCategory fromString(String value) =>
      MuscleCategory.values.firstWhere(
        (e) => e.name == value,
        orElse: () => MuscleCategory.core,
      );
}
