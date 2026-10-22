class Validadores {
  static final _formatoCorreo = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? correo(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return 'Escribe tu correo';
    if (!_formatoCorreo.hasMatch(texto)) return 'Escribe un correo válido';
    return null;
  }

  static String? contrasena(String? valor) {
    final texto = valor ?? '';
    if (texto.isEmpty) return 'Escribe tu contraseña';
    if (texto.length < 8) return 'Debe tener al menos 8 caracteres';
    return null;
  }

  static String? nombre(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return 'Escribe tu nombre';
    if (texto.length < 3) return 'Debe tener al menos 3 caracteres';
    return null;
  }

  static String? equipo(Object? valor) =>
      valor == null ? 'Selecciona un equipo' : null;

  static const minimoDescripcion = 10;
  static const minimoDiagnostico = 10;
  static const minimoAcciones = 10;
  static const minimoMotivo = 5;

  static String? descripcionProblema(String? valor) =>
      _textoMinimo(valor, 'Describe el problema', minimoDescripcion);

  static String? diagnostico(String? valor) =>
      _textoMinimo(valor, 'Describe el diagnóstico', minimoDiagnostico);

  static String? accionesRealizadas(String? valor) =>
      _textoMinimo(valor, 'Describe las acciones realizadas', minimoAcciones);

  static String? motivoCancelacion(String? valor) =>
      _textoMinimo(valor, 'Escribe el motivo de la cancelación', minimoMotivo);

  /// Texto obligatorio con un mínimo de caracteres, contado ya recortado.
  static String? _textoMinimo(String? valor, String vacio, int minimo) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return vacio;
    if (texto.length < minimo) return 'Debe tener al menos $minimo caracteres';
    return null;
  }
}
