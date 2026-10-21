import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'controllers/auth_controller.dart';
import 'controllers/equipos_controller.dart';
import 'controllers/seguimiento_controller.dart';
import 'controllers/tema_controller.dart';
import 'repositories/auth_repository.dart';
import 'repositories/equipo_repository.dart';
import 'screens/pantalla_arranque.dart';
import 'screens/pantalla_detalle_equipo.dart';
import 'screens/pantalla_inicio.dart';
import 'screens/pantalla_login.dart';
import 'screens/pantalla_registro.dart';
import 'services/almacen_token.dart';
import 'services/almacen_seguimiento.dart';
import 'services/api_client.dart';
import 'services/cache_equipos.dart';
import 'theme/tema_app.dart';
import 'utils/middleware_auth.dart';
import 'utils/rutas.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final caja = await Hive.openBox(TemaController.nombreCaja);
  final temaController = Get.put(TemaController(caja));

  final cliente = ApiClient(almacen: AlmacenToken());
  final auth = Get.put(AuthController(AuthRepository(cliente)));
  cliente.alCaducarSesion = auth.alCaducarSesion;

  final equipos = Get.put<EquipoRepository>(
    EquipoRepository(
      cliente,
      cache: CacheEquipos(),
      idUsuario: () => auth.usuario.value?.id,
    ),
  );
  Get.put(EquiposController(equipos, auth));
  Get.put(SeguimientoController(AlmacenSeguimiento(), auth));

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
      initialRoute: Rutas.arranque,
      getPages: [
        GetPage(name: Rutas.arranque, page: () => const PantallaArranque()),
        GetPage(
          name: Rutas.login,
          page: () => const PantallaLogin(),
          middlewares: [MiddlewareAuth(requiereSesion: false)],
        ),
        GetPage(
          name: Rutas.registro,
          page: () => const PantallaRegistro(),
          middlewares: [MiddlewareAuth(requiereSesion: false)],
        ),
        GetPage(
          name: Rutas.inicio,
          page: () => const PantallaInicio(),
          middlewares: [MiddlewareAuth(requiereSesion: true)],
        ),
        GetPage(
          name: Rutas.detalleEquipo,
          page: () => const PantallaDetalleEquipo(),
          middlewares: [MiddlewareAuth(requiereSesion: true)],
        ),
      ],
    );
  }
}
