// lib/screens/compromises_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:ui';

import 'payment_history_screen.dart';
import 'compromises_screen.dart'; // Para el modelo CompromiseModel si está ahí
import '../models/cuota_compromiso_model.dart';
import '../models/pago_compromiso_model.dart';
import 'package:app_muchik/config/constants.dart';

class CompromisesDetailScreen extends StatefulWidget {
  final String compromiseId;

  const CompromisesDetailScreen({super.key, required this.compromiseId});

  @override
  State<CompromisesDetailScreen> createState() => _CompromisesDetailScreenState();
}

class _CompromisesDetailScreenState extends State<CompromisesDetailScreen> {
  // --- COLORES OFICIALES ---
  final Color cAzulPetroleo = const Color(0xFF264653);
  final Color cVerdeMenta = const Color(0xFF2A9D8F);
  final Color cGrisClaro = const Color(0xFFF4F4F4);
  final Color cBlanco = const Color(0xFFFFFFFF);

  bool _isLoading = true;
  String? _errorMessage;
  CompromiseModel? _compromise;

  bool _showAllInstallments = false;
  bool _showAllPayments = false;

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

  Future<void> _submitPayment({
    required double amount,
    required String date,
    String? note,
    int? idcuota_compromiso,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    final idCuenta = prefs.getInt('idCuenta');

    if (token == null || idCuenta == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de autenticación o cuenta no seleccionada.'), backgroundColor: Colors.red),
      );
      return;
    }

    final url = Uri.parse('$API_BASE_URL/pagos-compromiso');

    Map<String, dynamic> body = {
      'idcompromiso': _compromise!.id,
      'idcuenta': idCuenta,
      'monto': amount,
      'fecha_pago': date,
      'nota': note,
    };
    if (idcuota_compromiso != null) {
      body['idcuota_compromiso'] = idcuota_compromiso;
    }

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Pago registrado con éxito.'), backgroundColor: cVerdeMenta),
        );
        _fetchCompromiseDetails();
      } else {
        String errorMessage = '';
        try {
          final errorData = json.decode(response.body);
          if (errorData['message'] != null) {
            errorMessage += '${errorData['message']}';
          }
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _onAddPaymentPressed() async {
    final List<CuotaCompromisoModel> allCuotas = _compromise?.cuotas ?? [];

    final List<CuotaCompromisoModel> pendingInstallments = allCuotas
        .where((cuota) => !cuota.pagado && cuota.saldoRestante > 0.01)
        .toList();

    CuotaCompromisoModel? preselectedInstallment;
    if (pendingInstallments.isNotEmpty) {
      preselectedInstallment = pendingInstallments.first;
    }

    if (mounted) {
      _showAddPaymentDialog(preselectedInstallment);
    }
  }

  void _showAddPaymentDialog(CuotaCompromisoModel? preselectedInstallment) {
    final formKey = GlobalKey<FormState>();

    final amountController = TextEditingController(text: preselectedInstallment?.saldoRestante.toStringAsFixed(2) ?? '');
    final noteController = TextEditingController();
    final dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));

    final int? selectedCuotaId = preselectedInstallment?.id;
    final double maxAmountPayable = preselectedInstallment?.saldoRestante ?? double.infinity;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: cBlanco,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Registrar Nuevo Pago',
                style: TextStyle(color: cAzulPetroleo, fontWeight: FontWeight.bold),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (preselectedInstallment != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cVerdeMenta.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: cVerdeMenta.withOpacity(0.3)),
                            ),
                            child: Text(
                              // AQUI ESTÁ EL FORMATO
                              "Pagando Cuota ${preselectedInstallment.numeroCuota} (${_formatDate(preselectedInstallment.fechaPagoProgramada)}) - Restante: ${_formatCurrency(preselectedInstallment.saldoRestante)}",
                              style: TextStyle(color: cAzulPetroleo, fontWeight: FontWeight.w600),
                            ),
                          ),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.only(bottom: 16.0),
                          child: Text(
                            "Pago flexible (sin cuota específica).",
                            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                          ),
                        ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: amountController,
                        decoration: InputDecoration(
                          labelText: 'Monto a Pagar',
                          prefixText: 'S/ ',
                          labelStyle: TextStyle(color: cAzulPetroleo.withOpacity(0.6)),
                          filled: true,
                          fillColor: cGrisClaro,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cVerdeMenta)),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Ingrese un monto.';
                          final double? amount = double.tryParse(value);
                          if (amount == null || amount <= 0) return 'Ingrese un monto válido.';
                          if (amount > (maxAmountPayable + 0.001)) {
                            return 'Monto excede el saldo restante (S/ ${maxAmountPayable.toStringAsFixed(2)}).';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: dateController,
                        decoration: InputDecoration(
                          labelText: 'Fecha de Pago',
                          labelStyle: TextStyle(color: cAzulPetroleo.withOpacity(0.6)),
                          suffixIcon: Icon(Icons.calendar_today, color: cAzulPetroleo),
                          filled: true,
                          fillColor: cGrisClaro,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cVerdeMenta)),
                        ),
                        readOnly: true,
                        onTap: () async {
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2101),
                            builder: (context, child) {
                              return Theme(
                                data: ThemeData.light().copyWith(
                                  primaryColor: cVerdeMenta,
                                  colorScheme: ColorScheme.light(primary: cVerdeMenta, onPrimary: cBlanco),
                                  buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (pickedDate != null) {
                            setDialogState(() {
                              dateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
                            });
                          }
                        },
                        validator: (value) => (value == null || value.isEmpty) ? 'Seleccione una fecha.' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: noteController,
                        decoration: InputDecoration(
                          labelText: 'Nota (Opcional)',
                          labelStyle: TextStyle(color: cAzulPetroleo.withOpacity(0.6)),
                          filled: true,
                          fillColor: cGrisClaro,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cVerdeMenta)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      final double amount = double.parse(amountController.text);
                      final String date = dateController.text;
                      final String note = noteController.text;

                      _showPaymentConfirmationDialog(
                        amount: amount,
                        date: date,
                        note: note,
                        idCuota: selectedCuotaId,
                        cuotaInfo: preselectedInstallment,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cVerdeMenta,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Continuar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatCurrency(double? value) {
    if (value == null) return 'N/A';
    // ✅ CAMBIO: Locale 'en_US' para formato 1,234.56
    final numberFormatter = NumberFormat.currency(locale: 'en_US', symbol: 'S/ ', decimalDigits: 2);
    return numberFormatter.format(value);
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
          Icon(icon, color: cVerdeMenta, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Colors.grey[600])),
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cAzulPetroleo)),
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
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cAzulPetroleo),
        ),
        Divider(color: Colors.grey[300]),
        const SizedBox(height: 10),
      ],
    );
  }

  void _showPaymentConfirmationDialog({
    required double amount,
    required String date,
    required String note,
    required int? idCuota,
    required CuotaCompromisoModel? cuotaInfo,
  }) {
    showDialog(
      context: context,
      barrierColor: cAzulPetroleo.withOpacity(0.3),
      builder: (ctx) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: AlertDialog(
            backgroundColor: cBlanco,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.check_circle_outline, color: cVerdeMenta, size: 28),
                const SizedBox(width: 10),
                Text('Confirmar Pago', style: TextStyle(fontWeight: FontWeight.bold, color: cAzulPetroleo)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Por favor verifica los detalles antes de procesar:',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                _buildConfirmationRow('Compromiso:', _compromise?.name ?? 'Sin nombre'),
                if (_compromise?.nombreTercero != null)
                  _buildConfirmationRow('Tercero:', _compromise!.nombreTercero!),
                const Divider(height: 20),
                _buildConfirmationRow(
                    'Tipo:',
                    cuotaInfo != null ? 'Cuota N° ${cuotaInfo.numeroCuota}' : 'Pago General'
                ),
                _buildConfirmationRow(
                    'Monto a Pagar:',
                    // ✅ USO DE FORMATTER
                    NumberFormat.currency(locale: 'en_US', symbol: 'S/ ', decimalDigits: 2).format(amount),
                    isBold: true,
                    valueColor: cVerdeMenta
                ),
                _buildConfirmationRow('Fecha:', _formatDate(date)),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Nota:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(note, style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Corregir', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                  _submitPayment(
                    amount: amount,
                    date: date,
                    note: note.isNotEmpty ? note : null,
                    idcuota_compromiso: idCuota,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: cVerdeMenta,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Confirmar y Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConfirmationRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: cAzulPetroleo)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: valueColor ?? cAzulPetroleo,
              fontSize: isBold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cGrisClaro,
      appBar: AppBar(
        backgroundColor: cBlanco,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cAzulPetroleo),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _compromise == null ? 'Detalle de Compromiso' : 'Detalle: ${_compromise!.name}',
          style: TextStyle(
            color: cAzulPetroleo,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_compromise != null)
            IconButton(
              icon: Icon(Icons.history, color: cAzulPetroleo),
              tooltip: 'Ver Historial de Pagos',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PaymentHistoryScreen(
                      compromiseId: _compromise!.id,
                      compromiseName: _compromise!.name,
                    ),
                  ),
                );
              },
            ),
          if (_compromise != null)
            IconButton(
              icon: Icon(Icons.add_card_outlined, color: cVerdeMenta),
              tooltip: 'Registrar Pago',
              onPressed: _onAddPaymentPressed,
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: cVerdeMenta))
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
          : _compromise == null
          ? Center(child: Text('No se encontró el compromiso.', style: TextStyle(color: cAzulPetroleo)))
          : _buildDetailsView(),
    );
  }

  Widget _buildSummaryItem({required IconData icon, required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: cAzulPetroleo, size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cAzulPetroleo.withOpacity(0.7)),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                value,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cAzulPetroleo),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsView() {
    final compromise = _compromise!;
    final double montoTotalPagado = compromise.montoTotalPagado ?? 0.0;
    final double montoTotal = compromise.montoTotal ?? 0.0;

    final double montoCuotaCalc = compromise.montoCuota ?? 0.0;
    final int cantidadCuotasCalc = compromise.cantidadCuotas ?? 0;

    double montoFinalCalculado = 0.0;
    bool esSinCuotas = (compromise.frecuencia?.id == 1) || (compromise.cantidadCuotas == 0);

    if (esSinCuotas) {
      final double tasa = compromise.tasaInteres ?? 0.0;
      final double interesCalculado = montoTotal * (tasa / 100);
      montoFinalCalculado = montoTotal + interesCalculado;
    } else {
      final double montoCuota = compromise.montoCuota ?? 0.0;
      final int cantidad = compromise.cantidadCuotas ?? 0;
      montoFinalCalculado = montoCuota * cantidad;
    }

    final List<CuotaCompromisoModel> allCuotas = compromise.cuotas;
    final bool hasInstallments = allCuotas.isNotEmpty;
    final bool hasMoreThanThree = allCuotas.length > 3;
    final List<CuotaCompromisoModel> cuotasToShow = _showAllInstallments
        ? allCuotas
        : (hasMoreThanThree ? allCuotas.sublist(0, 3) : allCuotas);

    final List<PagoCompromisoModel> allPayments = compromise.pagos;
    final bool hasMoreThanThreePayments = allPayments.length > 3;
    final List<PagoCompromisoModel> paymentsToShow = _showAllPayments
        ? allPayments
        : (hasMoreThanThreePayments ? allPayments.sublist(0, 3) : allPayments);

    // ✅ Formatter para la tabla
    final currencyFormatter = NumberFormat.currency(locale: 'en_US', symbol: 'S/ ', decimalDigits: 2);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cBlanco,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cVerdeMenta.withOpacity(0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  spreadRadius: 0,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  compromise.tipoCompromiso ?? 'COMPROMISO REGISTRADO',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cVerdeMenta,
                    letterSpacing: 0.5,
                  ),
                ),
                Divider(height: 24, color: cGrisClaro, thickness: 1.5),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryItem(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Capital',
                        value: _formatCurrency(compromise.montoTotal),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildSummaryItem(
                        icon: Icons.savings_outlined,
                        label: 'Total + Interés',
                        value: _formatCurrency(montoFinalCalculado),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryItem(
                        icon: Icons.check_circle_outline,
                        label: 'Pagado',
                        value: _formatCurrency(montoTotalPagado),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: (compromise.cantidadCuotas ?? 0) > 0
                          ? _buildSummaryItem(
                        icon: Icons.calendar_view_day_outlined,
                        label: 'Por Cuota',
                        value: _formatCurrency(compromise.montoCuota),
                      )
                          : const SizedBox(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          _buildSectionHeader('Pagos'),
          allPayments.isEmpty
              ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Center(child: Text('Aún no se han registrado pagos.', style: TextStyle(color: Colors.grey[600]))),
          )
              : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: double.infinity,
                child: DataTable(
                  columnSpacing: 16,
                  headingRowHeight: 40,
                  dataRowMinHeight: 48,
                  headingTextStyle: TextStyle(fontWeight: FontWeight.bold, color: cAzulPetroleo, fontSize: 13),
                  dataTextStyle: TextStyle(fontSize: 13, color: Colors.black87),
                  columns: const [
                    DataColumn(label: Text('Fecha')),
                    DataColumn(label: Text('Cuota')),
                    DataColumn(label: Text('Monto'), numeric: true),
                  ],
                  rows: paymentsToShow.map((pago) {
                    return DataRow(
                      cells: [
                        DataCell(Text(_formatDate(pago.fechaPago))),
                        DataCell(Text(pago.cuotaDisplayText)),
                        // ✅ USO DE FORMATTER
                        DataCell(Text(currencyFormatter.format(pago.monto), style: TextStyle(color: cAzulPetroleo, fontWeight: FontWeight.bold))),
                      ],
                    );
                  }).toList(),
                ),
              ),
              if (hasMoreThanThreePayments)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Center(
                    child: TextButton.icon(
                      icon: Icon(
                        _showAllPayments ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: cVerdeMenta,
                      ),
                      label: Text(
                        _showAllPayments ? 'Ver Menos Pagos' : 'Ver ${allPayments.length - 3} Pagos Más',
                        style: TextStyle(color: cVerdeMenta, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        setState(() {
                          _showAllPayments = !_showAllPayments;
                        });
                      },
                    ),
                  ),
                ),
            ],
          ),

          if (hasInstallments) ...[
            _buildSectionHeader('Cuotas'),
            allCuotas.isEmpty
                ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Center(child: Text('Este compromiso no tiene cuotas definidas.', style: TextStyle(color: Colors.grey[600]))),
            )
                : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: DataTable(
                    columnSpacing: 10,
                    headingRowHeight: 40,
                    dataRowMinHeight: 48,
                    headingTextStyle: TextStyle(fontWeight: FontWeight.bold, color: cAzulPetroleo, fontSize: 13),
                    dataTextStyle: const TextStyle(fontSize: 13, color: Colors.black87),
                    columns: const [
                      DataColumn(label: Text('N°')),
                      DataColumn(label: Text('Monto'), numeric: true),
                      DataColumn(label: Text('Por'), numeric: true),
                      DataColumn(label: Text('Estado')),
                      DataColumn(label: Text('Fecha')),
                    ],
                    rows: cuotasToShow.map((cuota) {
                      return DataRow(
                        cells: [
                          DataCell(Text(cuota.numeroCuota.toString())),
                          // ✅ USO DE FORMATTER
                          DataCell(Text(currencyFormatter.format(cuota.monto))),
                          // ✅ USO DE FORMATTER
                          DataCell(Text(
                            currencyFormatter.format(cuota.saldoRestante),
                            style: TextStyle(fontWeight: FontWeight.bold, color: cuota.pagado ? Colors.grey : cAzulPetroleo),
                          )),
                          DataCell(
                              Text(
                                cuota.statusText,
                                style: TextStyle(
                                  color: cuota.statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                          ),
                          DataCell(Text(_formatDate(cuota.fechaPagoProgramada))),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                if (hasMoreThanThree)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Center(
                      child: TextButton.icon(
                        icon: Icon(
                          _showAllInstallments ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: cVerdeMenta,
                        ),
                        label: Text(
                          _showAllInstallments ? 'Ver Menos Cuotas' : 'Ver ${allCuotas.length - 3} Cuotas Más',
                          style: TextStyle(color: cVerdeMenta, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          setState(() {
                            _showAllInstallments = !_showAllInstallments;
                          });
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ],

          _buildSectionHeader('Fechas y Frecuencia'),
          _buildDetailRow('Fecha de Inicio', _formatDate(compromise.date), Icons.calendar_today),
          _buildDetailRow('Fecha de Término', _formatDate(compromise.fechaTermino), Icons.event_available),
          _buildDetailRow('Frecuencia', compromise.frecuencia?.nombre ?? 'No especificada', Icons.repeat),

          _buildSectionHeader('Intereses'),
          _buildDetailRow('Tasa de Interés', '${compromise.tasaInteres?.toStringAsFixed(2) ?? '0.00'}%', Icons.percent),
          _buildDetailRow('Tipo de Interés', compromise.tipoInteres ?? 'N/A', Icons.functions),

          _buildSectionHeader('Otros Datos'),
          _buildDetailRow('Estado Actual', compromise.estado ?? 'N/A', Icons.info_outline),
          _buildDetailRow(
              'Tercero',
              compromise.nombreTercero ?? 'Sin tercero asignado',
              Icons.people_alt
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }
}