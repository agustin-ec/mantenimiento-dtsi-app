import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_dtsi/repositories/equipo_repository.dart';
import 'package:mantenimiento_dtsi/services/almacen_token.dart';
import 'package:mantenimiento_dtsi/services/api_client.dart';
import 'package:mantenimiento_dtsi/services/api_exception.dart';
import 'package:mantenimiento_dtsi/services/cache_equipos.dart';

import '../utils/adaptador_falso.dart';
import '../utils/hive_temporal.dart';
import '../utils/repositorio_equipos_falso.dart';

Map<String, dynamic> _json(int id) => equipoPrueba(id).toJson();

void main() {
  late Future<void> Function() limpiar;
  late CacheEquipos cache;
  int? usuario;

  EquipoRepository crear(AdaptadorFalso adaptador) {
    final cliente = ApiClient(almacen: AlmacenToken());
    cliente.dio.httpClientAdapter = adaptador;
    return EquipoRepository(cliente, cache: cache, idUsuario: () => usuario);
  }

  /// Carga una vez bien para dejar datos guardados.
  Future<void> sembrar() =>
      crear(AdaptadorFalso((o) async => json(200, [_json(1), _json(2)])))
          .listarEquipos();

  setUp(() async {
    limpiar = await iniciarHiveTemporal();
    FlutterSecureStorage.setMockInitialValues({});
    cache = CacheEquipos();
    usuario = 1;
  });

  tearDown(() => limpiar());

  test('una carga correcta actualiza la caché', () async {
    final antes = DateTime.now();
    final lista = await crear(
      AdaptadorFalso((o) async => json(200, [_json(1)])),
    ).listarEquipos();

    expect(lista.desdeCache, isFalse);
    final guardada = (await cache.leer(1))!;
    expect(guardada.equipos.single.id, 1);
    expect(guardada.sincronizadoEn.isBefore(antes), isFalse);
  });

  group('con datos guardados y fallo de red o servidor', () {
    final fallos = <String, Future<ResponseBody> Function(RequestOptions)>{
      'sin conexión': (o) async => throw DioException(
        requestOptions: o,
        type: DioExceptionType.connectionError,
      ),
      'tiempo agotado': (o) async => throw DioException(
        requestOptions: o,
        type: DioExceptionType.receiveTimeout,
      ),
      'error 500': (o) async => json(500, {'detail': 'x'}),
      'error 503': (o) async => json(503, {'detail': 'x'}),
    };

    fallos.forEach((nombre, manejador) {
      test('$nombre devuelve la caché marcada con su fecha', () async {
        await sembrar();
        final fecha = (await cache.leer(1))!.sincronizadoEn;

        final lista = await crear(AdaptadorFalso(manejador)).listarEquipos();
        expect(lista.desdeCache, isTrue);
        expect(lista.sincronizadoEn, fecha);
        expect(lista.equipos.map((e) => e.id), [1, 2]);
      });
    });
  });

  test('sin datos guardados el error sigue igual', () async {
    final repo = crear(AdaptadorFalso((o) async => json(500, {'detail': 'x'})));
    await expectLater(
      repo.listarEquipos(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.mensaje,
          'mensaje',
          ApiException.mensajeServidor,
        ),
      ),
    );
  });

  test('un 401 no usa la caché', () async {
    await sembrar();
    final repo = crear(AdaptadorFalso((o) async => json(401, {'detail': 'x'})));
    await expectLater(
      repo.listarEquipos(),
      throwsA(isA<ApiException>().having((e) => e.codigoEstado, 'c', 401)),
    );
  });

  test('un 404 o un 422 tampoco usan la caché', () async {
    await sembrar();
    for (final codigo in [404, 422]) {
      final repo = crear(
        AdaptadorFalso((o) async => json(codigo, {'detail': 'x'})),
      );
      await expectLater(repo.listarEquipos(), throwsA(isA<ApiException>()));
    }
  });

  test('la caché de otra persona no se usa', () async {
    await sembrar();
    usuario = 2;
    final repo = crear(
      AdaptadorFalso(
        (o) async => throw DioException(
          requestOptions: o,
          type: DioExceptionType.connectionError,
        ),
      ),
    );
    await expectLater(repo.listarEquipos(), throwsA(isA<ApiException>()));
  });

  test('sin persona activa no se guarda ni se lee la caché', () async {
    usuario = null;
    await crear(AdaptadorFalso((o) async => json(200, [_json(1)])))
        .listarEquipos();
    expect(await cache.leer(1), isNull);
  });
}
