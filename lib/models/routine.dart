import '../core/constants/db_constants.dart';

class Routine {
  const Routine({
    this.id,
    required this.name,
    this.notes,
  });

  final int? id;
  final String name;
  final String? notes;

  Routine copyWith({
    int? id,
    String? name,
    String? notes,
  }) =>
      Routine(
        id: id ?? this.id,
        name: name ?? this.name,
        notes: notes ?? this.notes,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) DbConstants.cRoId: id,
        DbConstants.cRoName: name,
        DbConstants.cRoNotes: notes,
      };

  factory Routine.fromMap(Map<String, dynamic> map) => Routine(
        id: map[DbConstants.cRoId] as int?,
        name: map[DbConstants.cRoName] as String,
        notes: map[DbConstants.cRoNotes] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Routine && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Routine(id: $id, name: $name)';
}
