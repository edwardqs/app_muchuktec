import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const String apiUrl = 'http://10.0.2.2:8000/api';

class BalanceCard extends StatefulWidget {
  const BalanceCard({super.key});

  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> {
  double _saldoActual = 0.0;
  double _ingresosMes = 0.0;
  double _gastosMes = 0.0;
  bool _isLoading = true;
  String? _accessToken;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('accessToken');

    if (_accessToken == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final accountsResponse = await http.get(
        Uri.parse('$apiUrl/cuentas'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
      );

      final movementsResponse = await http.get(
        Uri.parse('$apiUrl/movimientos'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (mounted) {
        if (accountsResponse.statusCode == 200 && movementsResponse.statusCode == 200) {
          final List<dynamic> accountsData = json.decode(accountsResponse.body);
          final List<dynamic> movementsData = json.decode(movementsResponse.body);
          double totalBalance = 0.0;
          for (var account in accountsData) {
            totalBalance += double.tryParse(account['saldo_actual'].toString()) ?? 0.0;
          }

          double totalIngresos = 0.0;
          double totalGastos = 0.0;
          final now = DateTime.now();
          for (var movement in movementsData) {
            final movementDate = DateTime.tryParse(movement['fecha'].toString());
            if (movementDate != null && movementDate.year == now.year && movementDate.month == now.month) {
              if (movement['tipo'] == 'ingreso') {
                totalIngresos += double.tryParse(movement['monto'].toString()) ?? 0.0;
              } else if (movement['tipo'] == 'gasto') {
                totalGastos += double.tryParse(movement['monto'].toString()) ?? 0.0;
              }
            }
          }

          setState(() {
            _saldoActual = totalBalance;
            _ingresosMes = totalIngresos;
            _gastosMes = totalGastos;
          });
        } else {
          print('Error al cargar datos. Códigos de estado: Cuentas(${accountsResponse.statusCode}), Movimientos(${movementsResponse.statusCode})');
        }
      }
    } catch (e) {
      if (mounted) {
        print('Excepción al cargar el saldo y movimientos: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4FC3F7), Color(0xFF29B6F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: _isLoading
          ? const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(color: Colors.white),
        ),
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Saldo Disponible',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'S/. ${_saldoActual.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ingresos este mes',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'S/. ${_ingresosMes.toStringAsFixed(2)}', // Mostrar ingresos dinámicos
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gastos este mes',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'S/. ${_gastosMes.toStringAsFixed(2)}', // Mostrar gastos dinámicos
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
