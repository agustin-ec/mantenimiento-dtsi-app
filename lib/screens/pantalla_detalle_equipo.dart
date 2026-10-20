import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/detalle_equipo_controller.dart';
import '../models/equipo.dart';
import '../models/evento_historial.dart';
import '../repositories/equipo_repository.dart';
import '../utils/texto.dart';
import '../widgets/indicador_estado.dart';
import '../widgets/vista_error.dart';
import '../widgets/vista_vacia.dart';

/// Datos de un equipo e historial de intervenciones. El equipo llega por
/// [Get.arguments] cuando se abre con una ruta.
class PantallaDetalleEquipo extends StatefulWidget {
  final Equipo? equipo;

  const PantallaDetalleEquipo({super.key, this.equipo});

  @override
  State<PantallaDetalleEquipo> createState() => _PantallaDetalleEquipoState();
}

class _PantallaDetalleEquipoState extends State<PantallaDetalleEquipo> {
  Equipo? _equipo;
  DetalleEquipoController? _controlador;

  @override
  void initState() {
    super.initState();
    final argumento = widget.equipo ?? Get.arguments;
    if (argumento is! Equipo) return;
    _equipo = argumento;
    _controlador = Get.put(
      DetalleEquipoController(Get.find<EquipoRepository>(), argumento.id),
      tag: '${argumento.id}',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _controlador!.cargar());
  }

  @override
  void dispose() {
    final equipo = _equipo;
    if (equipo != null) {
      Get.delete<DetalleEquipoController>(tag: '${equipo.id}');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final equipo = _equipo;
    final controlador = _controlador;
    if (equipo == null || controlador == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle del equipo')),
        body: const VistaVacia(titulo: 'No se encontró el equipo'),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(equipo.codigoInventario)),
      body: RefreshIndicator(
        onRefresh: controlador.cargar,
        child: Obx(() => _contenido(context, equipo, controlador)),
      ),
    );
  }

  Widget _contenido(
    BuildContext context,
    Equipo equipo,
    DetalleEquipoController controlador,
  ) {
    final tema = Theme.of(context);
    final eventos = controlador.eventos;
    final estado = controlador.estado.value;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${equipo.marca} ${equipo.modelo}',
          style: tema.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        IndicadorEstado(estado: equipo.estado),
        const SizedBox(height: 16),
        _Dato('Código de inventario', equipo.codigoInventario),
        _Dato('Número de serie', equipo.numeroSerie),
        _Dato('Tipo de equipo', equipo.tipoEquipo),
        _Dato('Sede', equipo.sede),
        _Dato('Ubicación', equipo.ubicacionDetallada),
        _Dato('Especificaciones', equipo.especificaciones),
        if (equipo.actualizadoEn != null)
          _Dato(
            'Última actualización',
            formatearFechaHora(equipo.actualizadoEn!),
          ),
        const SizedBox(height: 16),
        Text('Historial', style: tema.textTheme.titleLarge),
        const SizedBox(height: 8),
        if (estado == EstadoHistorial.cargando)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (estado == EstadoHistorial.error)
          SizedBox(
            height: 240,
            child: VistaError(
              mensaje: controlador.mensaje.value ?? '',
              alReintentar: controlador.cargar,
            ),
          )
        else if (estado == EstadoHistorial.vacio)
          const SizedBox(
            height: 200,
            child: VistaVacia(
              titulo: 'Sin historial',
              mensaje: 'Este equipo todavía no tiene intervenciones.',
            ),
          )
        else
          for (final evento in eventos) _TarjetaEvento(evento: evento),
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  final String etiqueta;
  final String? valor;

  const _Dato(this.etiqueta, this.valor);

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final texto = (valor == null || valor!.isEmpty) ? '—' : valor!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: tema.textTheme.labelMedium),
          Text(texto, style: tema.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _TarjetaEvento extends StatelessWidget {
  final EventoHistorial evento;

  const _TarjetaEvento({required this.evento});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cambio = [evento.estadoAnterior, evento.estadoNuevo];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(evento.accion, style: tema.textTheme.titleSmall),
            if (evento.fecha != null)
              Text(
                formatearFechaHora(evento.fecha!),
                style: tema.textTheme.labelMedium,
              ),
            if (cambio.any((c) => c != null && c.isNotEmpty))
              Text(
                '${cambio[0] ?? '—'} → ${cambio[1] ?? '—'}',
                style: tema.textTheme.bodyMedium,
              ),
            if (evento.ordenId != null)
              Text(
                'Orden #${evento.ordenId}',
                style: tema.textTheme.bodyMedium,
              ),
            if (evento.detalles != null && evento.detalles!.isNotEmpty)
              Text(evento.detalles!, style: tema.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
