import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mantenimiento_dtsi/controllers/auth_controller.dart';
import 'package:mantenimiento_dtsi/controllers/equipos_controller.dart';
import 'package:mantenimiento_dtsi/controllers/ordenes_controller.dart';
import 'package:mantenimiento_dtsi/models/equipo.dart';
import 'package:mantenimiento_dtsi/repositories/orden_repository.dart';
import 'package:mantenimiento_dtsi/screens/pantalla_formulario_orden.dart';
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

  final etiquetaEquipo1 = 'DTSI-1 · Dell Latitude 5420';

  /// Abre la lista de órdenes y, con el botón «+», el formulario.
  Future<void> abrir(WidgetTester tester, {bool cargarEquipos = true}) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final auth = Get.put(AuthController(RepositorioFalso(), navegar: (_) {}));
    auth.usuario.value = usuarioPrueba;
    final equipos = Get.put(EquiposController(repoEquipos, auth));
    if (cargarEquipos) await equipos.cargar();
    Get.put<OrdenRepository>(repo);
    Get.put(OrdenesController(repo, auth, equipos: equipos));
    await tester.pumpWidget(
      GetMaterialApp(
        theme: TemaApp.claro,
        home: const PantallaOrdenes(),
        getPages: [
          GetPage(
            name: Rutas.nuevaOrden,
            page: () => const PantallaFormularioOrden(),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byTooltip('Nueva orden'));
    await tester.pumpAndSettle();
  }

  Future<void> elegirEquipo(WidgetTester tester) async {
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(etiquetaEquipo1).last);
    await tester.pumpAndSettle();
  }

  Future<void> escribir(WidgetTester tester, String texto) async {
    await tester.enterText(find.byType(TextFormField), texto);
    await tester.pump();
  }

  Future<void> crear(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Crear orden'));
    await tester.pump();
  }

  setUp(() {
    repo = RepositorioOrdenesFalso()..ordenes = [ordenPrueba(1)];
    repoEquipos = RepositorioEquiposFalso()
      ..equipos = [
        equipoPrueba(1),
        equipoPrueba(2, estado: EstadoEquipo.dadoDeBaja, marca: 'HP'),
      ];
  });
  tearDown(Get.reset);

  testWidgets('el botón «+» abre el formulario con los valores por defecto', (
    tester,
  ) async {
    await abrir(tester);
    expect(find.text('Nueva orden'), findsOneWidget);
    expect(find.text('Correctivo'), findsOneWidget);
    expect(find.text('Media'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Crear orden'), findsOneWidget);
  });

  testWidgets('el selector no ofrece equipos dados de baja', (tester) async {
    await abrir(tester);
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    expect(find.text(etiquetaEquipo1), findsWidgets);
    expect(find.textContaining('DTSI-2'), findsNothing);
  });

  testWidgets('valida equipo y descripción antes de enviar', (tester) async {
    await abrir(tester);
    await crear(tester);
    expect(find.text('Selecciona un equipo'), findsOneWidget);
    expect(find.text('Describe el problema'), findsOneWidget);

    await elegirEquipo(tester);
    await escribir(tester, 'corto');
    await crear(tester);
    expect(find.text('Selecciona un equipo'), findsNothing);
    expect(find.text('Debe tener al menos 10 caracteres'), findsOneWidget);
    expect(repo.llamadas, isNot(contains('crearOrden')));
  });

  testWidgets('envía, vuelve a la lista y muestra «Orden creada»', (
    tester,
  ) async {
    repo.creada = ordenPrueba(50, equipoId: 1);
    await abrir(tester);
    await elegirEquipo(tester);
    await escribir(tester, 'La pantalla no enciende');
    await crear(tester);
    await tester.pumpAndSettle();

    expect(repo.creaciones, hasLength(1));
    expect(repo.creaciones.single['equipoId'], 1);
    expect(repo.creaciones.single['descripcion'], 'La pantalla no enciende');
    expect(find.byType(PantallaFormularioOrden), findsNothing);
    expect(find.text('Orden creada'), findsOneWidget);
    expect(find.text('OT-50'), findsOneWidget);
    expect(find.text('OT-1'), findsOneWidget);
    // La lista ya estaba cargada: se insertó sin pedirla otra vez.
    expect(repo.llamadas, ['listarOrdenes', 'crearOrden']);
  });

  testWidgets('bloquea el botón mientras se envía y no envía dos veces', (
    tester,
  ) async {
    repo.espera = Completer<void>();
    await abrir(tester);
    await elegirEquipo(tester);
    await escribir(tester, 'La pantalla no enciende');
    await crear(tester);

    final boton = find.byType(FilledButton);
    expect(tester.widget<FilledButton>(boton).onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(boton, warnIfMissed: false);
    await tester.pump();
    expect(repo.creaciones, hasLength(1));

    repo.espera!.complete();
    await tester.pumpAndSettle();
    expect(repo.creaciones, hasLength(1));
    expect(find.byType(PantallaFormularioOrden), findsNothing);
  });

  testWidgets('un error del servidor se muestra y se queda en el formulario', (
    tester,
  ) async {
    repo.errorCrear = const ApiException(
      'El equipo está dado de baja',
      codigoEstado: 400,
    );
    await abrir(tester);
    await elegirEquipo(tester);
    await escribir(tester, 'La pantalla no enciende');
    await crear(tester);
    await tester.pump();

    expect(find.text('El equipo está dado de baja'), findsOneWidget);
    expect(find.byType(PantallaFormularioOrden), findsOneWidget);
    expect(find.text('Orden creada'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('sin equipos cargados los pide y muestra «Reintentar» si falla', (
    tester,
  ) async {
    repoEquipos.error = const ApiException(ApiException.mensajeSinConexion);
    await abrir(tester, cargarEquipos: false);
    expect(find.text(ApiException.mensajeSinConexion), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Crear orden'),
          )
          .onPressed,
      isNull,
    );

    repoEquipos.error = null;
    await tester.tap(find.widgetWithText(FilledButton, 'Reintentar'));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
    expect(repoEquipos.llamadas, ['listarEquipos', 'listarEquipos']);
  });

  testWidgets('sin equipos elegibles muestra el estado vacío', (tester) async {
    repoEquipos.equipos = [equipoPrueba(2, estado: EstadoEquipo.dadoDeBaja)];
    await abrir(tester);
    expect(find.text('No hay equipos disponibles'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<int>), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });
}
