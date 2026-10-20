import 'package:flutter/material.dart';

import '../utils/texto.dart';

/// Aviso de que los datos mostrados vienen de la caché.
class AvisoCache extends StatelessWidget {
  final DateTime desde;
  final VoidCallback alReintentar;

  const AvisoCache({
    super.key,
    required this.desde,
    required this.alReintentar,
  });

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: colores.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Sin conexión — datos guardados (última sincronización: '
              '${formatearFechaCorta(desde)})',
              style: TextStyle(color: colores.onSecondaryContainer),
            ),
          ),
          TextButton(onPressed: alReintentar, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}
