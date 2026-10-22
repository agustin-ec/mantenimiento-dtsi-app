import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/ordenes_controller.dart';
import '../models/orden.dart';
import '../utils/rutas.dart';
import '../widgets/chips_filtro_estado.dart';
import '../widgets/tarjeta_orden.dart';
import '../widgets/vista_error.dart';
import '../widgets/vista_vacia.dart';

/// Lista de órdenes de mantenimiento con filtro por estado y arrastrar para
/// refrescar.
class PantallaOrdenes extends StatefulWidget {
  const PantallaOrdenes({super.key});

  @override
  State<PantallaOrdenes> createState() => _PantallaOrdenesState();
}

class _PantallaOrdenesState extends State<PantallaOrdenes> {
  final _controlador = Get.find<OrdenesController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _controlador.cargar());
  }

  Future<void> _nueva() async {
    final resultado = await Get.toNamed(Rutas.nuevaOrden);
    if (resultado is Orden && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Orden creada')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Órdenes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nueva orden',
            onPressed: _nueva,
          ),
        ],
      ),
      body: Column(
        children: [
          Obx(
            () => ChipsFiltroEstado<EstadoOrden>(
              estados: EstadoOrden.filtrables,
              etiqueta: (estado) => estado.etiqueta,
              conteo: _controlador.conteoPorEstado,
              total: _controlador.total,
              actual: _controlador.filtroEstado.value,
              alSeleccionar: _controlador.filtrarPorEstado,
            ),
          ),
          Expanded(child: Obx(_cuerpo)),
        ],
      ),
    );
  }

  Widget _cuerpo() {
    switch (_controlador.estado.value) {
      case EstadosOrdenes.cargando:
        return const Center(child: CircularProgressIndicator());
      case EstadosOrdenes.error:
        return RefreshIndicator(
          onRefresh: _controlador.refrescar,
          child: VistaError(
            mensaje: _controlador.mensaje.value ?? '',
            alReintentar: _controlador.cargar,
          ),
        );
      case EstadosOrdenes.vacio:
        return RefreshIndicator(
          onRefresh: _controlador.refrescar,
          child: const VistaVacia(
            titulo: 'Aún no hay órdenes registradas',
            mensaje:
                'Cuando se registren órdenes de mantenimiento aparecerán aquí.',
          ),
        );
      case EstadosOrdenes.exito:
        final lista = _controlador.ordenesFiltradas;
        if (lista.isEmpty) {
          return RefreshIndicator(
            onRefresh: _controlador.refrescar,
            child: VistaVacia(
              icono: Icons.search_off,
              titulo: 'Ninguna orden coincide',
              mensaje: 'Prueba con otro estado.',
              textoAccion: 'Limpiar filtros',
              alAccionar: _controlador.limpiarFiltros,
            ),
          );
        }
        final aviso = _controlador.mensaje.value;
        return RefreshIndicator(
          onRefresh: _controlador.refrescar,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: lista.length + (aviso != null ? 1 : 0),
            itemBuilder: (context, indice) {
              if (aviso != null && indice == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    aviso,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                );
              }
              return TarjetaOrden(
                orden: lista[indice - (aviso != null ? 1 : 0)],
              );
            },
          ),
        );
    }
  }
}
