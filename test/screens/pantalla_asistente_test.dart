import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mantenimiento_dtsi/controllers/asistente_controller.dart';
import 'package:mantenimiento_dtsi/controllers/auth_controller.dart';
import 'package:mantenimiento_dtsi/repositories/asistente_repository.dart';
import 'package:mantenimiento_dtsi/screens/pantalla_asistente.dart';
import 'package:mantenimiento_dtsi/services/api_exception.dart';
import 'package:mantenimiento_dtsi/theme/tema_app.dart';
import 'package:mantenimiento_dtsi/widgets/burbuja_mensaje.dart';

import '../utils/repositorio_asistente_falso.dart';
import '../utils/repositorio_falso.dart';

void main() {
  late RepositorioAsistenteFalso repo;

  const ejemploMantenimiento = '¿Cuántos equipos hay en mantenimiento?';
  const ejemploProceso = '¿Qué órdenes están en proceso?';
  const ejemploDisponibles = '¿Cuántos equipos están disponibles?';
  const textoPensando = 'El asistente está escribiendo…';

  final campo = find.byType(TextField);
  final botonEnviar = find.widgetWithIcon(IconButton, Icons.send);

  Future<void> abrir(WidgetTester tester) async {
    final auth = Get.put(AuthController(RepositorioFalso(), navegar: (_) {}));
    auth.usuario.value = usuarioPrueba;
    Get.put(AsistenteController(repo, auth));
    await tester.pumpWidget(
      GetMaterialApp(theme: TemaApp.claro, home: const PantallaAsistente()),
    );
    await tester.pump();
  }

  Future<void> escribirYEnviar(WidgetTester tester, String texto) async {
    await tester.enterText(campo, texto);
    await tester.tap(botonEnviar);
    await tester.pumpAndSettle();
  }

  setUp(() => repo = RepositorioAsistenteFalso());
  tearDown(Get.reset);

  testWidgets('el estado vacío da la bienvenida y tres ejemplos', (
    tester,
  ) async {
    await abrir(tester);

    expect(find.textContaining('asistente de mantenimiento'), findsOneWidget);
    expect(find.byType(ActionChip), findsNWidgets(3));
    expect(find.text(ejemploMantenimiento), findsOneWidget);
    expect(find.text(ejemploProceso), findsOneWidget);
    expect(find.text(ejemploDisponibles), findsOneWidget);
    expect(find.byType(BurbujaMensaje), findsNothing);
  });

  testWidgets('tocar un ejemplo envía esa pregunta y muestra la conversación', (
    tester,
  ) async {
    await abrir(tester);

    await tester.tap(find.widgetWithText(ActionChip, ejemploDisponibles));
    await tester.pumpAndSettle();

    expect(repo.preguntas, [ejemploDisponibles]);
    expect(find.byType(ActionChip), findsNothing);
    expect(find.byType(BurbujaMensaje), findsNWidgets(2));
    expect(find.text(repo.respuesta), findsOneWidget);
  });

  testWidgets(
    'enviar muestra los dos mensajes con hora, cada uno de su lado, y vacía el campo',
    (tester) async {
      await abrir(tester);
      await escribirYEnviar(tester, '¿Cuántas órdenes hay?');

      final burbujas = find.byType(BurbujaMensaje);
      expect(burbujas, findsNWidgets(2));
      expect(find.text('¿Cuántas órdenes hay?'), findsOneWidget);
      expect(find.text(repo.respuesta), findsOneWidget);
      expect(
        find.textContaining(RegExp(r'\d{2}/\d{2} \d{2}:\d{2}')),
        findsNWidgets(2),
      );

      Finder globo(int i) => find
          .descendant(of: burbujas.at(i), matching: find.byType(Container))
          .first;
      expect(
        tester.getTopLeft(globo(0)).dx,
        greaterThan(tester.getTopLeft(globo(1)).dx),
      );
      expect(
        tester.getTopRight(globo(0)).dx,
        greaterThan(tester.getTopRight(globo(1)).dx),
      );

      expect(tester.widget<TextField>(campo).controller!.text, isEmpty);
    },
  );

  testWidgets('la tecla de enviar del teclado también envía la pregunta', (
    tester,
  ) async {
    await abrir(tester);

    await tester.enterText(campo, '¿Cuántas órdenes hay?');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(repo.preguntas, ['¿Cuántas órdenes hay?']);
    expect(find.byType(BurbujaMensaje), findsNWidgets(2));
  });

  testWidgets('mientras piensa muestra el indicador y desactiva el botón', (
    tester,
  ) async {
    repo.espera = Completer<void>();
    await abrir(tester);

    await tester.enterText(campo, '¿Cuántas órdenes hay?');
    await tester.tap(botonEnviar);
    await tester.pump();

    expect(find.text(textoPensando), findsOneWidget);
    expect(tester.widget<IconButton>(botonEnviar).onPressed, isNull);

    repo.espera!.complete();
    await tester.pumpAndSettle();

    expect(find.text(textoPensando), findsNothing);
    expect(tester.widget<IconButton>(botonEnviar).onPressed, isNotNull);
  });

  testWidgets('un error muestra el aviso y «Reintentar» vuelve a preguntar', (
    tester,
  ) async {
    repo.error = const ApiException(
      AsistenteRepository.mensajeNoDisponible,
      codigoEstado: 502,
    );
    await abrir(tester);
    await escribirYEnviar(tester, '¿Cuántas órdenes hay?');

    expect(find.text(AsistenteRepository.mensajeNoDisponible), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);

    repo.error = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(repo.preguntas, hasLength(2));
    expect(find.text('Reintentar'), findsNothing);
    expect(find.text(AsistenteRepository.mensajeNoDisponible), findsNothing);
    expect(find.text('¿Cuántas órdenes hay?'), findsOneWidget);
    expect(find.text(repo.respuesta), findsOneWidget);
  });

  testWidgets('una pregunta inválida conserva el texto y muestra el error', (
    tester,
  ) async {
    await abrir(tester);
    await escribirYEnviar(tester, 'ab');

    expect(find.text('Escribe al menos 3 caracteres.'), findsOneWidget);
    expect(tester.widget<TextField>(campo).controller!.text, 'ab');
    expect(repo.preguntas, isEmpty);
    expect(find.byType(BurbujaMensaje), findsNothing);
  });

  testWidgets('el contador muestra los caracteres hasta 300', (tester) async {
    await abrir(tester);
    expect(find.text('0/300'), findsOneWidget);

    await tester.enterText(campo, 'hola');
    await tester.pump();

    expect(find.text('4/300'), findsOneWidget);
  });

  testWidgets('la lista se desplaza al final cuando llegan mensajes', (
    tester,
  ) async {
    repo.respuesta = 'Respuesta larga del asistente. ' * 8;
    await abrir(tester);

    for (var i = 0; i < 10; i++) {
      await escribirYEnviar(tester, 'Pregunta número $i');
    }

    final posicion = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
    expect(posicion.maxScrollExtent, greaterThan(0));
    expect(posicion.pixels, posicion.maxScrollExtent);
  });

  testWidgets('el botón y el campo tienen etiquetas de accesibilidad', (
    tester,
  ) async {
    final semantica = tester.ensureSemantics();
    await abrir(tester);

    expect(find.bySemanticsLabel('Enviar pregunta'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Escribir pregunta al asistente')),
      findsOneWidget,
    );
    semantica.dispose();
  });
}
