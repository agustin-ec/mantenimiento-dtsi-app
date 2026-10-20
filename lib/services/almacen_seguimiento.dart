import 'package:hive/hive.dart';

/// Ids de los equipos seguimiento en Hive, una caja por persona.
class AlmacenSeguimiento {
  static const _clave = 'ids';

  final Future<Box> Function(String nombre) _abrir;

  AlmacenSeguimiento({Future<Box> Function(String nombre)? abrirCaja})
    : _abrir = abrirCaja ?? ((nombre) => Hive.openBox(nombre));

  /// El nombre conserva «favoritos» para leer lo que ya se guardó con ese
  /// nombre antes del cambio a «Mis equipos».
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
