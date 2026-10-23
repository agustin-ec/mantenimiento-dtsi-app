import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mantenimiento_dtsi/controllers/auth_controller.dart';
import 'package:mantenimiento_dtsi/controllers/equipos_controller.dart';
import 'package:mantenimiento_dtsi/controllers/ordenes_controller.dart';
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

  /// Abre la lista y el detalle de OT-1, elimina la orden y vuelve a la lista.
  Future<void> eliminarDesdeDetalle(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    repo.ordenes = [ordenPrueba(1), ordenPrueba(2)];
    final auth = Get.put(AuthController(RepositorioFalso(), navegar: (_) {}));
    auth.usuario.value = usuarioPrueba;
    final equipos = Get.put(
      EquiposController(
        RepositorioEquiposFalso()..equipos = [equipoPrueba(1)],
        auth,
      ),
    );
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

    await tester.tap(find.widgetWithText(TextButton, 'Eliminar orden'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Eliminar orden'),
      ),
    );
    // Deja terminar la transición de vuelta a la lista, sin dejar pasar los
    // 3 segundos del aviso.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  setUp(() => repo = RepositorioOrdenesFalso());
  tearDown(Get.reset);

  testWidgets('tras eliminar, el aviso sigue visible sobre la lista', (
    tester,
  ) async {
    await eliminarDesdeDetalle(tester);

    expect(find.byType(PantallaDetalleOrden), findsNothing);
    expect(find.text('OT-1'), findsNothing);
    expect(find.text('OT-2'), findsOneWidget);
    expect(find.text('Orden eliminada'), findsOneWidget);

    // Dura unos 3 segundos: sigue ahí a los ~2.6 s y ya no pasados ~3.5 s (con la duración por defecto de 4 s seguiría).
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Orden eliminada'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Orden eliminada'), findsNothing);
  });

  testWidgets('tras un 404, «La orden ya no existe» sigue visible', (
    tester,
  ) async {
    repo.errorAccion = const ApiException(
      'Orden no encontrada',
      codigoEstado: 404,
    );
    await eliminarDesdeDetalle(tester);

    expect(find.byType(PantallaDetalleOrden), findsNothing);
    expect(find.text('La orden ya no existe'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('La orden ya no existe'), findsOneWidget);
  });
}
