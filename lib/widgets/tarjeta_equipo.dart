import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/equipo.dart';
import '../utils/rutas.dart';
import 'boton_favorito.dart';
import 'indicador_estado.dart';

/// Tarjeta de un equipo: abre el detalle y permite marcarlo como favorito.
class TarjetaEquipo extends StatelessWidget {
  final Equipo equipo;

  const TarjetaEquipo({super.key, required this.equipo});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => Get.toNamed(Rutas.detalleEquipo, arguments: equipo),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        equipo.codigoInventario,
                        style: tema.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${equipo.marca} ${equipo.modelo}',
                        style: tema.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(equipo.sede, style: tema.textTheme.bodyMedium),
                      const SizedBox(height: 8),
                      IndicadorEstado(estado: equipo.estado),
                    ],
                  ),
                ),
              ),
              BotonFavorito(equipoId: equipo.id),
            ],
          ),
        ),
      ),
    );
  }
}
