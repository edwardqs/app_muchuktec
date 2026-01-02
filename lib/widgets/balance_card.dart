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

  // Definimos los colores oficiales
  final Color cPetrolBlue = const Color(0xFF264653);
  final Color cMintGreen = const Color(0xFF2A9D8F);

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
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final accountUrl = Uri.parse('$API_BASE_URL/accounts/$_selectedAccountId');
      final movementsUrl = Uri.parse('$API_BASE_URL/movimientos').replace(
        queryParameters: {'idcuenta': _selectedAccountId.toString()},
      );

      // Usamos Future.wait para hacer ambas peticiones en paralelo (más rápido)
      final responses = await Future.wait([
        http.get(accountUrl, headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        }),
        http.get(movementsUrl, headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        }),
      ]);

      final accountsResponse = responses[0];
      final movementsResponse = responses[1];

      if (mounted) {
        if (accountsResponse.statusCode == 200 && movementsResponse.statusCode == 200) {
          final accountData = json.decode(accountsResponse.body);
          final List<dynamic> accountMovementsData = json.decode(movementsResponse.body);

          final totalBalance = double.tryParse(accountData['cuenta']['saldo_actual'].toString()) ?? 0.0;

          double totalIngresos = 0.0;
          double totalGastos = 0.0;

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
          print('Error al cargar datos.');
        }
      }
    } catch (e) {
      if (mounted) print('Excepción al cargar el saldo: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'es_ES',
      symbol: 'S/ ',
      decimalDigits: 2,
      customPattern: 'S/ #,##0.00',
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cPetrolBlue, cMintGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cPetrolBlue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: 'Poppins',
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            currencyFormatter.format(_saldoActual),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_downward, color: Colors.white, size: 12),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Ingresos',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currencyFormatter.format(_ingresosTotales),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 30,
                width: 1,
                color: Colors.white.withOpacity(0.2),
                margin: const EdgeInsets.symmetric(horizontal: 10),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_upward, color: Colors.white, size: 12),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Gastos',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currencyFormatter.format(_gastosTotales),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
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