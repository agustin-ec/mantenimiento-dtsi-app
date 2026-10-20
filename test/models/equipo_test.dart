import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_dtsi/models/equipo.dart';
import 'package:mantenimiento_dtsi/models/evento_historial.dart';

void main() {
  test('Equipo.fromJson lee todos los campos', () {
    final equipo = Equipo.fromJson({
      'id': 3,
      'codigo_inventario': 'DTSI-003',
      'numero_serie': 'SN123',
      'tipo_equipo': 'Laptop',
      'marca': 'Dell',
      'modelo': 'Latitude',
      'especificaciones': '16 GB',
      'sede': 'Sede Central',
      'ubicacion_detallada': 'Piso 2',
      'estado': 'EN_MANTENIMIENTO',
      'created_at': '2026-09-20T10:00:00Z',
      'updated_at': '2026-09-21T10:00:00Z',
    });
    expect(equipo.codigoInventario, 'DTSI-003');
    expect(equipo.estado, EstadoEquipo.enMantenimiento);
    expect(equipo.estado.etiqueta, 'En mantenimiento');
    expect(equipo.creadoEn, DateTime.utc(2026, 9, 20, 10));
  });

  test('Equipo.fromJson tolera campos ausentes y estado desconocido', () {
    final vacio = Equipo.fromJson({});
    expect(vacio.id, 0);
    expect(vacio.sede, '');
    expect(vacio.estado, EstadoEquipo.disponible);
    expect(vacio.especificaciones, isNull);

    final raro = Equipo.fromJson({'estado': 'OTRO', 'id': '5'});
    expect(raro.id, 5);
    expect(raro.estado, EstadoEquipo.desconocido);
  });

  test('toJson y fromJson son inversos', () {
    final original = Equipo.fromJson({
      'id': 1,
      'codigo_inventario': 'A-1',
      'numero_serie': 'S',
      'tipo_equipo': 'PC',
      'marca': 'HP',
      'modelo': 'X',
      'sede': 'Norte',
      'estado': 'DADO_DE_BAJA',
      'created_at': '2026-09-20T10:00:00Z',
      'updated_at': '2026-09-20T11:00:00Z',
    });
    final copia = Equipo.fromJson(original.toJson());
    expect(copia.toJson(), original.toJson());
    expect(copia.estado, EstadoEquipo.dadoDeBaja);
  });

  test('EventoHistorial.fromJson lee el evento y tolera nulos', () {
    final evento = EventoHistorial.fromJson({
      'id': 9,
      'orden_id': 4,
      'accion': 'CAMBIO_ESTADO',
      'estado_anterior': 'DISPONIBLE',
      'estado_nuevo': 'EN_MANTENIMIENTO',
      'detalles': 'Revisión',
      'timestamp': '2026-09-20T10:00:00Z',
    });
    expect(evento.ordenId, 4);
    expect(evento.fecha, DateTime.utc(2026, 9, 20, 10));

    final minimo = EventoHistorial.fromJson({'id': 1, 'accion': 'CREACION'});
    expect(minimo.ordenId, isNull);
    expect(minimo.fecha, isNull);
  });
}
