import 'package:flutter/material.dart';

import '../models/equipo.dart';

/// Punto de color y etiqueta del estado de un equipo.
class IndicadorEstado extends StatelessWidget {
  final EstadoEquipo estado;

  const IndicadorEstado({super.key, required this.estado});

  Color _color(ColorScheme colores) => switch (estado) {
    EstadoEquipo.disponible => colores.primary,
    EstadoEquipo.asignado => colores.tertiary,
    EstadoEquipo.enMantenimiento => colores.secondary,
    EstadoEquipo.fueraDeServicio => colores.error,
    EstadoEquipo.dadoDeBaja => colores.outline,
    EstadoEquipo.desconocido => colores.outline,
  };

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
          estado.etiqueta,
          style: tema.textTheme.labelMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}
