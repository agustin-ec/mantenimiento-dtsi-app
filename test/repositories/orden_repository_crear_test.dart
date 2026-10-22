import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_dtsi/models/orden.dart';
import 'package:mantenimiento_dtsi/repositories/orden_repository.dart';
import 'package:mantenimiento_dtsi/services/almacen_token.dart';
import 'package:mantenimiento_dtsi/services/api_client.dart';
import 'package:mantenimiento_dtsi/services/api_exception.dart';

import '../utils/adaptador_falso.dart';

const _creada = {
  'id': 8,
  'codigo_orden': 'OT-8',
  'equipo_id': 2,
  'solicitante_id': 1,
  'tipo_mantenimiento': 'PREVENTIVO',
  'prioridad': 'ALTA',
  'estado': 'CREADA',
  'descripcion_problema': 'Revisión general del equipo',
  'fecha_solicitud': '2026-09-20T10:00:00Z',
};

void main() {
  late AlmacenToken almacen;

  OrdenRepository crear(AdaptadorFalso adaptador) {
    final cliente = ApiClient(almacen: almacen);
    cliente.dio.httpClientAdapter = adaptador;
    return OrdenRepository(cliente);
  }

  Future<Orden> enviar(OrdenRepository repo) => repo.crearOrden(
    equipoId: 2,
    tipo: TipoMantenimiento.preventivo,
    prioridad: PrioridadOrden.alta,
    descripcion: 'Revisión general del equipo',
  );

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    almacen = AlmacenToken();
    await almacen.guardar('tok');
  });

  test('crearOrden envía el cuerpo del contrato y parsea el 201', () async {
    final adaptador = AdaptadorFalso((o) async => json(201, _creada));
    final orden = await enviar(crear(adaptador));

    final peticion = adaptador.peticiones.single;
    expect(peticion.method, 'POST');
    expect(peticion.path, '/mantenimientos/');
    expect(peticion.headers['Authorization'], 'Bearer tok');
    final cuerpo = peticion.data is String
        ? jsonDecode(peticion.data as String)
        : peticion.data;
    expect(cuerpo, {
      'equipo_id': 2,
      'tipo_mantenimiento': 'PREVENTIVO',
      'prioridad': 'ALTA',
      'descripcion_problema': 'Revisión general del equipo',
    });
    expect((cuerpo as Map).containsKey('solicitante_id'), isFalse);
    expect(orden.id, 8);
    expect(orden.estado, EstadoOrden.creada);
    expect(orden.prioridad, PrioridadOrden.alta);
  });

  test('un 400 sale con el detalle del backend', () async {
    final adaptador = AdaptadorFalso(
      (o) async => json(400, {'detail': 'El equipo está dado de baja'}),
    );
    expect(
      enviar(crear(adaptador)),
      throwsA(
        isA<ApiException>()
            .having((e) => e.codigoEstado, 'codigo', 400)
            .having((e) => e.mensaje, 'mensaje', 'El equipo está dado de baja'),
      ),
    );
  });

  test('un 422 sale con los campos a revisar', () async {
    final adaptador = AdaptadorFalso(
      (o) async => json(422, {
        'detail': [
          {
            'loc': ['body', 'descripcion_problema'],
          },
        ],
      }),
    );
    expect(
      enviar(crear(adaptador)),
      throwsA(
        isA<ApiException>()
            .having((e) => e.codigoEstado, 'codigo', 422)
            .having(
              (e) => e.mensaje,
              'mensaje',
              'Revisa el campo: descripcion_problema.',
            ),
      ),
    );
  });

  test('un 401 con token sale como sesión caducada', () async {
    final adaptador = AdaptadorFalso((o) async => json(401, {'detail': 'x'}));
    expect(
      enviar(crear(adaptador)),
      throwsA(
        isA<ApiException>().having(
          (e) => e.mensaje,
          'mensaje',
          ApiException.mensajeSesionCaducada,
        ),
      ),
    );
  });

  test('un 500 sale como error del servidor', () async {
    final adaptador = AdaptadorFalso((o) async => json(500, {'detail': 'x'}));
    expect(
      enviar(crear(adaptador)),
      throwsA(
        isA<ApiException>().having(
          (e) => e.mensaje,
          'mensaje',
          ApiException.mensajeServidor,
        ),
      ),
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
      enviar(crear(adaptador)),
      throwsA(
        isA<ApiException>().having(
          (e) => e.mensaje,
          'mensaje',
          ApiException.mensajeSinConexion,
        ),
      ),
    );
  });

  test('un 201 que no es un objeto es un error genérico', () async {
    final adaptador = AdaptadorFalso((o) async => json(201, [1]));
    expect(
      enviar(crear(adaptador)),
      throwsA(
        isA<ApiException>().having(
          (e) => e.mensaje,
          'mensaje',
          ApiException.mensajeGenerico,
        ),
      ),
    );
  });
}
