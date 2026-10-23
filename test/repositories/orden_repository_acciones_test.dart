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

const _orden = {
  'id': 7,
  'codigo_orden': 'OT-7',
  'equipo_id': 2,
  'solicitante_id': 1,
  'tipo_mantenimiento': 'CORRECTIVO',
  'prioridad': 'ALTA',
  'estado': 'EN_PROCESO',
  'descripcion_problema': 'No enciende',
  'fecha_solicitud': '2026-09-20T10:00:00Z',
};

void main() {
  late AlmacenToken almacen;

  OrdenRepository crear(AdaptadorFalso adaptador) {
    final cliente = ApiClient(almacen: almacen);
    cliente.dio.httpClientAdapter = adaptador;
    return OrdenRepository(cliente);
  }

  Object? cuerpoDe(RequestOptions peticion) => peticion.data is String
      ? jsonDecode(peticion.data as String)
      : peticion.data;

  final acciones = <String, Future<Orden> Function(OrdenRepository)>{
    'iniciar': (r) => r.iniciarOrden(7),
    'completar': (r) => r.completarOrden(
      7,
      diagnostico: 'Disco dañado por golpe',
      accionesRealizadas: 'Cambio de disco',
    ),
    'cancelar': (r) => r.cancelarOrden(7, motivo: 'Ya no hace falta'),
  };

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    almacen = AlmacenToken();
    await almacen.guardar('tok');
  });

  group('iniciarOrden', () {
    test('usa PATCH …/iniciar sin cuerpo y parsea el 200', () async {
      final adaptador = AdaptadorFalso((o) async => json(200, _orden));
      final orden = await crear(adaptador).iniciarOrden(7);

      final peticion = adaptador.peticiones.single;
      expect(peticion.method, 'PATCH');
      expect(peticion.path, '/mantenimientos/7/iniciar');
      expect(peticion.data, isNull);
      expect(peticion.headers['Authorization'], 'Bearer tok');
      expect(orden.estado, EstadoOrden.enProceso);
    });
  });

  group('completarOrden', () {
    test(
      'envía diagnóstico y acciones; sin repuestos no los incluye',
      () async {
        final adaptador = AdaptadorFalso(
          (o) async => json(200, {..._orden, 'estado': 'COMPLETADA'}),
        );
        final orden = await crear(adaptador).completarOrden(
          7,
          diagnostico: 'Disco dañado por golpe',
          accionesRealizadas: 'Cambio de disco',
        );

        final peticion = adaptador.peticiones.single;
        expect(peticion.method, 'PATCH');
        expect(peticion.path, '/mantenimientos/7/completar');
        expect(cuerpoDe(peticion), {
          'diagnostico': 'Disco dañado por golpe',
          'acciones_realizadas': 'Cambio de disco',
        });
        expect(orden.estado, EstadoOrden.completada);
      },
    );

    test('con repuestos los incluye; vacíos no', () async {
      final adaptador = AdaptadorFalso((o) async => json(200, _orden));
      final repo = crear(adaptador);
      await repo.completarOrden(
        7,
        diagnostico: 'Disco dañado por golpe',
        accionesRealizadas: 'Cambio de disco',
        repuestosUtilizados: 'SSD 480 GB',
      );
      await repo.completarOrden(
        7,
        diagnostico: 'Disco dañado por golpe',
        accionesRealizadas: 'Cambio de disco',
        repuestosUtilizados: '',
      );

      expect(
        (cuerpoDe(adaptador.peticiones[0]) as Map)['repuestos_utilizados'],
        'SSD 480 GB',
      );
      expect(
        (cuerpoDe(adaptador.peticiones[1]) as Map).containsKey(
          'repuestos_utilizados',
        ),
        isFalse,
      );
    });
  });

  group('cancelarOrden', () {
    test('envía el motivo y parsea el 200', () async {
      final adaptador = AdaptadorFalso(
        (o) async => json(200, {
          ..._orden,
          'estado': 'CANCELADA',
          'motivo_cancelacion': 'Ya no hace falta',
        }),
      );
      final orden = await crear(adaptador)
          .cancelarOrden(7, motivo: 'Ya no hace falta');

      final peticion = adaptador.peticiones.single;
      expect(peticion.method, 'PATCH');
      expect(peticion.path, '/mantenimientos/7/cancelar');
      expect(cuerpoDe(peticion), {'motivo_cancelacion': 'Ya no hace falta'});
      expect(orden.estado, EstadoOrden.cancelada);
      expect(orden.motivoCancelacion, 'Ya no hace falta');
    });
  });

  group('errores de cada acción', () {
    acciones.forEach((nombre, ejecutar) {
      Matcher error(int? codigo, String mensaje) => throwsA(
        isA<ApiException>()
            .having((e) => e.codigoEstado, 'codigo', codigo)
            .having((e) => e.mensaje, 'mensaje', mensaje),
      );

      test('$nombre: 400 con el detalle del backend', () async {
        final adaptador = AdaptadorFalso(
          (o) async => json(400, {'detail': 'La orden no se puede $nombre'}),
        );
        expect(
          ejecutar(crear(adaptador)),
          error(400, 'La orden no se puede $nombre'),
        );
      });

      test('$nombre: 404 con el detalle o el mensaje de respaldo', () async {
        final adaptador = AdaptadorFalso((o) async => json(404, {}));
        expect(
          ejecutar(crear(adaptador)),
          error(404, 'No se encontró lo que buscabas.'),
        );
      });

      test('$nombre: 422 con los campos a revisar', () async {
        final adaptador = AdaptadorFalso(
          (o) async => json(422, {
            'detail': [
              {
                'loc': ['body', 'motivo_cancelacion'],
              },
            ],
          }),
        );
        expect(
          ejecutar(crear(adaptador)),
          error(422, 'Revisa el campo: motivo_cancelacion.'),
        );
      });

      test('$nombre: 401 con token es sesión caducada', () async {
        final adaptador = AdaptadorFalso(
          (o) async => json(401, {'detail': 'x'}),
        );
        expect(
          ejecutar(crear(adaptador)),
          error(401, ApiException.mensajeSesionCaducada),
        );
      });

      test('$nombre: 500 es error del servidor', () async {
        final adaptador = AdaptadorFalso(
          (o) async => json(500, {'detail': 'x'}),
        );
        expect(
          ejecutar(crear(adaptador)),
          error(500, ApiException.mensajeServidor),
        );
      });

      test('$nombre: sin conexión', () async {
        final adaptador = AdaptadorFalso(
          (o) async => throw DioException(
            requestOptions: o,
            type: DioExceptionType.connectionError,
          ),
        );
        expect(
          ejecutar(crear(adaptador)),
          error(null, ApiException.mensajeSinConexion),
        );
      });

      test('$nombre: un 200 que no es objeto es error genérico', () async {
        final adaptador = AdaptadorFalso((o) async => json(200, [1]));
        expect(
          ejecutar(crear(adaptador)),
          error(null, ApiException.mensajeGenerico),
        );
      });
    });
  });
}
