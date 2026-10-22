import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_dtsi/models/orden.dart';

const _completa = {
  'id': 5,
  'codigo_orden': 'OT-2026-0005',
  'equipo_id': 3,
  'solicitante_id': 2,
  'tecnico_id': 4,
  'tipo_mantenimiento': 'PREVENTIVO',
  'prioridad': 'CRITICA',
  'estado': 'EN_PROCESO',
  'descripcion_problema': 'No arranca el sistema',
  'diagnostico': 'Disco dañado',
  'acciones_realizadas': 'Cambio de disco',
  'repuestos_utilizados': 'SSD 480 GB',
  'motivo_cancelacion': null,
  'fecha_solicitud': '2026-09-20T10:00:00Z',
  'fecha_inicio': '2026-09-21T08:30:00Z',
  'fecha_cierre': null,
};

void main() {
  test('lee una orden completa', () {
    final orden = Orden.fromJson(_completa);
    expect(orden.id, 5);
    expect(orden.codigoOrden, 'OT-2026-0005');
    expect(orden.equipoId, 3);
    expect(orden.solicitanteId, 2);
    expect(orden.tecnicoId, 4);
    expect(orden.tipo, TipoMantenimiento.preventivo);
    expect(orden.prioridad, PrioridadOrden.critica);
    expect(orden.estado, EstadoOrden.enProceso);
    expect(orden.diagnostico, 'Disco dañado');
    expect(orden.fechaSolicitud, DateTime.utc(2026, 9, 20, 10));
    expect(orden.fechaInicio, isNotNull);
    expect(orden.fechaCierre, isNull);
    expect(orden.motivoCancelacion, isNull);
  });

  test('un campo inesperado se ignora', () {
    final orden = Orden.fromJson({
      ..._completa,
      'campo_nuevo': {'a': 1},
      'otro': [1, 2],
    });
    expect(orden.id, 5);
    expect(orden.estado, EstadoOrden.enProceso);
  });

  test('un estado desconocido no rompe la lectura', () {
    final orden = Orden.fromJson({..._completa, 'estado': 'EN_REVISION'});
    expect(orden.estado, EstadoOrden.desconocido);
    expect(orden.codigoOrden, 'OT-2026-0005');
  });

  test('tipo y prioridad desconocidos quedan como desconocido', () {
    final orden = Orden.fromJson({
      ..._completa,
      'tipo_mantenimiento': 'OTRO',
      'prioridad': 7,
    });
    expect(orden.tipo, TipoMantenimiento.desconocido);
    expect(orden.prioridad, PrioridadOrden.desconocido);
  });

  test('campos ausentes o con otro tipo toman valores neutros', () {
    final orden = Orden.fromJson({
      'id': '9',
      'equipo_id': 'x',
      'estado': null,
      'fecha_solicitud': 'no es fecha',
      'codigo_orden': 12,
    });
    expect(orden.id, 9);
    expect(orden.equipoId, 0);
    expect(orden.estado, EstadoOrden.desconocido);
    expect(orden.fechaSolicitud, isNull);
    expect(orden.codigoOrden, '12');
    expect(orden.tecnicoId, isNull);
    expect(orden.descripcionProblema, '');
  });

  test('un mapa vacío no lanza', () {
    expect(Orden.fromJson({}).id, 0);
  });

  test('los estados filtrables excluyen desconocido', () {
    expect(EstadoOrden.filtrables, hasLength(5));
    expect(EstadoOrden.filtrables, isNot(contains(EstadoOrden.desconocido)));
  });
}
