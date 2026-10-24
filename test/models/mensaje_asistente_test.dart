import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_dtsi/models/mensaje_asistente.dart';

void main() {
  test('delUsuario marca el autor y conserva la hora dada', () {
    final hora = DateTime(2026, 10, 23, 9, 30);
    final mensaje = MensajeAsistente.delUsuario(
      '¿Qué equipos fallan?',
      hora: hora,
    );

    expect(mensaje.texto, '¿Qué equipos fallan?');
    expect(mensaje.autor, AutorMensaje.usuario);
    expect(mensaje.esDelUsuario, isTrue);
    expect(mensaje.hora, hora);
  });

  test('delAsistente no es del usuario y pone la hora actual por defecto', () {
    final antes = DateTime.now();
    final mensaje = MensajeAsistente.delAsistente('Hay 2 órdenes abiertas.');
    final despues = DateTime.now();

    expect(mensaje.autor, AutorMensaje.asistente);
    expect(mensaje.esDelUsuario, isFalse);
    expect(mensaje.hora.isBefore(antes), isFalse);
    expect(mensaje.hora.isAfter(despues), isFalse);
  });
}
