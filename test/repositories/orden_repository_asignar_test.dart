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
  'tecnico_id': 4,
  'tipo_mantenimiento': 'CORRECTIVO',
  'prioridad': 'ALTA',
  'estado': 'ASIGNADA',
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

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    almacen = AlmacenToken();
    await almacen.guardar('tok');
  });

  group('asignarTecnico', () {
    test('usa PATCH …/asignar con {tecnico_id} y parsea el 200', () async {
      final adaptador = AdaptadorFalso((o) async => json(200, _orden));
      final orden = await crear(adaptador).asignarTecnico(7, 4);

      final peticion = adaptador.peticiones.single;
      expect(peticion.method, 'PATCH');
      expect(peticion.path, '/mantenimientos/7/asignar');
      final cuerpo = peticion.data is String
          ? jsonDecode(peticion.data as String)
          : peticion.data;
      expect(cuerpo, {'tecnico_id': 4});
      expect(peticion.headers['Authorization'], 'Bearer tok');
      expect(orden.estado, EstadoOrden.asignada);
      expect(orden.tecnicoId, 4);
    });

    final errores = <int, String>{
      400: 'El técnico no existe, está inactivo o no tiene rol técnico',
      403: 'Permisos insuficientes. Operación permitida solo para roles: [\'admin\']',
      404: 'Orden no encontrada',
    };
    errores.forEach((codigo, detalle) {
      test('$codigo: conserva el mensaje en español del servidor', () async {
        final adaptador = AdaptadorFalso(
          (o) async => json(codigo, {'detail': detalle}),
        );
        await expectLater(
          crear(adaptador).asignarTecnico(7, 4),
          throwsA(
            isA<ApiException>()
                .having((e) => e.codigoEstado, 'código', codigo)
                .having((e) => e.mensaje, 'mensaje', detalle),
          ),
        );
      });
    });

    test('422 y 401 salen como ApiException', () async {
      final repo422 = crear(
        AdaptadorFalso(
          (o) async => json(422, {
            'detail': [
              {'msg': 'Campo requerido'},
            ],
          }),
        ),
      );
      await expectLater(
        repo422.asignarTecnico(7, 4),
        throwsA(
          isA<ApiException>().having((e) => e.codigoEstado, 'código', 422),
        ),
      );
      final repo401 = crear(AdaptadorFalso((o) async => json(401, {})));
      await expectLater(
        repo401.asignarTecnico(7, 4),
        throwsA(
          isA<ApiException>().having(
            (e) => e.mensaje,
            'mensaje',
            ApiException.mensajeSesionCaducada,
          ),
        ),
      );
    });

    test('una respuesta que no es un objeto es un error genérico', () async {
      final adaptador = AdaptadorFalso((o) async => json(200, [1]));
      await expectLater(
        crear(adaptador).asignarTecnico(7, 4),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('listarTecnicos', () {
    test('usa GET /usuarios/tecnicos y parsea la lista', () async {
      final adaptador = AdaptadorFalso(
        (o) async => json(200, [
          {'id': 4, 'nombre_completo': 'Ana Ruiz', 'rol': 'tecnico_dtsi'},
          'basura',
          {'id': 5, 'nombre_completo': 'Luis Mora', 'rol': 'tecnico'},
        ]),
      );
      final lista = await crear(adaptador).listarTecnicos();

      final peticion = adaptador.peticiones.single;
      expect(peticion.method, 'GET');
      expect(peticion.path, '/usuarios/tecnicos');
      expect(peticion.headers['Authorization'], 'Bearer tok');
      expect(lista.map((t) => t.nombreCompleto), ['Ana Ruiz', 'Luis Mora']);
    });

    test('403 para un técnico: mensaje del servidor', () async {
      final adaptador = AdaptadorFalso(
        (o) async => json(403, {'detail': 'Permisos insuficientes'}),
      );
      await expectLater(
        crear(adaptador).listarTecnicos(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.codigoEstado, 'código', 403)
              .having((e) => e.mensaje, 'mensaje', 'Permisos insuficientes'),
        ),
      );
    });

    test('una respuesta que no es lista es un error', () async {
      final adaptador = AdaptadorFalso((o) async => json(200, {'a': 1}));
      await expectLater(
        crear(adaptador).listarTecnicos(),
        throwsA(isA<ApiException>()),
      );
    });
  });

  test('DioException de red se traduce a ApiException', () async {
    final adaptador = AdaptadorFalso(
      (o) async => throw DioException(
        requestOptions: o,
        type: DioExceptionType.connectionError,
      ),
    );
    await expectLater(
      crear(adaptador).listarTecnicos(),
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
