import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mantenimiento_dtsi/controllers/auth_controller.dart';
import 'package:mantenimiento_dtsi/controllers/equipos_controller.dart';
import 'package:mantenimiento_dtsi/controllers/ordenes_controller.dart';
import 'package:mantenimiento_dtsi/models/orden.dart';
import 'package:mantenimiento_dtsi/models/usuario.dart';
import 'package:mantenimiento_dtsi/repositories/orden_repository.dart';
import 'package:mantenimiento_dtsi/screens/pantalla_detalle_orden.dart';
import 'package:mantenimiento_dtsi/screens/pantalla_ordenes.dart';
import 'package:mantenimiento_dtsi/services/api_exception.dart';
import 'package:mantenimiento_dtsi/theme/tema_app.dart';
import 'package:mantenimiento_dtsi/utils/rutas.dart';

import '../utils/repositorio_equipos_falso.dart';
import '../utils/repositorio_falso.dart';
import '../utils/repositorio_ordenes_falso.dart';

void main() {
  late RepositorioOrdenesFalso repo;
  late RepositorioEquiposFalso repoEquipos;

  /// Abre la lista y el detalle de OT-1 (solicitante con id 1).
  Future<void> abrirDetalle(
    WidgetTester tester, {
    int usuarioId = 1,
    String rol = 'tecnico_dtsi',
    EstadoOrden estado = EstadoOrden.creada,
  }) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    repo.ordenes = [ordenPrueba(1, estado: estado), ordenPrueba(2)];
    final auth = Get.put(AuthController(RepositorioFalso(), navegar: (_) {}));
    auth.usuario.value = Usuario(
      id: usuarioId,
      email: 'a@utb.edu.ec',
      nombreCompleto: 'Ana Pérez',
      rol: rol,
    );
    final equipos = Get.put(EquiposController(repoEquipos, auth));
    await equipos.cargar();
    Get.put<OrdenRepository>(repo);
    Get.put(OrdenesController(repo, auth, equipos: equipos));
    await tester.pumpWidget(
      GetMaterialApp(
        theme: TemaApp.claro,
        home: const PantallaOrdenes(),
        getPages: [
          GetPage(
            name: Rutas.detalleOrden,
            page: () => const PantallaDetalleOrden(),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('OT-1'));
    await tester.pumpAndSettle();
    repo.llamadas.clear();
  }

  Finder enDialogo(Finder f) =>
      find.descendant(of: find.byType(AlertDialog), matching: f);

  final boton = find.widgetWithText(TextButton, 'Eliminar orden');

  setUp(() {
    repo = RepositorioOrdenesFalso();
    repoEquipos = RepositorioEquiposFalso()..equipos = [equipoPrueba(1)];
  });
  tearDown(Get.reset);

  group('visibilidad del botón', () {
    testWidgets('el solicitante la ve en una orden CREADA', (tester) async {
      await abrirDetalle(tester);
      expect(boton, findsOneWidget);
    });

    testWidgets('un admin que no es el solicitante la ve', (tester) async {
      await abrirDetalle(tester, usuarioId: 9, rol: 'admin');
      expect(boton, findsOneWidget);
    });

    testWidgets('otro técnico no la ve', (tester) async {
      await abrirDetalle(tester, usuarioId: 2);
      expect(boton, findsNothing);
    });

    for (final estado in EstadoOrden.values) {
      if (estado == EstadoOrden.creada) continue;
      testWidgets('solicitante, ${estado.name}: no la ve', (tester) async {
        await abrirDetalle(tester, estado: estado);
        expect(find.text('Eliminar orden'), findsNothing);
      });
    }

    testWidgets('usa el color de error del tema', (tester) async {
      await abrirDetalle(tester);
      final estilo = tester.widget<TextButton>(boton).style!;
      expect(
        estilo.foregroundColor!.resolve({}),
        TemaApp.claro.colorScheme.error,
      );
    });
  });

  group('eliminar', () {
    testWidgets('pide confirmación; «Volver» no envía nada', (tester) async {
      await abrirDetalle(tester);
      await tester.tap(boton);
      await tester.pumpAndSettle();

      expect(find.text('Esta acción no se puede deshacer.'), findsOneWidget);
      await tester.tap(enDialogo(find.text('Volver')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(repo.eliminadas, isEmpty);
      expect(find.byType(PantallaDetalleOrden), findsOneWidget);
    });

    testWidgets('al confirmar cierra el detalle, quita la orden y avisa', (
      tester,
    ) async {
      await abrirDetalle(tester);
      await tester.tap(boton);
      await tester.pumpAndSettle();
      await tester.tap(
        enDialogo(find.widgetWithText(FilledButton, 'Eliminar orden')),
      );
      await tester.pumpAndSettle();

      expect(repo.eliminadas, [1]);
      expect(find.byType(PantallaDetalleOrden), findsNothing);
      expect(find.text('Orden eliminada'), findsOneWidget);
      expect(Get.find<OrdenesController>().ordenes.map((o) => o.id), [2]);
      expect(find.text('OT-1'), findsNothing);
      expect(find.text('OT-2'), findsOneWidget);
    });

    testWidgets('un 403 deja el diálogo abierto con el mensaje', (
      tester,
    ) async {
      repo.errorAccion = const ApiException(
        'Solo el solicitante de la orden o un administrador puede eliminarla',
        codigoEstado: 403,
      );
      await abrirDetalle(tester);
      await tester.tap(boton);
      await tester.pumpAndSettle();
      await tester.tap(
        enDialogo(find.widgetWithText(FilledButton, 'Eliminar orden')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(enDialogo(find.textContaining('solicitante')), findsOneWidget);
      expect(find.byType(PantallaDetalleOrden), findsOneWidget);
      expect(Get.find<OrdenesController>().ordenes, hasLength(2));
    });

    testWidgets('un 404 cierra el detalle, quita la orden y avisa', (
      tester,
    ) async {
      repo.errorAccion = const ApiException(
        'Orden no encontrada',
        codigoEstado: 404,
      );
      await abrirDetalle(tester);
      await tester.tap(boton);
      await tester.pumpAndSettle();
      await tester.tap(
        enDialogo(find.widgetWithText(FilledButton, 'Eliminar orden')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PantallaDetalleOrden), findsNothing);
      expect(find.text('La orden ya no existe'), findsOneWidget);
      expect(Get.find<OrdenesController>().ordenes.map((o) => o.id), [2]);
    });

    testWidgets('un 400 relee la orden y deja el mensaje en el detalle', (
      tester,
    ) async {
      repo.errorAccion = const ApiException(
        'Solo se pueden eliminar órdenes en estado CREADA. Estado actual: ASIGNADA.',
        codigoEstado: 400,
      );
      await abrirDetalle(tester);
      repo.detalle = ordenPrueba(1, estado: EstadoOrden.asignada);
      await tester.tap(boton);
      await tester.pumpAndSettle();
      await tester.tap(
        enDialogo(find.widgetWithText(FilledButton, 'Eliminar orden')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(PantallaDetalleOrden), findsOneWidget);
      expect(find.textContaining('Estado actual'), findsOneWidget);
      expect(find.text('Eliminar orden'), findsNothing);
    });
  });
}
