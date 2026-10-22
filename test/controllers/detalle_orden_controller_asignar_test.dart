import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mantenimiento_dtsi/controllers/auth_controller.dart';
import 'package:mantenimiento_dtsi/controllers/detalle_orden_controller.dart';
import 'package:mantenimiento_dtsi/controllers/equipos_controller.dart';
import 'package:mantenimiento_dtsi/controllers/ordenes_controller.dart';
import 'package:mantenimiento_dtsi/models/orden.dart';
import 'package:mantenimiento_dtsi/models/usuario.dart';
import 'package:mantenimiento_dtsi/services/api_exception.dart';

import '../utils/repositorio_equipos_falso.dart';
import '../utils/repositorio_falso.dart';
import '../utils/repositorio_ordenes_falso.dart';

Orden _conTecnico(int id, int tecnicoId, EstadoOrden estado) => Orden(
  id: id,
  codigoOrden: 'OT-$id',
  equipoId: 1,
  solicitanteId: 1,
  tecnicoId: tecnicoId,
  tipo: TipoMantenimiento.correctivo,
  prioridad: PrioridadOrden.alta,
  estado: estado,
  descripcionProblema: 'La pantalla no enciende',
);

void main() {
  late RepositorioOrdenesFalso repo;
  late RepositorioEquiposFalso repoEquipos;
  late AuthController auth;
  late OrdenesController ordenes;
  late EquiposController equipos;
  late DetalleOrdenController controlador;

  Future<void> esperar() => Future<void>.delayed(Duration.zero);

  DetalleOrdenController crear(Orden orden) => DetalleOrdenController(
    repo,
    orden,
    ordenes: ordenes,
    equipos: equipos,
    auth: auth,
  );

  setUp(() async {
    repo = RepositorioOrdenesFalso()..ordenes = [ordenPrueba(5)];
    repoEquipos = RepositorioEquiposFalso()..equipos = [equipoPrueba(1)];
    auth = AuthController(RepositorioFalso(), navegar: (_) {});
    equipos = Get.put(EquiposController(repoEquipos, auth));
    ordenes = Get.put(OrdenesController(repo, auth, equipos: equipos));
    await equipos.cargar();
    await ordenes.cargar();
    repo.llamadas.clear();
    repoEquipos.llamadas.clear();
    controlador = crear(ordenPrueba(5));
  });
  tearDown(Get.reset);

  test('éxito: actualiza detalle y lista, sin recargar equipos', () async {
    repo.resultadoAccion = _conTecnico(5, 4, EstadoOrden.asignada);

    final resultado = await controlador.asignar(4);

    expect(resultado, ResultadoAccion.exito);
    expect(repo.cambiosEstado.single, {
      'accion': 'asignarTecnico',
      'id': 5,
      'tecnicoId': 4,
    });
    expect(controlador.orden.value.tecnicoId, 4);
    expect(controlador.orden.value.estado, EstadoOrden.asignada);
    expect(ordenes.ordenes.single.tecnicoId, 4);
    expect(controlador.accionEnCurso.value, isNull);
    expect(controlador.mensajeAccion.value, isNull);
    await esperar();
    expect(repoEquipos.llamadas, isEmpty);
  });

  test('400: muestra el mensaje y relee la orden', () async {
    repo.errorAccion = const ApiException(
      'La orden está en estado terminal',
      codigoEstado: 400,
    );
    repo.detalle = ordenPrueba(5, estado: EstadoOrden.completada);

    final resultado = await controlador.asignar(4);

    expect(resultado, ResultadoAccion.rechazada);
    expect(controlador.mensajeAccion.value, 'La orden está en estado terminal');
    expect(repo.llamadas, ['asignarTecnico:5', 'obtenerOrden:5']);
    expect(controlador.orden.value.estado, EstadoOrden.completada);
    expect(controlador.accionEnCurso.value, isNull);
  });

  test('403: muestra el mensaje, no relee y devuelve error', () async {
    repo.errorAccion = const ApiException(
      'Permisos insuficientes',
      codigoEstado: 403,
    );

    final resultado = await controlador.asignar(4);

    expect(resultado, ResultadoAccion.error);
    expect(controlador.mensajeAccion.value, 'Permisos insuficientes');
    expect(repo.llamadas, ['asignarTecnico:5']);
    expect(controlador.orden.value.estado, EstadoOrden.creada);
  });

  test('doble envío: la segunda llamada no llega al servidor', () async {
    repo.esperaAccion = Completer<void>();
    final primera = controlador.asignar(4);
    await esperar();
    expect(controlador.accionEnCurso.value, AccionOrden.asignar);

    final segunda = await controlador.asignar(5);
    expect(segunda, ResultadoAccion.error);
    expect(repo.cambiosEstado, hasLength(1));

    repo.esperaAccion!.complete();
    expect(await primera, ResultadoAccion.exito);
    expect(controlador.accionEnCurso.value, isNull);
  });

  group('puedeAsignar', () {
    void sesionComo(String rol) {
      auth.usuario.value = Usuario(
        id: 1,
        email: 'a@utb.edu.ec',
        nombreCompleto: 'Ana',
        rol: rol,
      );
    }

    test('solo admin y solo en CREADA o ASIGNADA', () {
      sesionComo('admin');
      for (final estado in EstadoOrden.values) {
        final c = crear(ordenPrueba(5, estado: estado));
        expect(
          c.puedeAsignar,
          estado == EstadoOrden.creada || estado == EstadoOrden.asignada,
          reason: estado.name,
        );
      }
    });

    test('un técnico o sin sesión nunca puede', () {
      sesionComo('tecnico_dtsi');
      expect(controlador.puedeAsignar, isFalse);
      auth.usuario.value = null;
      expect(controlador.puedeAsignar, isFalse);
    });
  });
}
