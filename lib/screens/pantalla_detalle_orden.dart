import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/detalle_orden_controller.dart';
import '../controllers/ordenes_controller.dart';
import '../models/orden.dart';
import '../repositories/orden_repository.dart';
import '../utils/texto.dart';
import '../widgets/dato_etiquetado.dart';
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
      DetalleOrdenController(Get.find<OrdenRepository>(), argumento),
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
    );
  }

  Widget _contenido(BuildContext context, DetalleOrdenController controlador) {
    final tema = Theme.of(context);
    final orden = controlador.orden.value;
    final estado = controlador.estado.value;
    final aviso = controlador.mensaje.value;
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
              : 'Persona #${orden.tecnicoId}',
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
