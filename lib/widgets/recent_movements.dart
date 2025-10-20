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
          // Podrías mostrar un mensaje aquí indicando que no hay cuenta seleccionada
        });
      }
      return;
    }

    // ✅ 1. Construimos la URL CON el filtro idcuenta y un límite
    final uri = Uri.parse('$API_BASE_URL/movimientos').replace(
      queryParameters: {
        'idcuenta': _selectedAccountId.toString(),
        'limit': '5', // Pedimos solo los últimos 5 al backend
      },
    );

    try {
      final response = await http.get(
        uri, // Usamos la nueva URI con filtros
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
      );
      if (mounted) {
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          // ✅ 2. Asignamos directamente a _filteredMovements.
          setState(() {
            _filteredMovements = data.map((json) => Movement.fromJson(json)).toList();
          });
        } else {
          print('Error al cargar movimientos: ${response.statusCode} - ${response.body}');
          // Aquí podrías actualizar el estado para mostrar un mensaje de error en la UI
        }
      }
    } catch (e) {
      if (mounted) {
        print('Excepción al cargar movimientos: $e');
        // Mostrar mensaje de error de conexión en la UI
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
          child: _isLoading
              ? const Center(child: Padding(
            padding: EdgeInsets.all(24.0),
            child: CircularProgressIndicator(color: Colors.purple),
          ))
              : _filteredMovements.isEmpty
              ? const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(
              child: Text(
                'No hay movimientos recientes.',
                style: TextStyle(color: Colors.grey),
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
                    icon: isExpense ? Icons.remove_circle : Icons.add_circle,
                    iconColor: isExpense ? Colors.red : Colors.green,
                    title: movement.categoriaNombre,
                    date: DateFormat('dd MMM yyyy').format(DateTime.parse(movement.fecha)),
                    amount: '${isExpense ? '-' : '+'}S/${movement.monto.toStringAsFixed(2)}',
                    amountColor: isExpense ? Colors.red : Colors.green,
                  ),
                  if (index < (_filteredMovements.length > 5 ? 5 : _filteredMovements.length) - 1) const Divider(height: 1),
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
