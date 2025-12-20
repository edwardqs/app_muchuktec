// lib/widgets/quick_actions.dart
import 'package:flutter/material.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  // Definimos los colores oficiales localmente para este widget
  final Color cPetrolBlue = const Color(0xFF264653);
  final Color cMintGreen = const Color(0xFF2A9D8F);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Acciones Rápidas',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: cPetrolBlue, // Título en Azul Petróleo
            fontFamily: 'Poppins', // Tipografía oficial
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.add_circle_outline,
                label: 'Registrar\nMovimiento',
                // Estilo Verde Menta (Acción principal)
                color: cMintGreen.withOpacity(0.15),
                iconColor: cMintGreen,
                onTap: () {
                  Navigator.pushNamed(context, '/movements');
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: Icons.assignment_outlined,
                label: 'Asignar\nPresupuesto',
                // Estilo Azul Petróleo (Gestión)
                color: cPetrolBlue.withOpacity(0.1),
                iconColor: cPetrolBlue,
                onTap: () {
                  Navigator.pushNamed(context, '/assign-budget');
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: Icons.calendar_today_outlined,
                label: 'Registrar\nCompromiso',
                // Estilo Verde Menta (Acción de registro)
                color: cMintGreen.withOpacity(0.15),
                iconColor: cMintGreen,
                onTap: () {
                  Navigator.pushNamed(context, '/compromises_create');
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.category_outlined,
                label: 'Gestionar\nCategorías',
                // Estilo Azul Petróleo (Gestión)
                color: cPetrolBlue.withOpacity(0.1),
                iconColor: cPetrolBlue,
                onTap: () {
                  Navigator.pushNamed(context, '/categories');
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: Icons.event_note_outlined,
                label: 'Gestionar\nCompromisos',
                // Estilo Verde Menta (Para diferenciar de categorías o podrías usar Azul también)
                // He optado por Azul para agrupar "Gestionar" visualmente
                color: cPetrolBlue.withOpacity(0.1),
                iconColor: cPetrolBlue,
                onTap: () {
                  Navigator.pushNamed(context, '/compromises');
                },
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox()), // Espacio vacío para alineación
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16), // Bordes un poco más redondeados
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 26),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600, // Semi-bold para mejor lectura
                color: iconColor,
                fontFamily: 'Poppins', // Tipografía oficial
                height: 1.2, // Mejor interlineado
              ),
            ),
          ],
        ),
      ),
    );
  }
}