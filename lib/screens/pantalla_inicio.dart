import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/equipos_controller.dart';
import 'pantalla_equipos.dart';
import 'pantalla_mis_equipos.dart';
import 'pantalla_ordenes.dart';
import 'pantalla_perfil.dart';

/// Pantalla protegida con la barra inferior «Equipos», «Mis equipos», «Órdenes» y «Perfil».
class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  int _indice = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _indice,
        children: const [
          PantallaEquipos(),
          PantallaMisEquipos(),
          PantallaOrdenes(),
          PantallaPerfil(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) {
          // «Equipos» y «Mis equipos» leen la lista de equipos en memoria.
          if (i <= 1) Get.find<EquiposController>().actualizarSiHaceFalta();
          setState(() => _indice = i);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.precision_manufacturing_outlined),
            selectedIcon: Icon(Icons.precision_manufacturing),
            label: 'Equipos',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border),
            selectedIcon: Icon(Icons.bookmark),
            label: 'Mis equipos',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Órdenes',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
