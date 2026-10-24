import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_dtsi/repositories/asistente_repository.dart';
import 'package:mantenimiento_dtsi/services/almacen_token.dart';
import 'package:mantenimiento_dtsi/services/api_client.dart';
import 'package:mantenimiento_dtsi/services/api_exception.dart';

import '../utils/adaptador_falso.dart';

void main() {
  late AlmacenToken almacen;
  late ApiClient cliente;

  AsistenteRepository crear(AdaptadorFalso adaptador) {
    cliente = ApiClient(almacen: almacen);
    cliente.dio.httpClientAdapter = adaptador;
    return AsistenteRepository(cliente);
  }

  Matcher errorCon(int? codigo, String mensaje) => throwsA(
    isA<ApiException>()
        .having((e) => e.codigoEstado, 'codigo', codigo)
        .having((e) => e.mensaje, 'mensaje', mensaje),
  );

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    almacen = AlmacenToken();
    await almacen.guardar('tok');
  });

  test('preguntar envía el cuerpo {pregunta} por POST con el token', () async {
    final adaptador = AdaptadorFalso(
      (o) async => json(200, {'respuesta': 'ok'}),
    );
    await crear(adaptador).preguntar('¿Cuántas órdenes hay?');

    final peticion = adaptador.peticiones.single;
    expect(peticion.method, 'POST');
    expect(peticion.path, '/asistente/preguntar');
    expect(peticion.data, {'pregunta': '¿Cuántas órdenes hay?'});
    expect(peticion.headers['Authorization'], 'Bearer tok');
  });

  test('preguntar devuelve el texto de la respuesta', () async {
    final adaptador = AdaptadorFalso(
      (o) async => json(200, {'respuesta': 'Hay 3 órdenes abiertas.'}),
    );
    expect(
      await crear(adaptador).preguntar('¿Cuántas órdenes hay?'),
      'Hay 3 órdenes abiertas.',
    );
  });

  test('solo esta petición espera 30 s; las demás siguen en 15 s', () async {
    final adaptador = AdaptadorFalso(
      (o) async => json(200, {'respuesta': 'ok'}),
    );
    final repositorio = crear(adaptador);
    await repositorio.preguntar('¿Cuántas órdenes hay?');
    await cliente.dio.get('/health');

    expect(
      adaptador.peticiones.first.receiveTimeout,
      const Duration(seconds: 30),
    );
    expect(
      adaptador.peticiones.last.receiveTimeout,
      const Duration(seconds: 15),
    );
  });

  test('una respuesta sin texto en «respuesta» es un error genérico', () async {
    for (final cuerpo in <Object>[
      [1],
      {'otra': 'cosa'},
      {'respuesta': 5},
    ]) {
      final adaptador = AdaptadorFalso((o) async => json(200, cuerpo));
      await expectLater(
        crear(adaptador).preguntar('¿Cuántas órdenes hay?'),
        errorCon(null, ApiException.mensajeGenerico),
      );
    }
  });

  test('un 503 sale como «no está configurado» y conserva el código', () async {
    final adaptador = AdaptadorFalso(
      (o) async => json(503, {
        'detail': 'El asistente no está configurado en el servidor',
      }),
    );
    await expectLater(
      crear(adaptador).preguntar('¿Cuántas órdenes hay?'),
      errorCon(503, 'El asistente no está configurado en el servidor.'),
    );
  });

  test('un 502 sale como «no está disponible» y conserva el código', () async {
    final adaptador = AdaptadorFalso(
      (o) async =>
          json(502, {'detail': 'El asistente no está disponible por ahora'}),
    );
    await expectLater(
      crear(adaptador).preguntar('¿Cuántas órdenes hay?'),
      errorCon(
        502,
        'El asistente no está disponible por ahora. Intenta más tarde.',
      ),
    );
  });

  test('un 422 resume el campo inválido', () async {
    final adaptador = AdaptadorFalso(
      (o) async => json(422, {
        'detail': [
          {
            'loc': ['body', 'pregunta'],
            'msg': 'String should have at least 3 characters',
            'type': 'string_too_short',
          },
        ],
      }),
    );
    await expectLater(
      crear(adaptador).preguntar('ab'),
      errorCon(422, 'Revisa el campo: pregunta.'),
    );
  });

  test('el tiempo agotado usa el mensaje existente', () async {
    final adaptador = AdaptadorFalso(
      (o) async => throw DioException(
        requestOptions: o,
        type: DioExceptionType.receiveTimeout,
      ),
    );
    await expectLater(
      crear(adaptador).preguntar('¿Cuántas órdenes hay?'),
      errorCon(null, ApiException.mensajeTiempoAgotado),
    );
  });

  test('sin conexión usa el mensaje existente', () async {
    final adaptador = AdaptadorFalso(
      (o) async => throw DioException(
        requestOptions: o,
        type: DioExceptionType.connectionError,
      ),
    );
    await expectLater(
      crear(adaptador).preguntar('¿Cuántas órdenes hay?'),
      errorCon(null, ApiException.mensajeSinConexion),
    );
  });
}
