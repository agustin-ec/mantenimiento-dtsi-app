import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_dtsi/utils/validadores.dart';

void main() {
  group('diagnóstico y acciones realizadas (mínimo 10)', () {
    test('vacío o solo espacios piden el texto', () {
      expect(Validadores.diagnostico(null), 'Describe el diagnóstico');
      expect(Validadores.diagnostico('   '), 'Describe el diagnóstico');
      expect(
        Validadores.accionesRealizadas(''),
        'Describe las acciones realizadas',
      );
    });

    test('9 caracteres no alcanzan y 10 sí', () {
      expect(
        Validadores.diagnostico('123456789'),
        'Debe tener al menos 10 caracteres',
      );
      expect(Validadores.diagnostico('1234567890'), isNull);
      expect(
        Validadores.accionesRealizadas('123456789'),
        'Debe tener al menos 10 caracteres',
      );
      expect(Validadores.accionesRealizadas('1234567890'), isNull);
    });

    test('se cuentan los caracteres ya recortados', () {
      expect(
        Validadores.diagnostico('   123456789   '),
        'Debe tener al menos 10 caracteres',
      );
    });
  });

  group('motivo de cancelación (mínimo 5)', () {
    test('vacío o solo espacios piden el motivo', () {
      expect(
        Validadores.motivoCancelacion(null),
        'Escribe el motivo de la cancelación',
      );
      expect(
        Validadores.motivoCancelacion('  '),
        'Escribe el motivo de la cancelación',
      );
    });

    test('4 caracteres no alcanzan y 5 sí', () {
      expect(
        Validadores.motivoCancelacion('abcd'),
        'Debe tener al menos 5 caracteres',
      );
      expect(Validadores.motivoCancelacion('abcde'), isNull);
      expect(Validadores.motivoCancelacion('  abcd  '), isNotNull);
    });
  });

  test('la descripción del problema conserva su comportamiento', () {
    expect(Validadores.descripcionProblema(''), 'Describe el problema');
    expect(
      Validadores.descripcionProblema('corta'),
      'Debe tener al menos 10 caracteres',
    );
    expect(Validadores.descripcionProblema('Suficientemente larga'), isNull);
  });
}
