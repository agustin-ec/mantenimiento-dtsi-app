/// Persona autenticada, según el esquema UsuarioOut de /auth/me.
class Usuario {
  final int id;
  final String email;
  final String nombreCompleto;
  final String rol;
  final bool activo;
  final DateTime? creadoEn;

  const Usuario({
    required this.id,
    required this.email,
    required this.nombreCompleto,
    this.rol = 'tecnico_dtsi',
    this.activo = true,
    this.creadoEn,
  });

  /// Tolera campos ausentes o con otro tipo.
  factory Usuario.fromJson(Map<String, dynamic> json) {
    final rol = json['rol'];
    final creado = json['created_at'];
    return Usuario(
      id: (json['id'] as num?)?.toInt() ?? 0,
      email: json['email']?.toString() ?? '',
      nombreCompleto: json['nombre_completo']?.toString() ?? '',
      rol: rol is String && rol.isNotEmpty ? rol : 'tecnico_dtsi',
      activo: json['activo'] is bool ? json['activo'] as bool : true,
      creadoEn: creado is String ? DateTime.tryParse(creado) : null,
    );
  }

  /// Solo guía la interfaz: el servidor decide los permisos reales.
  bool get esAdmin => rol == 'admin';

  String get rolLegible => switch (rol) {
    'admin' => 'Administrador',
    'tecnico' => 'Técnico',
    'tecnico_dtsi' => 'Técnico DTSI',
    _ => rol,
  };
}
