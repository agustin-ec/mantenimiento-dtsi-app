import 'package:flutter/material.dart';

/// Fila horizontal de chips para filtrar por estado: «Todos» y un chip por
/// cada estado de [estados], con su conteo. [actual] null significa «Todos».
class ChipsFiltroEstado<T> extends StatelessWidget {
  final List<T> estados;
  final String Function(T estado) etiqueta;
  final Map<T, int> conteo;
  final int total;
  final T? actual;
  final void Function(T? estado) alSeleccionar;

  const ChipsFiltroEstado({
    super.key,
    required this.estados,
    required this.etiqueta,
    required this.conteo,
    required this.total,
    required this.actual,
    required this.alSeleccionar,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('Todos ($total)'),
              selected: actual == null,
              onSelected: (_) => alSeleccionar(null),
            ),
          ),
          for (final estado in estados)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('${etiqueta(estado)} (${conteo[estado] ?? 0})'),
                selected: actual == estado,
                onSelected: (_) => alSeleccionar(estado),
              ),
            ),
        ],
      ),
    );
  }
}
