import 'package:flutter/material.dart';

import '../models/equipo.dart';
import '../models/orden.dart';

/// Punto de color y etiqueta del estado de un equipo o de una orden.
class IndicadorEstado extends StatelessWidget {
  final String _etiqueta;
  final Color Function(ColorScheme colores) _color;

  IndicadorEstado({super.key, required EstadoEquipo estado})
    : _etiqueta = estado.etiqueta,
      _color = ((colores) => switch (estado) {
        EstadoEquipo.disponible => colores.primary,
        EstadoEquipo.asignado => colores.tertiary,
        EstadoEquipo.enMantenimiento => colores.secondary,
        EstadoEquipo.fueraDeServicio => colores.error,
        EstadoEquipo.dadoDeBaja => colores.outline,
        EstadoEquipo.desconocido => colores.outline,
      });

  IndicadorEstado.orden({super.key, required EstadoOrden estado})
    : _etiqueta = estado.etiqueta,
      _color = ((colores) => switch (estado) {
        EstadoOrden.creada => colores.outline,
        EstadoOrden.asignada => colores.tertiary,
        EstadoOrden.enProceso => colores.secondary,
        EstadoOrden.completada => colores.primary,
        EstadoOrden.cancelada => colores.error,
        EstadoOrden.desconocido => colores.outline,
      });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final color = _color(tema.colorScheme);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          _etiqueta,
          style: tema.textTheme.labelMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}
