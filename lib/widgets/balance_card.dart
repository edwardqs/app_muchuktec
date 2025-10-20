import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:app_muchik/config/constants.dart';

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
          // Podrías mostrar un mensaje aquí si no hay cuenta seleccionada
        });
      }
      return;
    }

    setState(() { _isLoading = true; }); // Inicia la carga

    try {
      // --- 1. Obtener la cuenta específica (sin cambios) ---
      final accountUrl = Uri.parse('$API_BASE_URL/accounts/$_selectedAccountId');
      final accountsResponse = await http.get(
        accountUrl,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
      );

      // --- 2. Obtener los movimientos DE ESA CUENTA ---
      // ✅ ¡CAMBIO AQUÍ! Añadimos el query parameter 'idcuenta'
      final movementsUrl = Uri.parse('$API_BASE_URL/movimientos').replace(
        queryParameters: {
          'idcuenta': _selectedAccountId.toString(),
        },
      );
      final movementsResponse = await http.get(
        movementsUrl, // Usamos la nueva URL con el filtro
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (mounted) {
        // Verificamos que AMBAS respuestas sean exitosas
        if (accountsResponse.statusCode == 200 && movementsResponse.statusCode == 200) {
          final accountData = json.decode(accountsResponse.body);
          // Ahora SÍ recibimos solo los movimientos filtrados
          final List<dynamic> accountMovementsData = json.decode(movementsResponse.body);

          final totalBalance = double.tryParse(accountData['cuenta']['saldo_actual'].toString()) ?? 0.0;

          double totalIngresos = 0.0;
          double totalGastos = 0.0;

          // Ya no necesitamos filtrar localmente, la API lo hizo
          for (var movement in accountMovementsData) {
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
          // Imprimimos ambos códigos para saber cuál falló
          print('Error al cargar datos. Códigos: Cuenta(${accountsResponse.statusCode}), Movimientos(${movementsResponse.statusCode})');
          // Aquí podrías mostrar un error en la UI
        }
      }
    } catch (e) {
      if (mounted) {
        print('Excepción al cargar el saldo y movimientos: $e');
        // Mostrar error de conexión en la UI
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
