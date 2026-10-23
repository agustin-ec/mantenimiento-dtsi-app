import '../utils/texto.dart';

/// Técnico disponible para asignar órdenes, según el esquema TecnicoOut de
/// GET /usuarios/tecnicos.
class Tecnico {
  final int id;
  final String nombreCompleto;
  final String rol;

  const Tecnico({
    required this.id,
    required this.nombreCompleto,
    this.rol = 'tecnico_dtsi',
  });

  /// Tolera campos ausentes o con otro tipo.
  factory Tecnico.fromJson(Map<String, dynamic> json) {
    return Tecnico(
      id: leerEntero(json['id']) ?? 0,
      nombreCompleto: json['nombre_completo']?.toString() ?? '',
      rol: json['rol']?.toString() ?? '',
    );
  }
}
