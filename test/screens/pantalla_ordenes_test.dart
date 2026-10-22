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

  Future<void> abrir(WidgetTester tester) async {
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
  }

  setUp(() {
    repo = RepositorioOrdenesFalso();
    repoEquipos = RepositorioEquiposFalso();
  });
  tearDown(Get.reset);

  testWidgets('muestra una tarjeta por orden con sus datos', (tester) async {
    repo.ordenes = [
      ordenPrueba(1),
      ordenPrueba(2, estado: EstadoOrden.cancelada),
    ];
    await abrir(tester);
    expect(find.byType(Card), findsNWidgets(2));
    expect(find.text('OT-1'), findsOneWidget);
    expect(find.text('Cancelada'), findsWidgets);
  });

  testWidgets('con el equipo cargado la tarjeta muestra código y nombre', (
    tester,
  ) async {
    repoEquipos.equipos = [equipoPrueba(1, marca: 'HP', modelo: 'ProBook')];
    repo.ordenes = [ordenPrueba(1, equipoId: 1)];
    await abrir(tester);
    expect(find.text('DTSI-1 · HP ProBook'), findsOneWidget);
  });

  testWidgets('sin el equipo cargado la tarjeta muestra «Equipo #id»', (
    tester,
  ) async {
    repo.ordenes = [ordenPrueba(1, equipoId: 9)];
    await abrir(tester);
    expect(find.text('Equipo #9'), findsOneWidget);
  });

  testWidgets('sin órdenes muestra el estado vacío', (tester) async {
    await abrir(tester);
    expect(find.text('Aún no hay órdenes registradas'), findsOneWidget);
  });

  testWidgets('el error muestra «Reintentar» y recarga', (tester) async {
    repo.error = const ApiException(ApiException.mensajeSinConexion);
    await abrir(tester);
    expect(find.text(ApiException.mensajeSinConexion), findsOneWidget);

    repo.error = null;
    repo.ordenes = [ordenPrueba(1)];
    await tester.tap(find.widgetWithText(FilledButton, 'Reintentar'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(Card), findsOneWidget);
    expect(repo.llamadas, ['listarOrdenes', 'listarOrdenes']);
  });

  testWidgets('los chips muestran el conteo y filtran por estado', (
    tester,
  ) async {
    repo.ordenes = [
      ordenPrueba(1),
      ordenPrueba(2, estado: EstadoOrden.enProceso),
      ordenPrueba(3, estado: EstadoOrden.enProceso),
    ];
    await abrir(tester);
    expect(find.text('Todos (3)'), findsOneWidget);
    expect(find.text('En proceso (2)'), findsOneWidget);
    expect(find.text('Asignada (0)'), findsOneWidget);

    await tester.tap(find.text('En proceso (2)'));
    await tester.pump();
    expect(find.byType(Card), findsNWidgets(2));

    await tester.tap(find.text('Asignada (0)'));
    await tester.pump();
    expect(find.text('Ninguna orden coincide'), findsOneWidget);
    await tester.tap(find.text('Limpiar filtros'));
    await tester.pump();
    expect(find.byType(Card), findsNWidgets(3));
  });

  testWidgets('una orden con estado desconocido se muestra sin romper', (
    tester,
  ) async {
    repo.ordenes = [ordenPrueba(1, estado: EstadoOrden.desconocido)];
    await abrir(tester);
    expect(find.text('Desconocido'), findsOneWidget);
    expect(find.text('Todos (1)'), findsOneWidget);
  });

  testWidgets('tocar una orden abre el detalle y lo refresca', (tester) async {
    repoEquipos.equipos = [equipoPrueba(1, marca: 'HP', modelo: 'ProBook')];
    repo.ordenes = [ordenPrueba(1, equipoId: 1)];
    repo.detalle = Orden(
      id: 1,
      codigoOrden: 'OT-1',
      equipoId: 1,
      estado: EstadoOrden.completada,
      diagnostico: 'Fuente dañada',
    );
    await abrir(tester);
    await tester.tap(find.text('OT-1'));
    await tester.pumpAndSettle();

    expect(find.byType(PantallaDetalleOrden), findsOneWidget);
    expect(find.text('Fuente dañada'), findsOneWidget);
    expect(find.text('DTSI-1 · HP ProBook'), findsWidgets);
    expect(repo.llamadas, ['listarOrdenes', 'obtenerOrden:1']);
  });
}
