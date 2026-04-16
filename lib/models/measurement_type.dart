enum MeasurementType {
  pecho,
  cintura,
  cadera,
  muslos,
  brazos,
  pantorrillas,
  cuello,
  hombros;

  String get displayName => switch (this) {
        MeasurementType.pecho => 'Pecho',
        MeasurementType.cintura => 'Cintura',
        MeasurementType.cadera => 'Cadera',
        MeasurementType.muslos => 'Muslos',
        MeasurementType.brazos => 'Brazos',
        MeasurementType.pantorrillas => 'Pantorrillas',
        MeasurementType.cuello => 'Cuello',
        MeasurementType.hombros => 'Hombros',
      };

  static MeasurementType fromString(String value) =>
      MeasurementType.values.firstWhere(
        (e) => e.name == value,
        orElse: () => MeasurementType.cintura,
      );
}
