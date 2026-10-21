import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mantenimiento_dtsi/controllers/auth_controller.dart';
import 'package:mantenimiento_dtsi/controllers/equipos_controller.dart';
import 'package:mantenimiento_dtsi/controllers/seguimiento_controller.dart';
import 'package:mantenimiento_dtsi/models/equipo.dart';
import 'package:mantenimiento_dtsi/screens/pantalla_equipos.dart';
import 'package:mantenimiento_dtsi/services/api_exception.dart';
import 'package:mantenimiento_dtsi/theme/tema_app.dart';

import '../utils/almacen_seguimiento_falso.dart';
import '../utils/repositorio_equipos_falso.dart';
import '../utils/repositorio_falso.dart';

void main() {
  late RepositorioEquiposFalso repo;
  late AlmacenSeguimientoFalso almacen;

  Future<void> abrir(WidgetTester tester) async {
    final auth = Get.put(AuthController(RepositorioFalso(), navegar: (_) {}));
    auth.usuario.value = usuarioPrueba;
    Get.put(EquiposController(repo, auth));
    Get.put(SeguimientoController(almacen, auth));
    await tester.pumpWidget(
      GetMaterialApp(theme: TemaApp.claro, home: const PantallaEquipos()),
    );
    await tester.pump();
    await tester.pump();
  }

  setUp(() {
    repo = RepositorioEquiposFalso();
    almacen = AlmacenSeguimientoFalso();
  });
  tearDown(Get.reset);

  testWidgets('muestra una tarjeta por equipo con sus datos', (tester) async {
    repo.equipos = [
      equipoPrueba(1),
      equipoPrueba(
        2,
        marca: 'HP',
        modelo: 'ProBook',
        sede: 'Norte',
        estado: EstadoEquipo.fueraDeServicio,
      ),
    ];
    await abrir(tester);

    expect(find.byType(Card), findsNWidgets(2));
    expect(find.text('DTSI-1'), findsOneWidget);
    expect(find.text('HP ProBook'), findsOneWidget);
    expect(find.text('Norte'), findsOneWidget);
    expect(find.text('Fuera de servicio'), findsWidgets);
  });

  testWidgets('sin equipos muestra el estado vacío', (tester) async {
    await abrir(tester);
    expect(find.text('Aún no hay equipos registrados'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('una búsqueda sin resultados muestra otro mensaje y limpia', (
    tester,
  ) async {
    repo.equipos = [equipoPrueba(1)];
    await abrir(tester);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text('Ningún equipo coincide'), findsOneWidget);
    expect(find.text('Aún no hay equipos registrados'), findsNothing);

    await tester.tap(find.text('Limpiar filtros'));
    await tester.pump();
    expect(find.byType(Card), findsOneWidget);
  });

  testWidgets('el chip de estado filtra la lista', (tester) async {
    repo.equipos = [
      equipoPrueba(1),
      equipoPrueba(2, estado: EstadoEquipo.asignado),
    ];
    await abrir(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Asignado (1)'));
    await tester.pump();
    expect(find.byType(Card), findsOneWidget);
    expect(find.text('DTSI-2'), findsOneWidget);
  });

  testWidgets('el error muestra «Reintentar» y recarga', (tester) async {
    repo.error = const ApiException(ApiException.mensajeSinConexion);
    await abrir(tester);
    expect(find.text(ApiException.mensajeSinConexion), findsOneWidget);

    repo.error = null;
    repo.equipos = [equipoPrueba(1)];
    await tester.tap(find.widgetWithText(FilledButton, 'Reintentar'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(Card), findsOneWidget);
    expect(repo.llamadas, ['listarEquipos', 'listarEquipos']);
  });

  testWidgets('los chips muestran el conteo, también con (0)', (tester) async {
    repo.equipos = [
      equipoPrueba(1),
      equipoPrueba(2, estado: EstadoEquipo.asignado),
      equipoPrueba(3, estado: EstadoEquipo.asignado),
    ];
    // Pantalla ancha para que se construyan todos los chips de la fila.
    tester.view.physicalSize = const Size(2000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await abrir(tester);

    expect(find.text('Todos (3)'), findsOneWidget);
    expect(find.text('Disponible (1)'), findsOneWidget);
    expect(find.text('Asignado (2)'), findsOneWidget);
    expect(find.text('Dado de baja (0)'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'DTSI-2');
    await tester.pump();
    expect(find.text('Todos (1)'), findsOneWidget);
    expect(find.text('Disponible (0)'), findsOneWidget);
    expect(find.text('Asignado (1)'), findsOneWidget);
  });

  testWidgets('el marcador sigue y deja de seguir un equipo', (tester) async {
    repo.equipos = [equipoPrueba(1)];
    await abrir(tester);

    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    await tester.tap(find.byTooltip('Seguir equipo'));
    await tester.pump();
    await tester.pump();
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(almacen.datos[usuarioPrueba.id], {1});

    await tester.tap(find.byTooltip('Dejar de seguir'));
    await tester.pump();
    await tester.pump();
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    expect(almacen.datos[usuarioPrueba.id], isEmpty);
  });

  testWidgets('los datos de la caché muestran el aviso con la fecha', (
    tester,
  ) async {
    repo.equipos = [equipoPrueba(1)];
    repo.desdeCache = DateTime(2026, 10, 20, 14, 5);
    await abrir(tester);

    expect(
      find.text(
        'Sin conexión — datos guardados (última sincronización: 20/10 14:05)',
      ),
      findsOneWidget,
    );
    expect(find.byType(Card), findsOneWidget);

    // «Reintentar» del aviso vuelve a pedir los datos; ya con red, desaparece.
    repo.desdeCache = null;
    await tester.tap(find.widgetWithText(TextButton, 'Reintentar'));
    await tester.pump();
    await tester.pump();
    expect(repo.llamadas, ['listarEquipos', 'listarEquipos']);
    expect(find.textContaining('Sin conexión'), findsNothing);
  });

  testWidgets('con datos frescos no hay aviso de caché', (tester) async {
    repo.equipos = [equipoPrueba(1)];
    await abrir(tester);
    expect(find.textContaining('Sin conexión'), findsNothing);
  });
}
