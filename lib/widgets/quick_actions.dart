// lib/widgets/quick_actions.dart
import 'package:flutter/material.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Acciones Rápidas',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.add_circle_outline,
                label: 'Registrar\nMovimiento',
                color: Colors.blue[100]!,
                iconColor: Colors.blue[700]!,
                onTap: () {
                  // RUTA ESPECÍFICA PARA ASIGNAR MOVIMIENTO
                  Navigator.pushNamed(context, '/movements');
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: Icons.assignment_outlined,
                label: 'Asignar\nPresupuesto',
                color: Colors.green[100]!,
                iconColor: Colors.green[700]!,
                onTap: () {
                  // RUTA ESPECÍFICA PARA ASIGNAR PRESUPUESTO
                  Navigator.pushNamed(context, '/assign-budget');
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: Icons.calendar_today_outlined,
                label: 'Registrar\nCompromiso',
                color: Colors.purple[100]!,
                iconColor: Colors.purple[700]!,
                onTap: () {
                  // ¡Corregido! Usa la ruta correcta
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
                color: Colors.yellow[100]!,
                iconColor: Colors.orange[700]!,
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
                color: Colors.pink[100]!,
                iconColor: Colors.pink[700]!,
                onTap: () {
                  Navigator.pushNamed(context, '/compromises');
                },
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox()), // Empty space for alignment
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
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: iconColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}