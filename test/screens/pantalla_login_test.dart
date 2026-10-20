import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mantenimiento_dtsi/controllers/auth_controller.dart';
import 'package:mantenimiento_dtsi/screens/pantalla_login.dart';
import 'package:mantenimiento_dtsi/services/api_exception.dart';
import 'package:mantenimiento_dtsi/theme/tema_app.dart';

import '../utils/repositorio_falso.dart';

void main() {
  late RepositorioFalso repo;

  Future<void> montar(WidgetTester tester) async {
    repo = RepositorioFalso();
    final auth = Get.put(AuthController(repo, navegar: (_) {}));
    auth.estado.value = EstadoAuth.sinSesion;
    await tester.pumpWidget(
      GetMaterialApp(theme: TemaApp.claro, home: const PantallaLogin()),
    );
  }

  final boton = find.widgetWithText(FilledButton, 'Iniciar sesión');

  tearDown(Get.reset);

  testWidgets('campos vacíos muestran errores y no llaman al repositorio', (
    tester,
  ) async {
    await montar(tester);
    await tester.tap(boton);
    await tester.pump();
    expect(find.text('Escribe tu correo'), findsOneWidget);
    expect(find.text('Escribe tu contraseña'), findsOneWidget);
    expect(repo.llamadas, isEmpty);
  });

  testWidgets('correo con formato inválido y contraseña corta', (tester) async {
    await montar(tester);
    await tester.enterText(find.byType(TextFormField).at(0), 'no-es-correo');
    await tester.enterText(find.byType(TextFormField).at(1), '123');
    await tester.tap(boton);
    await tester.pump();
    expect(find.text('Escribe un correo válido'), findsOneWidget);
    expect(find.text('Debe tener al menos 8 caracteres'), findsOneWidget);
  });

  testWidgets('ante un fallo muestra el mensaje', (tester) async {
    await montar(tester);
    repo.error = const ApiException(
      ApiException.mensajeCredenciales,
      codigoEstado: 401,
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'ana@utb.edu.ec');
    await tester.enterText(find.byType(TextFormField).at(1), 'clave1234');
    await tester.tap(boton);
    await tester.pump();
    await tester.pump();
    expect(find.text('Correo o contraseña incorrectos'), findsOneWidget);
  });
}
