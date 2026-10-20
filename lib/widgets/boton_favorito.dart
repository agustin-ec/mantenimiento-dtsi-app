import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/favoritos_controller.dart';

/// Estrella para marcar o desmarcar un equipo como favorito.
class BotonFavorito extends StatelessWidget {
  final int equipoId;

  const BotonFavorito({super.key, required this.equipoId});

  @override
  Widget build(BuildContext context) {
    final favoritos = Get.find<FavoritosController>();
    return Obx(() {
      final esFavorito = favoritos.esFavorito(equipoId);
      return IconButton(
        tooltip: esFavorito ? 'Quitar de favoritos' : 'Marcar como favorito',
        icon: Icon(esFavorito ? Icons.star : Icons.star_border),
        color: esFavorito ? Theme.of(context).colorScheme.primary : null,
        onPressed: () => favoritos.alternar(equipoId),
      );
    });
  }
}
