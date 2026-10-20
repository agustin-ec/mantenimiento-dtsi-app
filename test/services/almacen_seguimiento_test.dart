import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mantenimiento_dtsi/services/almacen_seguimiento.dart';

import '../utils/hive_temporal.dart';

void main() {
  late Future<void> Function() limpiar;
  late AlmacenSeguimiento almacen;

  setUp(() async {
    limpiar = await iniciarHiveTemporal();
    almacen = AlmacenSeguimiento();
  });

  tearDown(() => limpiar());

  test('sin datos devuelve un conjunto vacío', () async {
    expect(await almacen.leer(1), isEmpty);
  });

  test('persiste al cerrar y reabrir la caja', () async {
    await almacen.guardar(1, {3, 1, 2});
    await Hive.close();

    expect(await AlmacenSeguimiento().leer(1), {1, 2, 3});
  });

  test('guardar reemplaza lo anterior', () async {
    await almacen.guardar(1, {1, 2});
    await almacen.guardar(1, {2});
    expect(await almacen.leer(1), {2});
  });

  test('lee lo guardado antes con el nombre de caja «favoritos»', () async {
    final caja = await Hive.openBox('favoritos_1');
    await caja.put('ids', [4, 8]);
    await Hive.close();

    expect(await AlmacenSeguimiento().leer(1), {4, 8});
  });

  test('cada persona tiene su propio seguimiento', () async {
    await almacen.guardar(1, {1});
    await almacen.guardar(2, {5, 6});

    expect(await almacen.leer(1), {1});
    expect(await almacen.leer(2), {5, 6});
    expect(AlmacenSeguimiento.nombreCaja(2), 'favoritos_2');
  });
}
