// widgets/bottom_navigation.dart
import 'package:flutter/material.dart';

class CustomBottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const CustomBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  // Colores Oficiales
  final Color cPetrolBlue = const Color(0xFF264653);
  final Color cMintGreen = const Color(0xFF2A9D8F);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15), // Sombra más sutil y moderna
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) {
          print('CustomBottomNavigation tapped index: $index');
          // Evitamos recargar si ya estamos en la misma pestaña
          if (index == selectedIndex) return;

          switch (index) {
            case 0:
              Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
              break;
            case 1:
              Navigator.pushNamedAndRemoveUntil(context, '/reports', (route) => false);
              break;
            case 2:
            // Actualizado para navegar a Presupuestos
              Navigator.pushNamedAndRemoveUntil(context, '/budgets', (route) => false);
              break;
            case 3:
            // Actualizado para navegar a Categorías
              Navigator.pushNamedAndRemoveUntil(context, '/categories', (route) => false);
              break;
            case 4:
              Navigator.pushNamedAndRemoveUntil(context, '/settings', (route) => false);
              break;
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Ítem seleccionado: Verde Menta
        selectedItemColor: cMintGreen,
        // Ítem no seleccionado: Azul Petróleo con opacidad
        unselectedItemColor: cPetrolBlue.withOpacity(0.5),

        // Tipografía Poppins
        selectedLabelStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
            fontSize: 12
        ),
        unselectedLabelStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12
        ),

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Reportes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'Presupuestos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.category_outlined),
            activeIcon: Icon(Icons.category),
            label: 'Categorías',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}