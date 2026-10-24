import 'dart:async';

import '../models/orden.dart';
import 'almacen_estados_ordenes.dart';

/// Compara cada carga de órdenes con el último estado conocido de la persona y
/// avisa de los cambios ajenos. Las órdenes que le interesan son aquellas en
/// las que es solicitante o técnico.
class AvisosOrdenes {
  /// Con más cambios que estos en una misma carga se envía un solo resumen.
  static const maxAvisosIndividuales = 3;

  final AlmacenEstadosOrdenes _almacen;
  final int? Function() _idUsuario;
  final Future<void> Function(String titulo, String cuerpo) _avisar;

  int? _usuarioEnMemoria;
  Map<int, EstadoOrden>? _enMemoria;

  AvisosOrdenes(
    this._almacen, {
    required this._idUsuario,
    required this._avisar,
  });

  bool _leInteresa(Orden orden, int yo) =>
      orden.solicitanteId == yo || orden.tecnicoId == yo;

  /// Mapa de la persona, de memoria o del disco; null si aún no existe.
  Map<int, EstadoOrden>? _mapa(int yo) {
    if (_usuarioEnMemoria != yo) {
      _usuarioEnMemoria = yo;
      _enMemoria = _almacen.leer(yo);
    }
    return _enMemoria;
  }

  /// Olvida lo que hay en memoria (el disco no se toca).
  void limpiar() {
    _usuarioEnMemoria = null;
    _enMemoria = null;
  }

  /// Procesa una lista recién cargada. La primera vez de una persona (sin mapa
  /// guardado) solo guarda el mapa, sin avisar. Si guardar falla, no avisa y
  /// deja el mapa anterior, así el cambio se detecta en la siguiente carga.
  Future<void> alCargar(List<Orden> lista) async {
    final yo = _idUsuario();
    if (yo == null) return;
    final anterior = _mapa(yo);
    // Lo que no viene en la lista se conserva: el backend entrega una sola
    // página y su ausencia no es un cambio.
    final nuevo = <int, EstadoOrden>{...?anterior};
    final avisos = <(String, String)>[];

    for (final orden in lista) {
      if (!_leInteresa(orden, yo)) {
        nuevo.remove(orden.id);
        continue;
      }
      final previo = anterior?[orden.id];
      if (anterior != null && orden.estado != EstadoOrden.desconocido) {
        final titulo = 'Orden ${orden.codigoOrden}';
        if (previo == null) {
          if (orden.tecnicoId == yo && orden.solicitanteId != yo) {
            avisos.add((
              titulo,
              'Se te asignó esta orden. Estado: ${orden.estado.etiqueta}',
            ));
          }
        } else if (previo != orden.estado) {
          avisos.add((titulo, 'Ahora está ${orden.estado.etiqueta}'));
        }
      }
      nuevo[orden.id] = orden.estado;
    }

    await _almacen.guardar(yo, nuevo);
    _enMemoria = nuevo;
    await _enviar(avisos);
  }

  Future<void> _enviar(List<(String, String)> avisos) async {
    if (avisos.length > maxAvisosIndividuales) {
      avisos = [
        (
          'Órdenes actualizadas',
          'Tienes ${avisos.length} cambios en tus órdenes',
        ),
      ];
    }
    for (final (titulo, cuerpo) in avisos) {
      try {
        await _avisar(titulo, cuerpo);
      } catch (_) {
        // Un aviso que falla no impide los demás ni la carga.
      }
    }
  }

  /// Anota un cambio hecho por la propia persona para que no se tome como
  /// ajeno. Si aún no hay mapa, la primera carga lo creará.
  void registrarPropia(Orden orden) {
    final yo = _idUsuario();
    if (yo == null) return;
    final actual = _mapa(yo);
    if (actual == null) return;
    final nuevo = {...actual};
    if (_leInteresa(orden, yo)) {
      nuevo[orden.id] = orden.estado;
    } else {
      nuevo.remove(orden.id);
    }
    _guardarSinEsperar(yo, nuevo);
  }

  /// La persona eliminó la orden: ya no hay nada que comparar.
  void olvidar(int ordenId) {
    final yo = _idUsuario();
    if (yo == null) return;
    final actual = _mapa(yo);
    if (actual == null) return;
    _guardarSinEsperar(yo, {...actual}..remove(ordenId));
  }

  void _guardarSinEsperar(int yo, Map<int, EstadoOrden> nuevo) {
    _enMemoria = nuevo;
    unawaited(_almacen.guardar(yo, nuevo).catchError((_) {}));
  }
}
