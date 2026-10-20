import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mantenimiento_dtsi/controllers/auth_controller.dart';
import 'package:mantenimiento_dtsi/controllers/equipos_controller.dart';
import 'package:mantenimiento_dtsi/controllers/favoritos_controller.dart';
import 'package:mantenimiento_dtsi/screens/pantalla_favoritos.dart';
import 'package:mantenimiento_dtsi/services/api_exception.dart';
import 'package:mantenimiento_dtsi/theme/tema_app.dart';

import '../utils/almacen_favoritos_falso.dart';
import '../utils/repositorio_equipos_falso.dart';
import '../utils/repositorio_falso.dart';

void main() {
  late RepositorioEquiposFalso repo;
  late AlmacenFavoritosFalso almacen;
  late EquiposController equipos;
  late FavoritosController favoritos;

  Future<void> abrir(WidgetTester tester) async {
    final auth = Get.put(AuthController(RepositorioFalso(), navegar: (_) {}));
    auth.usuario.value = usuarioPrueba;
    equipos = Get.put(EquiposController(repo, auth));
    favoritos = Get.put(FavoritosController(almacen, auth));
    await favoritos.cargar();
    await equipos.cargar();
    await tester.pumpWidget(
      GetMaterialApp(theme: TemaApp.claro, home: const PantallaFavoritos()),
    );
    await tester.pump();
  }

  setUp(() {
    repo = RepositorioEquiposFalso();
    almacen = AlmacenFavoritosFalso();
  });
  tearDown(Get.reset);

  testWidgets('sin favoritos muestra el mensaje de vacío', (tester) async {
    repo.equipos = [equipoPrueba(1)];
    await abrir(tester);

    expect(find.text('Aún no tienes favoritos'), findsOneWidget);
    expect(find.text('Marca equipos con la estrella.'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('muestra solo las tarjetas de los equipos favoritos', (
    tester,
  ) async {
    repo.equipos = [equipoPrueba(1), equipoPrueba(2), equipoPrueba(3)];
    almacen.datos[usuarioPrueba.id] = {2, 3};
    await abrir(tester);

    expect(find.byType(Card), findsNWidgets(2));
    expect(find.text('DTSI-2'), findsOneWidget);
    expect(find.text('DTSI-1'), findsNothing);
  });

  testWidgets('un favorito que ya no existe no se muestra pero se conserva', (
    tester,
  ) async {
    repo.equipos = [equipoPrueba(1)];
    almacen.datos[usuarioPrueba.id] = {1, 99};
    await abrir(tester);

    expect(find.byType(Card), findsOneWidget);
    expect(favoritos.ids, {1, 99});
  });

  testWidgets('si ningún favorito está en la lista no dice que no hay', (
    tester,
  ) async {
    repo.equipos = [equipoPrueba(1)];
    almacen.datos[usuarioPrueba.id] = {99};
    await abrir(tester);

    expect(find.text('Aún no tienes favoritos'), findsNothing);
    expect(
      find.text('Tus favoritos no están en la lista actual'),
      findsOneWidget,
    );
    expect(favoritos.ids, {99});
  });

  testWidgets('sin conexión usa la caché y avisa con la fecha', (tester) async {
    repo.equipos = [equipoPrueba(1), equipoPrueba(2)];
    repo.desdeCache = DateTime(2026, 10, 20, 8, 30);
    almacen.datos[usuarioPrueba.id] = {2};
    await abrir(tester);

    expect(find.byType(Card), findsOneWidget);
    expect(find.text('DTSI-2'), findsOneWidget);
    expect(
      find.text(
        'Sin conexión — datos guardados (última sincronización: 20/10 08:30)',
      ),
      findsOneWidget,
    );
  });

  testWidgets('quitar la estrella saca la tarjeta de la pestaña', (
    tester,
  ) async {
    repo.equipos = [equipoPrueba(1)];
    almacen.datos[usuarioPrueba.id] = {1};
    await abrir(tester);

    await tester.tap(find.byTooltip('Quitar de favoritos'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(Card), findsNothing);
    expect(find.text('Aún no tienes favoritos'), findsOneWidget);
  });

  testWidgets('si la lista falla muestra el error con «Reintentar»', (
    tester,
  ) async {
    repo.error = const ApiException(ApiException.mensajeServidor);
    await abrir(tester);

    expect(find.text(ApiException.mensajeServidor), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Reintentar'), findsOneWidget);
  });
}
