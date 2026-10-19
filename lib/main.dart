import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'controllers/tema_controller.dart';
import 'screens/pantalla_inicial.dart';
import 'theme/tema_app.dart';

class Rutas {
  static const inicio = '/';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final caja = await Hive.openBox(TemaController.nombreCaja);
  final temaController = Get.put(TemaController(caja));

  runApp(AplicacionDtsi(modoInicial: temaController.modo.value));
}

class AplicacionDtsi extends StatelessWidget {
  final ThemeMode modoInicial;

  const AplicacionDtsi({super.key, required this.modoInicial});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Mantenimiento DTSI',
      theme: TemaApp.claro,
      darkTheme: TemaApp.oscuro,
      themeMode: modoInicial,
      initialRoute: Rutas.inicio,
      getPages: [
        GetPage(name: Rutas.inicio, page: () => const PantallaInicial()),
      ],
    );
  }
}
