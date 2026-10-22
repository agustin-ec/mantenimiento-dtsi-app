import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mantenimiento_dtsi/controllers/auth_controller.dart';
import 'package:mantenimiento_dtsi/controllers/equipos_controller.dart';
import 'package:mantenimiento_dtsi/controllers/formulario_orden_controller.dart';
import 'package:mantenimiento_dtsi/controllers/ordenes_controller.dart';
import 'package:mantenimiento_dtsi/models/equipo.dart';
import 'package:mantenimiento_dtsi/models/orden.dart';
import 'package:mantenimiento_dtsi/services/api_exception.dart';

import '../utils/repositorio_equipos_falso.dart';
import '../utils/repositorio_falso.dart';
import '../utils/repositorio_ordenes_falso.dart';

void main() {
  late RepositorioOrdenesFalso repo;
  late RepositorioEquiposFalso repoEquipos;
  late EquiposController equipos;
  late OrdenesController ordenes;

  Future<void> esperar() => Future<void>.delayed(Duration.zero);

  FormularioOrdenController abrir() =>
      Get.put(FormularioOrdenController(repo, equipos, ordenes));

  Future<void> llenar(FormularioOrdenController f) async {
    f.equipoId.value = 1;
    f.descripcion.value = 'La pantalla no enciende';
  }

  setUp(() async {
    repo = RepositorioOrdenesFalso()..ordenes = [ordenPrueba(1)];
    repoEquipos = RepositorioEquiposFalso()
      ..equipos = [
        equipoPrueba(1),
        equipoPrueba(2, estado: EstadoEquipo.dadoDeBaja),
        equipoPrueba(3, estado: EstadoEquipo.desconocido),
        equipoPrueba(4, estado: EstadoEquipo.enMantenimiento),
      ];
    final auth = AuthController(RepositorioFalso(), navegar: (_) {});
    equipos = Get.put(EquiposController(repoEquipos, auth));
    ordenes = Get.put(OrdenesController(repo, auth, equipos: equipos));
    await ordenes.cargar();
    repo.llamadas.clear();
  });

  tearDown(Get.reset);

  test('arranca con Correctivo, prioridad Media y sin envío en curso', () {
    final f = abrir();
    expect(f.tipo.value, TipoMantenimiento.correctivo);
    expect(f.prioridad.value, PrioridadOrden.media);
    expect(f.enviando.value, isFalse);
    expect(f.equipoId.value, isNull);
  });

  group('equipos del selector', () {
    test(
      'con los equipos cargados no pide nada y excluye los de baja',
      () async {
        await equipos.cargar();
        repoEquipos.llamadas.clear();
        final f = abrir();
        await esperar();

        expect(repoEquipos.llamadas, isEmpty);
        expect(f.equiposElegibles.map((e) => e.id), [1, 3, 4]);
        expect(f.hayEquipos, isTrue);
      },
    );

    test('sin cargar los equipos los pide al abrir', () async {
      final f = abrir();
      await esperar();

      expect(repoEquipos.llamadas, ['listarEquipos']);
      expect(f.estadoEquipos, EstadoEquipos.exito);
      expect(f.equiposElegibles.map((e) => e.id), [1, 3, 4]);
    });

    test('si la carga falla queda el error y se puede reintentar', () async {
      repoEquipos.error = const ApiException(ApiException.mensajeSinConexion);
      final f = abrir();
      await esperar();
      expect(f.estadoEquipos, EstadoEquipos.error);
      expect(f.mensajeEquipos, ApiException.mensajeSinConexion);
      expect(f.hayEquipos, isFalse);

      repoEquipos.error = null;
      f.recargarEquipos();
      await esperar();
      expect(f.estadoEquipos, EstadoEquipos.exito);
      expect(f.hayEquipos, isTrue);
    });

    test('sin equipos, o con todos de baja, no hay nada que elegir', () async {
      repoEquipos.equipos = [equipoPrueba(2, estado: EstadoEquipo.dadoDeBaja)];
      final f = abrir();
      await esperar();
      expect(f.equiposElegibles, isEmpty);
      expect(f.hayEquipos, isFalse);
    });
  });

  group('validación local', () {
    test(
      'sin equipo o con descripción corta no envía ni llama al repo',
      () async {
        await equipos.cargar();
        final f = abrir();

        expect(await f.enviar(), isNull);
        f.equipoId.value = 1;
        f.descripcion.value = '  corta  ';
        expect(f.validarDescripcion(), 'Debe tener al menos 10 caracteres');
        expect(await f.enviar(), isNull);
        expect(repo.llamadas, isEmpty);
        expect(f.validarEquipo(), isNull);
      },
    );

    test('mensajes en español', () {
      final f = abrir();
      expect(f.validarEquipo(), 'Selecciona un equipo');
      expect(f.validarDescripcion(), 'Describe el problema');
    });
  });

  group('envío', () {
    test(
      'éxito: devuelve la orden, la deja en la lista y baja el bloqueo',
      () async {
        await equipos.cargar();
        repo.creada = ordenPrueba(50);
        final f = abrir();
        f.tipo.value = TipoMantenimiento.preventivo;
        f.prioridad.value = PrioridadOrden.critica;
        f.equipoId.value = 1;
        f.descripcion.value = '  Revisión general del equipo  ';

        final orden = await f.enviar();

        expect(orden?.id, 50);
        expect(repo.creaciones.single, {
          'equipoId': 1,
          'tipo': TipoMantenimiento.preventivo,
          'prioridad': PrioridadOrden.critica,
          'descripcion': 'Revisión general del equipo',
        });
        expect(ordenes.ordenes.map((o) => o.id), [50, 1]);
        expect(f.enviando.value, isFalse);
        expect(f.mensaje.value, isNull);
      },
    );

    test(
      'error 400: deja el mensaje del servidor y la lista intacta',
      () async {
        await equipos.cargar();
        repo.errorCrear = const ApiException(
          'El equipo está dado de baja',
          codigoEstado: 400,
        );
        final f = abrir();
        await llenar(f);

        expect(await f.enviar(), isNull);
        expect(f.mensaje.value, 'El equipo está dado de baja');
        expect(f.enviando.value, isFalse);
        expect(ordenes.ordenes.map((o) => o.id), [1]);
      },
    );

    test('error 422: deja el mensaje de validación', () async {
      await equipos.cargar();
      repo.errorCrear = const ApiException(
        'Revisa el campo: descripcion_problema.',
        codigoEstado: 422,
      );
      final f = abrir();
      await llenar(f);

      expect(await f.enviar(), isNull);
      expect(f.mensaje.value, 'Revisa el campo: descripcion_problema.');
      expect(ordenes.ordenes.map((o) => o.id), [1]);
    });

    test('un nuevo intento limpia el mensaje anterior', () async {
      await equipos.cargar();
      repo.errorCrear = const ApiException(ApiException.mensajeServidor);
      final f = abrir();
      await llenar(f);
      await f.enviar();
      expect(f.mensaje.value, isNotNull);

      repo.errorCrear = null;
      expect(await f.enviar(), isNotNull);
      expect(f.mensaje.value, isNull);
    });

    test('bloquea el doble envío mientras la petición está en curso', () async {
      await equipos.cargar();
      repo.espera = Completer<void>();
      final f = abrir();
      await llenar(f);

      final primero = f.enviar();
      await esperar();
      expect(f.enviando.value, isTrue);

      expect(await f.enviar(), isNull);
      expect(repo.creaciones, hasLength(1));

      repo.espera!.complete();
      expect(await primero, isNotNull);
      expect(f.enviando.value, isFalse);
      expect(repo.creaciones, hasLength(1));
    });
  });
}
