import 'package:flutter/material.dart';

/// Diálogo breve de confirmación. Devuelve true solo si se confirma.
Future<bool> confirmarAccion(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  required String textoConfirmar,
}) async {
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (contexto) => AlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(contexto).pop(false),
          child: const Text('Volver'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(contexto).pop(true),
          child: Text(textoConfirmar),
        ),
      ],
    ),
  );
  return confirmado ?? false;
}
