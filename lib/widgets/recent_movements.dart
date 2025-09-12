// widgets/recent_movements.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

const String apiUrl = 'http://10.0.2.2:8000/api';

// --- Clases de modelos para los datos ---
class Movement {
  final String id;
  final String fecha;
  final double monto;
  final String tipo;
  final String nota;
  final String categoriaNombre;

  Movement({
    required this.id,
    required this.fecha,
    required this.monto,
    required this.tipo,
    required this.nota,
    required this.categoriaNombre,
  });

  factory Movement.fromJson(Map<String, dynamic> json) {
    return Movement(
      id: json['id']?.toString() ?? '',
      fecha: json['fecha'] as String? ?? '',
      monto: double.tryParse(json['monto'].toString()) ?? 0.0,
      tipo: json['tipo'] as String? ?? '',
      nota: json['nota'] as String? ?? '',
      categoriaNombre: json['categoria_nombre'] as String? ?? 'Sin Categoría',
    );
  }
}

class RecentMovements extends StatefulWidget {
  const RecentMovements({super.key});

  @override
  State<RecentMovements> createState() => _RecentMovementsState();
}

class _RecentMovementsState extends State<RecentMovements> {
  List<Movement> _movements = [];
  bool _isLoading = true;
  String? _accessToken;

  @override
  void initState() {
    super.initState();
    _fetchMovements();
  }

  Future<void> _fetchMovements() async {
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
      final response = await http.get(
        Uri.parse('$apiUrl/movimientos'),
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
            _movements = data.map((json) => Movement.fromJson(json)).toList();
          });
        } else {
          // Manejar el error de la API
          print('Error al cargar movimientos: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (mounted) {
        print('Excepción al cargar movimientos: $e');
        // Mostrar un mensaje al usuario en caso de error de conexión
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
              : _movements.isEmpty
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
            children: List.generate(_movements.length, (index) {
              final movement = _movements[index];
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
                  if (index < _movements.length - 1) const Divider(height: 1),
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