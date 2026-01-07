// lib/screens/payment_history_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_muchik/config/constants.dart';
import '../models/pago_compromiso_model.dart';
import 'package:intl/intl.dart';

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
  // --- COLORES OFICIALES ---
  final Color cAzulPetroleo = const Color(0xFF264653);
  final Color cVerdeMenta = const Color(0xFF2A9D8F);
  final Color cGrisClaro = const Color(0xFFF4F4F4);
  final Color cBlanco = const Color(0xFFFFFFFF);

  bool _isLoading = true;
  List<PagoCompromisoModel> _payments = [];
  String? _errorMessage;
  String? _accessToken;

  @override
  void initState() {
    super.initState();
    _fetchPaymentHistory();
  }

  // Helper para formato de moneda (1,234.56)
  String _formatCurrency(double amount) {
    final format = NumberFormat.currency(locale: 'en_US', symbol: 'S/ ', decimalDigits: 2);
    return format.format(amount);
  }

  void _showPaymentDetailsDialog(PagoCompromisoModel payment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cBlanco,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Detalle del Pago',
          style: TextStyle(color: cAzulPetroleo, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDialogRow('Monto Pagado:', _formatCurrency(payment.monto), isBoldValue: true, valueColor: cVerdeMenta),
              const SizedBox(height: 12),
              _buildDialogRow('Fecha de Pago:', payment.fechaFormateada), // Usamos fechaFormateada del modelo o formateamos aquí
              const SizedBox(height: 12),
              if (payment.nota != null && payment.nota!.isNotEmpty) ...[
                Text(
                  'Nota:',
                  style: TextStyle(fontWeight: FontWeight.w600, color: cAzulPetroleo.withOpacity(0.7), fontSize: 13),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cGrisClaro,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    payment.nota!,
                    style: TextStyle(color: cAzulPetroleo, fontSize: 14, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar', style: TextStyle(color: Colors.grey)),
          )
        ],
      ),
    );
  }

  Widget _buildDialogRow(String label, String value, {bool isBoldValue = false, Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w600, color: cAzulPetroleo.withOpacity(0.7), fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isBoldValue ? FontWeight.bold : FontWeight.normal,
            color: valueColor ?? cAzulPetroleo,
          ),
        ),
      ],
    );
  }

  Future<void> _fetchPaymentHistory() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('accessToken');

    if (_accessToken == null) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = 'Error de autenticación.'; });
      return;
    }

    if (mounted) setState(() { _isLoading = true; _errorMessage = null; });

    try {
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
      backgroundColor: cGrisClaro, // Fondo oficial
      appBar: AppBar(
        backgroundColor: cBlanco,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cAzulPetroleo),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Historial de Pagos',
              style: TextStyle(color: cAzulPetroleo, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.compromiseName,
              style: TextStyle(color: cAzulPetroleo.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.normal),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: cVerdeMenta))
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
          : _payments.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: cAzulPetroleo.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('No hay pagos registrados.', style: TextStyle(color: cAzulPetroleo.withOpacity(0.5))),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _payments.length,
        itemBuilder: (context, index) {
          final payment = _payments[index];

          // Título: Cuota o General
          String titleText = payment.cuotaDisplayText;
          // Formato de moneda corregido
          String amountText = _formatCurrency(payment.monto);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            color: cBlanco,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.black.withOpacity(0.05)),
            ),
            child: InkWell(
              onTap: () => _showPaymentDetailsDialog(payment),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cVerdeMenta.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.receipt_long_outlined, color: cVerdeMenta),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titleText,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: cAzulPetroleo,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            payment.fechaFormateada,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          amountText,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: cAzulPetroleo,
                          ),
                        ),
                        if (payment.nota != null && payment.nota!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Icon(Icons.comment, size: 14, color: Colors.grey[400]),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}