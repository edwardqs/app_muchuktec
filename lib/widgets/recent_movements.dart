import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:app_muchik/config/constants.dart';

// --- Clases de modelos para los datos ---
class Movement {
  final String id;
  final String fecha;
  final double monto;
  final String tipo;
  final String nota;
  final String categoriaNombre;
  final int idcuenta;

  Movement({
    required this.id,
    required this.fecha,
    required this.monto,
    required this.tipo,
    required this.nota,
    required this.categoriaNombre,
    required this.idcuenta,
  });

  factory Movement.fromJson(Map<String, dynamic> json) {
    return Movement(
      id: json['id']?.toString() ?? '',
      fecha: json['fecha'] as String? ?? '',
      monto: double.tryParse(json['monto'].toString()) ?? 0.0,
      tipo: json['tipo'] as String? ?? '',
      nota: json['nota'] as String? ?? '',
      categoriaNombre: json['categoria_nombre'] as String? ?? 'Sin Categoría',
      idcuenta: json['idcuenta'] as int? ?? 0,
    );
  }
}

class RecentMovements extends StatefulWidget {
  const RecentMovements({super.key});

  @override
  State<RecentMovements> createState() => _RecentMovementsState();
}

class _RecentMovementsState extends State<RecentMovements> {
  List<Movement> _filteredMovements = [];
  bool _isLoading = true;
  String? _accessToken;
  int? _selectedAccountId;

  // Colores Oficiales
  final Color cPetrolBlue = const Color(0xFF264653);
  final Color cMintGreen = const Color(0xFF2A9D8F);
  // Un rojo que complementa bien la paleta (para gastos)
  final Color cExpenseRed = const Color(0xFFE63946);

  @override
  void initState() {
    super.initState();
    _fetchMovements();
  }

  Future<void> _fetchMovements() async {
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

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    final uri = Uri.parse('$API_BASE_URL/movimientos').replace(
      queryParameters: {
        'idcuenta': _selectedAccountId.toString(),
        'limit': '5',
      },
    );

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (mounted) {
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          setState(() {
            _filteredMovements = data.map((json) => Movement.fromJson(json)).toList();
          });
        } else {
          print('Error loading recent movements: ${response.statusCode} - ${response.body}');
        }
      }
    } catch (e) {
      if (mounted) {
        print('Exception loading recent movements: $e');
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
    // ✅ DEFINIMOS EL FORMATO DE MONEDA AQUÍ
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_US',
      symbol: 'S/ ',
      decimalDigits: 2,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Últimos Movimientos',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: cPetrolBlue, // Azul Petróleo
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16), // Bordes más suaves
            boxShadow: [
              BoxShadow(
                color: cPetrolBlue.withOpacity(0.08), // Sombra tintada de azul
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _isLoading
              ? Center(child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: CircularProgressIndicator(color: cMintGreen), // Loader Verde Menta
          ))
              : _filteredMovements.isEmpty
              ? Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 40, color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Text(
                    'No hay movimientos recientes.',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
          )
              : Column(
            children: List.generate(_filteredMovements.length > 5 ? 5 : _filteredMovements.length, (index) {
              final movement = _filteredMovements[index];
              final isExpense = movement.tipo == 'gasto';

              return Column(
                children: [
                  _MovementItem(
                    icon: isExpense ? Icons.arrow_downward : Icons.arrow_upward,
                    // Usamos Rojo para gasto, Verde Menta para ingreso
                    iconColor: isExpense ? cExpenseRed : cMintGreen,
                    title: movement.categoriaNombre,
                    date: DateFormat('dd MMM yyyy').format(DateTime.parse(movement.fecha)),
                    // ✅ USAMOS EL FORMATTER AQUÍ
                    amount: '${isExpense ? '-' : '+'}${currencyFormatter.format(movement.monto)}',
                    amountColor: isExpense ? cExpenseRed : cMintGreen,
                    titleColor: cPetrolBlue,
                  ),
                  if (index < (_filteredMovements.length > 5 ? 5 : _filteredMovements.length) - 1)
                    Divider(height: 1, color: Colors.grey[100]),
                ],
              );
            }),
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
  final Color titleColor;

  const _MovementItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.date,
    required this.amount,
    required this.amountColor,
    required this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              // Fondo muy suave del color del icono
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12), // Cuadrado redondeado moderno
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: titleColor, // Azul Petróleo
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: amountColor,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }
}