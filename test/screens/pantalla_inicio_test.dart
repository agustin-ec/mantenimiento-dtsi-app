import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:mantenimiento_dtsi/controllers/asistente_controller.dart';
import 'package:mantenimiento_dtsi/controllers/auth_controller.dart';
import 'package:mantenimiento_dtsi/controllers/equipos_controller.dart';
import 'package:mantenimiento_dtsi/controllers/ordenes_controller.dart';
import 'package:mantenimiento_dtsi/controllers/seguimiento_controller.dart';
import 'package:mantenimiento_dtsi/controllers/tema_controller.dart';
import 'package:mantenimiento_dtsi/screens/pantalla_asistente.dart';
import 'package:mantenimiento_dtsi/screens/pantalla_inicio.dart';
import 'package:mantenimiento_dtsi/screens/pantalla_perfil.dart';
import 'package:mantenimiento_dtsi/services/api_exception.dart';
import 'package:mantenimiento_dtsi/theme/tema_app.dart';

import '../utils/almacen_seguimiento_falso.dart';
import '../utils/hive_temporal.dart';
import '../utils/repositorio_asistente_falso.dart';
import '../utils/repositorio_equipos_falso.dart';
import '../utils/repositorio_falso.dart';
import '../utils/repositorio_ordenes_falso.dart';

void main() {
  late Future<void> Function() limpiarHive;
  late Box caja;
  late RepositorioEquiposFalso repoEquipos;
  late EquiposController equipos;

  setUpAll(() async {
    limpiarHive = await iniciarHiveTemporal();
    caja = await Hive.openBox(TemaController.nombreCaja);
  });

  tearDownAll(() => limpiarHive());

  Future<void> abrir(WidgetTester tester) async {
    final auth = Get.put(AuthController(RepositorioFalso(), navegar: (_) {}));
    auth.usuario.value = usuarioPrueba;
    equipos = Get.put(EquiposController(repoEquipos, auth));
    Get.put(OrdenesController(RepositorioOrdenesFalso(), auth));
    Get.put(SeguimientoController(AlmacenSeguimientoFalso(), auth));
    Get.put(AsistenteController(RepositorioAsistenteFalso(), auth));
    Get.put(TemaController(caja));
    await tester.pumpWidget(
      GetMaterialApp(theme: TemaApp.claro, home: const PantallaInicio()),
    );
    await tester.pump();
  }

  Finder destino(String etiqueta) => find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(etiqueta),
  );

  setUp(() => repoEquipos = RepositorioEquiposFalso());
  tearDown(Get.reset);

  testWidgets('la barra tiene las cinco pestañas en orden', (tester) async {
    await abrir(tester);

    final etiquetas = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((d) => d.label);
    expect(etiquetas, [
      'Equipos',
      'Mis equipos',
      'Órdenes',
      'Asistente',
      'Perfil',
    ]);
  });

  testWidgets('la pestaña «Asistente» abre su pantalla y «Perfil» sigue', (
    tester,
  ) async {
    await abrir(tester);
    expect(find.byType(PantallaAsistente), findsNothing);

    await tester.tap(destino('Asistente'));
    await tester.pump();
    expect(find.byType(PantallaAsistente), findsOneWidget);

    await tester.tap(destino('Perfil'));
    await tester.pump();
    expect(find.byType(PantallaAsistente), findsNothing);
    expect(find.byType(PantallaPerfil), findsOneWidget);
  });

  testWidgets('«Equipos» y «Mis equipos» siguen actualizando los equipos', (
    tester,
  ) async {
    await abrir(tester);
    repoEquipos.error = const ApiException(ApiException.mensajeSinConexion);
    equipos.marcarDesactualizados();
    await tester.pump();
    repoEquipos.error = null;
    repoEquipos.llamadas.clear();

    await tester.tap(destino('Mis equipos'));
    await tester.pump();

    expect(repoEquipos.llamadas, ['listarEquipos']);
  });
}
