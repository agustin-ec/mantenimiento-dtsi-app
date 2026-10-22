import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_dtsi/models/orden.dart';

void main() {
  test('CREADA y ASIGNADA permiten iniciar y cancelar', () {
    for (final estado in [EstadoOrden.creada, EstadoOrden.asignada]) {
      expect(estado.accionesPermitidas, [
        AccionOrden.iniciar,
        AccionOrden.cancelar,
      ]);
    }
  });

  test('EN_PROCESO permite completar y cancelar', () {
    expect(EstadoOrden.enProceso.accionesPermitidas, [
      AccionOrden.completar,
      AccionOrden.cancelar,
    ]);
  });

  test('COMPLETADA, CANCELADA y un estado desconocido no permiten nada', () {
    for (final estado in [
      EstadoOrden.completada,
      EstadoOrden.cancelada,
      EstadoOrden.desconocido,
    ]) {
      expect(estado.accionesPermitidas, isEmpty);
    }
  });
}
