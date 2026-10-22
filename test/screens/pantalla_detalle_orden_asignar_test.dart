import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mantenimiento_dtsi/controllers/auth_controller.dart';
import 'package:mantenimiento_dtsi/controllers/equipos_controller.dart';
import 'package:mantenimiento_dtsi/controllers/ordenes_controller.dart';
import 'package:mantenimiento_dtsi/controllers/tecnicos_controller.dart';
import 'package:mantenimiento_dtsi/models/orden.dart';
import 'package:mantenimiento_dtsi/models/tecnico.dart';
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

Orden _conTecnico(int id, int? tecnicoId, EstadoOrden estado) => Orden(
  id: id,
  codigoOrden: 'OT-$id',
  equipoId: 1,
  solicitanteId: 1,
  tecnicoId: tecnicoId,
  tipo: TipoMantenimiento.correctivo,
  prioridad: PrioridadOrden.alta,
  estado: estado,
  descripcionProblema: 'La pantalla no enciende',
  fechaSolicitud: DateTime.utc(2026, 9, 20, 10),
);

void main() {
  late RepositorioOrdenesFalso repo;
  late RepositorioEquiposFalso repoEquipos;

  /// Abre la lista y, al tocar la tarjeta, el detalle de la orden OT-1.
  Future<void> abrirDetalle(
    WidgetTester tester, {
    String rol = 'admin',
    EstadoOrden estado = EstadoOrden.creada,
    int? tecnicoId,
  }) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    repo.ordenes = [_conTecnico(1, tecnicoId, estado)];
    final auth = Get.put(AuthController(RepositorioFalso(), navegar: (_) {}));
    auth.usuario.value = Usuario(
      id: 1,
      email: 'a@utb.edu.ec',
      nombreCompleto: 'Ana Pérez',
      rol: rol,
    );
    final equipos = Get.put(EquiposController(repoEquipos, auth));
    await equipos.cargar();
    Get.put<OrdenRepository>(repo);
    Get.put(OrdenesController(repo, auth, equipos: equipos));
    Get.put(TecnicosController(repo, auth));
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

  Finder enHoja(Finder f) =>
      find.descendant(of: find.byType(BottomSheet), matching: f);

  Finder botonAsignar() => enHoja(find.widgetWithText(FilledButton, 'Asignar'));

  setUp(() {
    repo = RepositorioOrdenesFalso()
      ..tecnicos = [
        const Tecnico(id: 4, nombreCompleto: 'Ana Ruiz'),
        const Tecnico(id: 5, nombreCompleto: 'Luis Mora'),
      ];
    repoEquipos = RepositorioEquiposFalso()..equipos = [equipoPrueba(1)];
  });
  tearDown(Get.reset);

  group('visibilidad de la acción', () {
    for (final estado in EstadoOrden.values) {
      final visible =
          estado == EstadoOrden.creada || estado == EstadoOrden.asignada;
      testWidgets('admin, ${estado.name}: ${visible ? 'visible' : 'oculta'}', (
        tester,
      ) async {
        await abrirDetalle(tester, estado: estado);
        expect(
          find.text('Asignar técnico'),
          visible ? findsOneWidget : findsNothing,
        );
      });
    }

    testWidgets('un técnico no la ve en una orden ASIGNADA', (tester) async {
      await abrirDetalle(
        tester,
        rol: 'tecnico_dtsi',
        estado: EstadoOrden.asignada,
        tecnicoId: 4,
      );
      expect(find.text('Asignar técnico'), findsNothing);
      expect(find.text('Reasignar'), findsNothing);
    });

    testWidgets('un técnico tampoco la ve en una orden CREADA', (tester) async {
      await abrirDetalle(tester, rol: 'tecnico_dtsi');
      expect(find.text('Asignar técnico'), findsNothing);
      expect(find.text('Reasignar'), findsNothing);
    });

    testWidgets('con técnico ya asignado el texto es «Reasignar»', (
      tester,
    ) async {
      await abrirDetalle(tester, estado: EstadoOrden.asignada, tecnicoId: 4);
      expect(find.text('Reasignar'), findsOneWidget);
      expect(find.text('Asignar técnico'), findsNothing);
    });
  });

  group('hoja de selección', () {
    testWidgets('lista los técnicos y «Asignar» espera una elección', (
      tester,
    ) async {
      await abrirDetalle(tester);
      await tester.tap(find.text('Asignar técnico'));
      await tester.pumpAndSettle();

      expect(repo.llamadas, ['listarTecnicos']);
      expect(enHoja(find.text('Ana Ruiz')), findsOneWidget);
      expect(enHoja(find.text('Luis Mora')), findsOneWidget);
      expect(tester.widget<FilledButton>(botonAsignar()).onPressed, isNull);

      await tester.tap(enHoja(find.text('Luis Mora')));
      await tester.pump();
      expect(tester.widget<FilledButton>(botonAsignar()).onPressed, isNotNull);
    });

    testWidgets('el técnico actual viene preseleccionado', (tester) async {
      await abrirDetalle(tester, estado: EstadoOrden.asignada, tecnicoId: 5);
      await tester.tap(find.text('Reasignar'));
      await tester.pumpAndSettle();

      final radio = tester.widget<RadioListTile<int>>(
        find.widgetWithText(RadioListTile<int>, 'Luis Mora'),
      );
      expect(radio.value, 5);
      final grupo = tester.widget<RadioGroup<int>>(
        find.byType(RadioGroup<int>),
      );
      expect(grupo.groupValue, 5);
    });

    testWidgets('al asignar muestra la orden actualizada y el nombre', (
      tester,
    ) async {
      repo.resultadoAccion = _conTecnico(1, 5, EstadoOrden.asignada);
      await abrirDetalle(tester);
      await tester.tap(find.text('Asignar técnico'));
      await tester.pumpAndSettle();
      await tester.tap(enHoja(find.text('Luis Mora')));
      await tester.pump();
      await tester.tap(botonAsignar());
      await tester.pumpAndSettle();

      expect(repo.cambiosEstado.single['tecnicoId'], 5);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Asignada'), findsWidgets);
      expect(find.text('Luis Mora'), findsOneWidget);
      expect(find.text('Reasignar'), findsOneWidget);
      expect(Get.find<OrdenesController>().ordenes.single.tecnicoId, 5);
      expect(repoEquipos.llamadas, ['listarEquipos']);
    });

    testWidgets('un 403 deja la hoja abierta con el mensaje', (tester) async {
      repo.errorAccion = const ApiException(
        'Permisos insuficientes',
        codigoEstado: 403,
      );
      await abrirDetalle(tester);
      await tester.tap(find.text('Asignar técnico'));
      await tester.pumpAndSettle();
      await tester.tap(enHoja(find.text('Ana Ruiz')));
      await tester.pump();
      await tester.tap(botonAsignar());
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(enHoja(find.text('Permisos insuficientes')), findsOneWidget);
    });

    testWidgets('error de la lista: «Reintentar» la vuelve a pedir', (
      tester,
    ) async {
      repo.errorTecnicos = const ApiException('Sin conexión');
      await abrirDetalle(tester);
      await tester.tap(find.text('Asignar técnico'));
      await tester.pumpAndSettle();
      expect(enHoja(find.text('Sin conexión')), findsOneWidget);

      repo.errorTecnicos = null;
      await tester.tap(enHoja(find.text('Reintentar')));
      await tester.pumpAndSettle();
      expect(enHoja(find.text('Ana Ruiz')), findsOneWidget);
      expect(repo.llamadas.where((l) => l == 'listarTecnicos'), hasLength(2));
    });

    testWidgets('lista vacía muestra el estado vacío', (tester) async {
      repo.tecnicos = [];
      await abrirDetalle(tester);
      await tester.tap(find.text('Asignar técnico'));
      await tester.pumpAndSettle();
      expect(enHoja(find.text('No hay técnicos disponibles')), findsOneWidget);
    });

    testWidgets('mientras carga muestra el indicador de progreso', (
      tester,
    ) async {
      repo.esperaTecnicos = Completer<void>();
      await abrirDetalle(tester);
      await tester.tap(find.text('Asignar técnico'));
      await tester.pump();
      await tester.pump();
      expect(enHoja(find.byType(CircularProgressIndicator)), findsOneWidget);
      repo.esperaTecnicos!.complete();
      await tester.pumpAndSettle();
      expect(enHoja(find.text('Ana Ruiz')), findsOneWidget);
    });
  });

  group('nombre del técnico en el detalle', () {
    testWidgets('sin lista en memoria muestra «Técnico #id» y no la pide', (
      tester,
    ) async {
      await abrirDetalle(tester, estado: EstadoOrden.asignada, tecnicoId: 4);
      expect(find.text('Técnico #4'), findsOneWidget);
      expect(repo.llamadas, isNot(contains('listarTecnicos')));
    });

    testWidgets('con la lista cargada muestra el nombre', (tester) async {
      await abrirDetalle(tester, estado: EstadoOrden.asignada, tecnicoId: 4);
      await Get.find<TecnicosController>().cargar();
      await tester.pump();
      expect(find.text('Ana Ruiz'), findsOneWidget);
      expect(find.text('Técnico #4'), findsNothing);
    });
  });
}
