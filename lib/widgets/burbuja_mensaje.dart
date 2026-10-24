import 'package:flutter/material.dart';

import '../models/mensaje_asistente.dart';
import '../utils/texto.dart';

/// Mensaje de la conversación con el asistente: el de la persona a la derecha
/// y el del asistente a la izquierda, con su hora.
class BurbujaMensaje extends StatelessWidget {
  final MensajeAsistente mensaje;

  const BurbujaMensaje({super.key, required this.mensaje});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final delUsuario = mensaje.esDelUsuario;
    final fondo = delUsuario
        ? esquema.primaryContainer
        : esquema.secondaryContainer;
    final texto = delUsuario
        ? esquema.onPrimaryContainer
        : esquema.onSecondaryContainer;

    return Align(
      alignment: delUsuario ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  mensaje.texto,
                  style: tema.textTheme.bodyMedium?.copyWith(color: texto),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatearFechaCorta(mensaje.hora),
                style: tema.textTheme.labelSmall?.copyWith(color: texto),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
