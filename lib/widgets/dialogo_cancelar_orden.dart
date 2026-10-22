import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/detalle_orden_controller.dart';
import '../utils/validadores.dart';
import 'campo_formulario.dart';

/// Pide el motivo y la confirmación para cancelar una orden. Se cierra al
/// terminar bien o si el servidor rechaza la transición; ante cualquier otro
/// error se queda abierto con el mensaje para no perder lo escrito.
Future<void> mostrarDialogoCancelarOrden(
  BuildContext context,
  DetalleOrdenController controlador,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DialogoCancelarOrden(controlador: controlador),
  );
}

class _DialogoCancelarOrden extends StatefulWidget {
  final DetalleOrdenController controlador;

  const _DialogoCancelarOrden({required this.controlador});

  @override
  State<_DialogoCancelarOrden> createState() => _DialogoCancelarOrdenState();
}

class _DialogoCancelarOrdenState extends State<_DialogoCancelarOrden> {
  final _formulario = GlobalKey<FormState>();
  final _motivo = TextEditingController();

  DetalleOrdenController get _controlador => widget.controlador;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    if (_controlador.accionEnCurso.value != null ||
        !_formulario.currentState!.validate()) {
      return;
    }
    final resultado = await _controlador.cancelar(_motivo.text);
    if (resultado != ResultadoAccion.error && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Obx(() {
      final enviando = _controlador.accionEnCurso.value != null;
      final error = _controlador.mensajeAccion.value;
      return PopScope(
        canPop: !enviando,
        child: AlertDialog(
          title: const Text('Cancelar orden'),
          content: SingleChildScrollView(
            child: Form(
              key: _formulario,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Esta acción no se puede deshacer.',
                    style: tema.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  CampoFormulario(
                    controlador: _motivo,
                    etiqueta: 'Motivo de la cancelación',
                    validador: Validadores.motivoCancelacion,
                    teclado: TextInputType.multiline,
                    habilitado: !enviando,
                    accion: TextInputAction.newline,
                    lineas: 3,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error,
                      style: tema.textTheme.bodyMedium?.copyWith(
                        color: tema.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: enviando ? null : () => Navigator.of(context).pop(),
              child: const Text('Volver'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: tema.colorScheme.error,
                foregroundColor: tema.colorScheme.onError,
              ),
              onPressed: enviando ? null : _confirmar,
              child: enviando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Cancelar orden'),
            ),
          ],
        ),
      );
    });
  }
}
