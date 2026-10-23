/// Quién escribió un mensaje de la conversación con el asistente.
enum AutorMensaje { usuario, asistente }

/// Un mensaje de la conversación con el asistente. Solo vive en memoria.
class MensajeAsistente {
  final String texto;
  final AutorMensaje autor;
  final DateTime hora;

  const MensajeAsistente({
    required this.texto,
    required this.autor,
    required this.hora,
  });

  /// Si no se indica [hora], se usa la actual.
  factory MensajeAsistente.delUsuario(String texto, {DateTime? hora}) =>
      MensajeAsistente(
        texto: texto,
        autor: AutorMensaje.usuario,
        hora: hora ?? DateTime.now(),
      );

  factory MensajeAsistente.delAsistente(String texto, {DateTime? hora}) =>
      MensajeAsistente(
        texto: texto,
        autor: AutorMensaje.asistente,
        hora: hora ?? DateTime.now(),
      );

  bool get esDelUsuario => autor == AutorMensaje.usuario;
}
