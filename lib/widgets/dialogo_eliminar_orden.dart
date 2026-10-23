import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/detalle_orden_controller.dart';

/// Pide confirmación para eliminar una orden y devuelve cómo terminó (null si
/// la persona vuelve atrás). Se cierra al terminar bien, si la orden ya no
/// existe o si el servidor rechaza el estado; ante cualquier otro error se
/// queda abierto con el mensaje.
Future<ResultadoAccion?> mostrarDialogoEliminarOrden(
  BuildContext context,
  DetalleOrdenController controlador,
) {
  return showDialog<ResultadoAccion>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DialogoEliminarOrden(controlador: controlador),
  );
}

class _DialogoEliminarOrden extends StatelessWidget {
  final DetalleOrdenController controlador;

  const _DialogoEliminarOrden({required this.controlador});

  Future<void> _confirmar(BuildContext context) async {
    if (controlador.accionEnCurso.value != null) return;
    final resultado = await controlador.eliminar();
    if (resultado != ResultadoAccion.error && context.mounted) {
      Navigator.of(context).pop(resultado);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Obx(() {
      final enviando = controlador.accionEnCurso.value != null;
      final error = controlador.mensajeAccion.value;
      return PopScope(
        canPop: !enviando,
        child: AlertDialog(
          title: const Text('Eliminar orden'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Esta acción no se puede deshacer.',
                  style: tema.textTheme.bodyMedium,
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
              onPressed: enviando ? null : () => _confirmar(context),
              child: enviando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Eliminar orden'),
            ),
          ],
        ),
      );
    });
  }
}
