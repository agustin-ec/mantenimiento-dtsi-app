import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'controllers/actualizador_ordenes_controller.dart';
import 'controllers/asistente_controller.dart';
import 'controllers/auth_controller.dart';
import 'controllers/equipos_controller.dart';
import 'controllers/notificaciones_controller.dart';
import 'controllers/ordenes_controller.dart';
import 'controllers/seguimiento_controller.dart';
import 'controllers/tecnicos_controller.dart';
import 'controllers/tema_controller.dart';
import 'repositories/asistente_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/equipo_repository.dart';
import 'repositories/orden_repository.dart';
import 'screens/pantalla_arranque.dart';
import 'screens/pantalla_detalle_equipo.dart';
import 'screens/pantalla_detalle_orden.dart';
import 'screens/pantalla_formulario_orden.dart';
import 'screens/pantalla_inicio.dart';
import 'screens/pantalla_login.dart';
import 'screens/pantalla_registro.dart';
import 'services/almacen_estados_ordenes.dart';
import 'services/almacen_token.dart';
import 'services/almacen_seguimiento.dart';
import 'services/api_client.dart';
import 'services/avisos_ordenes.dart';
import 'services/cache_equipos.dart';
import 'services/servicio_notificaciones.dart';
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

  // Solo prepara el canal; el permiso se pide después de iniciar sesión.
  final notificaciones = ServicioNotificacionesLocales();
  await notificaciones.iniciar();
  Get.put<ServicioNotificaciones>(notificaciones);
  final notificacionesController = Get.put(
    NotificacionesController(notificaciones, auth, caja),
  );

  final equipos = Get.put<EquipoRepository>(
    EquipoRepository(
      cliente,
      cache: CacheEquipos(),
      idUsuario: () => auth.usuario.value?.id,
    ),
  );
  final equiposController = Get.put(EquiposController(equipos, auth));
  final ordenes = Get.put<OrdenRepository>(OrdenRepository(cliente));
  final avisos = AvisosOrdenes(
    AlmacenEstadosOrdenes(caja),
    idUsuario: () => auth.usuario.value?.id,
    avisar: notificacionesController.avisar,
  );
  final ordenesController = Get.put(
    OrdenesController(
      ordenes,
      auth,
      equipos: equiposController,
      avisos: avisos,
    ),
  );
  Get.put(ActualizadorOrdenesController(ordenesController, auth));
  Get.put(TecnicosController(ordenes, auth));
  Get.put(SeguimientoController(AlmacenSeguimiento(), auth));
  Get.put(AsistenteController(AsistenteRepository(cliente), auth));

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
        GetPage(
          name: Rutas.detalleOrden,
          page: () => const PantallaDetalleOrden(),
          middlewares: [MiddlewareAuth(requiereSesion: true)],
        ),
        GetPage(
          name: Rutas.nuevaOrden,
          page: () => const PantallaFormularioOrden(),
          middlewares: [MiddlewareAuth(requiereSesion: true)],
        ),
      ],
    );
  }
}
