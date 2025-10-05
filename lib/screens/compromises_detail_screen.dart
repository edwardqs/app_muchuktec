// lib/screens/compromises_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'compromises_screen.dart';
const String API_BASE_URL = 'http://10.0.2.2:8000/api';

class CompromisesDetailScreen extends StatefulWidget {
  final String compromiseId;

  const CompromisesDetailScreen({super.key, required this.compromiseId});

  @override
  State<CompromisesDetailScreen> createState() => _CompromisesDetailScreenState();
}

class _CompromisesDetailScreenState extends State<CompromisesDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  CompromiseModel? _compromise;

  @override
  void initState() {
    super.initState();
    _fetchCompromiseDetails();
  }

  Future<void> _fetchCompromiseDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    if (token == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error de autenticación. Por favor, inicie sesión de nuevo.';
      });
      return;
    }

    try {
      final url = Uri.parse('$API_BASE_URL/compromisos/${widget.compromiseId}');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _compromise = CompromiseModel.fromJson(data);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al cargar los detalles: ${response.statusCode}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'No se pudo conectar al servidor.';
      });
    }
  }

  String _formatCurrency(double? value) {
    if (value == null) return 'N/A';
    final format = NumberFormat.currency(locale: 'es_PE', symbol: 'S/', decimalDigits: 2);
    return format.format(value);
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return 'N/A';
    try {
      final dateTime = DateTime.parse(date);
      return DateFormat('dd/MM/yyyy').format(dateTime);
    } catch (e) {
      return date;
    }
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.purple[400], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Colors.grey[600])),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 25),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const Divider(color: Colors.grey),
        const SizedBox(height: 10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          // Muestra un título genérico mientras carga
          _compromise == null ? 'Detalle de Compromiso' : 'Detalle: ${_compromise!.name}',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_compromise != null) // Solo muestra el botón si ya cargaron los datos
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () {
                // TODO: Implementar navegación a la pantalla de edición
              },
            ),
        ],
      ),
      // 6. El cuerpo de la pantalla ahora maneja los 3 estados posibles
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
          : _compromise == null
          ? const Center(child: Text('No se encontró el compromiso.'))
          : _buildDetailsView(), // Llama al método que construye la UI
    );
  }

  // Método que contiene la UI que ya tenías, para mantener el build() limpio
  Widget _buildDetailsView() {
    final compromise = _compromise!; // Sabemos que no es nulo aquí

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple[50],
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.purple.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  compromise.tipoCompromiso ?? 'COMPROMISO REGISTRADO',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[700],
                  ),
                ),
                const Divider(height: 20, color: Colors.purple),
                _buildDetailRow(
                    'Monto Total',
                    _formatCurrency(compromise.montoTotal), Icons.money),
                _buildDetailRow(
                    'Monto por Cuota',
                    _formatCurrency(compromise.montoCuota),
                    Icons.payment),
              ],
            ),
          ),
          _buildSectionHeader('Cuotas y Pagos'),
          _buildDetailRow('Total de Cuotas', (compromise.cantidadCuotas ?? 0).toString(), Icons.format_list_numbered),
          _buildDetailRow('Cuotas Pagadas', (compromise.cuotasPagadas ?? 0).toString(), Icons.check_circle_outline),
          _buildSectionHeader('Fechas y Frecuencia'),
          _buildDetailRow('Fecha de Inicio', _formatDate(compromise.date), Icons.calendar_today),
          _buildDetailRow('Fecha de Término', _formatDate(compromise.fechaTermino), Icons.event_available),
          _buildDetailRow('Frecuencia', (compromise.idfrecuencia ?? 'N/A').toString(), Icons.repeat),
          _buildSectionHeader('Intereses'),
          _buildDetailRow('Tasa de Interés', '${compromise.tasaInteres?.toStringAsFixed(2) ?? '0.00'}%', Icons.percent),
          _buildDetailRow('Tipo de Interés', compromise.tipoInteres ?? 'N/A', Icons.functions),
          _buildSectionHeader('Otros Datos'),
          _buildDetailRow('Estado Actual', compromise.estado ?? 'N/A', Icons.info),
          _buildDetailRow('ID del Tercero', (compromise.idtercero ?? 'N/A').toString(), Icons.people_alt),
          const SizedBox(height: 50),
        ],
      ),
    );
  }
}