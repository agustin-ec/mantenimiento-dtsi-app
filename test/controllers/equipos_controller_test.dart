import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mantenimiento_dtsi/controllers/auth_controller.dart';
import 'package:mantenimiento_dtsi/controllers/equipos_controller.dart';
import 'package:mantenimiento_dtsi/models/equipo.dart';
import 'package:mantenimiento_dtsi/services/api_exception.dart';

import '../utils/repositorio_equipos_falso.dart';
import '../utils/repositorio_falso.dart';

void main() {
  late RepositorioEquiposFalso repo;
  late RepositorioFalso repoAuth;
  late AuthController auth;
  late EquiposController controlador;

  setUp(() {
    repo = RepositorioEquiposFalso()
      ..equipos = [
        equipoPrueba(1),
        equipoPrueba(
          2,
          marca: 'HP',
          modelo: 'ProBook',
          sede: 'Campus Ñandú',
          estado: EstadoEquipo.asignado,
        ),
        equipoPrueba(3, estado: EstadoEquipo.asignado),
      ];
    repoAuth = RepositorioFalso();
    auth = AuthController(repoAuth, navegar: (_) {});
    controlador = Get.put(EquiposController(repo, auth));
  });

  tearDown(Get.reset);

  test('cargar con datos termina en éxito', () async {
    await controlador.cargar();
    expect(controlador.estado.value, EstadoEquipos.exito);
    expect(controlador.equipos, hasLength(3));
  });

  test('cargar sin equipos termina en vacío', () async {
    repo.equipos = [];
    await controlador.cargar();
    expect(controlador.estado.value, EstadoEquipos.vacio);
    expect(controlador.sinCoincidencias, isFalse);
  });

  test('cargar con fallo termina en error con el mensaje', () async {
    repo.error = const ApiException(ApiException.mensajeSinConexion);
    await controlador.cargar();
    expect(controlador.estado.value, EstadoEquipos.error);
    expect(controlador.mensaje.value, ApiException.mensajeSinConexion);
  });

  test('refrescar con fallo conserva los datos y deja el mensaje', () async {
    await controlador.cargar();
    repo.error = const ApiException(ApiException.mensajeServidor);
    await controlador.refrescar();
    expect(controlador.estado.value, EstadoEquipos.exito);
    expect(controlador.equipos, hasLength(3));
    expect(controlador.mensaje.value, ApiException.mensajeServidor);
  });

  test('refrescar sin datos previos y con fallo va a error', () async {
    repo.error = const ApiException(ApiException.mensajeServidor);
    await controlador.refrescar();
    expect(controlador.estado.value, EstadoEquipos.error);
  });

  test('filtro por estado deja solo los equipos de ese estado', () async {
    await controlador.cargar();
    controlador.filtrarPorEstado(EstadoEquipo.asignado);
    expect(controlador.equiposFiltrados.map((e) => e.id), [2, 3]);
    controlador.filtrarPorEstado(null);
    expect(controlador.equiposFiltrados, hasLength(3));
  });

  test('la búsqueda mira código, marca, modelo y sede sin tildes', () async {
    await controlador.cargar();
    controlador.buscar('dtsi-3');
    expect(controlador.equiposFiltrados.map((e) => e.id), [3]);
    controlador.buscar('hp');
    expect(controlador.equiposFiltrados.map((e) => e.id), [2]);
    controlador.buscar('PROBOOK');
    expect(controlador.equiposFiltrados.map((e) => e.id), [2]);
    controlador.buscar('nandu');
    expect(controlador.equiposFiltrados.map((e) => e.id), [2]);
  });

  test('búsqueda y filtro se combinan', () async {
    await controlador.cargar();
    controlador.buscar('dell');
    controlador.filtrarPorEstado(EstadoEquipo.asignado);
    expect(controlador.equiposFiltrados.map((e) => e.id), [3]);
  });

  test('sin resultados de búsqueda no es lo mismo que lista vacía', () async {
    await controlador.cargar();
    controlador.buscar('no existe');
    expect(controlador.equiposFiltrados, isEmpty);
    expect(controlador.estado.value, EstadoEquipos.exito);
    expect(controlador.sinCoincidencias, isTrue);
    expect(controlador.hayFiltros, isTrue);

    controlador.limpiarFiltros();
    expect(controlador.sinCoincidencias, isFalse);
    expect(controlador.equiposFiltrados, hasLength(3));
  });

  group('limpieza al terminar la sesión', () {
    Future<void> cargarConFiltros() async {
      await controlador.cargar();
      controlador.buscar('dell');
      controlador.filtrarPorEstado(EstadoEquipo.asignado);
    }

    void esperarLimpio() {
      expect(controlador.equipos, isEmpty);
      expect(controlador.busqueda.value, '');
      expect(controlador.filtroEstado.value, isNull);
      expect(controlador.mensaje.value, isNull);
      expect(controlador.estado.value, EstadoEquipos.cargando);
    }

    test('el cierre manual limpia los datos', () async {
      await cargarConFiltros();
      await auth.cerrarSesion();
      esperarLimpio();
    });

    test('la caducidad por 401 limpia los datos', () async {
      await cargarConFiltros();
      auth.alCaducarSesion();
      esperarLimpio();
    });

    test(
      'una respuesta que llega después de cerrar sesión se descarta',
      () async {
        final pendiente = controlador.cargar();
        await auth.cerrarSesion();
        await pendiente;
        esperarLimpio();
      },
    );
  });
}
