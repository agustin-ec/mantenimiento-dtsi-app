import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_dtsi/controllers/detalle_equipo_controller.dart';
import 'package:mantenimiento_dtsi/models/evento_historial.dart';
import 'package:mantenimiento_dtsi/services/api_exception.dart';

import '../utils/repositorio_equipos_falso.dart';

void main() {
  late RepositorioEquiposFalso repo;
  late DetalleEquipoController controlador;

  setUp(() {
    repo = RepositorioEquiposFalso();
    controlador = DetalleEquipoController(repo, 7);
  });

  test('ordena el historial del más reciente al más antiguo', () async {
    repo.historial = [
      EventoHistorial(id: 1, accion: 'A', fecha: DateTime.utc(2026, 1, 1)),
      EventoHistorial(id: 3, accion: 'C', fecha: DateTime.utc(2026, 3, 1)),
      EventoHistorial(id: 2, accion: 'B', fecha: DateTime.utc(2026, 2, 1)),
    ];
    await controlador.cargar();
    expect(controlador.estado.value, EstadoHistorial.exito);
    expect(controlador.eventos.map((e) => e.id), [3, 2, 1]);
    expect(repo.llamadas, ['listarHistorial:7']);
  });

  test('sin eventos termina en vacío', () async {
    await controlador.cargar();
    expect(controlador.estado.value, EstadoHistorial.vacio);
  });

  test('un fallo termina en error con el mensaje', () async {
    repo.errorHistorial = const ApiException(ApiException.mensajeServidor);
    await controlador.cargar();
    expect(controlador.estado.value, EstadoHistorial.error);
    expect(controlador.mensaje.value, ApiException.mensajeServidor);
  });
}
