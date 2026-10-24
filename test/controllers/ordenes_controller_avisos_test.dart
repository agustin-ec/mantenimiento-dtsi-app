import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mantenimiento_dtsi/controllers/auth_controller.dart';
import 'package:mantenimiento_dtsi/controllers/ordenes_controller.dart';
import 'package:mantenimiento_dtsi/models/orden.dart';
import 'package:mantenimiento_dtsi/models/usuario.dart';
import 'package:mantenimiento_dtsi/services/avisos_ordenes.dart';

import '../utils/almacen_estados_ordenes_falso.dart';
import '../utils/repositorio_falso.dart';
import '../utils/repositorio_ordenes_falso.dart';

/// Repositorio cuya lista llega cuando se abre la [puerta], con lo que había
/// al pedirla (una respuesta atrasada).
class _RepositorioLento extends RepositorioOrdenesFalso {
  Completer<void>? puerta;

  @override
  Future<List<Orden>> listarOrdenes() async {
    final copia = List.of(ordenes);
    await puerta?.future;
    return copia;
  }
}

Orden orden(
  int id, {
  int solicitante = 2,
  int? tecnico,
  EstadoOrden estado = EstadoOrden.creada,
}) => Orden(
  id: id,
  codigoOrden: 'OT-$id',
  equipoId: 1,
  solicitanteId: solicitante,
  tecnicoId: tecnico,
  estado: estado,
);

const _otraPersona = Usuario(
  id: 2,
  email: 'luis@utb.edu.ec',
  nombreCompleto: 'Luis Mora',
);

