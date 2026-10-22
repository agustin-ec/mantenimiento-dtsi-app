import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_dtsi/repositories/orden_repository.dart';
import 'package:mantenimiento_dtsi/services/almacen_token.dart';
import 'package:mantenimiento_dtsi/services/api_client.dart';
import 'package:mantenimiento_dtsi/services/api_exception.dart';

import '../utils/adaptador_falso.dart';

void main() {
  late AlmacenToken almacen;

  OrdenRepository crear(AdaptadorFalso adaptador) {
    final cliente = ApiClient(almacen: almacen);
    cliente.dio.httpClientAdapter = adaptador;
    return OrdenRepository(cliente);
  }

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    almacen = AlmacenToken();
    await almacen.guardar('tok');
  });

  test('usa DELETE /mantenimientos/{id} y acepta el 204 sin cuerpo', () async {
    final adaptador = AdaptadorFalso(
      (o) async => ResponseBody.fromString('', 204),
    );
    await crear(adaptador).eliminarOrden(7);

    final peticion = adaptador.peticiones.single;
    expect(peticion.method, 'DELETE');
    expect(peticion.path, '/mantenimientos/7');
    expect(peticion.headers['Authorization'], 'Bearer tok');
  });

  final errores = <int, String>{
    400: 'Solo se pueden eliminar órdenes en estado CREADA. Estado actual: EN_PROCESO.',
    403: 'Solo el solicitante de la orden o un administrador puede eliminarla',
    404: 'Orden no encontrada',
  };
  errores.forEach((codigo, detalle) {
    test('$codigo: conserva el mensaje del servidor', () async {
      final adaptador = AdaptadorFalso(
        (o) async => json(codigo, {'detail': detalle}),
      );
      await expectLater(
        crear(adaptador).eliminarOrden(7),
        throwsA(
          isA<ApiException>()
              .having((e) => e.codigoEstado, 'código', codigo)
              .having((e) => e.mensaje, 'mensaje', detalle),
        ),
      );
    });
  });

  test('401: sesión caducada', () async {
    final adaptador = AdaptadorFalso((o) async => json(401, {}));
    await expectLater(
      crear(adaptador).eliminarOrden(7),
      throwsA(
        isA<ApiException>().having(
          (e) => e.mensaje,
          'mensaje',
          ApiException.mensajeSesionCaducada,
        ),
      ),
    );
  });

  test('sin conexión sale como ApiException', () async {
    final adaptador = AdaptadorFalso(
      (o) async => throw DioException(
        requestOptions: o,
        type: DioExceptionType.connectionError,
      ),
    );
    await expectLater(
      crear(adaptador).eliminarOrden(7),
      throwsA(
        isA<ApiException>().having(
          (e) => e.mensaje,
          'mensaje',
          ApiException.mensajeSinConexion,
        ),
      ),
    );
  });
}
