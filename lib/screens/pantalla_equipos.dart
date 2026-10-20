import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/equipos_controller.dart';
import '../models/equipo.dart';
import '../utils/rutas.dart';
import '../widgets/indicador_estado.dart';
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
          _FiltrosEstado(controlador: _controlador),
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
              return _TarjetaEquipo(equipo: equipo);
            },
          ),
        );
    }
  }
}

class _FiltrosEstado extends StatelessWidget {
  final EquiposController controlador;

  const _FiltrosEstado({required this.controlador});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Obx(() {
        final actual = controlador.filtroEstado.value;
        final conteo = controlador.conteoPorEstado;
        return ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('Todos (${controlador.totalCoincidencias})'),
                selected: actual == null,
                onSelected: (_) => controlador.filtrarPorEstado(null),
              ),
            ),
            for (final estado in EstadoEquipo.filtrables)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('${estado.etiqueta} (${conteo[estado] ?? 0})'),
                  selected: actual == estado,
                  onSelected: (_) => controlador.filtrarPorEstado(estado),
                ),
              ),
          ],
        );
      }),
    );
  }
}

class _TarjetaEquipo extends StatelessWidget {
  final Equipo equipo;

  const _TarjetaEquipo({required this.equipo});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => Get.toNamed(Rutas.detalleEquipo, arguments: equipo),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(equipo.codigoInventario, style: tema.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                '${equipo.marca} ${equipo.modelo}',
                style: tema.textTheme.bodyLarge,
              ),
              const SizedBox(height: 4),
              Text(equipo.sede, style: tema.textTheme.bodyMedium),
              const SizedBox(height: 8),
              IndicadorEstado(estado: equipo.estado),
            ],
          ),
        ),
      ),
    );
  }
}
