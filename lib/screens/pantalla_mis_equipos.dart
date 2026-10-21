import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/equipos_controller.dart';
import '../controllers/seguimiento_controller.dart';
import '../widgets/aviso_cache.dart';
import '../widgets/tarjeta_equipo.dart';
import '../widgets/vista_error.dart';
import '../widgets/vista_vacia.dart';

/// Equipos que la persona sigue. Usa la lista de [EquiposController], así
/// que también funciona con datos de la caché.
class PantallaMisEquipos extends StatelessWidget {
  const PantallaMisEquipos({super.key});

  @override
  Widget build(BuildContext context) {
    final equipos = Get.find<EquiposController>();
    final seguimiento = Get.find<SeguimientoController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Mis equipos')),
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
                  return _lista(equipos, seguimiento);
              }
            }),
          ),
        ],
      ),
    );
  }

  Widget _lista(EquiposController equipos, SeguimientoController seguimiento) {
    final ids = seguimiento.ids.toSet();
    final lista = equipos.porIds(ids);
    if (lista.isEmpty) {
      // Con ids guardados que ya no están en la lista, el mensaje no debe
      // decir que no sigue ninguno.
      return RefreshIndicator(
        onRefresh: equipos.refrescar,
        child: ids.isEmpty
            ? const VistaVacia(
                icono: Icons.bookmark_border,
                titulo: 'Aún no sigues ningún equipo',
                mensaje: 'Toca el marcador en los equipos que atiendes.',
              )
            : const VistaVacia(
                icono: Icons.bookmark_border,
                titulo:
                    'Tus equipos en seguimiento no están en la lista actual',
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
