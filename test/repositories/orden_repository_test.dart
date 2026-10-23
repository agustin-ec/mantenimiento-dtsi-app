import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_dtsi/models/orden.dart';
import 'package:mantenimiento_dtsi/repositories/orden_repository.dart';
import 'package:mantenimiento_dtsi/services/almacen_token.dart';
import 'package:mantenimiento_dtsi/services/api_client.dart';
import 'package:mantenimiento_dtsi/services/api_exception.dart';

import '../utils/adaptador_falso.dart';

const _orden = {
  'id': 1,
  'codigo_orden': 'OT-1',
  'equipo_id': 2,
  'solicitante_id': 3,
  'tipo_mantenimiento': 'CORRECTIVO',
  'prioridad': 'MEDIA',
  'estado': 'ASIGNADA',
  'descripcion_problema': 'Falla de red',
  'fecha_solicitud': '2026-09-20T10:00:00Z',
};

void main() {
  late AlmacenToken almacen;

  OrdenRepository crear(AdaptadorFalso adaptador) {
    final cliente = ApiClient(almacen: almacen);
    cliente.dio.httpClientAdapter = adaptador;
    return OrdenRepository(cliente);
  }

  Matcher errorCon(int? codigo, [String? mensaje]) => throwsA(
    isA<ApiException>()
        .having((e) => e.codigoEstado, 'codigo', codigo)
        .having(
          (e) => mensaje == null || e.mensaje == mensaje,
          'mensaje',
          true,
        ),
  );

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    almacen = AlmacenToken();
    await almacen.guardar('tok');
  });

  test('listarOrdenes envía skip y limit=100 con el token y parsea', () async {
    final adaptador = AdaptadorFalso((o) async => json(200, [_orden]));
    final ordenes = await crear(adaptador).listarOrdenes();

    final peticion = adaptador.peticiones.single;
    expect(peticion.method, 'GET');
    expect(peticion.path, '/mantenimientos/');
    expect(peticion.queryParameters, {'skip': 0, 'limit': 100});
    expect(peticion.headers['Authorization'], 'Bearer tok');
    expect(ordenes.single.estado, EstadoOrden.asignada);
  });

  test('listarOrdenes con arreglo vacío devuelve lista vacía', () async {
    final adaptador = AdaptadorFalso((o) async => json(200, []));
    expect(await crear(adaptador).listarOrdenes(), isEmpty);
  });

  test('listarOrdenes ignora elementos que no son objetos', () async {
    final adaptador = AdaptadorFalso((o) async => json(200, [_orden, 5]));
    expect(await crear(adaptador).listarOrdenes(), hasLength(1));
  });

  test('un estado desconocido y un campo extra no rompen la lista', () async {
    final adaptador = AdaptadorFalso(
      (o) async => json(200, [
        {..._orden, 'estado': 'PAUSADA', 'campo_nuevo': true},
      ]),
    );
    final ordenes = await crear(adaptador).listarOrdenes();
    expect(ordenes.single.estado, EstadoOrden.desconocido);
  });

  test('una respuesta que no es arreglo es un error genérico', () async {
    final adaptador = AdaptadorFalso((o) async => json(200, {'a': 1}));
    expect(
      crear(adaptador).listarOrdenes(),
      errorCon(null, ApiException.mensajeGenerico),
    );
  });

  test('obtenerOrden usa la ruta con el id y parsea', () async {
    final adaptador = AdaptadorFalso((o) async => json(200, _orden));
    final orden = await crear(adaptador).obtenerOrden(1);

    expect(adaptador.peticiones.single.path, '/mantenimientos/1');
    expect(orden.codigoOrden, 'OT-1');
  });

  test('obtenerOrden con una respuesta que no es objeto es error', () async {
    final adaptador = AdaptadorFalso((o) async => json(200, [1]));
    expect(
      crear(adaptador).obtenerOrden(1),
      errorCon(null, ApiException.mensajeGenerico),
    );
  });

  test('un 403 sale con el mensaje del backend o el de respaldo', () async {
    var cuerpo = <String, dynamic>{'detail': 'Sin permiso para ver la orden'};
    final adaptador = AdaptadorFalso((o) async => json(403, cuerpo));
    final repo = crear(adaptador);
    await expectLater(
      repo.obtenerOrden(1),
      throwsA(
        isA<ApiException>()
            .having((e) => e.codigoEstado, 'codigo', 403)
            .having(
              (e) => e.mensaje,
              'mensaje',
              'Sin permiso para ver la orden',
            ),
      ),
    );
    cuerpo = {};
    await expectLater(
      repo.obtenerOrden(1),
      throwsA(
        isA<ApiException>().having(
          (e) => e.mensaje,
          'mensaje',
          'No tienes permiso para realizar esta acción.',
        ),
      ),
    );
  });

  test('un 404 sale como no encontrado', () async {
    final adaptador = AdaptadorFalso((o) async => json(404, {}));
    expect(crear(adaptador).obtenerOrden(9), errorCon(404));
  });

  test('un 422 sale como error de validación', () async {
    final adaptador = AdaptadorFalso(
      (o) async => json(422, {
        'detail': [
          {
            'loc': ['query', 'limit'],
          },
        ],
      }),
    );
    expect(crear(adaptador).listarOrdenes(), errorCon(422));
  });

  test('un 500 sale como ApiException del servidor', () async {
    final adaptador = AdaptadorFalso((o) async => json(500, {'detail': 'x'}));
    expect(
      crear(adaptador).listarOrdenes(),
      errorCon(500, ApiException.mensajeServidor),
    );
  });

  test('sin conexión sale con el mensaje de red', () async {
    final adaptador = AdaptadorFalso(
      (o) async => throw DioException(
        requestOptions: o,
        type: DioExceptionType.connectionError,
      ),
    );
    expect(
      crear(adaptador).listarOrdenes(),
      errorCon(null, ApiException.mensajeSinConexion),
    );
  });
}
