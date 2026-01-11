// lib/screens/compromises_create.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
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
  // --- COLORES OFICIALES ---
  final Color cAzulPetroleo = const Color(0xFF264653);
  final Color cVerdeMenta = const Color(0xFF2A9D8F);
  final Color cGrisClaro = const Color(0xFFF4F4F4);
  final Color cBlanco = const Color(0xFFFFFFFF);

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _entityController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _interestRateController = TextEditingController();
  final TextEditingController _installmentsController = TextEditingController();
  final TextEditingController _calculatedAmountController = TextEditingController();
  DateTime? _startDate;

  String _selectedType = 'Deuda';
  String _interestType = 'Simple';
  String _selectedFrequency = 'Sin cuotas';

  bool _isLoading = true;
  bool isLoading = true;

  String? _accessToken;
  int? _idCuenta;
  String? _profileImageUrl;

  List<Map<String, dynamic>> _terceros = [];
  int? _selectedTerceroId;

  // Mapa: Texto visible -> ID que vas a enviar
  final Map<String, int> frequencyMap = {
    'Sin cuotas': 1,
    'Semanal': 2,
    'Mensual': 3,
    'Anual': 4,
  };

  String _selectedFrequencyText = 'Sin cuotas';
  int? _selectedFrequencyId;

  @override
  void initState() {
    super.initState();
    setState(() {
      _isLoading = false;
      isLoading = false;
    });
    _selectedFrequencyId = frequencyMap[_selectedFrequencyText];
    _loadAccessToken().then((_) {
      if (_accessToken != null) {
        _loadSelectedAccountAndFetchImage();
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

  // Variable para guardar el total internamente
  double _montoTotalFinal = 0.0;

  void _calculateInstallmentAmount() {
    final double? P = double.tryParse(_amountController.text);
    final double? tasaAnual = double.tryParse(_interestRateController.text);
    final int? n = int.tryParse(_installmentsController.text);

    if (P == null || P <= 0 || n == null || n <= 0) {
      _calculatedAmountController.text = '';
      _montoTotalFinal = 0.0;
      return;
    }

    double frequencyFactor = 12;
    if (_selectedFrequencyText == 'Semanal') {
      frequencyFactor = 52;
    } else if (_selectedFrequencyText == 'Mensual') {
      frequencyFactor = 12;
    } else if (_selectedFrequencyText == 'Anual') {
      frequencyFactor = 1;
    }
    double ia = (tasaAnual ?? 0.0) / 100;
    double i = ia/frequencyFactor;
    double C = 0.0;

    if (_interestType == 'Simple') {
      // FÓRMULA (SIMPLE): M = P(1 + i*n)
      _montoTotalFinal = P * (1 + (i * n));
      C = _montoTotalFinal / n;
    } else {
      // FÓRMULA (COMPUESTO): M = P * [1+(1+i)^1/f-1]^n
      if (i > 0) {
        double f = 1/frequencyFactor;
        double factor = pow(1 + ia, f).toDouble(); // (1+i)^f
        double Ca = (1 + factor -1);
        _montoTotalFinal = P * pow(Ca, n).toDouble();// C^n
        C = _montoTotalFinal / n;
      } else {
        C = P / n;
        _montoTotalFinal = P;
      }
    }

    // Mostramos la cuota (C) en el controlador existente
    _calculatedAmountController.text = C.toStringAsFixed(2);
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (BuildContext context, Widget? child) {
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
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  // ✅ VALIDACIÓN DE TERCERO NO REGISTRADO
  void _showUnregisteredTerceroDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: cBlanco,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              const SizedBox(width: 8),
              const Expanded(child: Text('Tercero no registrado', style: TextStyle(fontSize: 18))),
            ],
          ),
          content: Text(
            'El tercero "${_entityController.text}" no se encuentra en sus registros. Debe registrarlo antes de asignar un compromiso.',
            style: TextStyle(color: cAzulPetroleo),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: cVerdeMenta,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(context);
                // Asumiendo que la ruta de terceros es '/terceros'
                Navigator.pushNamed(context, '/compromises_tiers').then((_) {
                  // Recargar terceros al volver
                  _loadTerceros();
                });
              },
              child: const Text('Registrar Tercero', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // ✅ FUNCIÓN DE CONFIRMACIÓN MODIFICADA CON VALIDACIONES
  void _showConfirmationDialog() {
    // 1. Validar campos obligatorios específicos
    List<String> missingFields = [];

    if (_nameController.text.trim().isEmpty) missingFields.add('Nombre');
    if (_entityController.text.trim().isEmpty) missingFields.add('Tercero');
    if (_amountController.text.trim().isEmpty) missingFields.add('Monto total');
    if (_startDate == null) missingFields.add('Fecha de inicio');

    // Validación de cuotas si la frecuencia NO es 'Sin cuotas'
    if (_selectedFrequencyText != 'Sin cuotas') {
      if (_installmentsController.text.trim().isEmpty || _installmentsController.text == '0') {
        missingFields.add('Cantidad de cuotas');
      }
    }

    if (missingFields.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor complete: ${missingFields.join(', ')}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // 2. Validar que el tercero exista en la lista cargada
    // Buscamos si el texto actual coincide con algún nombre en la lista (case insensitive)
    final existingTercero = _terceros.firstWhere(
          (t) => t['nombre'].toString().toLowerCase() == _entityController.text.trim().toLowerCase(),
      orElse: () => {},
    );

    if (existingTercero.isEmpty) {
      // El tercero escrito no está en la lista -> Mostrar Modal
      _showUnregisteredTerceroDialog();
      return;
    } else {
      // Si existe, nos aseguramos que el ID esté seteado correctamente
      _selectedTerceroId = existingTercero['id'];
    }

    // 3. Si todo está bien, mostrar diálogo de confirmación
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: cBlanco,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Confirmar Registro', style: TextStyle(fontWeight: FontWeight.bold, color: cAzulPetroleo)),
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
                _buildPreviewText('Frecuencia:', _selectedFrequencyText),
                _buildPreviewText('Cuota Calculada:', 'S/. ${_calculatedAmountController.text.isEmpty ? '0.00' : _calculatedAmountController.text}'),
                _buildPreviewText('Fecha de Inicio:', DateFormat('dd/MM/yyyy').format(_startDate!)),
                _buildPreviewText(
                  'Total a Pagar (M):',
                  'S/. ${_montoTotalFinal.toStringAsFixed(2)}',
                ),
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
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: cVerdeMenta,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Confirmar', style: TextStyle(color: cBlanco, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(context).pop();
                _saveCompromise();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildPreviewText(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: cAzulPetroleo,
              ),
            ),
            TextSpan(
              text: ' $value',
              style: TextStyle(color: cAzulPetroleo.withOpacity(0.8)),
            ),
          ],
        ),
      ),
    );
  }

  void _saveCompromise() async {
    if (_accessToken == null || _idCuenta == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No se encontró el token de acceso.'), backgroundColor: Colors.red),
      );
      return;
    }

    DateTime? fechaTermino;
    int cuotas = int.parse(_installmentsController.text.isEmpty ? '0' : _installmentsController.text);

    if (_selectedFrequencyText == 'Sin cuotas') {
      fechaTermino = null;
    } else if (cuotas > 0) {
      switch (_selectedFrequencyText) {
        case 'S':
          fechaTermino = _startDate!.add(Duration(days: 7 * cuotas));
          break;
        case 'M':
          fechaTermino = DateTime(
            _startDate!.year,
            _startDate!.month + cuotas,
            _startDate!.day,
          );
          break;
        case 'A':
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
      'estado': 'Pendiente',
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
          SnackBar(content: const Text('Compromiso guardado exitosamente'), backgroundColor: cVerdeMenta),
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
      backgroundColor: cGrisClaro, // Fondo oficial
      appBar: AppBar(
        backgroundColor: cBlanco,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cAzulPetroleo),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Compromisos',
          style: TextStyle(
            color: cAzulPetroleo,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: cAzulPetroleo),
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
                color: cVerdeMenta.withOpacity(0.2), // Fondo suave avatar
                shape: BoxShape.circle,
              ),
              child: _isLoading
                  ? Center(
                  child: CircularProgressIndicator(
                    color: cVerdeMenta,
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
                    return Icon(Icons.person, size: 24, color: cAzulPetroleo);
                  },
                ),
              )
                  : Icon(Icons.person, size: 24, color: cAzulPetroleo),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRadioGroup('Tipo:', ['Deuda', 'Préstamo'], _selectedType, (value) {
              setState(() {
                _selectedType = value!;
              });
            }),
            const SizedBox(height: 24),

            _buildLabeledTextField(
              label: 'Nombre',
              hint: 'Ej: Pago de refrigeradora',
              controller: _nameController,
            ),
            const SizedBox(height: 16),

            _buildEntidadField(),
            const SizedBox(height: 16),

            _buildLabeledTextField(
              label: 'Monto total',
              hint: 'S/.',
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
              ],
            ),
            const SizedBox(height: 16),

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

            _buildRadioGroup('Tipo de interés:', ['Simple', 'Compuesto'], _interestType, (value) {
              setState(() {
                _interestType = value!;
                _calculateInstallmentAmount();
              });
            }),
            const SizedBox(height: 16),

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
                      FilteringTextInputFormatter.digitsOnly,
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

            _buildLabeledTextField(
              label: 'Cuota calculada:',
              hint: 'S/.',
              controller: _calculatedAmountController,
              keyboardType: TextInputType.number,
              enabled: _selectedFrequencyText != 'Sin cuotas',
            ),
            const SizedBox(height: 16),

            _buildDateField(
              label: 'Fecha de inicio del compromiso',
              hint: 'dd/mm/aaaa',
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                // ✅ CAMBIO: Ahora llama a _showConfirmationDialog que contiene las validaciones
                onPressed: isLoading ? null : _showConfirmationDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cVerdeMenta,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  shadowColor: cVerdeMenta.withOpacity(0.4),
                ),
                child: isLoading
                    ? SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(color: cBlanco, strokeWidth: 3),
                )
                    : Text(
                  'Guardar compromiso',
                  style: TextStyle(
                    color: cBlanco,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
          style: TextStyle(
            fontSize: 14,
            color: cAzulPetroleo.withOpacity(0.7),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          enabled: enabled,
          inputFormatters: inputFormatters,
          style: TextStyle(color: cAzulPetroleo, fontSize: 16),
          decoration: InputDecoration(
            prefixText: prefix,
            prefixStyle: TextStyle(color: cAzulPetroleo, fontSize: 16),
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            filled: true,
            fillColor: cBlanco,
            contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: cVerdeMenta, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEntidadField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tercero',
          style: TextStyle(
            fontSize: 14,
            color: cAzulPetroleo.withOpacity(0.7),
            fontWeight: FontWeight.w600,
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

            // Si el controlador del padre tiene texto pero el interno no, sincronizamos.
            if (_entityController.text.isNotEmpty && controller.text.isEmpty) {
              controller.text = _entityController.text;
            }

            return TextField(
              controller: controller,
              focusNode: focusNode,
              style: TextStyle(color: cAzulPetroleo),
              // ✅ CAMBIO: Detectamos cambios manuales para resetear el ID seleccionado
              onChanged: (val) {
                _entityController.text = val;
                // Si el usuario edita el texto, reseteamos el ID porque podría no coincidir ya
                _selectedTerceroId = null;
              },
              decoration: InputDecoration(
                hintText: 'Escribe para buscar...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: cBlanco,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cVerdeMenta, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
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
          style: TextStyle(
            fontSize: 14,
            color: cAzulPetroleo.withOpacity(0.7),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _selectDate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: cBlanco,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _startDate == null
                      ? hint
                      : DateFormat('dd/MM/yyyy').format(_startDate!),
                  style: TextStyle(
                    color: _startDate == null ? Colors.grey[400] : cAzulPetroleo,
                    fontSize: 16,
                  ),
                ),
                Icon(Icons.calendar_today, color: cVerdeMenta),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRadioGroup(String label, List<String> options, String selectedValue, void Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: cAzulPetroleo.withOpacity(0.7),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: options.map((option) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: option == options.last ? 0 : 16),
                child: RadioListTile<String>(
                  title: Text(option, style: TextStyle(color: cAzulPetroleo)),
                  value: option,
                  groupValue: selectedValue,
                  onChanged: onChanged,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: cVerdeMenta,
                  tileColor: cBlanco,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFrequencyDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Frecuencia',
          style: TextStyle(
            fontSize: 14,
            color: cAzulPetroleo.withOpacity(0.7),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: cBlanco,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedFrequencyText,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down, color: cAzulPetroleo),
              dropdownColor: cBlanco,
              items: frequencyMap.keys
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    style: TextStyle(fontSize: 16, color: cAzulPetroleo),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedFrequencyText = newValue!;
                  _selectedFrequencyId = frequencyMap[newValue];

                  if (_selectedFrequencyText == 'Sin cuotas') {
                    _installmentsController.text = '0';
                  }
                  _calculateInstallmentAmount();
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
        color: cBlanco,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: cBlanco,
        selectedItemColor: cAzulPetroleo, // Azul Petróleo para seleccionado
        unselectedItemColor: Colors.grey[400],
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
    _amountController.removeListener(_calculateInstallmentAmount);
    _amountController.dispose();
    _interestRateController.removeListener(_calculateInstallmentAmount);
    _interestRateController.dispose();
    _installmentsController.removeListener(_calculateInstallmentAmount);
    _installmentsController.dispose();
    _calculatedAmountController.dispose();
    super.dispose();
  }
}