import '../core/constants/db_constants.dart';

class Session {
  const Session({
    this.id,
    required this.date,
    this.durationSeconds,
    this.notes,
    this.routineId,
  });

  final int? id;
  final DateTime date;
  final int? durationSeconds;
  final String? notes;
  final int? routineId;

  Session copyWith({
    int? id,
    DateTime? date,
    int? durationSeconds,
    String? notes,
    int? routineId,
  }) =>
      Session(
        id: id ?? this.id,
        date: date ?? this.date,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        notes: notes ?? this.notes,
        routineId: routineId ?? this.routineId,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) DbConstants.cSeId: id,
        DbConstants.cSeDate: date.toIso8601String(),
        DbConstants.cSeDurationSeconds: durationSeconds,
        DbConstants.cSeNotes: notes,
        DbConstants.cSeRoutineId: routineId,
      };

  factory Session.fromMap(Map<String, dynamic> map) => Session(
        id: map[DbConstants.cSeId] as int?,
        date: DateTime.parse(map[DbConstants.cSeDate] as String),
        durationSeconds: map[DbConstants.cSeDurationSeconds] as int?,
        notes: map[DbConstants.cSeNotes] as String?,
        routineId: map[DbConstants.cSeRoutineId] as int?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Session && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Session(id: $id, date: ${date.toIso8601String()})';
}
