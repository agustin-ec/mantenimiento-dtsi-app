import 'package:flutter/material.dart';

/// Pantalla provisional mientras no existan las pantallas de negocio.
class PantallaInicial extends StatelessWidget {
  const PantallaInicial({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Mantenimiento DTSI')),
      body: Center(
        child: Text(
          'Base de la aplicación lista',
          style: tema.textTheme.titleMedium,
        ),
      ),
    );
  }
}
