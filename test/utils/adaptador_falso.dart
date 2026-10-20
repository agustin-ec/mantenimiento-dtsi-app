import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Adaptador falso: responde según el [manejador] y guarda las peticiones.
class AdaptadorFalso implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions) manejador;
  final List<RequestOptions> peticiones = [];

  AdaptadorFalso(this.manejador);

  @override
  Future<ResponseBody> fetch(
    RequestOptions opciones,
    Stream<Uint8List>? cuerpo,
    Future<void>? cancelar,
  ) {
    peticiones.add(opciones);
    return manejador(opciones);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody json(int codigo, Object cuerpo) => ResponseBody.fromString(
  jsonEncode(cuerpo),
  codigo,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);
