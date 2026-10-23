import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/asistente_controller.dart';
import '../widgets/burbuja_mensaje.dart';

/// Conversación con el asistente de IA, que responde consultas de solo lectura
/// sobre equipos y órdenes.
class PantallaAsistente extends StatefulWidget {
  const PantallaAsistente({super.key});

  @override
  State<PantallaAsistente> createState() => _PantallaAsistenteState();
}

class _PantallaAsistenteState extends State<PantallaAsistente> {
  static const _ejemplos = [
    '¿Cuántos equipos hay en mantenimiento?',
    '¿Qué órdenes están en proceso?',
    '¿Cuántos equipos están disponibles?',
  ];

  final _controlador = Get.find<AsistenteController>();
  final _texto = TextEditingController();
  final _desplazamiento = ScrollController();
  final _vigilantes = <Worker>[];

  @override
  void initState() {
    super.initState();
    _vigilantes.addAll([
      ever(_controlador.mensajes, (_) => _irAlFinal()),
      ever(_controlador.pensando, (_) => _irAlFinal()),
    ]);
  }

  @override
  void dispose() {
    for (final vigilante in _vigilantes) {
      vigilante.dispose();
    }
    _texto.dispose();
    _desplazamiento.dispose();
    super.dispose();
  }

  void _irAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_desplazamiento.hasClients) return;
      _desplazamiento.animateTo(
        _desplazamiento.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  /// Vacía el campo solo si el controlador aceptó la pregunta; el mensaje de
  /// la persona se agrega de forma síncrona, antes de esperar la respuesta.
  Future<void> _enviar() async {
    if (_controlador.pensando.value) return;
    final antes = _controlador.mensajes.length;
    final envio = _controlador.enviar(_texto.text);
    if (_controlador.mensajes.length > antes) _texto.clear();
    await envio;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Asistente')),
      body: Column(
        children: [
          Expanded(child: Obx(_cuerpo)),
          Obx(_aviso),
          _entrada(),
        ],
      ),
    );
  }

  Widget _cuerpo() {
    final mensajes = _controlador.mensajes;
    final pensando = _controlador.pensando.value;
    if (mensajes.isEmpty && !pensando) return _bienvenida();
    return ListView.builder(
      controller: _desplazamiento,
      padding: const EdgeInsets.all(16),
      itemCount: mensajes.length + (pensando ? 1 : 0),
      itemBuilder: (context, indice) {
        if (indice == mensajes.length) return const _Escribiendo();
        return BurbujaMensaje(mensaje: mensajes[indice]);
      },
    );
  }

  Widget _bienvenida() {
    final tema = Theme.of(context);
    return LayoutBuilder(
      builder: (context, restricciones) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: restricciones.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.smart_toy_outlined,
                    size: 48,
                    color: tema.colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Hola, soy el asistente de mantenimiento',
                    style: tema.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Puedo responder consultas sobre los equipos y las '
                    'órdenes. Solo leo información, no hago cambios.',
                    style: tema.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final ejemplo in _ejemplos)
                        ActionChip(
                          label: Text(ejemplo),
                          onPressed: () => _controlador.enviar(ejemplo),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _aviso() {
    final mensaje = _controlador.error.value;
    if (mensaje == null) return const SizedBox.shrink();
    final esquema = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: esquema.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              mensaje,
              style: TextStyle(color: esquema.onErrorContainer),
            ),
          ),
          if (_controlador.puedeReintentar)
            TextButton(
              onPressed: _controlador.reintentar,
              child: const Text('Reintentar'),
            ),
        ],
      ),
    );
  }

  Widget _entrada() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Semantics(
                label: 'Escribir pregunta al asistente',
                textField: true,
                child: TextField(
                  controller: _texto,
                  maxLength: AsistenteController.maximo,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _enviar(),
                  decoration: const InputDecoration(
                    hintText: 'Escribe tu pregunta',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Obx(
              () => Semantics(
                label: 'Enviar pregunta',
                button: true,
                excludeSemantics: true,
                enabled: !_controlador.pensando.value,
                onTap: _controlador.pensando.value ? null : _enviar,
                child: IconButton.filled(
                  icon: const Icon(Icons.send),
                  onPressed: _controlador.pensando.value ? null : _enviar,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Indicador al final de la lista mientras se espera la respuesta.
class _Escribiendo extends StatelessWidget {
  const _Escribiendo();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            'El asistente está escribiendo…',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
