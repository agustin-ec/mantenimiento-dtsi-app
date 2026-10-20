import '../utils/texto.dart';

/// Estado de un equipo, según el enum EstadoEquipo del backend.
enum EstadoEquipo {
  disponible('DISPONIBLE', 'Disponible'),
  asignado('ASIGNADO', 'Asignado'),
  enMantenimiento('EN_MANTENIMIENTO', 'En mantenimiento'),
  fueraDeServicio('FUERA_DE_SERVICIO', 'Fuera de servicio'),
  dadoDeBaja('DADO_DE_BAJA', 'Dado de baja'),
  desconocido('', 'Desconocido');

  final String valorApi;
  final String etiqueta;

  const EstadoEquipo(this.valorApi, this.etiqueta);

  /// Estados que ofrece el filtro (todos menos [desconocido]).
  static const filtrables = [
    disponible,
    asignado,
    enMantenimiento,
    fueraDeServicio,
    dadoDeBaja,
  ];

  /// Un valor ausente toma el defecto del backend (DISPONIBLE); uno que no
  /// se reconoce queda como [desconocido].
  static EstadoEquipo desdeApi(Object? valor) {
    if (valor == null) return disponible;
    return filtrables.firstWhere(
      (e) => e.valorApi == valor.toString(),
      orElse: () => desconocido,
    );
  }
}

/// Equipo del inventario, según el esquema EquipoOut.
class Equipo {
  final int id;
  final String codigoInventario;
  final String numeroSerie;
  final String tipoEquipo;
  final String marca;
  final String modelo;
  final String? especificaciones;
  final String sede;
  final String? ubicacionDetallada;
  final EstadoEquipo estado;
  final DateTime? creadoEn;
  final DateTime? actualizadoEn;

  const Equipo({
    required this.id,
    required this.codigoInventario,
    this.numeroSerie = '',
    this.tipoEquipo = '',
    required this.marca,
    required this.modelo,
    this.especificaciones,
    required this.sede,
    this.ubicacionDetallada,
    this.estado = EstadoEquipo.disponible,
    this.creadoEn,
    this.actualizadoEn,
  });

  /// Tolera campos ausentes o con otro tipo.
  factory Equipo.fromJson(Map<String, dynamic> json) {
    return Equipo(
      id: leerEntero(json['id']) ?? 0,
      codigoInventario: json['codigo_inventario']?.toString() ?? '',
      numeroSerie: json['numero_serie']?.toString() ?? '',
      tipoEquipo: json['tipo_equipo']?.toString() ?? '',
      marca: json['marca']?.toString() ?? '',
      modelo: json['modelo']?.toString() ?? '',
      especificaciones: json['especificaciones']?.toString(),
      sede: json['sede']?.toString() ?? '',
      ubicacionDetallada: json['ubicacion_detallada']?.toString(),
      estado: EstadoEquipo.desdeApi(json['estado']),
      creadoEn: _fecha(json['created_at']),
      actualizadoEn: _fecha(json['updated_at']),
    );
  }

  /// Mismas claves que usa el backend, para poder leerlo de nuevo con
  /// [Equipo.fromJson].
  Map<String, dynamic> toJson() => {
    'id': id,
    'codigo_inventario': codigoInventario,
    'numero_serie': numeroSerie,
    'tipo_equipo': tipoEquipo,
    'marca': marca,
    'modelo': modelo,
    'especificaciones': especificaciones,
    'sede': sede,
    'ubicacion_detallada': ubicacionDetallada,
    'estado': estado.valorApi,
    'created_at': creadoEn?.toIso8601String(),
    'updated_at': actualizadoEn?.toIso8601String(),
  };

  static DateTime? _fecha(Object? valor) =>
      valor is String ? DateTime.tryParse(valor) : null;
}
