import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:mantenimiento_dtsi/controllers/tema_controller.dart';

void main() {
  late Directory directorio;
  late Box caja;

  setUp(() async {
    directorio = await Directory.systemTemp.createTemp('hive_tema');
    Hive.init(directorio.path);
    caja = await Hive.openBox(TemaController.nombreCaja);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await directorio.delete(recursive: true);
  });

  test('por defecto sigue al sistema', () {
    expect(TemaController(caja).modo.value, ThemeMode.system);
  });

  testWidgets('cambia el modo y lo conserva en Hive', (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: SizedBox()));
    final controlador = TemaController(caja);

    await tester.runAsync(() => controlador.cambiarModo(ThemeMode.dark));
    expect(controlador.modo.value, ThemeMode.dark);
    await tester.pump();
    expect(Get.rootController.themeMode, ThemeMode.dark);

    // Un controlador nuevo recupera la preferencia guardada.
    expect(TemaController(caja).modo.value, ThemeMode.dark);
  });

  test('ignora un valor guardado no válido', () async {
    await caja.put('modo_tema', 'otro');
    expect(TemaController(caja).modo.value, ThemeMode.system);
  });
}
