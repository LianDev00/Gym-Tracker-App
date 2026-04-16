import '../core/constants/db_constants.dart';

/// Registro diario de métricas corporales (peso + medidas).
class BodyEntry {
  const BodyEntry({
    this.id,
    required this.date,
    this.weightKg,
    this.heightCm,
    this.notes,
  });

  final int? id;
  final DateTime date;
  final double? weightKg;
  final double? heightCm;
  final String? notes;

  BodyEntry copyWith({
    int? id,
    DateTime? date,
    double? weightKg,
    double? heightCm,
    String? notes,
  }) =>
      BodyEntry(
        id: id ?? this.id,
        date: date ?? this.date,
        weightKg: weightKg ?? this.weightKg,
        heightCm: heightCm ?? this.heightCm,
        notes: notes ?? this.notes,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) DbConstants.cBeId: id,
        DbConstants.cBeDate: date.toIso8601String(),
        DbConstants.cBeWeightKg: weightKg,
        DbConstants.cBeHeightCm: heightCm,
        DbConstants.cBeNotes: notes,
      };

  factory BodyEntry.fromMap(Map<String, dynamic> map) => BodyEntry(
        id: map[DbConstants.cBeId] as int?,
        date: DateTime.parse(map[DbConstants.cBeDate] as String),
        weightKg: map[DbConstants.cBeWeightKg] as double?,
        heightCm: map[DbConstants.cBeHeightCm] as double?,
        notes: map[DbConstants.cBeNotes] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BodyEntry && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
