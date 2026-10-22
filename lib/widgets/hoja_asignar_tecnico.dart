import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/detalle_orden_controller.dart';
import '../controllers/tecnicos_controller.dart';
import 'vista_error.dart';
import 'vista_vacia.dart';

/// Lista de técnicos con selección única. Pide la lista al controlador al
/// abrirse. Se cierra al asignar bien o si el servidor rechaza la acción; ante
/// cualquier otro error se queda abierta con el mensaje.
Future<void> mostrarHojaAsignarTecnico(
  BuildContext context,
  DetalleOrdenController controlador,
) {
  final tecnicos = controlador.tecnicos;
  if (tecnicos == null) return Future.value();
  unawaited(tecnicos.cargar());
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        _HojaAsignarTecnico(controlador: controlador, tecnicos: tecnicos),
  );
}

class _HojaAsignarTecnico extends StatefulWidget {
  final DetalleOrdenController controlador;
  final TecnicosController tecnicos;

  const _HojaAsignarTecnico({
    required this.controlador,
    required this.tecnicos,
  });

  @override
  State<_HojaAsignarTecnico> createState() => _HojaAsignarTecnicoState();
}

class _HojaAsignarTecnicoState extends State<_HojaAsignarTecnico> {
  late int? _elegido = widget.controlador.orden.value.tecnicoId;

  DetalleOrdenController get _controlador => widget.controlador;

  Future<void> _asignar() async {
    final elegido = _elegido;
    if (elegido == null || _controlador.accionEnCurso.value != null) return;
    final resultado = await _controlador.asignar(elegido);
    if (resultado != ResultadoAccion.error && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _controlador.orden.value.tecnicoId == null
                  ? 'Asignar técnico'
                  : 'Reasignar técnico',
              style: tema.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Flexible(child: Obx(_cuerpo)),
          ],
        ),
      ),
    );
  }

  Widget _cuerpo() {
    final tecnicos = widget.tecnicos;
    switch (tecnicos.estado.value) {
      case EstadosTecnicos.cargando:
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        );
      case EstadosTecnicos.error:
        return VistaError(
          mensaje: tecnicos.mensaje.value ?? 'Ocurrió un error inesperado.',
          alReintentar: tecnicos.cargar,
        );
      case EstadosTecnicos.vacio:
        return const VistaVacia(
          titulo: 'No hay técnicos disponibles',
          mensaje: 'No se encontraron técnicos activos para asignar.',
        );
      case EstadosTecnicos.exito:
        return _lista();
    }
  }

  Widget _lista() {
    final tema = Theme.of(context);
    final enviando = _controlador.accionEnCurso.value != null;
    final error = _controlador.mensajeAccion.value;
    final actual = _controlador.orden.value.tecnicoId;
    final puedeEnviar = _elegido != null && _elegido != actual && !enviando;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: RadioGroup<int>(
              groupValue: _elegido,
              onChanged: (valor) {
                if (!enviando) setState(() => _elegido = valor);
              },
              child: Column(
                children: [
                  for (final tecnico in widget.tecnicos.tecnicos)
                    RadioListTile<int>(
                      value: tecnico.id,
                      enabled: !enviando,
                      title: Text(tecnico.nombreCompleto),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(
            error,
            style: tema.textTheme.bodyMedium?.copyWith(
              color: tema.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: enviando ? null : () => Navigator.of(context).pop(),
              child: const Text('Volver'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: puedeEnviar ? _asignar : null,
              child: enviando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Asignar'),
            ),
          ],
        ),
      ],
    );
  }
}
