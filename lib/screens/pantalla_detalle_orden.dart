import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/detalle_orden_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/equipos_controller.dart';
import '../controllers/ordenes_controller.dart';
import '../controllers/tecnicos_controller.dart';
import '../models/orden.dart';
import '../repositories/orden_repository.dart';
import '../utils/texto.dart';
import '../widgets/dato_etiquetado.dart';
import '../widgets/dialogo_cancelar_orden.dart';
import '../widgets/dialogo_confirmacion.dart';
import '../widgets/hoja_asignar_tecnico.dart';
import '../widgets/hoja_completar_orden.dart';
import '../widgets/indicador_estado.dart';
import '../widgets/vista_vacia.dart';

/// Datos de una orden. La orden llega por [Get.arguments] cuando se abre con
/// una ruta; se muestra de inmediato y se refresca con el backend.
class PantallaDetalleOrden extends StatefulWidget {
  final Orden? orden;

  const PantallaDetalleOrden({super.key, this.orden});

  @override
  State<PantallaDetalleOrden> createState() => _PantallaDetalleOrdenState();
}

class _PantallaDetalleOrdenState extends State<PantallaDetalleOrden> {
  Orden? _orden;
  DetalleOrdenController? _controlador;

  @override
  void initState() {
    super.initState();
    final argumento = widget.orden ?? Get.arguments;
    if (argumento is! Orden) return;
    _orden = argumento;
    _controlador = Get.put(
      DetalleOrdenController(
        Get.find<OrdenRepository>(),
        argumento,
        ordenes: Get.find<OrdenesController>(),
        equipos: Get.find<EquiposController>(),
        tecnicos: Get.isRegistered<TecnicosController>()
            ? Get.find<TecnicosController>()
            : null,
        auth: Get.find<AuthController>(),
      ),
      tag: '${argumento.id}',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _controlador!.cargar());
  }

  @override
  void dispose() {
    final orden = _orden;
    if (orden != null) {
      Get.delete<DetalleOrdenController>(tag: '${orden.id}');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controlador = _controlador;
    if (_orden == null || controlador == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle de la orden')),
        body: const VistaVacia(titulo: 'No se encontró la orden'),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(controlador.orden.value.codigoOrden)),
      ),
      body: RefreshIndicator(
        onRefresh: controlador.cargar,
        child: Obx(() => _contenido(context, controlador)),
      ),
      bottomNavigationBar: Obx(() => _barraAcciones(context, controlador)),
    );
  }

  Future<void> _iniciar(DetalleOrdenController controlador) async {
    final confirmado = await confirmarAccion(
      context,
      titulo: 'Iniciar orden',
      mensaje:
          'La orden pasará a «En proceso» y el equipo a «En mantenimiento». '
          '¿Quieres continuar?',
      textoConfirmar: 'Iniciar',
    );
    if (confirmado) await controlador.iniciar();
  }

  Widget _barraAcciones(
    BuildContext context,
    DetalleOrdenController controlador,
  ) {
    final acciones = [
      ...controlador.acciones,
      if (controlador.puedeAsignar) AccionOrden.asignar,
    ];
    if (acciones.isEmpty) return const SizedBox.shrink();
    final habilitadas = controlador.accionesHabilitadas;
    final enCurso = controlador.accionEnCurso.value;
    final colores = Theme.of(context).colorScheme;

    Widget contenido(AccionOrden accion, String texto) => enCurso == accion
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(texto);

    final botones = <Widget>[
      for (final accion in acciones)
        Expanded(
          child: switch (accion) {
            AccionOrden.iniciar => FilledButton(
              onPressed: habilitadas ? () => _iniciar(controlador) : null,
              child: contenido(accion, 'Iniciar'),
            ),
            AccionOrden.completar => FilledButton(
              onPressed: habilitadas
                  ? () => mostrarHojaCompletarOrden(context, controlador)
                  : null,
              child: contenido(accion, 'Completar'),
            ),
            AccionOrden.asignar => OutlinedButton(
              onPressed: habilitadas
                  ? () => mostrarHojaAsignarTecnico(context, controlador)
                  : null,
              child: contenido(
                accion,
                controlador.orden.value.tecnicoId == null
                    ? 'Asignar técnico'
                    : 'Reasignar',
              ),
            ),
            AccionOrden.cancelar => OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: colores.error),
              onPressed: habilitadas
                  ? () => mostrarDialogoCancelarOrden(context, controlador)
                  : null,
              child: contenido(accion, 'Cancelar orden'),
            ),
          },
        ),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            for (var i = 0; i < botones.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              botones[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget _contenido(BuildContext context, DetalleOrdenController controlador) {
    final tema = Theme.of(context);
    final orden = controlador.orden.value;
    final estado = controlador.estado.value;
    final aviso = controlador.mensaje.value;
    final avisoAccion = controlador.mensajeAccion.value;
    String fecha(DateTime? f) => f == null ? '' : formatearFechaHora(f);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (estado == EstadoDetalleOrden.cargando)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: LinearProgressIndicator(),
          ),
        if (avisoAccion != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              avisoAccion,
              style: TextStyle(color: tema.colorScheme.error),
            ),
          ),
        if (estado == EstadoDetalleOrden.error && aviso != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    aviso,
                    style: TextStyle(color: tema.colorScheme.error),
                  ),
                ),
                TextButton(
                  onPressed: controlador.cargar,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        Text(
          Get.find<OrdenesController>().etiquetaEquipo(orden.equipoId),
          style: tema.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        IndicadorEstado.orden(estado: orden.estado),
        const SizedBox(height: 16),
        DatoEtiquetado('Código de la orden', orden.codigoOrden),
        DatoEtiquetado('Tipo de mantenimiento', orden.tipo.etiqueta),
        DatoEtiquetado('Prioridad', orden.prioridad.etiqueta),
        DatoEtiquetado('Solicitante', 'Persona #${orden.solicitanteId}'),
        DatoEtiquetado(
          'Técnico',
          orden.tecnicoId == null
              ? 'Sin asignar'
              : controlador.tecnicos?.nombrePara(orden.tecnicoId) ??
                    'Técnico #${orden.tecnicoId}',
        ),
        DatoEtiquetado('Descripción del problema', orden.descripcionProblema),
        DatoEtiquetado('Diagnóstico', orden.diagnostico),
        DatoEtiquetado('Acciones realizadas', orden.accionesRealizadas),
        DatoEtiquetado('Repuestos utilizados', orden.repuestosUtilizados),
        if (orden.estado == EstadoOrden.cancelada)
          DatoEtiquetado('Motivo de cancelación', orden.motivoCancelacion),
        DatoEtiquetado('Fecha de solicitud', fecha(orden.fechaSolicitud)),
        DatoEtiquetado('Fecha de inicio', fecha(orden.fechaInicio)),
        DatoEtiquetado('Fecha de cierre', fecha(orden.fechaCierre)),
      ],
    );
  }
}
