/// Estado visual de una región muscular en la figura anatómica.
/// El orden de declaración define la prioridad: si una región califica para
/// varios estados en la misma sesión, gana el de mayor índice.
enum MuscleState {
  idle,
  recovering,
  secondary,
  active,
  dominant;
}
