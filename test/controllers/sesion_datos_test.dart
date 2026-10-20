import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mantenimiento_dtsi/controllers/auth_controller.dart';
import 'package:mantenimiento_dtsi/controllers/equipos_controller.dart';
import 'package:mantenimiento_dtsi/controllers/favoritos_controller.dart';
import 'package:mantenimiento_dtsi/repositories/equipo_repository.dart';
import 'package:mantenimiento_dtsi/services/almacen_favoritos.dart';
import 'package:mantenimiento_dtsi/services/almacen_token.dart';
import 'package:mantenimiento_dtsi/services/api_client.dart';
import 'package:mantenimiento_dtsi/services/cache_equipos.dart';

import '../utils/adaptador_falso.dart';
import '../utils/hive_temporal.dart';
import '../utils/repositorio_equipos_falso.dart';
import '../utils/repositorio_falso.dart';

/// Recorrido completo con Hive real: lo que se limpia al terminar la sesión es
/// la memoria; la caché y los favoritos siguen en disco.
void main() {
  late Future<void> Function() limpiar;
  late bool hayRed;
  late AuthController auth;
  late EquiposController equipos;
  late FavoritosController favoritos;
  late CacheEquipos cache;
  late AlmacenFavoritos almacen;

  setUp(() async {
    limpiar = await iniciarHiveTemporal();
    FlutterSecureStorage.setMockInitialValues({});
    hayRed = true;
    cache = CacheEquipos();
    almacen = AlmacenFavoritos();

    final cliente = ApiClient(almacen: AlmacenToken());
    cliente.dio.httpClientAdapter = AdaptadorFalso((o) async {
      if (!hayRed) {
        throw DioException(
          requestOptions: o,
          type: DioExceptionType.connectionError,
        );
      }
      return json(200, [equipoPrueba(1).toJson(), equipoPrueba(2).toJson()]);
    });

    auth = AuthController(RepositorioFalso(), navegar: (_) {});
    final repo = EquipoRepository(
      cliente,
      cache: cache,
      idUsuario: () => auth.usuario.value?.id,
    );
    equipos = Get.put(EquiposController(repo, auth));
    favoritos = Get.put(FavoritosController(almacen, auth));
  });

  tearDown(() async {
    Get.reset();
    await limpiar();
  });

  Future<void> esperar() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  test('al terminar la sesión, memoria limpia y disco intacto', () async {
    await auth.iniciarSesion('ana@utb.edu.ec', 'clave1234');
    await equipos.cargar();
    await favoritos.alternar(2);

    await auth.cerrarSesion();
    expect(equipos.equipos, isEmpty);
    expect(favoritos.ids, isEmpty);
    expect((await cache.leer(usuarioPrueba.id))?.equipos, hasLength(2));
    expect(await almacen.leer(usuarioPrueba.id), {2});

    // Al volver a entrar sin red: favoritos y equipos desde el disco.
    hayRed = false;
    await auth.iniciarSesion('ana@utb.edu.ec', 'clave1234');
    await esperar();
    await equipos.cargar();
    expect(favoritos.ids, {2});
    expect(equipos.cacheDesde.value, isNotNull);
    expect(equipos.porIds(favoritos.ids.toSet()).single.id, 2);
  });

  test('la caducidad por 401 tampoco borra el disco', () async {
    await auth.iniciarSesion('ana@utb.edu.ec', 'clave1234');
    await equipos.cargar();
    await favoritos.alternar(1);

    auth.alCaducarSesion();
    expect(equipos.equipos, isEmpty);
    expect(equipos.cacheDesde.value, isNull);
    expect(favoritos.ids, isEmpty);
    expect(await cache.leer(usuarioPrueba.id), isNotNull);
    expect(await almacen.leer(usuarioPrueba.id), {1});
  });
}
