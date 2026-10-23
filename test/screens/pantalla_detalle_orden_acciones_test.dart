import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mantenimiento_dtsi/controllers/auth_controller.dart';
import 'package:mantenimiento_dtsi/controllers/equipos_controller.dart';
import 'package:mantenimiento_dtsi/controllers/ordenes_controller.dart';
import 'package:mantenimiento_dtsi/models/orden.dart';
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

  /// Abre la lista y, al tocar la tarjeta, el detalle de una orden en [estado].
  Future<void> abrirDetalle(WidgetTester tester, EstadoOrden estado) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    repo.ordenes = [ordenPrueba(1, estado: estado)];
    final auth = Get.put(AuthController(RepositorioFalso(), navegar: (_) {}));
    auth.usuario.value = usuarioPrueba;
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
    repoEquipos.llamadas.clear();
  }

  Finder enDialogo(Finder f) =>
      find.descendant(of: find.byType(AlertDialog), matching: f);

  Finder enHoja(Finder f) =>
      find.descendant(of: find.byType(BottomSheet), matching: f);

  setUp(() {
    repo = RepositorioOrdenesFalso();
    repoEquipos = RepositorioEquiposFalso()..equipos = [equipoPrueba(1)];
  });
  tearDown(Get.reset);

  group('acciones visibles según el estado', () {
    final esperado = <EstadoOrden, List<String>>{
      EstadoOrden.creada: ['Iniciar', 'Cancelar orden'],
      EstadoOrden.asignada: ['Iniciar', 'Cancelar orden'],
      EstadoOrden.enProceso: ['Completar', 'Cancelar orden'],
      EstadoOrden.completada: [],
      EstadoOrden.cancelada: [],
      EstadoOrden.desconocido: [],
    };
    esperado.forEach((estado, botones) {
      testWidgets('${estado.name}: ${botones.isEmpty ? 'ninguna' : botones}', (
        tester,
      ) async {
        await abrirDetalle(tester, estado);
        for (final texto in ['Iniciar', 'Completar', 'Cancelar orden']) {
          final bar = find.descendant(
            of: find.byType(SafeArea),
            matching: find.text(texto),
          );
          expect(
            bar,
            botones.contains(texto) ? findsOneWidget : findsNothing,
            reason: texto,
          );
        }
      });
    });
  });

  group('iniciar', () {
    testWidgets('pide confirmación; «Volver» no envía nada', (tester) async {
      await abrirDetalle(tester, EstadoOrden.creada);
      await tester.tap(find.widgetWithText(FilledButton, 'Iniciar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Iniciar orden'), findsOneWidget);
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(repo.cambiosEstado, isEmpty);
    });

    testWidgets('al confirmar actualiza el detalle, la lista y los equipos', (
      tester,
    ) async {
      await abrirDetalle(tester, EstadoOrden.creada);
      await tester.tap(find.widgetWithText(FilledButton, 'Iniciar'));
      await tester.pumpAndSettle();
      await tester.tap(enDialogo(find.widgetWithText(FilledButton, 'Iniciar')));
      await tester.pumpAndSettle();

      expect(repo.cambiosEstado.single['accion'], 'iniciarOrden');
      expect(find.text('En proceso'), findsOneWidget);
      expect(find.text('Iniciar'), findsNothing);
      expect(find.text('Completar'), findsOneWidget);
      expect(
        Get.find<OrdenesController>().ordenes.single.estado,
        EstadoOrden.enProceso,
      );
      expect(repoEquipos.llamadas, ['listarEquipos']);
    });
  });

  group('completar', () {
    Future<void> abrirHoja(WidgetTester tester) async {
      await abrirDetalle(tester, EstadoOrden.enProceso);
      await tester.tap(find.widgetWithText(FilledButton, 'Completar'));
      await tester.pumpAndSettle();
    }

    testWidgets('valida los textos antes de enviar', (tester) async {
      await abrirHoja(tester);
      expect(find.text('Repuestos utilizados (opcional)'), findsOneWidget);

      await tester.tap(enHoja(find.widgetWithText(FilledButton, 'Completar')));
      await tester.pump();
      expect(find.text('Describe el diagnóstico'), findsOneWidget);
      expect(find.text('Describe las acciones realizadas'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'corto');
      await tester.enterText(find.byType(TextFormField).at(1), '  corto  ');
      await tester.tap(enHoja(find.widgetWithText(FilledButton, 'Completar')));
      await tester.pump();
      expect(find.text('Debe tener al menos 10 caracteres'), findsNWidgets(2));
      expect(repo.cambiosEstado, isEmpty);
    });

    testWidgets('con datos válidos envía, cierra y muestra COMPLETADA', (
      tester,
    ) async {
      await abrirHoja(tester);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        '  Disco dañado por golpe  ',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Cambio de disco',
      );
      await tester.tap(enHoja(find.widgetWithText(FilledButton, 'Completar')));
      await tester.pumpAndSettle();

      expect(
        repo.cambiosEstado.single['diagnostico'],
        'Disco dañado por golpe',
      );
      expect(repo.cambiosEstado.single['repuestosUtilizados'], '');
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Completada'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Completar'), findsNothing);
      expect(
        find.widgetWithText(OutlinedButton, 'Cancelar orden'),
        findsNothing,
      );
    });

    testWidgets('un error del servidor deja la hoja abierta con el mensaje', (
      tester,
    ) async {
      repo.errorAccion = const ApiException(ApiException.mensajeServidor);
      await abrirHoja(tester);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Disco dañado por golpe',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Cambio de disco',
      );
      await tester.tap(enHoja(find.widgetWithText(FilledButton, 'Completar')));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(enHoja(find.text(ApiException.mensajeServidor)), findsOneWidget);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byType(TextFormField).at(0),
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        'Disco dañado por golpe',
      );
    });
  });

  group('cancelar', () {
    Future<void> abrirDialogo(WidgetTester tester) async {
      await abrirDetalle(tester, EstadoOrden.enProceso);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar orden'));
      await tester.pumpAndSettle();
    }

    testWidgets('avisa que no se puede deshacer y valida el motivo', (
      tester,
    ) async {
      await abrirDialogo(tester);
      expect(find.text('Esta acción no se puede deshacer.'), findsOneWidget);

      final confirmar = enDialogo(
        find.widgetWithText(FilledButton, 'Cancelar orden'),
      );
      await tester.tap(confirmar);
      await tester.pump();
      expect(find.text('Escribe el motivo de la cancelación'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), ' abc ');
      await tester.tap(confirmar);
      await tester.pump();
      expect(find.text('Debe tener al menos 5 caracteres'), findsOneWidget);
      expect(repo.cambiosEstado, isEmpty);
    });

    testWidgets('«Volver» cierra sin enviar nada', (tester) async {
      await abrirDialogo(tester);
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(repo.cambiosEstado, isEmpty);
    });

    testWidgets('al confirmar con motivo válido cancela la orden', (
      tester,
    ) async {
      await abrirDialogo(tester);
      await tester.enterText(find.byType(TextFormField), '  Ya no hace falta ');
      await tester.tap(
        enDialogo(find.widgetWithText(FilledButton, 'Cancelar orden')),
      );
      await tester.pumpAndSettle();

      expect(repo.cambiosEstado.single['motivo'], 'Ya no hace falta');
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Cancelada'), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, 'Cancelar orden'),
        findsNothing,
      );
      expect(repoEquipos.llamadas, ['listarEquipos']);
    });
  });

  testWidgets('un 400 muestra el mensaje y el estado real de la orden', (
    tester,
  ) async {
    await abrirDetalle(tester, EstadoOrden.creada);
    repo.errorAccion = const ApiException(
      'La orden ya fue iniciada por otra persona',
      codigoEstado: 400,
    );
    repo.detalle = ordenPrueba(1, estado: EstadoOrden.enProceso);

    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar'));
    await tester.pumpAndSettle();
    await tester.tap(enDialogo(find.widgetWithText(FilledButton, 'Iniciar')));
    await tester.pumpAndSettle();

    expect(
      find.text('La orden ya fue iniciada por otra persona'),
      findsOneWidget,
    );
    expect(find.text('En proceso'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Iniciar'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Completar'), findsOneWidget);
    expect(repo.llamadas, ['iniciarOrden:1', 'obtenerOrden:1']);
  });

  testWidgets('mientras la acción está en curso los botones se bloquean', (
    tester,
  ) async {
    await abrirDetalle(tester, EstadoOrden.creada);
    repo.esperaAccion = Completer<void>();

    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar'));
    await tester.pumpAndSettle();
    await tester.tap(enDialogo(find.widgetWithText(FilledButton, 'Iniciar')));
    // Deja que el diálogo termine de cerrarse (el indicador sigue girando).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AlertDialog), findsNothing);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();
    expect(repo.cambiosEstado, hasLength(1));

    repo.esperaAccion!.complete();
    await tester.pumpAndSettle();
    expect(repo.cambiosEstado, hasLength(1));
    expect(find.text('En proceso'), findsOneWidget);
  });
}
