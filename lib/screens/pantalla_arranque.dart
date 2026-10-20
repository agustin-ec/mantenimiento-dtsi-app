import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';

/// Restaura la sesión antes de mostrar nada, para evitar un parpadeo del login.
class PantallaArranque extends StatefulWidget {
  const PantallaArranque({super.key});

  @override
  State<PantallaArranque> createState() => _PantallaArranqueState();
}

class _PantallaArranqueState extends State<PantallaArranque> {
  final _auth = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _auth.restaurarSesion(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Obx(() {
          if (_auth.estado.value != EstadoAuth.error) {
            return const CircularProgressIndicator();
          }
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _auth.mensaje.value ?? '',
                  textAlign: TextAlign.center,
                  style: tema.textTheme.bodyLarge?.copyWith(
                    color: tema.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _auth.restaurarSesion,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
