import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/equipos_controller.dart';
import '../models/equipo.dart';
import '../widgets/aviso_cache.dart';
import '../widgets/chips_filtro_estado.dart';
import '../widgets/tarjeta_equipo.dart';
import '../widgets/vista_error.dart';
import '../widgets/vista_vacia.dart';

/// Lista de equipos con búsqueda, filtro por estado y arrastrar para refrescar.
class PantallaEquipos extends StatefulWidget {
  const PantallaEquipos({super.key});

  @override
  State<PantallaEquipos> createState() => _PantallaEquiposState();
}

class _PantallaEquiposState extends State<PantallaEquipos> {
  final _controlador = Get.find<EquiposController>();
  final _campoBusqueda = TextEditingController();

  @override
  void initState() {
    super.initState();
    _campoBusqueda.text = _controlador.busqueda.value;
    WidgetsBinding.instance.addPostFrameCallback((_) => _controlador.cargar());
  }

  @override
  void dispose() {
    _campoBusqueda.dispose();
    super.dispose();
  }

  void _limpiarFiltros() {
    _campoBusqueda.clear();
    _controlador.limpiarFiltros();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Equipos')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _campoBusqueda,
              onChanged: _controlador.buscar,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Buscar por código, marca, modelo o sede',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Obx(
            () => ChipsFiltroEstado<EstadoEquipo>(
              estados: EstadoEquipo.filtrables,
              etiqueta: (estado) => estado.etiqueta,
              conteo: _controlador.conteoPorEstado,
              total: _controlador.totalCoincidencias,
              actual: _controlador.filtroEstado.value,
              alSeleccionar: _controlador.filtrarPorEstado,
            ),
          ),
          Obx(() {
            final desde = _controlador.cacheDesde.value;
            if (desde == null) return const SizedBox.shrink();
            return AvisoCache(
              desde: desde,
              alReintentar: _controlador.refrescar,
            );
          }),
          Expanded(child: Obx(_cuerpo)),
        ],
      ),
    );
  }

  Widget _cuerpo() {
    switch (_controlador.estado.value) {
      case EstadoEquipos.cargando:
        return const Center(child: CircularProgressIndicator());
      case EstadoEquipos.error:
        return RefreshIndicator(
          onRefresh: _controlador.refrescar,
          child: VistaError(
            mensaje: _controlador.mensaje.value ?? '',
            alReintentar: _controlador.cargar,
          ),
        );
      case EstadoEquipos.vacio:
        return RefreshIndicator(
          onRefresh: _controlador.refrescar,
          child: const VistaVacia(
            titulo: 'Aún no hay equipos registrados',
            mensaje: 'Cuando se registren equipos aparecerán aquí.',
          ),
        );
      case EstadoEquipos.exito:
        final lista = _controlador.equiposFiltrados;
        if (lista.isEmpty) {
          return RefreshIndicator(
            onRefresh: _controlador.refrescar,
            child: VistaVacia(
              icono: Icons.search_off,
              titulo: 'Ningún equipo coincide',
              mensaje: 'Prueba con otra búsqueda u otro estado.',
              textoAccion: 'Limpiar filtros',
              alAccionar: _limpiarFiltros,
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
              final equipo = lista[indice - (aviso != null ? 1 : 0)];
              return TarjetaEquipo(equipo: equipo);
            },
          ),
        );
    }
  }
}
