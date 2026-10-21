import 'dart:convert';

import 'package:hive/hive.dart';

import '../models/equipo.dart';
import '../models/lista_equipos.dart';

/// Caché de equipos en Hive, una caja por persona. Guarda la lista como
/// cadena JSON (sin adaptadores) y la fecha de la última sincronización.
class CacheEquipos {
  static const _claveEquipos = 'equipos';
  static const _claveFecha = 'sincronizado_en';

  final Future<Box> Function(String nombre) _abrir;

  CacheEquipos({Future<Box> Function(String nombre)? abrirCaja})
    : _abrir = abrirCaja ?? ((nombre) => Hive.openBox(nombre));

  static String nombreCaja(int usuarioId) => 'cache_equipos_$usuarioId';

  Future<void> guardar(
    int usuarioId,
    List<Equipo> equipos,
    DateTime fecha,
  ) async {
    final caja = await _abrir(nombreCaja(usuarioId));
    await caja.put(
      _claveEquipos,
      jsonEncode(equipos.map((e) => e.toJson()).toList()),
    );
    await caja.put(_claveFecha, fecha.toIso8601String());
  }

  /// Devuelve null si no hay datos guardados o no se pueden leer.
  Future<ListaEquipos?> leer(int usuarioId) async {
    final caja = await _abrir(nombreCaja(usuarioId));
    final texto = caja.get(_claveEquipos);
    final fecha = DateTime.tryParse('${caja.get(_claveFecha)}');
    if (texto is! String || fecha == null) return null;
    try {
      final datos = jsonDecode(texto);
      if (datos is! List) return null;
      final equipos = datos
          .whereType<Map>()
          .map((m) => Equipo.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      return ListaEquipos(equipos, sincronizadoEn: fecha, desdeCache: true);
    } on FormatException {
      return null;
    }
  }
}
