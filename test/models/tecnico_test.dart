import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_dtsi/models/tecnico.dart';

void main() {
  test('lee los campos del contrato TecnicoOut', () {
    final tecnico = Tecnico.fromJson({
      'id': 4,
      'nombre_completo': 'Luis Mora',
      'rol': 'tecnico_dtsi',
    });
    expect(tecnico.id, 4);
    expect(tecnico.nombreCompleto, 'Luis Mora');
    expect(tecnico.rol, 'tecnico_dtsi');
  });

  test('tolera el id como texto', () {
    expect(Tecnico.fromJson({'id': '9'}).id, 9);
  });

  test('tolera campos ausentes o nulos', () {
    final tecnico = Tecnico.fromJson({'id': null, 'nombre_completo': null});
    expect(tecnico.id, 0);
    expect(tecnico.nombreCompleto, '');
    expect(tecnico.rol, '');
  });
}
