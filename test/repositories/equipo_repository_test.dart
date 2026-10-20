import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_dtsi/models/equipo.dart';
import 'package:mantenimiento_dtsi/repositories/equipo_repository.dart';
import 'package:mantenimiento_dtsi/services/almacen_token.dart';
import 'package:mantenimiento_dtsi/services/api_client.dart';
import 'package:mantenimiento_dtsi/services/api_exception.dart';

import '../utils/adaptador_falso.dart';

const _equipo = {
  'id': 1,
  'codigo_inventario': 'DTSI-001',
  'numero_serie': 'SN1',
  'tipo_equipo': 'Laptop',
  'marca': 'Dell',
  'modelo': 'Latitude',
  'sede': 'Sede Central',
  'estado': 'ASIGNADO',
  'created_at': '2026-09-20T10:00:00Z',
  'updated_at': '2026-09-20T10:00:00Z',
};

void main() {
  late AlmacenToken almacen;

  EquipoRepository crear(AdaptadorFalso adaptador) {
    final cliente = ApiClient(almacen: almacen);
    cliente.dio.httpClientAdapter = adaptador;
    return EquipoRepository(cliente);
  }

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    almacen = AlmacenToken();
    await almacen.guardar('tok');
  });

  test('listarEquipos envía skip y limit=100 con el token y parsea', () async {
    final adaptador = AdaptadorFalso((o) async => json(200, [_equipo]));
    final equipos = await crear(adaptador).listarEquipos();

    final peticion = adaptador.peticiones.single;
    expect(peticion.method, 'GET');
    expect(peticion.path, '/equipos/');
    expect(peticion.queryParameters, {'skip': 0, 'limit': 100});
    expect(peticion.headers['Authorization'], 'Bearer tok');
    expect(equipos.desdeCache, isFalse);
    expect(equipos.equipos.single.estado, EstadoEquipo.asignado);
  });

  test('listarEquipos con arreglo vacío devuelve lista vacía', () async {
    final adaptador = AdaptadorFalso((o) async => json(200, []));
    expect((await crear(adaptador).listarEquipos()).equipos, isEmpty);
  });

  test('listarEquipos ignora elementos que no son objetos', () async {
    final adaptador = AdaptadorFalso((o) async => json(200, [_equipo, 5]));
    expect((await crear(adaptador).listarEquipos()).equipos, hasLength(1));
  });

  test('una respuesta que no es arreglo es un error genérico', () async {
    final adaptador = AdaptadorFalso((o) async => json(200, {'a': 1}));
    expect(
      crear(adaptador).listarEquipos(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.mensaje,
          'mensaje',
          ApiException.mensajeGenerico,
        ),
      ),
    );
  });

  test('listarHistorial usa la ruta del equipo y parsea eventos', () async {
    final adaptador = AdaptadorFalso(
      (o) async => json(200, [
        {
          'id': 2,
          'equipo_id': 7,
          'usuario_id': 1,
          'accion': 'CREACION',
          'timestamp': '2026-09-20T10:00:00Z',
        },
      ]),
    );
    final eventos = await crear(adaptador).listarHistorial(7);

    final peticion = adaptador.peticiones.single;
    expect(peticion.path, '/equipos/7/historial');
    expect(peticion.queryParameters, {'skip': 0, 'limit': 100});
    expect(eventos.single.accion, 'CREACION');
  });

  test('un 500 sale como ApiException del servidor', () async {
    final adaptador = AdaptadorFalso((o) async => json(500, {'detail': 'x'}));
    expect(
      crear(adaptador).listarEquipos(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.mensaje,
          'mensaje',
          ApiException.mensajeServidor,
        ),
      ),
    );
  });

  test('un 401 con token sale como sesión caducada', () async {
    final adaptador = AdaptadorFalso((o) async => json(401, {'detail': 'x'}));
    expect(
      crear(adaptador).listarHistorial(1),
      throwsA(isA<ApiException>().having((e) => e.codigoEstado, 'codigo', 401)),
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
      crear(adaptador).listarEquipos(),
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
