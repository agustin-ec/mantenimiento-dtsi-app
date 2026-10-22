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

  static String? descripcionProblema(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return 'Describe el problema';
    if (texto.length < minimoDescripcion) {
      return 'Debe tener al menos $minimoDescripcion caracteres';
    }
    return null;
  }
}
