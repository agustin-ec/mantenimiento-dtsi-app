import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../utils/rutas.dart';
import '../utils/validadores.dart';
import '../widgets/campo_formulario.dart';

class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  final _auth = Get.find<AuthController>();
  final _formulario = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  void _enviar() {
    if (_auth.estaCargando || !_formulario.currentState!.validate()) return;
    _auth.iniciarSesion(_correo.text, _contrasena.text);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesión')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formulario,
                child: Obx(() {
                  final cargando = _auth.estaCargando;
                  final aviso = _auth.aviso.value;
                  final error = _auth.mensaje.value;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (aviso != null) ...[
                        Text(
                          aviso,
                          style: tema.textTheme.bodyMedium?.copyWith(
                            color: tema.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      CampoFormulario(
                        controlador: _correo,
                        etiqueta: 'Correo',
                        validador: Validadores.correo,
                        teclado: TextInputType.emailAddress,
                        habilitado: !cargando,
                        autocompletar: const [AutofillHints.email],
                      ),
                      const SizedBox(height: 16),
                      CampoFormulario(
                        controlador: _contrasena,
                        etiqueta: 'Contraseña',
                        validador: Validadores.contrasena,
                        oculto: true,
                        habilitado: !cargando,
                        accion: TextInputAction.done,
                        alEnviar: _enviar,
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          error,
                          style: tema.textTheme.bodyMedium?.copyWith(
                            color: tema.colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: cargando ? null : _enviar,
                        child: cargando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Iniciar sesión'),
                      ),
                      TextButton(
                        onPressed: cargando
                            ? null
                            : () {
                                _auth.limpiarMensajes();
                                Get.toNamed(Rutas.registro);
                              },
                        child: const Text('¿No tienes cuenta? Regístrate'),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
