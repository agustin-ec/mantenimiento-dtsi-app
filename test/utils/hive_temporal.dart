import 'dart:io';

import 'package:hive/hive.dart';

/// Inicia Hive en un directorio temporal y devuelve cómo limpiarlo.
Future<Future<void> Function()> iniciarHiveTemporal() async {
  final directorio = await Directory.systemTemp.createTemp('hive_prueba');
  Hive.init(directorio.path);
  return () async {
    await Hive.deleteFromDisk();
    await directorio.delete(recursive: true);
  };
}