void main() {
  late _RepositorioLento repo;
  late AlmacenEstadosOrdenesFalso almacen;
  late AuthController auth;
  late OrdenesController controlador;
  late List<(String, String)> avisados;
  late bool fallaAvisar;

  setUp(() {
    repo = _RepositorioLento();
    almacen = AlmacenEstadosOrdenesFalso();
    avisados = [];
    fallaAvisar = false;
    auth = AuthController(RepositorioFalso(), navegar: (_) {});
    auth.usuario.value = usuarioPrueba;
    auth.estado.value = EstadoAuth.conSesion;
    final avisos = AvisosOrdenes(
      almacen,
      idUsuario: () => auth.usuario.value?.id,
      avisar: (titulo, cuerpo) async {
        if (fallaAvisar) throw StateError('fallo al avisar');
        avisados.add((titulo, cuerpo));
      },
    );
    controlador = Get.put(OrdenesController(repo, auth, avisos: avisos));
  });

  tearDown(Get.reset);

  test(
    'la primera carga no avisa y guarda solo las órdenes de interés',
    () async {
      repo.ordenes = [
        orden(1, solicitante: 1),
        orden(2, solicitante: 2, tecnico: 1),
        orden(3, solicitante: 2, tecnico: 3),
      ];

      await controlador.cargar();

      expect(avisados, isEmpty);
      expect(almacen.datos[1], {1: EstadoOrden.creada, 2: EstadoOrden.creada});
    },
  );

  test('un cambio de estado en una orden mía da un aviso exacto', () async {
    repo.ordenes = [orden(2, solicitante: 1, estado: EstadoOrden.asignada)];
    await controlador.cargar();

    repo.ordenes = [orden(2, solicitante: 1, estado: EstadoOrden.enProceso)];
    await controlador.refrescar();

    expect(avisados, [('Orden OT-2', 'Ahora está En proceso')]);
  });

  test('también avisa cuando soy el técnico de la orden', () async {
    repo.ordenes = [
      orden(4, solicitante: 2, tecnico: 1, estado: EstadoOrden.asignada),
    ];
    await controlador.cargar();

    repo.ordenes = [
      orden(4, solicitante: 2, tecnico: 1, estado: EstadoOrden.completada),
    ];
    await controlador.refrescar();

    expect(avisados, [('Orden OT-4', 'Ahora está Completada')]);
  });

  test('un cambio en una orden ajena no avisa', () async {
    repo.ordenes = [
      orden(1, solicitante: 1),
      orden(5, solicitante: 2, tecnico: 3),
    ];
    await controlador.cargar();

    repo.ordenes = [
      orden(1, solicitante: 1),
      orden(5, solicitante: 2, tecnico: 3, estado: EstadoOrden.enProceso),
    ];
    await controlador.refrescar();

    expect(avisados, isEmpty);
  });

  group('acciones de la propia persona', () {
    setUp(() async {
      repo.ordenes = [orden(1, solicitante: 1, estado: EstadoOrden.asignada)];
      await controlador.cargar();
    });

    test('actualizarOrden no se interpreta como un cambio ajeno', () async {
      controlador.actualizarOrden(
        orden(1, solicitante: 1, estado: EstadoOrden.enProceso),
      );
      repo.ordenes = [orden(1, solicitante: 1, estado: EstadoOrden.enProceso)];

      await controlador.refrescar();

      expect(avisados, isEmpty);
    });

    test('una orden que yo creé no avisa', () async {
      controlador.incorporarCreada(orden(9, solicitante: 1));
      repo.ordenes = [
        orden(9, solicitante: 1),
        orden(1, solicitante: 1, estado: EstadoOrden.asignada),
      ];

      await controlador.refrescar();

      expect(avisados, isEmpty);
    });

    test('una orden que yo eliminé sale del mapa', () async {
      controlador.quitar(1);

      expect(almacen.datos[1], isEmpty);
    });
  });

  test('una orden nueva asignada a mí como técnico avisa', () async {
    repo.ordenes = [orden(1, solicitante: 1)];
    await controlador.cargar();

    repo.ordenes = [
      orden(1, solicitante: 1),
      orden(7, solicitante: 2, tecnico: 1, estado: EstadoOrden.asignada),
      orden(8, solicitante: 1, tecnico: 1, estado: EstadoOrden.asignada),
    ];
    await controlador.refrescar();

    expect(avisados, [
      ('Orden OT-7', 'Se te asignó esta orden. Estado: Asignada'),
    ]);
  });

  test('hasta 3 cambios dan un aviso por cambio', () async {
    repo.ordenes = [for (var i = 1; i <= 3; i++) orden(i, solicitante: 1)];
    await controlador.cargar();

    repo.ordenes = [
      for (var i = 1; i <= 3; i++)
        orden(i, solicitante: 1, estado: EstadoOrden.enProceso),
    ];
    await controlador.refrescar();

    expect(avisados, hasLength(3));
    expect(
      avisados.map((a) => a.$1),
      unorderedEquals(['Orden OT-1', 'Orden OT-2', 'Orden OT-3']),
    );
  });

  test('más de 3 cambios dan un solo resumen', () async {
    repo.ordenes = [for (var i = 1; i <= 4; i++) orden(i, solicitante: 1)];
    await controlador.cargar();

    repo.ordenes = [
      for (var i = 1; i <= 4; i++)
        orden(i, solicitante: 1, estado: EstadoOrden.enProceso),
    ];
    await controlador.refrescar();

    expect(avisados, [
      ('Órdenes actualizadas', 'Tienes 4 cambios en tus órdenes'),
    ]);
  });

  test('el mapa es por persona y no se mezcla entre personas', () async {
    repo.ordenes = [orden(1, solicitante: 1, estado: EstadoOrden.asignada)];
    await controlador.cargar();

    await auth.cerrarSesion();
    auth.usuario.value = _otraPersona;
    auth.estado.value = EstadoAuth.conSesion;

    // Primera carga de la otra persona: no hay mapa suyo, así que no avisa.
    repo.ordenes = [orden(1, solicitante: 1, estado: EstadoOrden.enProceso)];
    await controlador.cargar();
    expect(avisados, isEmpty);
    expect(almacen.datos[2], isEmpty);
    expect(almacen.datos[1], {1: EstadoOrden.asignada});

    // Al volver la primera persona, su mapa sigue ahí y detecta el cambio.
    await auth.cerrarSesion();
    auth.usuario.value = usuarioPrueba;
    auth.estado.value = EstadoAuth.conSesion;
    await controlador.cargar();
    expect(avisados, [('Orden OT-1', 'Ahora está En proceso')]);
  });

  test('si me quitan una orden o desaparece de la lista no avisa', () async {
    repo.ordenes = [
      orden(1, solicitante: 2, tecnico: 1, estado: EstadoOrden.asignada),
      orden(2, solicitante: 1),
    ];
    await controlador.cargar();

    repo.ordenes = [
      orden(1, solicitante: 2, tecnico: 3, estado: EstadoOrden.enProceso),
    ];
    await controlador.refrescar();

    expect(avisados, isEmpty);
    expect(almacen.datos[1], {2: EstadoOrden.creada});
  });

  test(
    'una respuesta atrasada tras una acción propia no avisa ni revierte',
    () async {
      repo.ordenes = [orden(1, solicitante: 1, estado: EstadoOrden.asignada)];
      await controlador.cargar();

      repo.puerta = Completer<void>();
      final carga = controlador.refrescar();
      await Future<void>.delayed(Duration.zero);
      controlador.actualizarOrden(
        orden(1, solicitante: 1, estado: EstadoOrden.enProceso),
      );
      repo.puerta!.complete();
      await carga;

      expect(avisados, isEmpty);
      expect(almacen.datos[1], {1: EstadoOrden.enProceso});
    },
  );

  test('un fallo del almacén o del aviso no vuelve error la lista', () async {
    repo.ordenes = [orden(1, solicitante: 1)];
    almacen.fallaAlGuardar = true;
    await controlador.cargar();
    expect(controlador.estado.value, EstadosOrdenes.exito);
    expect(controlador.mensaje.value, isNull);

    almacen.fallaAlGuardar = false;
    fallaAvisar = true;
    await controlador.refrescar();
    repo.ordenes = [orden(1, solicitante: 1, estado: EstadoOrden.enProceso)];
    await controlador.refrescar();
    expect(controlador.estado.value, EstadosOrdenes.exito);
    expect(controlador.mensaje.value, isNull);
    expect(controlador.ordenes, hasLength(1));
  });
}
