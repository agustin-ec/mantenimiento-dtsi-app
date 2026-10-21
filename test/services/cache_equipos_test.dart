import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mantenimiento_dtsi/models/equipo.dart';
import 'package:mantenimiento_dtsi/services/cache_equipos.dart';

import '../utils/hive_temporal.dart';
import '../utils/repositorio_equipos_falso.dart';

void main() {
  late Future<void> Function() limpiar;
  late CacheEquipos cache;

  setUp(() async {
    limpiar = await iniciarHiveTemporal();
    cache = CacheEquipos();
  });

  tearDown(() => limpiar());

  test('sin datos guardados devuelve null', () async {
    expect(await cache.leer(1), isNull);
  });

  test('guarda y recupera la lista con su fecha', () async {
    final fecha = DateTime(2026, 10, 20, 14, 5);
    await cache.guardar(1, [
      equipoPrueba(1),
      equipoPrueba(2, estado: EstadoEquipo.asignado),
    ], fecha);

    final lista = (await cache.leer(1))!;
    expect(lista.desdeCache, isTrue);
    expect(lista.sincronizadoEn, fecha);
    expect(lista.equipos.map((e) => e.codigoInventario), ['DTSI-1', 'DTSI-2']);
    expect(lista.equipos.last.estado, EstadoEquipo.asignado);
  });

  test('sobrevive al cierre y la reapertura de Hive', () async {
    await cache.guardar(1, [equipoPrueba(1)], DateTime(2026, 10, 20));
    await Hive.close();

    final reabierta = await CacheEquipos().leer(1);
    expect(reabierta?.equipos, hasLength(1));
  });

  test('cada persona tiene su propia caja', () async {
    await cache.guardar(1, [equipoPrueba(1)], DateTime(2026, 10, 20));
    await cache.guardar(2, [
      equipoPrueba(7),
      equipoPrueba(8),
    ], DateTime(2026, 10, 21));

    expect((await cache.leer(1))!.equipos, hasLength(1));
    expect((await cache.leer(2))!.equipos, hasLength(2));
    expect(await cache.leer(3), isNull);
    expect(CacheEquipos.nombreCaja(2), 'cache_equipos_2');
  });

  test('datos ilegibles se tratan como si no hubiera caché', () async {
    final caja = await Hive.openBox(CacheEquipos.nombreCaja(1));
    await caja.put('equipos', '{no es json');
    await caja.put('sincronizado_en', DateTime(2026, 10, 20).toIso8601String());
    expect(await cache.leer(1), isNull);
  });
}
