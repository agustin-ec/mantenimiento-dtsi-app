import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_dtsi/services/servicio_notificaciones.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const canal = MethodChannel('dexterous.com/flutter/local_notifications');

  late List<MethodCall> llamadas;

  /// Respuesta por método; si es una excepción, se lanza como fallo del plugin.
  late Map<String, Object?> respuestas;

  List<MethodCall> de(String metodo) =>
      llamadas.where((l) => l.method == metodo).toList();

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    llamadas = [];
    respuestas = {'initialize': true};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, (llamada) async {
          llamadas.add(llamada);
          final respuesta = respuestas[llamada.method];
          if (respuesta is Exception) throw respuesta;
          return respuesta;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('iniciar dos veces inicializa y crea el canal una sola vez', () async {
    final servicio = ServicioNotificacionesLocales();

    await servicio.iniciar();
    await servicio.iniciar();

    expect(de('initialize'), hasLength(1));
    final canales = de('createNotificationChannel');
    expect(canales, hasLength(1));
    final argumentos = canales.single.arguments as Map;
    expect(argumentos['name'], 'Órdenes de mantenimiento');
    expect(argumentos['importance'], Importance.high.value);
  });

  test('un fallo del plugin al iniciar no lanza', () async {
    respuestas['initialize'] = PlatformException(code: 'fallo');

    await ServicioNotificacionesLocales().iniciar();
  });

  test('pedirPermiso devuelve true solo si el plugin lo concede', () async {
    final servicio = ServicioNotificacionesLocales();

    respuestas['requestNotificationsPermission'] = true;
    expect(await servicio.pedirPermiso(), isTrue);

    respuestas['requestNotificationsPermission'] = false;
    expect(await servicio.pedirPermiso(), isFalse);

    respuestas['requestNotificationsPermission'] = null;
    expect(await servicio.pedirPermiso(), isFalse);

    respuestas['requestNotificationsPermission'] = PlatformException(
      code: 'fallo',
    );
    expect(await servicio.pedirPermiso(), isFalse);
  });

  test('permisoConcedido consulta el estado sin mostrar el diálogo', () async {
    final servicio = ServicioNotificacionesLocales();

    respuestas['areNotificationsEnabled'] = true;
    expect(await servicio.permisoConcedido(), isTrue);

    respuestas['areNotificationsEnabled'] = false;
    expect(await servicio.permisoConcedido(), isFalse);

    respuestas['areNotificationsEnabled'] = null;
    expect(await servicio.permisoConcedido(), isFalse);

    respuestas['areNotificationsEnabled'] = PlatformException(code: 'fallo');
    expect(await servicio.permisoConcedido(), isFalse);

    expect(de('requestNotificationsPermission'), isEmpty);
  });

  test('mostrarAviso envía el título y el cuerpo al plugin', () async {
    await ServicioNotificacionesLocales().mostrarAviso(
      'Orden actualizada',
      'La orden OT-1 pasó a En proceso.',
    );

    final mostrados = de('show');
    expect(mostrados, hasLength(1));
    final argumentos = mostrados.single.arguments as Map;
    expect(argumentos['title'], 'Orden actualizada');
    expect(argumentos['body'], 'La orden OT-1 pasó a En proceso.');
  });

  test('un fallo del plugin al mostrar el aviso no lanza', () async {
    respuestas['show'] = PlatformException(code: 'fallo');

    await ServicioNotificacionesLocales().mostrarAviso('Título', 'Cuerpo');
  });
}
