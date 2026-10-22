import '../utils/texto.dart';

/// Estado de una orden, según el enum EstadoOrden del backend.
enum EstadoOrden {
  creada('CREADA', 'Creada'),
  asignada('ASIGNADA', 'Asignada'),
  enProceso('EN_PROCESO', 'En proceso'),
  completada('COMPLETADA', 'Completada'),
  cancelada('CANCELADA', 'Cancelada'),
  desconocido('', 'Desconocido');

  final String valorApi;
  final String etiqueta;

  const EstadoOrden(this.valorApi, this.etiqueta);

  /// Estados que ofrece el filtro (todos menos [desconocido]).
  static const filtrables = [
    creada,
    asignada,
    enProceso,
    completada,
    cancelada,
  ];

  /// Acciones que ofrece la app según el estado. Solo guían la interfaz: el
  /// servidor decide si la transición es válida. Con un estado que no se
  /// reconoce no se ofrece ninguna.
  List<AccionOrden> get accionesPermitidas => switch (this) {
    creada || asignada => const [AccionOrden.iniciar, AccionOrden.cancelar],
    enProceso => const [AccionOrden.completar, AccionOrden.cancelar],
    completada || cancelada || desconocido => const [],
  };

  /// Solo en estos estados se puede asignar o reasignar un técnico.
  bool get permiteAsignar => this == creada || this == asignada;

  /// Un valor ausente o que no se reconoce queda como [desconocido].
  static EstadoOrden desdeApi(Object? valor) {
    return filtrables.firstWhere(
      (e) => e.valorApi == valor?.toString(),
      orElse: () => desconocido,
    );
  }
}

/// Cambios de estado que se pueden pedir desde el detalle de una orden.
enum AccionOrden { iniciar, completar, cancelar, asignar }

/// Tipo de mantenimiento, según el enum TipoMantenimiento del backend.
enum TipoMantenimiento {
  preventivo('PREVENTIVO', 'Preventivo'),
  correctivo('CORRECTIVO', 'Correctivo'),
  predictivo('PREDICTIVO', 'Predictivo'),
  desconocido('', 'Desconocido');

  final String valorApi;
  final String etiqueta;

  const TipoMantenimiento(this.valorApi, this.etiqueta);

  /// Tipos que se pueden elegir al crear una orden (todos menos
  /// [desconocido]).
  static const seleccionables = [preventivo, correctivo, predictivo];

  static TipoMantenimiento desdeApi(Object? valor) {
    return values.firstWhere(
      (t) => t != desconocido && t.valorApi == valor?.toString(),
      orElse: () => desconocido,
    );
  }
}

/// Prioridad de una orden, según el enum Prioridad del backend.
enum PrioridadOrden {
  baja('BAJA', 'Baja'),
  media('MEDIA', 'Media'),
  alta('ALTA', 'Alta'),
  critica('CRITICA', 'Crítica'),
  desconocido('', 'Desconocida');

  final String valorApi;
  final String etiqueta;

  const PrioridadOrden(this.valorApi, this.etiqueta);

  /// Prioridades que se pueden elegir al crear una orden (todas menos
  /// [desconocido]).
  static const seleccionables = [baja, media, alta, critica];

  static PrioridadOrden desdeApi(Object? valor) {
    return values.firstWhere(
      (p) => p != desconocido && p.valorApi == valor?.toString(),
      orElse: () => desconocido,
    );
  }
}

/// Orden de mantenimiento, según el esquema OrdenMantenimientoOut.
class Orden {
  final int id;
  final String codigoOrden;
  final int equipoId;
  final int solicitanteId;
  final int? tecnicoId;
  final TipoMantenimiento tipo;
  final PrioridadOrden prioridad;
  final EstadoOrden estado;
  final String descripcionProblema;
  final String? diagnostico;
  final String? accionesRealizadas;
  final String? repuestosUtilizados;
  final String? motivoCancelacion;
  final DateTime? fechaSolicitud;
  final DateTime? fechaInicio;
  final DateTime? fechaCierre;

  const Orden({
    required this.id,
    this.codigoOrden = '',
    required this.equipoId,
    this.solicitanteId = 0,
    this.tecnicoId,
    this.tipo = TipoMantenimiento.desconocido,
    this.prioridad = PrioridadOrden.desconocido,
    this.estado = EstadoOrden.desconocido,
    this.descripcionProblema = '',
    this.diagnostico,
    this.accionesRealizadas,
    this.repuestosUtilizados,
    this.motivoCancelacion,
    this.fechaSolicitud,
    this.fechaInicio,
    this.fechaCierre,
  });

  /// Tolera campos ausentes, con otro tipo o que el contrato no conoce.
  factory Orden.fromJson(Map<String, dynamic> json) {
    return Orden(
      id: leerEntero(json['id']) ?? 0,
      codigoOrden: json['codigo_orden']?.toString() ?? '',
      equipoId: leerEntero(json['equipo_id']) ?? 0,
      solicitanteId: leerEntero(json['solicitante_id']) ?? 0,
      tecnicoId: leerEntero(json['tecnico_id']),
      tipo: TipoMantenimiento.desdeApi(json['tipo_mantenimiento']),
      prioridad: PrioridadOrden.desdeApi(json['prioridad']),
      estado: EstadoOrden.desdeApi(json['estado']),
      descripcionProblema: json['descripcion_problema']?.toString() ?? '',
      diagnostico: json['diagnostico']?.toString(),
      accionesRealizadas: json['acciones_realizadas']?.toString(),
      repuestosUtilizados: json['repuestos_utilizados']?.toString(),
      motivoCancelacion: json['motivo_cancelacion']?.toString(),
      fechaSolicitud: _fecha(json['fecha_solicitud']),
      fechaInicio: _fecha(json['fecha_inicio']),
      fechaCierre: _fecha(json['fecha_cierre']),
    );
  }

  static DateTime? _fecha(Object? valor) =>
      valor is String ? DateTime.tryParse(valor) : null;
}
