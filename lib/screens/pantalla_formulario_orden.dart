import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/equipos_controller.dart';
import '../controllers/formulario_orden_controller.dart';
import '../controllers/ordenes_controller.dart';
import '../models/orden.dart';
import '../repositories/orden_repository.dart';
import '../utils/validadores.dart';
import '../widgets/campo_formulario.dart';
import '../widgets/vista_error.dart';
import '../widgets/vista_vacia.dart';

/// Formulario para crear una orden de mantenimiento. Al crearla cierra la
/// pantalla y devuelve la [Orden] con [Get.back].
class PantallaFormularioOrden extends StatefulWidget {
  const PantallaFormularioOrden({super.key});

  @override
  State<PantallaFormularioOrden> createState() =>
      _PantallaFormularioOrdenState();
}

class _PantallaFormularioOrdenState extends State<PantallaFormularioOrden> {
  final _formulario = GlobalKey<FormState>();
  late final FormularioOrdenController _controlador;
  late final TextEditingController _descripcion;

  @override
  void initState() {
    super.initState();
    _controlador = Get.put(
      FormularioOrdenController(
        Get.find<OrdenRepository>(),
        Get.find<EquiposController>(),
        Get.find<OrdenesController>(),
      ),
    );
    _descripcion = TextEditingController(text: _controlador.descripcion.value)
      ..addListener(() => _controlador.descripcion.value = _descripcion.text);
  }

  @override
  void dispose() {
    _descripcion.dispose();
    Get.delete<FormularioOrdenController>();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_controlador.enviando.value || !_formulario.currentState!.validate()) {
      return;
    }
    final orden = await _controlador.enviar();
    if (orden != null && mounted) Get.back(result: orden);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva orden')),
      body: SafeArea(
        child: Form(
          key: _formulario,
          child: Obx(() {
            final enviando = _controlador.enviando.value;
            final error = _controlador.mensaje.value;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _selectorEquipo(enviando),
                const SizedBox(height: 16),
                DropdownButtonFormField<TipoMantenimiento>(
                  initialValue: _controlador.tipo.value,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de mantenimiento',
                  ),
                  items: [
                    for (final tipo in TipoMantenimiento.seleccionables)
                      DropdownMenuItem(value: tipo, child: Text(tipo.etiqueta)),
                  ],
                  onChanged: enviando
                      ? null
                      : (tipo) {
                          if (tipo != null) _controlador.tipo.value = tipo;
                        },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<PrioridadOrden>(
                  initialValue: _controlador.prioridad.value,
                  decoration: const InputDecoration(labelText: 'Prioridad'),
                  items: [
                    for (final prioridad in PrioridadOrden.seleccionables)
                      DropdownMenuItem(
                        value: prioridad,
                        child: Text(prioridad.etiqueta),
                      ),
                  ],
                  onChanged: enviando
                      ? null
                      : (prioridad) {
                          if (prioridad != null) {
                            _controlador.prioridad.value = prioridad;
                          }
                        },
                ),
                const SizedBox(height: 16),
                CampoFormulario(
                  controlador: _descripcion,
                  etiqueta: 'Descripción del problema',
                  validador: Validadores.descripcionProblema,
                  teclado: TextInputType.multiline,
                  habilitado: !enviando,
                  accion: TextInputAction.newline,
                  lineas: 4,
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
                  onPressed: enviando || !_controlador.hayEquipos
                      ? null
                      : _enviar,
                  child: enviando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Crear orden'),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _selectorEquipo(bool enviando) {
    switch (_controlador.estadoEquipos) {
      case EstadoEquipos.cargando:
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        );
      case EstadoEquipos.error:
        return SizedBox(
          height: 240,
          child: VistaError(
            mensaje: _controlador.mensajeEquipos ?? '',
            alReintentar: _controlador.recargarEquipos,
          ),
        );
      case EstadoEquipos.vacio:
      case EstadoEquipos.exito:
        final equipos = _controlador.equiposElegibles;
        if (equipos.isEmpty) {
          return const SizedBox(
            height: 200,
            child: VistaVacia(
              titulo: 'No hay equipos disponibles',
              mensaje: 'Se necesita al menos un equipo para crear una orden.',
            ),
          );
        }
        final elegido = _controlador.equipoId.value;
        return DropdownButtonFormField<int>(
          initialValue: equipos.any((e) => e.id == elegido) ? elegido : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Equipo'),
          validator: Validadores.equipo,
          items: [
            for (final equipo in equipos)
              DropdownMenuItem(
                value: equipo.id,
                child: Text(
                  '${equipo.codigoInventario} · ${equipo.marca} ${equipo.modelo}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: enviando ? null : (id) => _controlador.equipoId.value = id,
        );
    }
  }
}
