// lib/screens/compromises_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'compromises_screen.dart';
import '../models/cuota_compromiso_model.dart';
import 'package:app_muchik/config/constants.dart';

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
  bool _showAllInstallments = false;

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

  // Método para enviar el pago a la API
  Future<void> _submitPayment({
    required double amount,
    required String date,
    String? note,
    int? idcuota_compromiso,

  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    // Asumo que tienes la cuenta activa guardada en SharedPreferences
    final idCuenta = prefs.getInt('idCuenta');

    if (token == null || idCuenta == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de autenticación o cuenta no seleccionada.'), backgroundColor: Colors.red),
      );
      return;
    }

    final url = Uri.parse('$API_BASE_URL/pagos-compromiso');

    // Build the request body dynamically
    Map<String, dynamic> body = {
      'idcompromiso': _compromise!.id,
      'idcuenta': idCuenta,
      'monto': amount,
      'fecha_pago': date,
      'nota': note,
    };
    // Add the installment ID only if one was selected
    if (idcuota_compromiso != null) {
      body['idcuota_compromiso'] = idcuota_compromiso;
    }

    try{
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
          const SnackBar(content: Text('Pago registrado con éxito.'), backgroundColor: Colors.green),
        );
        _fetchCompromiseDetails();
      } else {
        String errorMessage = 'Error al registrar el pago: ${response.statusCode}';
        try {
          final errorData = json.decode(response.body);
          if (errorData['message'] != null) {
            errorMessage += ' - ${errorData['message']}';
          }
        } catch (_) {} // Ignore decoding errors
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

// Metodo para listar las cuotas pendientes
  Future<List<CuotaCompromisoModel>> _fetchPendingInstallments() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    if (token == null || _compromise == null) {
      throw Exception('Token o compromiso no disponible');
    }

    final url = Uri.parse('$API_BASE_URL/compromisos/${_compromise!.id}/cuotas-pendientes');
    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => CuotaCompromisoModel.fromJson(json)).toList();
    } else {
      throw Exception('Error al cargar cuotas: ${response.statusCode}');
    }
  }

