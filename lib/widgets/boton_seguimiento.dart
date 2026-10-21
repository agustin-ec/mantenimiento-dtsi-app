import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/seguimiento_controller.dart';

/// Marcador para seguir o dejar de seguir un equipo.
class BotonSeguimiento extends StatelessWidget {
  final int equipoId;

  const BotonSeguimiento({super.key, required this.equipoId});

  @override
  Widget build(BuildContext context) {
    final seguimiento = Get.find<SeguimientoController>();
    return Obx(() {
      final estaSiguiendo = seguimiento.estaSiguiendo(equipoId);
      return IconButton(
        tooltip: estaSiguiendo ? 'Dejar de seguir' : 'Seguir equipo',
        icon: Icon(estaSiguiendo ? Icons.bookmark : Icons.bookmark_border),
        color: estaSiguiendo ? Theme.of(context).colorScheme.primary : null,
        onPressed: () => seguimiento.alternar(equipoId),
      );
    });
  }
}
