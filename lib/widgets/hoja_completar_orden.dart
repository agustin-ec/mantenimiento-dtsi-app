import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/detalle_orden_controller.dart';
import '../utils/validadores.dart';
import 'campo_formulario.dart';

/// Formulario para completar una orden. Se cierra al terminar bien o si el
/// servidor rechaza la transición; ante cualquier otro error se queda abierto
/// con el mensaje para no perder lo escrito.
Future<void> mostrarHojaCompletarOrden(
  BuildContext context,
  DetalleOrdenController controlador,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _HojaCompletarOrden(controlador: controlador),
  );
}

class _HojaCompletarOrden extends StatefulWidget {
  final DetalleOrdenController controlador;

  const _HojaCompletarOrden({required this.controlador});

  @override
  State<_HojaCompletarOrden> createState() => _HojaCompletarOrdenState();
}

class _HojaCompletarOrdenState extends State<_HojaCompletarOrden> {
  final _formulario = GlobalKey<FormState>();
  final _diagnostico = TextEditingController();
  final _acciones = TextEditingController();
  final _repuestos = TextEditingController();

  DetalleOrdenController get _controlador => widget.controlador;

  @override
  void dispose() {
    _diagnostico.dispose();
    _acciones.dispose();
    _repuestos.dispose();
    super.dispose();
  }

  Future<void> _completar() async {
    if (_controlador.accionEnCurso.value != null ||
        !_formulario.currentState!.validate()) {
      return;
    }
    final resultado = await _controlador.completar(
      diagnostico: _diagnostico.text,
      accionesRealizadas: _acciones.text,
      repuestosUtilizados: _repuestos.text,
    );
    if (resultado != ResultadoAccion.error && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formulario,
          child: Obx(() {
            final enviando = _controlador.accionEnCurso.value != null;
            final error = _controlador.mensajeAccion.value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Completar orden', style: tema.textTheme.titleLarge),
                const SizedBox(height: 16),
                CampoFormulario(
                  controlador: _diagnostico,
                  etiqueta: 'Diagnóstico',
                  validador: Validadores.diagnostico,
                  teclado: TextInputType.multiline,
                  habilitado: !enviando,
                  accion: TextInputAction.newline,
                  lineas: 3,
                ),
                const SizedBox(height: 16),
                CampoFormulario(
                  controlador: _acciones,
                  etiqueta: 'Acciones realizadas',
                  validador: Validadores.accionesRealizadas,
                  teclado: TextInputType.multiline,
                  habilitado: !enviando,
                  accion: TextInputAction.newline,
                  lineas: 3,
                ),
                const SizedBox(height: 16),
                CampoFormulario(
                  controlador: _repuestos,
                  etiqueta: 'Repuestos utilizados (opcional)',
                  validador: (_) => null,
                  teclado: TextInputType.multiline,
                  habilitado: !enviando,
                  accion: TextInputAction.newline,
                  lineas: 2,
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    error,
                    style: tema.textTheme.bodyMedium?.copyWith(
                      color: tema.colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: enviando
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Volver'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: enviando ? null : _completar,
                      child: enviando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Completar'),
                    ),
                  ],
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
