// lib/screens/compromises_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'payment_history_screen.dart';
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

  bool _isOpeningPaymentDialog = false;

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

  // Metodo para enviar el pago a la API
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

  /// Esta función se llama al presionar el botón de añadir pago
  Future<void> _onAddPaymentPressed() async {
    // 1. Obtener la lista COMPLETA de cuotas desde el compromiso ya cargado
    final List<CuotaCompromisoModel> allCuotas = _compromise?.cuotas ?? [];

    // 2. Filtrar para encontrar las pendientes (no pagadas Y con saldo > 0)
    //    Tu modelo CuotaCompromisoModel ya calcula 'pagado' y 'saldoRestante'
    final List<CuotaCompromisoModel> pendingInstallments = allCuotas
        .where((cuota) => !cuota.pagado && cuota.saldoRestante > 0.01)
        .toList();
    // (Asumimos que la lista ya viene ordenada por numero_cuota desde el backend)

    CuotaCompromisoModel? preselectedInstallment;
    if (pendingInstallments.isNotEmpty) {
      // 3. Pre-seleccionar la primera de la lista de pendientes
      preselectedInstallment = pendingInstallments.first;
    }

    // 4. Mostrar el diálogo, pasando la cuota preseleccionada (o null)
    if (mounted) {
      _showAddPaymentDialog(preselectedInstallment);
    }
    // No necesitamos _isOpeningPaymentDialog porque la operación es instantánea
  }

// Metodo para mostrar el diálogo
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Muestra texto informativo ---
                      if (preselectedInstallment != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration( /* ... estilos ... */ ),
                            child: Text(
                              // ✅ Usa el 'displayText' del modelo (que muestra saldo restante)
                              "Pagando ${preselectedInstallment.displayText}",
                              style: TextStyle(color: Colors.purple[800], fontWeight: FontWeight.w500),
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
                      // --- Campo de Monto (con validación de maxAmountPayable) ---
                      TextFormField(
                        controller: amountController,
                        decoration: const InputDecoration(labelText: 'Monto a Pagar', prefixText: 'S/ '),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Ingrese un monto.';
                          final double? amount = double.tryParse(value);
                          if (amount == null || amount <= 0) return 'Ingrese un monto válido.';

                          // Validación de monto máximo
                          if (amount > (maxAmountPayable + 0.001)) {
                            return 'Monto excede el saldo restante (S/ ${maxAmountPayable.toStringAsFixed(2)}).';
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
    final numberFormatter = NumberFormat("#,##0.00", "es_PE");
    String numeroFormateado = numberFormatter.format(value);
    return 'S/ $numeroFormateado';
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
            // Botón para ver historial (NUEVO)
            if (_compromise != null) // Solo mostrar si ya cargó el compromiso
              IconButton(
                icon: const Icon(Icons.history, color: Colors.blueGrey),
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
            // Boton para agregar pago
            if (_compromise != null)
              IconButton(
                // ✅ Ya no necesita _isOpeningPaymentDialog porque ahora es instantáneo
                icon: const Icon(Icons.add_card_outlined, color: Colors.purple),
                tooltip: 'Registrar Pago',
                onPressed: _onAddPaymentPressed, // Llama a la función local
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

  Widget _buildSummaryItem({required IconData icon, required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.purple[400], size: 20),
        const SizedBox(width: 8), // Menos espacio horizontal
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: Colors.grey[700]), // Tamaño ajustado
                overflow: TextOverflow.ellipsis, // Evitar overflow si es largo
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87), // Tamaño ajustado
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
    final double progresoPago = (montoTotal > 0) ? (montoTotalPagado / montoTotal) : 0.0;

    // CALCULO DEL MONTO A PAGAR TOTAL
    final double montoCuotaCalc = compromise.montoCuota ?? 0.0;
    final int cantidadCuotasCalc = compromise.cantidadCuotas ?? 0;
    // Monto final = Monto de cuota * Cantidad de cuotas (si hay cuotas)
    // Si no hay cuotas, usamos el monto total original como fallback.
    final double montoFinalCalculado = (cantidadCuotasCalc > 0 && montoCuotaCalc > 0)
        ? (montoCuotaCalc * cantidadCuotasCalc)
        : compromise.montoTotal ?? 0.0;

    final currencyFormatter = NumberFormat.currency(locale: 'es_PE', symbol: 'S/', decimalDigits: 2);

    // --- Logic for showing installments ---
    final List<CuotaCompromisoModel> allCuotas = compromise.cuotas;
    final bool hasInstallments = allCuotas.isNotEmpty;
    final bool hasMoreThanThree = allCuotas.length > 3;
    final List<CuotaCompromisoModel> cuotasToShow = _showAllInstallments
        ? allCuotas
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

                // --- Fila 1 (Monto Total y Monto Final) ---
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryItem( // Usamos un widget auxiliar
                        icon: Icons.request_quote_outlined,
                        label: 'Monto Original', // Etiqueta más clara
                        value: _formatCurrency(compromise.montoTotal),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildSummaryItem(
                        icon: Icons.monetization_on_outlined, // Icono diferente
                        label: 'Monto Final', // Nueva etiqueta
                        value: _formatCurrency(montoFinalCalculado), // Valor calculado
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10), // Espacio entre filas

                // --- Fila 2 (Monto Cuota y Monto Pagado) ---
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryItem(
                        icon: Icons.paid_outlined,
                        label: 'Monto Pagado',
                        value: _formatCurrency(montoTotalPagado),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      // Ocultar si no hay cuotas
                      child: (compromise.cantidadCuotas ?? 0) > 0
                          ? _buildSummaryItem(
                        icon: Icons.payment_outlined,
                        label: 'Monto por Cuota',
                        value: _formatCurrency(compromise.montoCuota),
                      )
                          : const SizedBox(), // Espacio vacío si no hay cuotas
                    ),
                  ],
                ),

              ],
            ),
          ),
          if (hasInstallments) ...[
            _buildSectionHeader('Cuotas'),
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
                    columnSpacing: 14, // Reducir espacio entre columnas
                    headingRowHeight: 40,
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 60,
                    headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13),
                    dataTextStyle: const TextStyle(fontSize: 13, color: Colors.black87),

                    // ✅ --- COLUMNAS ACTUALIZADAS ---
                    columns: const [
                      DataColumn(label: Text('N°')),
                      DataColumn(label: Text('Monto'), numeric: true),
                      DataColumn(label: Text('Por'), numeric: true), // <-- NUEVA COLUMNA
                      DataColumn(label: Text('Estado')),
                      DataColumn(label: Text('Fecha')),
                    ],

                    // ✅ --- FILAS ACTUALIZADAS ---
                    rows: cuotasToShow.map((cuota) {
                      return DataRow(
                        cells: [
                          DataCell(Text(cuota.numeroCuota.toString())),
                          // Usa el formateador de monto TOTAL
                          DataCell(Text(cuota.montoTotalFormateado)),
                          // Usa el formateador de SALDO RESTANTE
                          DataCell(Text(
                            cuota.saldoRestanteFormateado,
                            style: TextStyle(fontWeight: FontWeight.bold, color: cuota.pagado ? Colors.grey : Colors.black),
                          )),
                          DataCell(
                              Text(
                                cuota.statusText, // 'Pendiente', 'Parcial', 'Pagada'
                                style: TextStyle(
                                  color: cuota.statusColor, // Color dinámico
                                  fontWeight: FontWeight.w500,
                                ),
                              )
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
          ],
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