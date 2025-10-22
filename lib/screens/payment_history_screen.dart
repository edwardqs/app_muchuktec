// lib/screens/payment_history_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_muchik/config/constants.dart';
import '../models/pago_compromiso_model.dart'; // Importa el modelo

class PaymentHistoryScreen extends StatefulWidget {
  final String compromiseId;
  final String compromiseName; // Pasar el nombre para el título

  const PaymentHistoryScreen({
    super.key,
    required this.compromiseId,
    required this.compromiseName,
  });

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  bool _isLoading = true;
  List<PagoCompromisoModel> _payments = [];
  String? _errorMessage;
  String? _accessToken;

  @override
  void initState() {
    super.initState();
    _fetchPaymentHistory();
  }

  Future<void> _fetchPaymentHistory() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('accessToken');

    if (_accessToken == null) {
      setState(() { _isLoading = false; _errorMessage = 'Error de autenticación.'; });
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      // Usamos la nueva ruta del backend
      final url = Uri.parse('$API_BASE_URL/compromisos/${widget.compromiseId}/pagos');
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _payments = data.map((json) => PagoCompromisoModel.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al cargar historial: ${response.statusCode}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error de conexión: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historial: ${widget.compromiseName}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
          : _payments.isEmpty
          ? const Center(child: Text('No hay pagos registrados para este compromiso.'))
          : ListView.builder(
        itemCount: _payments.length,
        itemBuilder: (context, index) {
          final payment = _payments[index];

          // Construir el texto del TÍTULO
          String titleText = payment.montoFormateado;
          // ✅ Usar el nuevo campo String?
          if (payment.numeroCuotaDisplay != null) {
            // Determina si es un número o la palabra "Flexible"
            bool isNumeric = int.tryParse(payment.numeroCuotaDisplay!) != null;
            if (isNumeric) {
              titleText = 'Cuota ${payment.numeroCuotaDisplay} - ' + titleText;
            } else {
              titleText = 'Cuota ${payment.numeroCuotaDisplay} - ' + titleText; // Ej: "(Flexible)"
            }
          }

          // Construir el texto del SUBTÍTULO (sin cambios)
          String subtitleText = 'Fecha: ${payment.fechaFormateada}';
          if (payment.nota != null && payment.nota!.isNotEmpty) {
            subtitleText += '\nNota: ${payment.nota}';
          }

          return Card( // Usamos Card para un mejor diseño
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            elevation: 2,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green[100],
                child: Icon(Icons.receipt_long, color: Colors.green[700]),
              ),
              title: Text(titleText, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(subtitleText),
              isThreeLine: payment.nota != null && payment.nota!.isNotEmpty,
            ),
          );
        },
      ),
    );
  }
}