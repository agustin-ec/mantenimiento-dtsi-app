import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/equipos_controller.dart';
import '../controllers/favoritos_controller.dart';
import '../widgets/aviso_cache.dart';
import '../widgets/tarjeta_equipo.dart';
import '../widgets/vista_error.dart';
import '../widgets/vista_vacia.dart';

/// Equipos marcados con la estrella. Usa la lista de [EquiposController], así
/// que también funciona con datos de la caché.
class PantallaFavoritos extends StatelessWidget {
  const PantallaFavoritos({super.key});

  @override
  Widget build(BuildContext context) {
    final equipos = Get.find<EquiposController>();
    final favoritos = Get.find<FavoritosController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Favoritos')),
      body: Column(
        children: [
          Obx(() {
            final desde = equipos.cacheDesde.value;
            if (desde == null) return const SizedBox.shrink();
            return AvisoCache(desde: desde, alReintentar: equipos.refrescar);
          }),
          Expanded(
            child: Obx(() {
              switch (equipos.estado.value) {
                case EstadoEquipos.cargando:
                  return const Center(child: CircularProgressIndicator());
                case EstadoEquipos.error:
                  return VistaError(
                    mensaje: equipos.mensaje.value ?? '',
                    alReintentar: equipos.cargar,
                  );
                case EstadoEquipos.vacio:
                case EstadoEquipos.exito:
                  return _lista(equipos, favoritos);
              }
            }),
          ),
        ],
      ),
    );
  }

  Widget _lista(EquiposController equipos, FavoritosController favoritos) {
    final ids = favoritos.ids.toSet();
    final lista = equipos.porIds(ids);
    if (lista.isEmpty) {
      // Con ids guardados que ya no están en la lista, el mensaje no debe
      // decir que no hay favoritos.
      return RefreshIndicator(
        onRefresh: equipos.refrescar,
        child: ids.isEmpty
            ? const VistaVacia(
                icono: Icons.star_border,
                titulo: 'Aún no tienes favoritos',
                mensaje: 'Marca equipos con la estrella.',
              )
            : const VistaVacia(
                icono: Icons.star_border,
                titulo: 'Tus favoritos no están en la lista actual',
                mensaje: 'Volverán a aparecer si el equipo regresa.',
              ),
      );
    }
    return RefreshIndicator(
      onRefresh: equipos.refrescar,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: lista.length,
        itemBuilder: (context, i) => TarjetaEquipo(equipo: lista[i]),
      ),
    );
  }
}
