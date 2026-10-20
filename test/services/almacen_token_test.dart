import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_dtsi/services/almacen_token.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('guarda, lee y borra el token', () async {
    final almacen = AlmacenToken();
    expect(await almacen.leer(), isNull);

    await almacen.guardar('token-de-prueba');
    expect(await almacen.leer(), 'token-de-prueba');

    await almacen.borrar();
    expect(await almacen.leer(), isNull);
  });
}
