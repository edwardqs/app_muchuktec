// widgets/recent_movements.dart
import 'package:flutter/material.dart';

class RecentMovements extends StatelessWidget {
  const RecentMovements({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Últimos Movimientos',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _MovementItem(
                icon: Icons.remove_circle,
                iconColor: Colors.red,
                title: 'Supermercado',
                date: '20 Jul 2025',
                amount: '-S/45.00',
                amountColor: Colors.red,
              ),
              const Divider(height: 1),
              _MovementItem(
                icon: Icons.add_circle,
                iconColor: Colors.green,
                title: 'Salario',
                date: '15 Jul 2025',
                amount: '+S/1,500.00',
                amountColor: Colors.green,
              ),
              const Divider(height: 1),
              _MovementItem(
                icon: Icons.remove_circle,
                iconColor: Colors.red,
                title: 'Transporte',
                date: '19 Jul 2025',
                amount: '-S/10.00',
                amountColor: Colors.red,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MovementItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String date;
  final String amount;
  final Color amountColor;

  const _MovementItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.date,
    required this.amount,
    required this.amountColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }
}
