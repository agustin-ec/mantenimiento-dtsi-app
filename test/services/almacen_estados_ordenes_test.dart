import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mantenimiento_dtsi/models/orden.dart';
import 'package:mantenimiento_dtsi/services/almacen_estados_ordenes.dart';

void main() {
  late Directory directorio;
  late Box caja;
  late AlmacenEstadosOrdenes almacen;

  setUp(() async {
    directorio = await Directory.systemTemp.createTemp('hive_estados');
    Hive.init(directorio.path);
    caja = await Hive.openBox('prueba_estados');
    almacen = AlmacenEstadosOrdenes(caja);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await directorio.delete(recursive: true);
  });

  test(
    'sin mapa guardado leer devuelve null; guardar y leer coinciden',
    () async {
      expect(almacen.leer(1), isNull);

      await almacen.guardar(1, {
        3: EstadoOrden.enProceso,
        7: EstadoOrden.creada,
      });

      expect(almacen.leer(1), {
        3: EstadoOrden.enProceso,
        7: EstadoOrden.creada,
      });
    },
  );

  test('un mapa vacío guardado se distingue de no haber mapa', () async {
    await almacen.guardar(1, {});

    expect(almacen.leer(1), isEmpty);
    expect(almacen.leer(2), isNull);
  });

  test('cada persona tiene su propio mapa y no se mezclan', () async {
    await almacen.guardar(1, {3: EstadoOrden.creada});
    await almacen.guardar(2, {3: EstadoOrden.completada});

    expect(almacen.leer(1), {3: EstadoOrden.creada});
    expect(almacen.leer(2), {3: EstadoOrden.completada});
    expect(
      caja.keys,
      unorderedEquals([
        AlmacenEstadosOrdenes.clave(1),
        AlmacenEstadosOrdenes.clave(2),
      ]),
    );
  });

  test(
    'en el disco solo hay texto: id de la orden y estado del backend',
    () async {
      await almacen.guardar(5, {3: EstadoOrden.enProceso});

      final crudo = caja.get(AlmacenEstadosOrdenes.clave(5)) as Map;
      expect(crudo, {'3': 'EN_PROCESO'});
    },
  );

  test('un valor guardado con otra forma se ignora', () async {
    await caja.put(AlmacenEstadosOrdenes.clave(1), 'basura');

    expect(almacen.leer(1), isNull);
  });
}
