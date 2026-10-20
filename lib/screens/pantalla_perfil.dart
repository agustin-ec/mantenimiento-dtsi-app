import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../controllers/tema_controller.dart';

/// Datos de la persona, selector de tema y cierre de sesión.
class PantallaPerfil extends StatelessWidget {
  const PantallaPerfil({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final temaControlador = Get.find<TemaController>();
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Obx(() {
            final usuario = auth.usuario.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  usuario?.nombreCompleto ?? '',
                  style: tema.textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  usuario?.rolLegible ?? '',
                  style: tema.textTheme.bodyLarge,
                ),
              ],
            );
          }),
          const SizedBox(height: 24),
          Text('Tema', style: tema.textTheme.titleMedium),
          const SizedBox(height: 8),
          Obx(
            () => SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('Sistema')),
                ButtonSegment(value: ThemeMode.light, label: Text('Claro')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Oscuro')),
              ],
              selected: {temaControlador.modo.value},
              onSelectionChanged: (seleccion) =>
                  temaControlador.cambiarModo(seleccion.first),
            ),
          ),
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: auth.cerrarSesion,
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}
