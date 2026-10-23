import 'package:flutter/material.dart';

/// Etiqueta pequeña con su valor debajo; un valor vacío se muestra como «—».
class DatoEtiquetado extends StatelessWidget {
  final String etiqueta;
  final String? valor;

  const DatoEtiquetado(this.etiqueta, this.valor, {super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final texto = (valor == null || valor!.isEmpty) ? '—' : valor!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: tema.textTheme.labelMedium),
          Text(texto, style: tema.textTheme.bodyLarge),
        ],
      ),
    );
  }
}
