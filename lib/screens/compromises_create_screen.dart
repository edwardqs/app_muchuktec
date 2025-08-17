// lib/screens/compromises_create.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

const String apiUrl = 'http://10.0.2.2:8000/api';

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
  String _selectedFrequency = 'Sin cuota'; // Frecuencia de la cuota

  bool isLoading = false;
  String? _accessToken;
  int? _idCuenta;

  List<Map<String, dynamic>> _terceros = [];
  int? _selectedTerceroId;


  @override
  void initState() {
    super.initState();
    _loadAccessToken().then((_) {
      _loadTerceros();
    });
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

  Future<void> _loadTerceros() async {
    if (_accessToken == null) return;
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/terceros'),
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

    if (_selectedFrequencyText == 'Sin cuota') {
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
        Uri.parse('$apiUrl/compromisos'),
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
        // Limpiar los campos después de guardar
        _nameController.clear();
        _entityController.clear();
        _amountController.clear();
        _interestRateController.clear();
        _installmentsController.clear();
        _calculatedAmountController.clear();
        setState(() {
          _startDate = null;
          _selectedType = 'Deuda';
          _interestType = 'Simple';
          _selectedFrequency = 'Sin cuota';
        });
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
            onPressed: () {},
          ),
          InkWell(
            onTap: () {
              print('Navigating to accounts_screen');
              Navigator.pushNamed(context, '/accounts');
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.purple[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                size: 20,
                color: Colors.purple[700],
              ),
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
              hint: 'S/.',
              controller: _amountController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // Campo Tasa de interés
            _buildLabeledTextField(
              label: 'Tasa de interés:',
              hint: '0.00%',
              controller: _interestRateController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // Radio buttons para Simple/Compuesto
            _buildRadioGroup('Tipo de interés:', ['Simple', 'Compuesto'], _interestType, (value) {
              setState(() {
                _interestType = value!;
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
                    enabled: _selectedFrequencyText != 'Sin cuota',
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
    bool enabled = true, // <--- nuevo
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
          decoration: InputDecoration(
            hintText: hint,
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
              borderSide: const BorderSide(color: Colors.orange, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          'Entidad',
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
    'Sin cuota': 1,
    'S': 2,
    'M': 3,
    'A': 4,
  };

// Variable para guardar el texto seleccionado (para mostrar en el Dropdown)
  String _selectedFrequencyText = 'Sin cuota';

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

                  if (_selectedFrequencyText == 'Sin cuota') {
                    _installmentsController.text = '0'; // siempre 0
                  }
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
    _amountController.dispose();
    _interestRateController.dispose();
    _installmentsController.dispose();
    _calculatedAmountController.dispose();
    super.dispose();
  }
}