// Metodo para mostrar el diálogo
  void _showAddPaymentDialog() {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));

    int? selectedCuotaId; // To store the selected installment ID
    List<CuotaCompromisoModel> pendingInstallments = []; // To store fetched installments

    showDialog(
      context: context,
      builder: (context) {
        // Use StatefulBuilder to manage the dialog's internal state
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Registrar Nuevo Pago'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // --- Dropdown for Pending Installments ---
                      FutureBuilder<List<CuotaCompromisoModel>>(
                        future: _fetchPendingInstallments(),
                        builder: (context, snapshot) {
                          // Loading state
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 20.0),
                              child: CircularProgressIndicator(),
                            ));
                          }
                          // Error state
                          if (snapshot.hasError) {
                            return Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.red));
                          }
                          // No data or empty list state
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            // Allow manual payment even if no installments found
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text('No hay cuotas específicas pendientes.', style: TextStyle(color: Colors.grey)),
                            );
                          }

                          // Success state - build the dropdown
                          pendingInstallments = snapshot.data!;
                          return DropdownButtonFormField<int>(
                            value: selectedCuotaId,
                            hint: const Text('Seleccionar cuota (opcional)'),
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Cuota Específica'),
                            items: pendingInstallments.map((cuota) {
                              return DropdownMenuItem<int>(
                                value: cuota.id,
                                child: Text(cuota.displayText, overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (int? newValue) {
                              setDialogState(() {
                                selectedCuotaId = newValue;
                                if (newValue != null) {
                                  final selectedCuota = pendingInstallments.firstWhere((c) => c.id == newValue);
                                  amountController.text = selectedCuota.monto.toStringAsFixed(2);
                                } else {
                                  amountController.clear();
                                }
                              });
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: amountController,
                        decoration: const InputDecoration(labelText: 'Monto a Pagar', prefixText: 'S/ '),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty || double.tryParse(value) == null || double.parse(value) <= 0) {
                            return 'Ingrese un monto válido.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: dateController,
                        decoration: const InputDecoration(
                            labelText: 'Fecha de Pago',
                            suffixIcon: Icon(Icons.calendar_today),
                        ),
                        readOnly: true,
                        onTap: () async {
                          DateTime initial = DateTime.now();
                          // Intenta usar la fecha actual del campo como fecha inicial
                          try {
                            if (dateController.text.isNotEmpty) {
                              initial = DateFormat('yyyy-MM-dd').parse(dateController.text);
                            }
                          } catch (e) {
                            // Si hay error al parsear, usa la fecha actual
                          }

                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                              lastDate: DateTime(2101),
                          );
                          if (pickedDate != null) {
                            setDialogState(() {
                              dateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
                            });
                          }
                        },
                        validator: (value) { // Validación opcional
                          if (value == null || value.isEmpty) {
                            return 'Seleccione una fecha.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: noteController,
                        decoration: const InputDecoration(labelText: 'Nota (Opcional)'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      _submitPayment(
                        amount: double.parse(amountController.text),
                        date: dateController.text,
                        note: noteController.text.isNotEmpty ? noteController.text : null,
                        idcuota_compromiso: selectedCuotaId,
                      );
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Guardar Pago'),
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
            if (_compromise != null)
              IconButton(
                icon: const Icon(Icons.add_card_outlined, color: Colors.purple), // Icono más descriptivo
                tooltip: 'Registrar Pago',
                onPressed: () {
                  _showAddPaymentDialog(); // Llamamos a la función que muestra la ventana
                },
              ),
          ]
      ),
      // 6. El cuerpo de la pantalla ahora maneja los 3 estados posibles
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
          : _compromise == null
          ? const Center(child: Text('No se encontró el compromiso.'))
          : _buildDetailsView(), // Llama al metodo que construye la UI
    );
  }

  // Metodo que contiene la UI que ya tenías, para mantener el build() limpio
  // lib/screens/compromises_detail_screen.dart (inside _CompromisesDetailScreenState)

  Widget _buildDetailsView() {
    final compromise = _compromise!;
    final double montoTotalPagado = compromise.montoTotalPagado ?? 0.0;
    final double montoTotal = compromise.montoTotal ?? 0.0;
    final double progresoPago = (montoTotal > 0) ? (montoTotalPagado / montoTotal) : 0.0;

    final currencyFormatter = NumberFormat.currency(locale: 'es_PE', symbol: 'S/', decimalDigits: 2);

    // --- Logic for showing installments ---
    final List<CuotaCompromisoModel> allCuotas = compromise.cuotas;
    final bool hasMoreThanThree = allCuotas.length > 3;
    // Determine which installments to show based on the state variable _showAllInstallments
    final List<CuotaCompromisoModel> cuotasToShow = _showAllInstallments
        ? allCuotas // Show all if flag is true
        : (hasMoreThanThree ? allCuotas.sublist(0, 3) : allCuotas); // Show first 3 or all if less than 3

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- SECCIÓN DE RESUMEN PRINCIPAL ---
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
                    'Monto Total', // Changed label slightly
                    _formatCurrency(compromise.montoTotal),
                    Icons.request_quote_outlined), // Changed Icon
                _buildDetailRow(
                    'Monto por Cuota',
                    _formatCurrency(compromise.montoCuota),
                    Icons.payment_outlined), // Changed Icon
                _buildDetailRow(
                    'Monto Total Pagado',
                    _formatCurrency(montoTotalPagado), Icons.paid_outlined),
              ],
            ),
          ),
          _buildSectionHeader('Cuotas y Pagos'),
          // Inside _buildDetailsView, after _buildSectionHeader('Cuotas y Pagos')

          Padding(
            padding: const EdgeInsets.only(bottom: 12.0), // Consistent padding
            child: Row(
              children: [
                // --- Total de Cuotas Section ---
                Expanded( // Takes up half the available space
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.format_list_numbered, color: Colors.purple[400], size: 20),
                      const SizedBox(width: 12),
                      Expanded( // Prevents overflow if label/value is long
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total de Cuotas',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Colors.grey[600]), // Label style from _buildDetailRow
                            ),
                            Text(
                              (compromise.cantidadCuotas ?? 0).toString(),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87), // Value style from _buildDetailRow
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Optional: Add some space between the two items if needed
                const SizedBox(width: 16),

                // --- Cuotas Pagadas Section ---
                Expanded( // Takes up the other half
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.purple[400], size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cuotas Pagadas',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Colors.grey[600]), // Label style
                            ),
                            Text(
                              (compromise.cuotasPagadas ?? 0).toString(),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87), // Value style
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          allCuotas.isEmpty
              ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Center(child: Text('Este compromiso no tiene cuotas definidas.', style: TextStyle(color: Colors.grey))),
          )
              : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, // Make button full width if desired
            children: [
              // --- The DataTable ---
              SizedBox(
                width: double.infinity,
                child: DataTable(
                  columnSpacing: 16,
                  headingRowHeight: 40,
                  dataRowMinHeight: 48,
                  dataRowMaxHeight: 60,
                  headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13),
                  dataTextStyle: const TextStyle(fontSize: 13, color: Colors.black87),
                  columns: const [
                    DataColumn(label: Text('N°')),
                    DataColumn(label: Text('Monto'), numeric: true),
                    DataColumn(label: Text('Estado')),
                    DataColumn(label: Text('Fecha Prog.')),
                  ],
                  // ✅ Use cuotasToShow (the potentially shorter list)
                  rows: cuotasToShow.map((cuota) {
                    return DataRow(
                      cells: [
                        DataCell(Text(cuota.numeroCuota.toString())),
                        DataCell(Text(currencyFormatter.format(cuota.monto))),
                        DataCell(
                          Text(
                            cuota.statusText,
                            style: TextStyle(
                              color: cuota.pagado ? Colors.green.shade700 : Colors.orange.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        DataCell(Text(_formatDate(cuota.fechaPagoProgramada))),
                      ],
                    );
                  }).toList(),
                ),
              ),
              // --- "View More" / "View Less" Button ---
              // ✅ Show button only if there are more than 3 installments
              if (hasMoreThanThree)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Center( // Center the button
                    child: TextButton.icon(
                      icon: Icon(
                        _showAllInstallments ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: Colors.purple[700],
                      ),
                      label: Text(
                        _showAllInstallments ? 'Ver Menos Cuotas' : 'Ver ${allCuotas.length - 3} Cuotas Más',
                        style: TextStyle(color: Colors.purple[700]),
                      ),
                      onPressed: () {
                        // Toggle the state and rebuild
                        setState(() {
                          _showAllInstallments = !_showAllInstallments;
                        });
                      },
                    ),
                  ),
                ),
            ],
          ),
          // --- FIN DE SECCIÓN DETALLE DE CUOTAS ---

          // --- SECCIÓN DE FECHAS Y FRECUENCIA ---
          _buildSectionHeader('Fechas y Frecuencia'),
          _buildDetailRow('Fecha de Inicio', _formatDate(compromise.date), Icons.calendar_today),
          _buildDetailRow('Fecha de Término', _formatDate(compromise.fechaTermino), Icons.event_available),
          _buildDetailRow('Frecuencia', compromise.frecuencia?.nombre ?? 'No especificada', Icons.repeat), // Uses name

          // --- SECCIÓN DE INTERESES ---
          _buildSectionHeader('Intereses'),
          _buildDetailRow('Tasa de Interés', '${compromise.tasaInteres?.toStringAsFixed(2) ?? '0.00'}%', Icons.percent),
          _buildDetailRow('Tipo de Interés', compromise.tipoInteres ?? 'N/A', Icons.functions),

          // --- SECCIÓN OTROS DATOS ---
          _buildSectionHeader('Otros Datos'),
          _buildDetailRow('Estado Actual', compromise.estado ?? 'N/A', Icons.info_outline), // Changed Icon
          _buildDetailRow('ID del Tercero', (compromise.idtercero ?? 'N/A').toString(), Icons.people_alt),
          const SizedBox(height: 50),
        ],
      ),
    );
  }
}