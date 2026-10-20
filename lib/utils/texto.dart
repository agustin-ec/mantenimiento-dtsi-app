/// Minúsculas y sin tildes, para comparar textos al buscar.
String normalizarTexto(String texto) {
  const origen = 'áàäâéèëêíìïîóòöôúùüûñ';
  const destino = 'aaaaeeeeiiiioooouuuun';
  final minuscula = texto.toLowerCase();
  final salida = StringBuffer();
  for (final caracter in minuscula.split('')) {
    final posicion = origen.indexOf(caracter);
    salida.write(posicion >= 0 ? destino[posicion] : caracter);
  }
  return salida.toString();
}

/// Fecha y hora como dd/mm/aaaa hh:mm (hora local).
String formatearFechaHora(DateTime fecha) {
  final f = fecha.toLocal();
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(f.day)}/${dos(f.month)}/${f.year} ${dos(f.hour)}:${dos(f.minute)}';
}

/// Entero desde un número o un texto; null si no se puede leer.
int? leerEntero(Object? valor) {
  if (valor is num) return valor.toInt();
  if (valor is String) return int.tryParse(valor);
  return null;
}
