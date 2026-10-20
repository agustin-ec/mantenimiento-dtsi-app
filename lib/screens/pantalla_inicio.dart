import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';

/// Pantalla protegida provisional; luego será la lista de equipos.
class PantallaInicio extends StatelessWidget {
  const PantallaInicio({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Mantenimiento DTSI')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Obx(() {
            final usuario = auth.usuario.value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  usuario?.nombreCompleto ?? '',
                  style: tema.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  usuario?.rolLegible ?? '',
                  style: tema.textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: auth.cerrarSesion,
                  child: const Text('Cerrar sesión'),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
