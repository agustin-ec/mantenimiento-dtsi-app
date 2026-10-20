import 'package:mantenimiento_dtsi/models/equipo.dart';
import 'package:mantenimiento_dtsi/models/evento_historial.dart';
import 'package:mantenimiento_dtsi/models/lista_equipos.dart';
import 'package:mantenimiento_dtsi/repositories/equipo_repository.dart';
import 'package:mantenimiento_dtsi/services/api_exception.dart';

Equipo equipoPrueba(
  int id, {
  String marca = 'Dell',
  String modelo = 'Latitude 5420',
  String sede = 'Sede Central',
  EstadoEquipo estado = EstadoEquipo.disponible,
}) => Equipo(
  id: id,
  codigoInventario: 'DTSI-$id',
  marca: marca,
  modelo: modelo,
  sede: sede,
  estado: estado,
);

/// Repositorio de equipos sin red.
class RepositorioEquiposFalso implements EquipoRepository {
  List<Equipo> equipos = [];
  List<EventoHistorial> historial = [];
  ApiException? error;

  /// Si se define, la lista sale marcada como «desde caché» con esta fecha.
  DateTime? desdeCache;
  ApiException? errorHistorial;
  final List<String> llamadas = [];

  @override
  Future<ListaEquipos> listarEquipos() async {
    llamadas.add('listarEquipos');
    if (error != null) throw error!;
    return ListaEquipos(
      List.of(equipos),
      sincronizadoEn: desdeCache ?? DateTime.now(),
      desdeCache: desdeCache != null,
    );
  }

  @override
  Future<List<EventoHistorial>> listarHistorial(int equipoId) async {
    llamadas.add('listarHistorial:$equipoId');
    if (errorHistorial != null) throw errorHistorial!;
    return List.of(historial);
  }
}
