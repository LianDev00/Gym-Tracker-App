import '../core/constants/db_constants.dart';
import 'measurement_type.dart';

/// Medida corporal específica (ej. cintura: 82 cm) asociada a un [BodyEntry].
class BodyMeasurement {
  const BodyMeasurement({
    this.id,
    required this.bodyEntryId,
    required this.type,
    required this.valueCm,
  });

  final int? id;
  final int bodyEntryId;
  final MeasurementType type;
  final double valueCm;

  BodyMeasurement copyWith({
    int? id,
    int? bodyEntryId,
    MeasurementType? type,
    double? valueCm,
  }) =>
      BodyMeasurement(
        id: id ?? this.id,
        bodyEntryId: bodyEntryId ?? this.bodyEntryId,
        type: type ?? this.type,
        valueCm: valueCm ?? this.valueCm,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) DbConstants.cBmId: id,
        DbConstants.cBmBodyEntryId: bodyEntryId,
        DbConstants.cBmType: type.name,
        DbConstants.cBmValueCm: valueCm,
      };

  factory BodyMeasurement.fromMap(Map<String, dynamic> map) => BodyMeasurement(
        id: map[DbConstants.cBmId] as int?,
        bodyEntryId: map[DbConstants.cBmBodyEntryId] as int,
        type: MeasurementType.fromString(map[DbConstants.cBmType] as String),
        valueCm: map[DbConstants.cBmValueCm] as double,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BodyMeasurement && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
