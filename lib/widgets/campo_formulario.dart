import 'package:flutter/material.dart';

/// Campo de texto con etiqueta y validación; opcionalmente oculta el texto.
class CampoFormulario extends StatelessWidget {
  final TextEditingController controlador;
  final String etiqueta;
  final String? Function(String?) validador;
  final TextInputType teclado;
  final bool oculto;
  final bool habilitado;
  final Iterable<String>? autocompletar;
  final TextInputAction accion;
  final VoidCallback? alEnviar;

  const CampoFormulario({
    super.key,
    required this.controlador,
    required this.etiqueta,
    required this.validador,
    this.teclado = TextInputType.text,
    this.oculto = false,
    this.habilitado = true,
    this.autocompletar,
    this.accion = TextInputAction.next,
    this.alEnviar,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controlador,
      decoration: InputDecoration(labelText: etiqueta),
      validator: validador,
      keyboardType: teclado,
      obscureText: oculto,
      enabled: habilitado,
      autofillHints: autocompletar,
      textInputAction: accion,
      onFieldSubmitted: alEnviar == null ? null : (_) => alEnviar!(),
    );
  }
}
