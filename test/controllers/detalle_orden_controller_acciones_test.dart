import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mantenimiento_dtsi/controllers/auth_controller.dart';
import 'package:mantenimiento_dtsi/controllers/detalle_orden_controller.dart';
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
  late OrdenesController ordenes;
  late EquiposController equipos;
  late DetalleOrdenController controlador;

  Future<void> esperar() => Future<void>.delayed(Duration.zero);

  setUp(() async {
    repo = RepositorioOrdenesFalso()..ordenes = [ordenPrueba(5)];
    repoEquipos = RepositorioEquiposFalso()..equipos = [equipoPrueba(1)];
    final auth = AuthController(RepositorioFalso(), navegar: (_) {});
    equipos = Get.put(EquiposController(repoEquipos, auth));
    ordenes = Get.put(OrdenesController(repo, auth, equipos: equipos));
    await equipos.cargar();
    await ordenes.cargar();
    repo.llamadas.clear();
    repoEquipos.llamadas.clear();
    controlador = DetalleOrdenController(
      repo,
      ordenPrueba(5),
      ordenes: ordenes,
      equipos: equipos,
    );
  });

  tearDown(Get.reset);

  group('éxito', () {
    test(
      'iniciar: actualiza el detalle, la lista y pide recargar equipos',
      () async {
        final resultado = await controlador.iniciar();

        expect(resultado, ResultadoAccion.exito);
        expect(repo.llamadas, ['iniciarOrden:5']);
        expect(controlador.orden.value.estado, EstadoOrden.enProceso);
        expect(controlador.accionEnCurso.value, isNull);
        expect(controlador.mensajeAccion.value, isNull);
        expect(ordenes.ordenes.single.estado, EstadoOrden.enProceso);
        await esperar();
        expect(repoEquipos.llamadas, ['listarEquipos']);
      },
    );

    test('completar: envía los textos recortados', () async {
      final resultado = await controlador.completar(
        diagnostico: '  Disco dañado por golpe  ',
        accionesRealizadas: '  Cambio de disco  ',
        repuestosUtilizados: '   ',
      );

      expect(resultado, ResultadoAccion.exito);
      expect(repo.cambiosEstado.single, {
        'accion': 'completarOrden',
        'id': 5,
        'diagnostico': 'Disco dañado por golpe',
        'accionesRealizadas': 'Cambio de disco',
        'repuestosUtilizados': '',
      });
      expect(controlador.orden.value.estado, EstadoOrden.completada);
      expect(ordenes.ordenes.single.estado, EstadoOrden.completada);
      expect(controlador.acciones, isEmpty);
    });

    test('completar con repuestos los envía recortados', () async {
      await controlador.completar(
        diagnostico: 'Disco dañado por golpe',
        accionesRealizadas: 'Cambio de disco',
        repuestosUtilizados: ' SSD 480 GB ',
      );
      expect(repo.cambiosEstado.single['repuestosUtilizados'], 'SSD 480 GB');
    });

    test('cancelar: envía el motivo recortado', () async {
      final resultado = await controlador.cancelar('  Ya no hace falta  ');

      expect(resultado, ResultadoAccion.exito);
      expect(repo.cambiosEstado.single['motivo'], 'Ya no hace falta');
      expect(controlador.orden.value.estado, EstadoOrden.cancelada);
      expect(ordenes.ordenes.single.estado, EstadoOrden.cancelada);
      await esperar();
      expect(repoEquipos.llamadas, ['listarEquipos']);
    });

    test('funciona sin controladores de lista ni de equipos', () async {
      final solo = DetalleOrdenController(repo, ordenPrueba(5));
      expect(await solo.iniciar(), ResultadoAccion.exito);
      expect(solo.orden.value.estado, EstadoOrden.enProceso);
    });
  });

  group('400: la transición ya no es válida', () {
    const rechazo = ApiException(
      'La orden ya fue iniciada por otra persona',
      codigoEstado: 400,
    );

    test('muestra el mensaje y relee la orden real', () async {
      repo.errorAccion = rechazo;
      repo.detalle = ordenPrueba(5, estado: EstadoOrden.enProceso);

      final resultado = await controlador.iniciar();

      expect(resultado, ResultadoAccion.rechazada);
      expect(repo.llamadas, ['iniciarOrden:5', 'obtenerOrden:5']);
      expect(
        controlador.mensajeAccion.value,
        'La orden ya fue iniciada por otra persona',
      );
      expect(controlador.orden.value.estado, EstadoOrden.enProceso);
      expect(controlador.acciones, [
        AccionOrden.completar,
        AccionOrden.cancelar,
      ]);
      expect(ordenes.ordenes.single.estado, EstadoOrden.enProceso);
      expect(controlador.accionEnCurso.value, isNull);
      await esperar();
      expect(repoEquipos.llamadas, isEmpty);
    });

    test('si la relectura falla queda solo el mensaje del servidor', () async {
      repo.errorAccion = rechazo;
      repo.errorDetalle = const ApiException(ApiException.mensajeSinConexion);

      final resultado = await controlador.iniciar();

      expect(resultado, ResultadoAccion.rechazada);
      expect(
        controlador.mensajeAccion.value,
        'La orden ya fue iniciada por otra persona',
      );
      expect(controlador.orden.value.estado, EstadoOrden.creada);
      expect(ordenes.ordenes.single.estado, EstadoOrden.creada);
    });
  });

  group('otros errores: no se relee ni se toca nada', () {
    final casos = {
      '404': const ApiException('No se encontró la orden', codigoEstado: 404),
      '422': const ApiException('Revisa el campo: motivo.', codigoEstado: 422),
      '500': const ApiException(
        ApiException.mensajeServidor,
        codigoEstado: 500,
      ),
      'sin conexión': const ApiException(ApiException.mensajeSinConexion),
    };

    casos.forEach((nombre, error) {
      test(nombre, () async {
        repo.errorAccion = error;

        final resultado = await controlador.iniciar();

        expect(resultado, ResultadoAccion.error);
        expect(repo.llamadas, ['iniciarOrden:5']);
        expect(controlador.mensajeAccion.value, error.mensaje);
        expect(controlador.orden.value.estado, EstadoOrden.creada);
        expect(ordenes.ordenes.single.estado, EstadoOrden.creada);
        expect(controlador.accionEnCurso.value, isNull);
        await esperar();
        expect(repoEquipos.llamadas, isEmpty);
      });
    });

    test('un intento nuevo limpia el mensaje anterior', () async {
      repo.errorAccion = const ApiException(ApiException.mensajeServidor);
      await controlador.iniciar();
      expect(controlador.mensajeAccion.value, isNotNull);

      repo.errorAccion = null;
      expect(await controlador.iniciar(), ResultadoAccion.exito);
      expect(controlador.mensajeAccion.value, isNull);
    });
  });

  group('doble envío', () {
    test('mientras hay una acción en curso se ignoran las demás', () async {
      repo.esperaAccion = Completer<void>();

      final primera = controlador.iniciar();
      await esperar();
      expect(controlador.accionEnCurso.value, AccionOrden.iniciar);
      expect(controlador.accionesHabilitadas, isFalse);

      expect(await controlador.iniciar(), ResultadoAccion.error);
      expect(
        await controlador.cancelar('Ya no hace falta'),
        ResultadoAccion.error,
      );
      expect(repo.cambiosEstado, hasLength(1));

      repo.esperaAccion!.complete();
      expect(await primera, ResultadoAccion.exito);
      expect(controlador.accionEnCurso.value, isNull);
      expect(repo.cambiosEstado, hasLength(1));
    });
  });

  group('validación local', () {
    test('completar con textos cortos no envía nada', () async {
      expect(
        await controlador.completar(
          diagnostico: 'corto',
          accionesRealizadas: 'Cambio de disco',
        ),
        ResultadoAccion.error,
      );
      expect(
        controlador.mensajeAccion.value,
        'Debe tener al menos 10 caracteres',
      );
      expect(
        await controlador.completar(
          diagnostico: 'Disco dañado por golpe',
          accionesRealizadas: '   ',
        ),
        ResultadoAccion.error,
      );
      expect(
        controlador.mensajeAccion.value,
        'Describe las acciones realizadas',
      );
      expect(repo.cambiosEstado, isEmpty);
    });

    test('cancelar con un motivo corto no envía nada', () async {
      expect(await controlador.cancelar(' abc '), ResultadoAccion.error);
      expect(
        controlador.mensajeAccion.value,
        'Debe tener al menos 5 caracteres',
      );
      expect(repo.cambiosEstado, isEmpty);
    });
  });

  group('acciones habilitadas', () {
    test('esperan a la primera lectura y se habilitan al terminarla', () async {
      expect(controlador.accionesHabilitadas, isFalse);
      await controlador.cargar();
      expect(controlador.accionesHabilitadas, isTrue);
    });

    test('si la lectura falla se habilitan con el estado conocido', () async {
      repo.errorDetalle = const ApiException(ApiException.mensajeSinConexion);
      await controlador.cargar();
      expect(controlador.estado.value, EstadoDetalleOrden.error);
      expect(controlador.accionesHabilitadas, isTrue);
    });

    test('cargar limpia el mensaje de la última acción', () async {
      repo.errorAccion = const ApiException(ApiException.mensajeServidor);
      await controlador.iniciar();
      expect(controlador.mensajeAccion.value, isNotNull);
      await controlador.cargar();
      expect(controlador.mensajeAccion.value, isNull);
    });
  });
}
