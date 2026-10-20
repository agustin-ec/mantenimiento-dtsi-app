import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_dtsi/controllers/auth_controller.dart';
import 'package:mantenimiento_dtsi/services/api_exception.dart';
import 'package:mantenimiento_dtsi/utils/rutas.dart';

import '../utils/repositorio_falso.dart';

void main() {
  late RepositorioFalso repo;
  late List<String> rutas;
  late AuthController auth;

  setUp(() {
    repo = RepositorioFalso();
    rutas = [];
    auth = AuthController(repo, navegar: rutas.add);
  });

  test('inicio de sesión correcto', () async {
    await auth.iniciarSesion(' ana@utb.edu.ec ', 'clave1234');
    expect(auth.estado.value, EstadoAuth.conSesion);
    expect(auth.usuario.value?.nombreCompleto, 'Ana Pérez');
    expect(rutas, [Rutas.inicio]);
  });

  test('credenciales incorrectas muestran el mensaje', () async {
    repo.error = const ApiException(
      ApiException.mensajeCredenciales,
      codigoEstado: 401,
    );
    await auth.iniciarSesion('ana@utb.edu.ec', 'mala-clave');
    expect(auth.estado.value, EstadoAuth.error);
    expect(auth.mensaje.value, 'Correo o contraseña incorrectos');
    expect(auth.usuario.value, isNull);
    expect(rutas, isEmpty);
  });

  test('registro con correo duplicado no inicia sesión', () async {
    repo.errorRegistro = const ApiException(
      'El correo ya está registrado',
      codigoEstado: 400,
    );
    await auth.registrar('Ana Pérez', 'ana@utb.edu.ec', 'clave1234');
    expect(auth.estado.value, EstadoAuth.error);
    expect(auth.mensaje.value, 'El correo ya está registrado');
    expect(repo.llamadas, ['registrar']);
  });

  test('registro correcto inicia sesión sola', () async {
    await auth.registrar('Ana Pérez', 'ana@utb.edu.ec', 'clave1234');
    expect(repo.llamadas, ['registrar', 'iniciarSesion']);
    expect(auth.estado.value, EstadoAuth.conSesion);
    expect(rutas, [Rutas.inicio]);
  });

  test('sesión restaurada con token válido', () async {
    repo.token = true;
    await auth.restaurarSesion();
    expect(auth.estado.value, EstadoAuth.conSesion);
    expect(auth.usuario.value?.email, 'ana@utb.edu.ec');
    expect(rutas, [Rutas.inicio]);
  });

  test('sin token va al inicio de sesión', () async {
    await auth.restaurarSesion();
    expect(auth.estado.value, EstadoAuth.sinSesion);
    expect(rutas, [Rutas.login]);
    expect(repo.llamadas, isEmpty);
  });

  test('token inválido (401) se borra y vuelve al login', () async {
    repo.token = true;
    repo.errorPerfil = const ApiException(
      ApiException.mensajeSesionCaducada,
      codigoEstado: 401,
    );
    await auth.restaurarSesion();
    expect(auth.estado.value, EstadoAuth.sinSesion);
    expect(repo.token, isFalse);
    expect(rutas, [Rutas.login]);
  });

  test(
    'falla de red al restaurar conserva el token y permite reintentar',
    () async {
      repo.token = true;
      repo.errorPerfil = const ApiException(ApiException.mensajeSinConexion);
      await auth.restaurarSesion();
      expect(auth.estado.value, EstadoAuth.error);
      expect(auth.mensaje.value, ApiException.mensajeSinConexion);
      expect(repo.token, isTrue);
    },
  );

  test('cerrar sesión borra el token y vuelve al login', () async {
    await auth.iniciarSesion('ana@utb.edu.ec', 'clave1234');
    await auth.cerrarSesion();
    expect(auth.estado.value, EstadoAuth.sinSesion);
    expect(auth.usuario.value, isNull);
    expect(repo.cierres, 1);
    expect(rutas.last, Rutas.login);
  });

  test('sesión caducada avisa y vuelve al login', () async {
    await auth.iniciarSesion('ana@utb.edu.ec', 'clave1234');
    auth.alCaducarSesion();
    expect(auth.estado.value, EstadoAuth.sinSesion);
    expect(auth.aviso.value, 'Tu sesión caducó, inicia sesión de nuevo.');
    expect(rutas.last, Rutas.login);
  });
}
