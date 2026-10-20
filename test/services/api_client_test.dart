import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_dtsi/services/almacen_token.dart';
import 'package:mantenimiento_dtsi/services/api_client.dart';
import 'package:mantenimiento_dtsi/services/api_exception.dart';

import '../utils/adaptador_falso.dart';

void main() {
  late AlmacenToken almacen;
  late int caducadas;

  ApiClient crear(AdaptadorFalso adaptador) {
    final cliente = ApiClient(
      almacen: almacen,
      alCaducarSesion: () => caducadas++,
    );
    cliente.dio.httpClientAdapter = adaptador;
    return cliente;
  }

  Future<ApiException> fallo(ApiClient cliente, [String ruta = '/x']) async {
    try {
      await cliente.dio.get(ruta);
    } on DioException catch (e) {
      return ApiException.desdeDio(e);
    }
    fail('Se esperaba un error');
  }

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    almacen = AlmacenToken();
    caducadas = 0;
  });

  group('configuración', () {
    test('usa la URL base y 15 s de espera', () {
      final dio = crear(AdaptadorFalso((_) async => json(200, {}))).dio;
      expect(dio.options.baseUrl, ApiClient.urlBase);
      expect(ApiClient.urlBase, 'http://10.0.2.2:8001');
      expect(dio.options.connectTimeout, const Duration(seconds: 15));
      expect(dio.options.receiveTimeout, const Duration(seconds: 15));
    });
  });

  group('interceptor del token', () {
    test('añade Authorization cuando hay token', () async {
      await almacen.guardar('abc');
      final adaptador = AdaptadorFalso((_) async => json(200, {}));
      await crear(adaptador).dio.get('/x');
      expect(
        adaptador.peticiones.single.headers['Authorization'],
        'Bearer abc',
      );
    });

    test('no añade Authorization sin token', () async {
      final adaptador = AdaptadorFalso((_) async => json(200, {}));
      await crear(adaptador).dio.get('/x');
      expect(
        adaptador.peticiones.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });
  });

  group('401', () {
    test('con token: borra el token y avisa de sesión caducada', () async {
      await almacen.guardar('abc');
      final cliente = crear(
        AdaptadorFalso((_) async => json(401, {'detail': 'x'})),
      );
      final e = await fallo(cliente);
      expect(e.mensaje, 'Tu sesión caducó, inicia sesión de nuevo');
      expect(await almacen.leer(), isNull);
      expect(caducadas, 1);
    });

    test(
      'sin token: credenciales incorrectas, sin aviso de caducidad',
      () async {
        final cliente = crear(
          AdaptadorFalso((_) async => json(401, {'detail': 'x'})),
        );
        final e = await fallo(cliente);
        expect(e.mensaje, 'Correo o contraseña incorrectos');
        expect(caducadas, 0);
      },
    );
  });

  group('mapeo de errores', () {
    Future<ApiException> conRespuesta(int codigo, Object cuerpo) =>
        fallo(crear(AdaptadorFalso((_) async => json(codigo, cuerpo))));

    for (final codigo in [400, 403, 404, 409]) {
      test('$codigo usa el texto de detail', () async {
        final e = await conRespuesta(codigo, {'detail': 'Texto del servidor'});
        expect(e.mensaje, 'Texto del servidor');
        expect(e.codigoEstado, codigo);
      });
    }

    test('404 sin detail de cadena usa un mensaje por defecto', () async {
      final e = await conRespuesta(404, {'detail': []});
      expect(e.mensaje, 'No se encontró lo que buscabas.');
    });

    test('422 resume los campos con problema', () async {
      final e = await conRespuesta(422, {
        'detail': [
          {
            'loc': ['body', 'email'],
            'msg': 'valor no válido',
            'type': 'value_error',
          },
          {
            'loc': ['body', 'password'],
            'msg': 'muy corta',
            'type': 'value_error',
          },
        ],
      });
      expect(e.mensaje, 'Revisa los campos: email y password.');
    });

    test('422 con un solo campo', () async {
      final e = await conRespuesta(422, {
        'detail': [
          {
            'loc': ['query', 'limite'],
            'msg': 'm',
            'type': 't',
          },
        ],
      });
      expect(e.mensaje, 'Revisa el campo: limite.');
    });

    test('5xx devuelve el mensaje del servidor', () async {
      final e = await conRespuesta(503, {'detail': 'traza interna'});
      expect(e.mensaje, 'El servidor tuvo un problema. Inténtalo más tarde.');
    });

    test('tiempo agotado', () async {
      final cliente = crear(
        AdaptadorFalso(
          (o) async => throw DioException(
            requestOptions: o,
            type: DioExceptionType.receiveTimeout,
          ),
        ),
      );
      expect(
        (await fallo(cliente)).mensaje,
        'Se agotó el tiempo de espera. Inténtalo de nuevo.',
      );
    });

    test('sin conexión', () async {
      final cliente = crear(
        AdaptadorFalso(
          (o) async => throw DioException(
            requestOptions: o,
            type: DioExceptionType.connectionError,
          ),
        ),
      );
      final e = await fallo(cliente);
      expect(e.mensaje, 'Sin conexión. Revisa tu red e inténtalo de nuevo.');
      expect(e.mensaje.contains('Dio'), isFalse);
    });
  });
}
