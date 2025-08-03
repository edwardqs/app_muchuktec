// widgets/budget_compliance.dart
import 'package:flutter/material.dart';

class BudgetCompliance extends StatelessWidget {
  const BudgetCompliance({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cumplimiento de Presupuestos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),

          // Alimentación
          _BudgetItem(
            category: 'Alimentación',
            budget: 'S/300.00',
            spent: 'S/280.00',
            remaining: '8% restante',
            spentColor: Colors.red[600]!,
            remainingColor: Colors.green[600]!,
            isOverBudget: false,
          ),

          const SizedBox(height: 16),

          // Transporte
          _BudgetItem(
            category: 'Transporte',
            budget: 'S/100.00',
            spent: 'S/70.00',
            remaining: '30% restante',
            spentColor: Colors.green[600]!,
            remainingColor: Colors.green[600]!,
            isOverBudget: false,
          ),

          const SizedBox(height: 16),

          // Entretenimiento
          _BudgetItem(
            category: 'Entretenimiento',
            budget: 'S/150.00',
            spent: 'S/160.00',
            remaining: 'Excedido en S/10.00',
            spentColor: Colors.red[600]!,
            remainingColor: Colors.red[600]!,
            isOverBudget: true,
          ),
        ],
      ),
    );
  }
}

class _BudgetItem extends StatelessWidget {
  final String category;
  final String budget;
  final String spent;
  final String remaining;
  final Color spentColor;
  final Color remainingColor;
  final bool isOverBudget;

  const _BudgetItem({
    required this.category,
    required this.budget,
    required this.spent,
    required this.remaining,
    required this.spentColor,
    required this.remainingColor,
    required this.isOverBudget,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              category,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            Text(
              spent,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: spentColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Presupuesto: $budget',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            Text(
              remaining,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: remainingColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
