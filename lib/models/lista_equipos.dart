import 'equipo.dart';

/// Equipos listados, con el origen de los datos.
class ListaEquipos {
  final List<Equipo> equipos;

  /// Cuándo se obtuvieron del backend. Si [desdeCache] es verdadero, es la
  /// fecha de la última sincronización correcta.
  final DateTime sincronizadoEn;
  final bool desdeCache;

  const ListaEquipos(
    this.equipos, {
    required this.sincronizadoEn,
    this.desdeCache = false,
  });
}
