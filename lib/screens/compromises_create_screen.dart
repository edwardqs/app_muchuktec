// lib/screens/compromises_create.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:app_muchik/config/constants.dart';

class CompromisesCreateScreen extends StatefulWidget {
  const CompromisesCreateScreen({super.key});

  @override
  State<CompromisesCreateScreen> createState() => _CompromisesCreateScreenState();
}

class _CompromisesCreateScreenState extends State<CompromisesCreateScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _entityController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _interestRateController = TextEditingController();
  final TextEditingController _installmentsController = TextEditingController();
  final TextEditingController _calculatedAmountController = TextEditingController();
  DateTime? _startDate;

  String _selectedType = 'Deuda'; // "Deuda" o "Préstamo"
  String _interestType = 'Simple'; // "Simple" o "Compuesto"
  String _selectedFrequency = 'Sin cuotas'; // Frecuencia de la cuota

  bool _isLoading = true; // Mantenemos esta para el appbar
  bool isLoading = true; // Renombrado de isLoading a _isLoading para evitar ambigüedad

  String? _accessToken;
  int? _idCuenta;
  String? _profileImageUrl;

  List<Map<String, dynamic>> _terceros = [];
  int? _selectedTerceroId;

  @override
  void initState() {
    super.initState();
    setState(() {
      _isLoading = false;
      isLoading = false; // Para la vista principal
    });
    _selectedFrequencyId = frequencyMap[_selectedFrequencyText];
    _loadAccessToken().then((_) {
      // Solo intenta cargar la imagen y los terceros si el token existe
      if (_accessToken != null) {
        _loadSelectedAccountAndFetchImage(); // <-- ¡Llama a la función!
        _loadTerceros();
      }
    });
    _amountController.addListener(_calculateInstallmentAmount);
    _interestRateController.addListener(_calculateInstallmentAmount);
    _installmentsController.addListener(_calculateInstallmentAmount);
  }



  Future<void> _loadAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('accessToken');
    _idCuenta = prefs.getInt('idCuenta');
    if (_accessToken == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontró un token de sesión. Por favor, inicie sesión.'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _loadSelectedAccountAndFetchImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      final int? selectedAccountId = prefs.getInt('idCuenta');

      if (token == null) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/');
        }
        return;
      }

      if (selectedAccountId == null) {
        if (mounted) {
          setState(() {
            _profileImageUrl = null;
          });
        }
        return;
      }

      final url = Uri.parse('$API_BASE_URL/accounts/${selectedAccountId.toString()}');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final accountData = data['cuenta'];
        final relativePath = accountData['ruta_imagen'] as String?;

        setState(() {
          if (relativePath != null) {
            _profileImageUrl = '$STORAGE_BASE_URL/$relativePath';
          } else {
            _profileImageUrl = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        print('Excepción al obtener los detalles de la cuenta: $e');
      }
    }
  }

  Future<void> _loadTerceros() async {
    if (_accessToken == null) return;
    try {
      final response = await http.get(
        Uri.parse('$API_BASE_URL/terceros'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        setState(() {
          _terceros = List<Map<String, dynamic>>.from(data);
        });
      } else {
        print("Error al cargar terceros: ${response.body}");
      }
    } catch (e) {
      print("Excepción cargando terceros: $e");
    }
  }

  void _calculateInstallmentAmount() {
    final String amountText = _amountController.text;
    final String rateText = _interestRateController.text;
    final String installmentsText = _installmentsController.text;

    // Convertir los valores a números, con manejo de errores
    final double? amount = double.tryParse(amountText);
    final double? rate = double.tryParse(rateText);
    final int? installments = int.tryParse(installmentsText);

    // Si algún valor es nulo o cero, no se puede calcular
    if (amount == null || amount <= 0 || (installments == null || installments <= 0)) {
      _calculatedAmountController.text = ''; // Limpiar el campo si no hay valores válidos
      return;
    }

    double calculatedAmount = 0.0;
    double monthlyRate = (rate ?? 0.0) / 100 / 12; // Convertir tasa anual a mensual

    if (_interestType == 'Simple') {
      // Fórmula de interés simple: Monto total / cuotas + (Monto total * tasa de interés / 12)
      // O una versión simplificada, asumiendo que el interés se paga con el principal
      if (installments > 0) {
        calculatedAmount = (amount + (amount * (rate ?? 0.0) / 100)) / installments;
      }
    } else { // Interés compuesto
      // Fórmula de anualidad (cuota fija)
      if (monthlyRate > 0) {
        calculatedAmount = amount * (monthlyRate * (1 + monthlyRate) * installments) / ((1 + monthlyRate) * installments - 1);
      } else {
        // Si la tasa es 0, es solo el monto / cuotas
        calculatedAmount = amount / installments;
      }
    }

    // Actualizar el controlador de la cuota calculada con el resultado, redondeado a 2 decimales
    _calculatedAmountController.text = calculatedAmount.toStringAsFixed(2);
  }

  // Método para seleccionar la fecha
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  // Método para mostrar el diálogo de confirmación
  void _showConfirmationDialog() {
    // Primero, se verifica si hay campos vacíos.
    if (_nameController.text.isEmpty ||
        _entityController.text.isEmpty ||
        _amountController.text.isEmpty ||
        _startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, complete los campos obligatorios.'), backgroundColor: Colors.red),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Confirmar Registro', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                _buildPreviewText('Tipo:', _selectedType),
                _buildPreviewText('Nombre:', _nameController.text),
                _buildPreviewText('Entidad:', _entityController.text),
                _buildPreviewText('Monto Total:', 'S/. ${_amountController.text}'),
                _buildPreviewText('Tasa de Interés:', '${_interestRateController.text.isEmpty ? '0.00' : _interestRateController.text}%'),
                _buildPreviewText('Tipo de Interés:', _interestType),
                _buildPreviewText('Cuotas:', _installmentsController.text.isEmpty ? '0' : _installmentsController.text),
                _buildPreviewText('Frecuencia:', _selectedFrequency),
                _buildPreviewText('Cuota Calculada:', 'S/. ${_calculatedAmountController.text.isEmpty ? '0.00' : _calculatedAmountController.text}'),
                _buildPreviewText('Fecha de Inicio:', DateFormat('dd/MM/yyyy').format(_startDate!)),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Confirmar', style: TextStyle(color: Color(0xFF9B59B6))),
              onPressed: () {
                Navigator.of(context).pop(); // Cierra el diálogo
                _saveCompromise(); // Llama al método de guardado
              },
            ),
          ],
        );
      },
    );
  }

  // Método auxiliar para el texto de la vista previa
  Widget _buildPreviewText(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            TextSpan(
              text: ' $value',
              style: const TextStyle(color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }

  // Método para guardar el compromiso (llama a la API)
  void _saveCompromise() async {
    if (_accessToken == null || _idCuenta == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No se encontró el token de acceso.'), backgroundColor: Colors.red),
      );
      return;
    }

    // Calcular fecha de término en base a frecuencia y cuotas
    DateTime? fechaTermino;
    int cuotas = int.parse(_installmentsController.text.isEmpty ? '0' : _installmentsController.text);

    if (_selectedFrequencyText == 'Sin cuotas') {
      fechaTermino = null;
    } else if (cuotas > 0) {
      switch (_selectedFrequencyText) {
        case 'S': // Semanal
          fechaTermino = _startDate!.add(Duration(days: 7 * cuotas));
          break;
        case 'M': // Mensual
          fechaTermino = DateTime(
            _startDate!.year,
            _startDate!.month + cuotas,
            _startDate!.day,
          );
          break;
        case 'A': // Anual
          fechaTermino = DateTime(
            _startDate!.year + cuotas,
            _startDate!.month,
            _startDate!.day,
          );
          break;
      }
    }


    final body = {
      'idcuenta': _idCuenta,
      'tipo_compromiso': _selectedType,
      'nombre': _nameController.text,
      'idtercero': _selectedTerceroId,
      'monto_total': double.parse(_amountController.text),
      'tasa_interes': double.parse(_interestRateController.text.isEmpty ? '0.0' : _interestRateController.text),
      'tipo_interes': _interestType,
      'cantidad_cuotas': int.parse(_installmentsController.text.isEmpty ? '0' : _installmentsController.text),
      'idfrecuencia': _selectedFrequencyId,
      'monto_cuota': double.parse(_calculatedAmountController.text.isEmpty ? '0.0' : _calculatedAmountController.text),
      'fecha_inicio': _startDate!.toIso8601String().split('T')[0],
      'fecha_termino': fechaTermino != null ? fechaTermino.toIso8601String().split('T')[0] : null,
      'estado': 'Pendiente', // valor inicial por defecto
    };

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$API_BASE_URL/compromisos'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
          'Accept': 'application/json',
        },
        body: json.encode(body),
      );

      if (!mounted) return;
      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compromiso guardado exitosamente'), backgroundColor: Colors.green),
        );
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: ${response.body}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo conectar al servidor. Intente de nuevo.'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Compromisos',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.black),
            onPressed: () {
              Navigator.pushNamed(context, '/notifications');
            },
          ),
          InkWell(
            onTap: () {
              Navigator.pushNamed(context, '/accounts');
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.purple[100],
                shape: BoxShape.circle,
              ),
              child: _isLoading
                  ? const Center(
                  child: CircularProgressIndicator(
                    color: Colors.purple,
                    strokeWidth: 2,
                  ))
                  : _profileImageUrl != null
                  ? ClipOval(
                child: Image.network(
                  _profileImageUrl!,
                  fit: BoxFit.cover,
                  width: 40,
                  height: 40,
                  errorBuilder: (context, error, stackTrace) {
                    print('Error al cargar la imagen de red: $error');
                    return Icon(Icons.person, size: 24, color: Colors.purple[700]);
                  },
                ),
              )
                  : Icon(Icons.person, size: 24, color: Colors.purple[700]),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Radio buttons para Deuda/Préstamo
            _buildRadioGroup('Tipo:', ['Deuda', 'Préstamo'], _selectedType, (value) {
              setState(() {
                _selectedType = value!;
              });
            }),
            const SizedBox(height: 24),

            // Campo Nombre
            _buildLabeledTextField(
              label: 'Nombre',
              hint: 'Pago de refrigeradora...',
              controller: _nameController,
            ),
            const SizedBox(height: 16),

            // Campo Entidad
            _buildEntidadField(),
            const SizedBox(height: 16),


            // Campo Monto total
            _buildLabeledTextField(
              label: 'Monto total',
              hint: '00.00',
              controller: _amountController,
              prefix: 'S/. ',
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
              ],
              contentPadding: const EdgeInsets.fromLTRB(10, 14, 16, 14),
            ),
            const SizedBox(height: 16),

            // Campo Tasa de interés
            _buildLabeledTextField(
              label: 'Tasa de interés:',
              hint: '0.00%',
              controller: _interestRateController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
            ),
            const SizedBox(height: 16),

            // Radio buttons para Simple/Compuesto
            _buildRadioGroup('Tipo de interés:', ['Simple', 'Compuesto'], _interestType, (value) {
              setState(() {
                _interestType = value!;
                _calculateInstallmentAmount(); // <-- Llamar al cálculo aquí

              });
            }),
            const SizedBox(height: 16),

            // Campo Cuotas y Frecuencia
            Row(
              children: [
                Expanded(
                  child: _buildLabeledTextField(
                    label: 'Cuotas',
                    hint: '5',
                    controller: _installmentsController,
                    keyboardType: TextInputType.number,
                    enabled: _selectedFrequencyText != 'Sin cuotas',
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly, // <-- Solo números enteros
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildFrequencyDropdown(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Campo Cuota mensual
            _buildLabeledTextField(
              label: 'Cuota mensual(u otro) calculada:',
              hint: 'S/.',
              controller: _calculatedAmountController,
              keyboardType: TextInputType.number,
              enabled: _selectedFrequencyText != 'Sin cuotas',
            ),
            const SizedBox(height: 16),

            // Campo Fecha de inicio
            _buildDateField(
              label: 'Fecha de inicio del compromiso',
              hint: 'dd/mm/aa',
            ),
            const SizedBox(height: 24),

            // Botón de guardar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : _showConfirmationDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9B59B6),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  'Guardar compromiso',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildLabeledTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
    List<TextInputFormatter>? inputFormatters,
    String? prefix,
    EdgeInsetsGeometry? contentPadding,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color.fromARGB(255, 78, 78, 78),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          enabled: enabled,
          inputFormatters: inputFormatters,
          style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w400
          ),
          decoration: InputDecoration(
            prefixText: prefix,
            prefixStyle: const TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w400
            ),

            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            filled: true,
            fillColor: Colors.white,

            // Ajustar el padding interno ayuda a que se vea centrado verticalmente
            contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 14),

            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.orange, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  // ====================== CAMPO ENTIDAD (TERCERO) ======================
  Widget _buildEntidadField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tercero',
          style: TextStyle(
            fontSize: 14,
            color: Color.fromARGB(255, 78, 78, 78),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Autocomplete<Map<String, dynamic>>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<Map<String, dynamic>>.empty();
            }
            return _terceros.where((tercero) =>
                tercero['nombre']
                    .toLowerCase()
                    .contains(textEditingValue.text.toLowerCase()));
          },
          displayStringForOption: (option) => option['nombre'],
          fieldViewBuilder:
              (context, controller, focusNode, onFieldSubmitted) {
            controller.text = _entityController.text;
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: 'Escribe para buscar...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                  const BorderSide(color: Colors.orange, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
            );
          },
          onSelected: (Map<String, dynamic> selection) {
            setState(() {
              _selectedTerceroId = selection['id'];
              _entityController.text = selection['nombre'];
            });
          },
        ),
      ],
    );
  }


  Widget _buildDateField({
    required String label,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color.fromARGB(255, 78, 78, 78),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _selectDate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _startDate == null
                      ? hint
                      : DateFormat('dd/MM/yyyy').format(_startDate!),
                  style: TextStyle(
                    color: _startDate == null ? Colors.grey[400] : Colors.black,
                    fontSize: 16,
                  ),
                ),
                const Icon(Icons.calendar_today, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Nuevo widget para los Radio Buttons
  Widget _buildRadioGroup(String label, List<String> options, String selectedValue, void Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color.fromARGB(255, 78, 78, 78),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: options.map((option) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: option == options.last ? 0 : 16),
                child: RadioListTile<String>(
                  title: Text(option),
                  value: option,
                  groupValue: selectedValue,
                  onChanged: onChanged,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: const Color(0xFF2C97C1),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

// Mapa: Texto visible -> ID que vas a enviar
  final Map<String, int> frequencyMap = {
    'Sin cuotas': 1,
    'S': 2,
    'M': 3,
    'A': 4,
  };

// Variable para guardar el texto seleccionado (para mostrar en el Dropdown)
  String _selectedFrequencyText = 'Sin cuotas';

// Variable para guardar el ID que se enviará a la API
  int? _selectedFrequencyId;

  Widget _buildFrequencyDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Frecuencia',
          style: TextStyle(
            fontSize: 14,
            color: Color.fromARGB(255, 78, 78, 78),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedFrequencyText,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
              items: frequencyMap.keys
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    style: const TextStyle(fontSize: 16, color: Colors.black),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedFrequencyText = newValue!;
                  _selectedFrequencyId = frequencyMap[newValue];

                  if (_selectedFrequencyText == 'Sin cuotas') {
                    _installmentsController.text = '0'; // siempre 0
                  }
                  _calculateInstallmentAmount(); // <-- Llamar al cálculo aquí

                });
              },
            ),
          ),
        ),
      ],
    );
  }



  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            label: 'Reportes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Presupuestos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.category),
            label: 'Categorías',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: 'Ajustes',
          ),
        ],
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, '/dashboard');
              break;
            case 1:
              Navigator.pushReplacementNamed(context, '/reports');
              break;
            case 2:
              Navigator.pushReplacementNamed(context, '/budgets');
            case 3:
              Navigator.pushReplacementNamed(context, '/categories');
              break;
            case 4:
              Navigator.pushReplacementNamed(context, '/settings');
              break;
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _entityController.dispose();
    _amountController.removeListener(_calculateInstallmentAmount); // <-- Remover listener
    _amountController.dispose();
    _interestRateController.removeListener(_calculateInstallmentAmount); // <-- Remover listener
    _interestRateController.dispose();
    _installmentsController.removeListener(_calculateInstallmentAmount); // <-- Remover listener
    _installmentsController.dispose();
    _calculatedAmountController.dispose();
    super.dispose();
  }
}
