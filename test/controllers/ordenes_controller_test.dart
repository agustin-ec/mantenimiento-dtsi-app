import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mantenimiento_dtsi/controllers/auth_controller.dart';
import 'package:mantenimiento_dtsi/controllers/equipos_controller.dart';
import 'package:mantenimiento_dtsi/controllers/ordenes_controller.dart';
import 'package:mantenimiento_dtsi/models/orden.dart';
import 'package:mantenimiento_dtsi/services/api_exception.dart';

import '../utils/repositorio_equipos_falso.dart';
import '../utils/repositorio_falso.dart';
import '../utils/repositorio_ordenes_falso.dart';

void main() {
  late RepositorioOrdenesFalso repo;
  late RepositorioEquiposFalso repoEquipos;
  late AuthController auth;
  late EquiposController equipos;
  late OrdenesController controlador;

  setUp(() {
    repo = RepositorioOrdenesFalso()
      ..ordenes = [
        ordenPrueba(
          1,
          estado: EstadoOrden.creada,
          fechaSolicitud: DateTime.utc(2026, 9, 1),
        ),
        ordenPrueba(
          2,
          estado: EstadoOrden.enProceso,
          fechaSolicitud: DateTime.utc(2026, 9, 3),
        ),
        ordenPrueba(
          3,
          estado: EstadoOrden.enProceso,
          fechaSolicitud: DateTime.utc(2026, 9, 2),
        ),
        ordenPrueba(
          4,
          estado: EstadoOrden.desconocido,
          fechaSolicitud: DateTime.utc(2026, 8, 1),
        ),
      ];
    repoEquipos = RepositorioEquiposFalso();
    auth = AuthController(RepositorioFalso(), navegar: (_) {});
    equipos = Get.put(EquiposController(repoEquipos, auth));
    controlador = Get.put(OrdenesController(repo, auth, equipos: equipos));
  });

  tearDown(Get.reset);

  test(
    'cargar con datos termina en éxito, de la más reciente a la más antigua',
    () async {
      await controlador.cargar();
      expect(controlador.estado.value, EstadosOrdenes.exito);
      expect(controlador.ordenes.map((o) => o.id), [2, 3, 1, 4]);
    },
  );

  test('cargar sin órdenes termina en vacío', () async {
    repo.ordenes = [];
    await controlador.cargar();
    expect(controlador.estado.value, EstadosOrdenes.vacio);
  });

  test('cargar con fallo termina en error con el mensaje', () async {
    repo.error = const ApiException(ApiException.mensajeSinConexion);
    await controlador.cargar();
    expect(controlador.estado.value, EstadosOrdenes.error);
    expect(controlador.mensaje.value, ApiException.mensajeSinConexion);
  });

  test('refrescar con fallo conserva los datos y deja el mensaje', () async {
    await controlador.cargar();
    repo.error = const ApiException(ApiException.mensajeServidor);
    await controlador.refrescar();
    expect(controlador.estado.value, EstadosOrdenes.exito);
    expect(controlador.ordenes, hasLength(4));
    expect(controlador.mensaje.value, ApiException.mensajeServidor);
  });

  test('refrescar con fallo y sin datos pasa a error', () async {
    repo.error = const ApiException(ApiException.mensajeServidor);
    await controlador.refrescar();
    expect(controlador.estado.value, EstadosOrdenes.error);
  });

  test('el filtro deja solo las órdenes del estado', () async {
    await controlador.cargar();
    controlador.filtrarPorEstado(EstadoOrden.enProceso);
    expect(controlador.ordenesFiltradas.map((o) => o.id), [2, 3]);
    expect(controlador.hayFiltros, isTrue);
    controlador.limpiarFiltros();
    expect(controlador.ordenesFiltradas, hasLength(4));
  });

  test(
    'los conteos incluyen todos los estados y «Todos» los desconocidos',
    () async {
      await controlador.cargar();
      final conteo = controlador.conteoPorEstado;
      expect(conteo.keys, EstadoOrden.filtrables);
      expect(conteo[EstadoOrden.creada], 1);
      expect(conteo[EstadoOrden.enProceso], 2);
      expect(conteo[EstadoOrden.cancelada], 0);
      expect(controlador.total, 4);
    },
  );

  group('equipo de la orden', () {
    test('con el equipo cargado muestra código y nombre', () async {
      repoEquipos.equipos = [equipoPrueba(7, marca: 'HP', modelo: 'ProBook')];
      await equipos.cargar();
      expect(controlador.etiquetaEquipo(7), 'DTSI-7 · HP ProBook');
      expect(repoEquipos.llamadas, ['listarEquipos']);
    });

    test('sin el equipo cargado usa «Equipo #id» y no pide nada', () async {
      expect(controlador.etiquetaEquipo(7), 'Equipo #7');
      expect(repoEquipos.llamadas, isEmpty);
    });

    test('sin controlador de equipos usa «Equipo #id»', () {
      final solo = OrdenesController(repo, auth);
      expect(solo.etiquetaEquipo(3), 'Equipo #3');
    });
  });

  group('al terminar la sesión', () {
    Future<void> cargarConFiltro() async {
      await controlador.cargar();
      controlador.filtrarPorEstado(EstadoOrden.creada);
    }

    void esperarLimpio() {
      expect(controlador.ordenes, isEmpty);
      expect(controlador.filtroEstado.value, isNull);
      expect(controlador.mensaje.value, isNull);
      expect(controlador.estado.value, EstadosOrdenes.cargando);
    }

    test('el cierre manual limpia los datos', () async {
      await cargarConFiltro();
      await auth.cerrarSesion();
      esperarLimpio();
    });

    test('la caducidad por 401 limpia los datos', () async {
      await cargarConFiltro();
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
