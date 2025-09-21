import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

const String apiUrl = 'http://10.0.2.2:8000/api';

class BalanceCard extends StatefulWidget {
  const BalanceCard({super.key});

  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> {
  double _saldoActual = 0.0;
  double _ingresosTotales = 0.0;
  double _gastosTotales = 0.0;
  bool _isLoading = true;
  String? _accessToken;
  int? _selectedAccountId;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('accessToken');
    _selectedAccountId = prefs.getInt('idCuenta');

    if (_accessToken == null || _selectedAccountId == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      // 1. Obtener la cuenta específica
      final accountUrl = Uri.parse('$apiUrl/accounts/$_selectedAccountId');
      final accountsResponse = await http.get(
        accountUrl,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
      );

      // 2. Obtener TODOS los movimientos
      final movementsUrl = Uri.parse('$apiUrl/movimientos');
      final movementsResponse = await http.get(
        movementsUrl,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (mounted) {
        if (accountsResponse.statusCode == 200 && movementsResponse.statusCode == 200) {
          final accountData = json.decode(accountsResponse.body);
          final List<dynamic> allMovementsData = json.decode(movementsResponse.body);

          // Filtrar los movimientos por el idcuenta localmente
          final filteredMovements = allMovementsData
              .where((movement) => movement['idcuenta'] == _selectedAccountId)
              .toList();

          // El saldo actual es el de la única cuenta seleccionada
          final totalBalance = double.tryParse(accountData['cuenta']['saldo_actual'].toString()) ?? 0.0;

          double totalIngresos = 0.0;
          double totalGastos = 0.0;

          // Recorrer solo los movimientos de la cuenta seleccionada
          for (var movement in filteredMovements) {
            if (movement['tipo'] == 'ingreso') {
              totalIngresos += double.tryParse(movement['monto'].toString()) ?? 0.0;
            } else if (movement['tipo'] == 'gasto') {
              totalGastos += double.tryParse(movement['monto'].toString()) ?? 0.0;
            }
          }

          setState(() {
            _saldoActual = totalBalance;
            _ingresosTotales = totalIngresos;
            _gastosTotales = totalGastos;
          });
        } else {
          print('Error al cargar datos. Códigos de estado: Cuenta(${accountsResponse.statusCode}), Movimientos(${movementsResponse.statusCode})');
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
    final currencyFormatter = NumberFormat.currency(locale: 'es_ES', symbol: 'S/', decimalDigits: 2);

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
            currencyFormatter.format(_saldoActual),
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
                      'Ingresos totales',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      currencyFormatter.format(_ingresosTotales),
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
                      'Gastos totales',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      currencyFormatter.format(_gastosTotales),
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
