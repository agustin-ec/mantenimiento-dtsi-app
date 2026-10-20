import 'package:flutter/material.dart';

/// Mensaje de error con botón «Reintentar». Se puede desplazar, así que
/// funciona dentro de un RefreshIndicator.
class VistaError extends StatelessWidget {
  final String mensaje;
  final VoidCallback alReintentar;

  const VistaError({
    super.key,
    required this.mensaje,
    required this.alReintentar,
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
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: tema.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    mensaje,
                    style: tema.textTheme.bodyLarge?.copyWith(
                      color: tema.colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: alReintentar,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
