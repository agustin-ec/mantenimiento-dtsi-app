import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/ordenes_controller.dart';
import '../models/orden.dart';
import '../utils/rutas.dart';
import '../utils/texto.dart';
import 'indicador_estado.dart';

/// Tarjeta de una orden: abre el detalle.
class TarjetaOrden extends StatelessWidget {
  final Orden orden;

  const TarjetaOrden({super.key, required this.orden});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final controlador = Get.find<OrdenesController>();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => Get.toNamed(Rutas.detalleOrden, arguments: orden),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(orden.codigoOrden, style: tema.textTheme.titleMedium),
              const SizedBox(height: 4),
              Obx(
                () => Text(
                  controlador.etiquetaEquipo(orden.equipoId),
                  style: tema.textTheme.bodyLarge,
                ),
              ),
              if (orden.descripcionProblema.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  orden.descripcionProblema,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tema.textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  IndicadorEstado.orden(estado: orden.estado),
                  const SizedBox(width: 12),
                  Text(
                    'Prioridad ${orden.prioridad.etiqueta.toLowerCase()}',
                    style: tema.textTheme.labelMedium,
                  ),
                  const Spacer(),
                  if (orden.fechaSolicitud != null)
                    Text(
                      formatearFechaCorta(orden.fechaSolicitud!),
                      style: tema.textTheme.labelMedium,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
