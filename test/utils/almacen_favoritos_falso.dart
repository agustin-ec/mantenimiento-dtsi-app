import 'package:mantenimiento_dtsi/services/almacen_favoritos.dart';

/// Favoritos en memoria, por persona, para pruebas de widget (sin disco).
class AlmacenFavoritosFalso implements AlmacenFavoritos {
  final Map<int, Set<int>> datos = {};
  bool fallaAlGuardar = false;

  @override
  Future<Set<int>> leer(int usuarioId) async => {...?datos[usuarioId]};

  @override
  Future<void> guardar(int usuarioId, Set<int> ids) async {
    if (fallaAlGuardar) throw StateError('disco lleno');
    datos[usuarioId] = {...ids};
  }
}
