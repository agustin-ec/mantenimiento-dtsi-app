import 'package:get/get.dart';

import '../models/mensaje_asistente.dart';
import '../repositories/asistente_repository.dart';
import '../services/api_exception.dart';
import '../utils/sesion.dart';
import 'auth_controller.dart';

/// Conversación con el asistente. El historial vive solo en memoria y se
/// vacía cuando la sesión termina, sea por cierre manual o por caducidad.
class AsistenteController extends GetxController {
  static const minimo = 3;
  static const maximo = 300;
  static const mensajeCorta = 'Escribe al menos 3 caracteres.';
  static const mensajeLarga = 'Máximo 300 caracteres.';

  final AsistenteRepository _repositorio;
  final AuthController _auth;

  final mensajes = <MensajeAsistente>[].obs;
  final pensando = false.obs;
  final RxnString error = RxnString();

  /// Cambia al limpiar: una respuesta que llega después se descarta.
  int _generacion = 0;

  /// Última pregunta que falló; permite [reintentar] sin repetir el mensaje.
  String? _preguntaFallida;

  AsistenteController(this._repositorio, this._auth);

  @override
  void onInit() {
    super.onInit();
    alCambiarSesion(_auth, alTerminar: limpiar);
  }

  bool get puedeReintentar => _preguntaFallida != null && !pensando.value;

  /// Valida la pregunta, la agrega a la conversación y pide la respuesta.
  /// Se ignora mientras ya se espera una respuesta.
  Future<void> enviar(String texto) async {
    if (pensando.value) return;
    final pregunta = texto.trim();
    if (pregunta.length < minimo) {
      error.value = mensajeCorta;
      return;
    }
    if (pregunta.length > maximo) {
      error.value = mensajeLarga;
      return;
    }
    _preguntaFallida = null;
    mensajes.add(MensajeAsistente.delUsuario(pregunta));
    await _preguntar(pregunta);
  }

  /// Repite la última pregunta que falló, sin duplicar el mensaje del usuario.
  Future<void> reintentar() async {
    final pregunta = _preguntaFallida;
    if (pregunta == null || pensando.value) return;
    await _preguntar(pregunta);
  }

  Future<void> _preguntar(String pregunta) async {
    final generacion = _generacion;
    error.value = null;
    pensando.value = true;
    try {
      final respuesta = await _repositorio.preguntar(pregunta);
      if (generacion != _generacion) return;
      mensajes.add(MensajeAsistente.delAsistente(respuesta));
      _preguntaFallida = null;
    } catch (e) {
      if (generacion != _generacion) return;
      error.value = ApiException.desdeError(e).mensaje;
      _preguntaFallida = pregunta;
    }
    pensando.value = false;
  }

  /// Descarta de la memoria la conversación de la persona.
  void limpiar() {
    _generacion++;
    mensajes.clear();
    error.value = null;
    pensando.value = false;
    _preguntaFallida = null;
  }
}
