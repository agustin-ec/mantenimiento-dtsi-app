import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Avisos locales del dispositivo. Ningún método lanza excepciones: un fallo
/// del plugin nunca debe romper la app.
abstract class ServicioNotificaciones {
  /// Prepara el plugin y el canal de Android. Hacerlo más de una vez no tiene
  /// efecto.
  Future<void> iniciar();

  /// Muestra el diálogo del sistema si hace falta. Devuelve true si el permiso
  /// quedó concedido; false si se denegó o si algo falló.
  Future<bool> pedirPermiso();

  /// Consulta el estado actual del permiso sin mostrar ningún diálogo. Devuelve
  /// false si no está concedido o si algo falló.
  Future<bool> permisoConcedido();

  Future<void> mostrarAviso(String titulo, String cuerpo);
}

/// Implementación real sobre flutter_local_notifications.
class ServicioNotificacionesLocales implements ServicioNotificaciones {
  static const _idCanal = 'ordenes_mantenimiento';
  static const _nombreCanal = 'Órdenes de mantenimiento';
  static const _descripcionCanal =
      'Avisos sobre el estado de las órdenes de mantenimiento.';

  final FlutterLocalNotificationsPlugin _plugin;

  Future<void>? _inicio;
  int _siguienteId = 0;

  ServicioNotificacionesLocales({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> iniciar() => _inicio ??= _inicializar();

  Future<void> _inicializar() async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_notificacion'),
        ),
      );
      await _android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _idCanal,
          _nombreCanal,
          description: _descripcionCanal,
          importance: Importance.high,
        ),
      );
    } catch (_) {
      // Sin plugin no hay avisos, pero la app sigue funcionando.
    }
  }

  @override
  Future<bool> pedirPermiso() async {
    try {
      return await _android?.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> permisoConcedido() async {
    try {
      return await _android?.areNotificationsEnabled() ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> mostrarAviso(String titulo, String cuerpo) async {
    try {
      await iniciar();
      await _plugin.show(
        id: _siguienteId++,
        title: titulo,
        body: cuerpo,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _idCanal,
            _nombreCanal,
            channelDescription: _descripcionCanal,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (_) {
      // Un aviso que falla no debe afectar a quien lo pidió.
    }
  }
}
