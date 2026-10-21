import 'package:flutter/material.dart';

/// Mensaje centrado para listas sin contenido. Se puede desplazar, así que
/// funciona dentro de un RefreshIndicator.
class VistaVacia extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String? mensaje;
  final String? textoAccion;
  final VoidCallback? alAccionar;

  const VistaVacia({
    super.key,
    required this.titulo,
    this.icono = Icons.inbox_outlined,
    this.mensaje,
    this.textoAccion,
    this.alAccionar,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return LayoutBuilder(
      builder: (context, restricciones) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: restricciones.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icono, size: 48, color: tema.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    titulo,
                    style: tema.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (mensaje != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      mensaje!,
                      style: tema.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (textoAccion != null && alAccionar != null) ...[
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: alAccionar,
                      child: Text(textoAccion!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
