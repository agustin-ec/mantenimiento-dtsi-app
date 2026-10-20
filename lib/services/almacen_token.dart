import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda el token JWT únicamente en el almacenamiento seguro del sistema.
class AlmacenToken {
  static const _clave = 'token_jwt';

  final FlutterSecureStorage _almacen;

  AlmacenToken({FlutterSecureStorage? almacen})
    : _almacen = almacen ?? const FlutterSecureStorage();

  Future<String?> leer() => _almacen.read(key: _clave);

  Future<void> guardar(String token) =>
      _almacen.write(key: _clave, value: token);

  Future<void> borrar() => _almacen.delete(key: _clave);
}
