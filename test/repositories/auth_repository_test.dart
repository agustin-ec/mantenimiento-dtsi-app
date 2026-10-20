import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_dtsi/repositories/auth_repository.dart';
import 'package:mantenimiento_dtsi/services/almacen_token.dart';
import 'package:mantenimiento_dtsi/services/api_client.dart';
import 'package:mantenimiento_dtsi/services/api_exception.dart';

import '../utils/adaptador_falso.dart';

const _perfil = {
  'id': 7,
  'email': 'ana@utb.edu.ec',
  'nombre_completo': 'Ana Pérez',
  'rol': 'tecnico_dtsi',
  'activo': true,
  'created_at': '2026-09-20T00:00:00Z',
};

void main() {
  late AlmacenToken almacen;

  AuthRepository crear(AdaptadorFalso adaptador) {
    final cliente = ApiClient(almacen: almacen);
    cliente.dio.httpClientAdapter = adaptador;
    return AuthRepository(cliente);
  }

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    almacen = AlmacenToken();
  });

  test(
    'iniciarSesion envía formulario, guarda el token y trae el perfil',
    () async {
      final adaptador = AdaptadorFalso((o) async {
        if (o.path == '/auth/login') {
          return json(200, {'access_token': 'tok', 'token_type': 'bearer'});
        }
        return json(200, _perfil);
      });
      final usuario = await crear(adaptador)
          .iniciarSesion('ana@utb.edu.ec', 'clave1234');

      final login = adaptador.peticiones.first;
      expect(login.contentType, Headers.formUrlEncodedContentType);
      expect(login.data, {
        'username': 'ana@utb.edu.ec',
        'password': 'clave1234',
      });
      expect(await almacen.leer(), 'tok');
      expect(adaptador.peticiones.last.headers['Authorization'], 'Bearer tok');
      expect(usuario.nombreCompleto, 'Ana Pérez');
      expect(usuario.id, 7);
    },
  );

  test('credenciales incorrectas: ApiException y sin token guardado', () async {
    final repo = crear(
      AdaptadorFalso(
        (_) async => json(401, {'detail': 'Credenciales inválidas'}),
      ),
    );
    await expectLater(
      repo.iniciarSesion('a@b.co', 'x'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.mensaje,
          'mensaje',
          'Correo o contraseña incorrectos',
        ),
      ),
    );
    expect(await almacen.leer(), isNull);
  });

  test('si el perfil falla tras el login, no queda token', () async {
    final repo = crear(
      AdaptadorFalso(
        (o) async => o.path == '/auth/login'
            ? json(200, {'access_token': 'tok'})
            : json(500, {}),
      ),
    );
    await expectLater(
      repo.iniciarSesion('a@b.co', 'x'),
      throwsA(isA<ApiException>()),
    );
    expect(await almacen.leer(), isNull);
  });

  test('registrar envía JSON y devuelve el usuario (201)', () async {
    final adaptador = AdaptadorFalso((_) async => json(201, _perfil));
    final usuario = await crear(adaptador)
        .registrar('Ana Pérez', 'ana@utb.edu.ec', 'clave1234');
    expect(adaptador.peticiones.single.data, {
      'nombre_completo': 'Ana Pérez',
      'email': 'ana@utb.edu.ec',
      'password': 'clave1234',
    });
    expect(usuario.email, 'ana@utb.edu.ec');
  });

  test('registrar con datos inválidos (422) resume los campos', () async {
    final repo = crear(
      AdaptadorFalso(
        (_) async => json(422, {
          'detail': [
            {
              'loc': ['body', 'email'],
              'msg': 'm',
              'type': 't',
            },
          ],
        }),
      ),
    );
    await expectLater(
      repo.registrar('Ana', 'x', 'clave1234'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.mensaje,
          'mensaje',
          'Revisa el campo: email.',
        ),
      ),
    );
  });

  test('obtenerPerfil tolera campos ausentes', () async {
    final repo = crear(AdaptadorFalso((_) async => json(200, {'id': 3})));
    final usuario = await repo.obtenerPerfil();
    expect(usuario.id, 3);
    expect(usuario.email, '');
    expect(usuario.rol, 'tecnico_dtsi');
  });

  test('cerrarSesion borra el token', () async {
    await almacen.guardar('tok');
    final repo = crear(AdaptadorFalso((_) async => json(200, {})));
    expect(await repo.tieneToken(), isTrue);
    await repo.cerrarSesion();
    expect(await repo.tieneToken(), isFalse);
  });
}
