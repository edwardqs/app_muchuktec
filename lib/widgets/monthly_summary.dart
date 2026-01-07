// widgets/monthly_summary.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // ✅ Import necesario
import '../widgets/finance_chart.dart';

class MonthlySummary extends StatelessWidget {
  const MonthlySummary({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ DEFINIMOS EL FORMATO DE MONEDA AQUÍ
    final currencyFormat = NumberFormat.currency(
        locale: 'en_US',
        symbol: 'S/ ',
        decimalDigits: 2
    );

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
            'Resumen Mensual (Julio 2025)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),

          // Summary Numbers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  const Text(
                    'Ingresos',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // ✅ USO DEL FORMATTER
                  Text(
                    currencyFormat.format(2500.00),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[600],
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  const Text(
                    'Gastos',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // ✅ USO DEL FORMATTER
                  Text(
                    currencyFormat.format(1249.25),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[600],
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  const Text(
                    'Balance',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // ✅ USO DEL FORMATTER
                  Text(
                    currencyFormat.format(1250.75),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[600],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 30),

          // Chart
          const FinanceChart(),

          const SizedBox(height: 20),

          // Month Labels
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text('Ene', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text('Feb', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text('Mar', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text('Abr', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text('May', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text('Jun', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}