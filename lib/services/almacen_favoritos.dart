import 'package:hive/hive.dart';

/// Ids de los equipos favoritos en Hive, una caja por persona.
class AlmacenFavoritos {
  static const _clave = 'ids';

  final Future<Box> Function(String nombre) _abrir;

  AlmacenFavoritos({Future<Box> Function(String nombre)? abrirCaja})
    : _abrir = abrirCaja ?? ((nombre) => Hive.openBox(nombre));

  static String nombreCaja(int usuarioId) => 'favoritos_$usuarioId';

  Future<Set<int>> leer(int usuarioId) async {
    final caja = await _abrir(nombreCaja(usuarioId));
    final guardado = caja.get(_clave);
    if (guardado is! List) return {};
    return guardado.whereType<int>().toSet();
  }

  Future<void> guardar(int usuarioId, Set<int> ids) async {
    final caja = await _abrir(nombreCaja(usuarioId));
    await caja.put(_clave, ids.toList()..sort());
  }
}
