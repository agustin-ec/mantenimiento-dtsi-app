import '../utils/texto.dart';

/// Evento de la hoja de vida de un equipo (HistorialIntervencionOut).
class EventoHistorial {
  final int id;
  final int? ordenId;
  final String accion;
  final String? estadoAnterior;
  final String? estadoNuevo;
  final String? detalles;
  final DateTime? fecha;

  const EventoHistorial({
    required this.id,
    this.ordenId,
    required this.accion,
    this.estadoAnterior,
    this.estadoNuevo,
    this.detalles,
    this.fecha,
  });

  /// Tolera campos ausentes o con otro tipo.
  factory EventoHistorial.fromJson(Map<String, dynamic> json) {
    final fecha = json['timestamp'];
    return EventoHistorial(
      id: leerEntero(json['id']) ?? 0,
      ordenId: leerEntero(json['orden_id']),
      accion: json['accion']?.toString() ?? '',
      estadoAnterior: json['estado_anterior']?.toString(),
      estadoNuevo: json['estado_nuevo']?.toString(),
      detalles: json['detalles']?.toString(),
      fecha: fecha is String ? DateTime.tryParse(fecha) : null,
    );
  }
}
