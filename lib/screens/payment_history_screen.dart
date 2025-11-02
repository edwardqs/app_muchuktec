// lib/screens/payment_history_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_muchik/config/constants.dart';
import '../models/pago_compromiso_model.dart';

class PaymentHistoryScreen extends StatefulWidget {
  final String compromiseId;
  final String compromiseName;

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

  void _showPaymentDetailsDialog(PagoCompromisoModel payment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detalle del Pago'),
        content: SingleChildScrollView( // Por si la nota es muy larga
          child: Column(
            mainAxisSize: MainAxisSize.min, // Ajustar tamaño al contenido
            crossAxisAlignment: CrossAxisAlignment.start, // Alinear texto a la izquierda
            children: [
              // Mostrar Monto
              Text(
                'Monto Pagado:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
              ),
              Text(
                payment.montoFormateado, // Usamos el formateador del modelo
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Mostrar Fecha
              Text(
                'Fecha de Pago:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
              ),
              Text(
                payment.fechaFormateada, // Usamos el formateador del modelo
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),

              // Mostrar Nota (solo si existe)
              if (payment.nota != null && payment.nota!.isNotEmpty) ...[
                Text(
                  'Nota:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
                ),
                Text(
                  payment.nota!,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Botón para cerrar
            child: const Text('Cerrar'),
          )
        ],
      ),
    );
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
          String titleText = '${payment.cuotaDisplayText} - ${payment.montoFormateado}';
          // --- LÓGICA DE SUBTÍTULO (sin cambios) ---
          String subtitleText = 'Fecha: ${payment.fechaFormateada}';
          if (payment.nota != null && payment.nota!.isNotEmpty) {
            subtitleText += '\nNota: ${payment.nota}';
          }

          return Card(
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
              onTap: () {
                _showPaymentDetailsDialog(payment);
              },
            ),
          );
        },
      ),
    );
  }
}