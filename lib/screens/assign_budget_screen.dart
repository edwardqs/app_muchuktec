// lib/screens/assign_budget_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category_model.dart';
import 'package:flutter/services.dart';
import 'package:app_muchik/config/constants.dart';
import 'package:intl/intl.dart'; // Import intl

class AssignBudgetScreen extends StatefulWidget {
  const AssignBudgetScreen({super.key});

  @override
  State<AssignBudgetScreen> createState() => _AssignBudgetScreenState();
}

class _AssignBudgetScreenState extends State<AssignBudgetScreen> {
  final TextEditingController _amountController = TextEditingController();

  CategoryModel? _selectedCategory;
  String _selectedMonth = 'Mes - Año';
  String? _profileImageUrl;

  List<CategoryModel> categories = [];
  String? errorMessage;
  String? _accessToken;
  int? _idCuenta;

  // --- 👇 ESTADOS CORREGIDOS ---
  // _isLoading es para la carga de la PÁGINA (AppBar y cuerpo)
  bool _isLoading = true;
  // _isSaving es para la acción de GUARDAR (el botón)
  bool _isSaving = false;
  // --- FIN DE ESTADOS CORREGIDOS ---

  List<String> months = [];

  @override
  void initState() {
    super.initState();
    _generateMonthsList();
    _loadAllData(); // Llamada única
  }

  // --- 👇 initState Y loadAllData CORREGIDOS ---
  Future<void> _loadAllData() async {
    // El estado ya es _isLoading = true por defecto
    setState(() {
      errorMessage = null;
    });

    await _loadUserDataAndFetchCategories();
    // Solo carga la imagen si la carga de datos del usuario fue exitosa
    if (_accessToken != null) {
      await _loadSelectedAccountAndFetchImage();
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false; // Termina la carga de la PÁGINA
    });
  }
  // --- FIN DE CORRECCIÓN ---

  void _generateMonthsList() {
    months.add('Mes - Año');
    final now = DateTime.now();
    final spanishMonths = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];

    for (int i = 0; i < 12; i++) {
      final nextMonthDate = DateTime(now.year, now.month + i , 1);
      final month = spanishMonths[nextMonthDate.month - 1];
      final year = nextMonthDate.year;
      months.add('$month $year');
    }
  }

  Future<void> _loadSelectedAccountAndFetchImage() async {
    // Ya tenemos _accessToken y _idCuenta desde _loadUserDataAndFetchCategories
    // Pero volvemos a obtener el token para estar seguros
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      final int? selectedAccountId = prefs.getInt('idCuenta');

      if (token == null) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/');
        return;
      }
      if (selectedAccountId == null) {
        if (mounted) setState(() => _profileImageUrl = null);
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

  Future<void> _loadUserDataAndFetchCategories() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('accessToken');
    _idCuenta = prefs.getInt('idCuenta');

    if (_accessToken != null && _idCuenta != null) {
      await _fetchCategories(); // Usamos await para esperar que termine
    } else {
      if (!mounted) return;
      setState(() {
        errorMessage = 'No se encontró un token de sesión. Por favor, inicie sesión.';
        // No ponemos _isLoading = false aquí, dejamos que _loadAllData lo haga
      });
    }
  }

  Future<void> _fetchCategories() async {
    if (_accessToken == null || _idCuenta == null) {
      setState(() {
        errorMessage = 'Token o ID de cuenta no disponibles.';
      });
      return;
    }

    try {
      final url = Uri.parse('$API_BASE_URL/categorias').replace(
        queryParameters: {
          'idcuenta': _idCuenta.toString(),
        },
      );

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
          'Accept': 'application/json',
        },
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        if (data is List) {
          setState(() {
            categories = data.map((json) => CategoryModel.fromJson(json)).toList();
          });
        } else {
          setState(() {
            errorMessage = 'Formato de datos inesperado del servidor.';
          });
        }
      } else {
        setState(() {
          errorMessage = 'Error al cargar las categorías. Código: ${response.statusCode}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'No se pudo conectar al servidor. Revise su conexión.';
      });
    }
  }

  // --- 👇 sendBudgetToApi CORREGIDO ---
  Future<void> _sendBudgetToApi(Map<String, dynamic> budgetData) async {
    // _isSaving ya es true, no necesitamos setState aquí
    try {
      final response = await http.post(
        Uri.parse('$API_BASE_URL/presupuestos'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
          'Accept': 'application/json',
        },
        body: json.encode(budgetData),
      );

      if (!mounted) return; // Chequeo de seguridad

      if (response.statusCode == 201) {
        _showSnackBar('Presupuesto asignado exitosamente.', Colors.green);

        // ¡REDIRECCIÓN!
        Navigator.pushReplacementNamed(context, '/budgets');

        // Ya no necesitamos limpiar campos ni cambiar estado,
        // porque la pantalla se va a destruir.

      } else {
        // Hubo un error en el API
        final Map<String, dynamic> responseBody = json.decode(response.body);
        final String message = responseBody['message'] ?? 'Error al asignar el presupuesto.';
        _showSnackBar(message, Colors.red);
        // Vuelve a habilitar el botón si hay un error
        setState(() {
          _isSaving = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('No se pudo conectar al servidor.', Colors.red);
      // Vuelve a habilitar el botón si hay una excepción
      setState(() {
        _isSaving = false;
      });
    }
  }
  // --- FIN DE CORRECCIÓN ---

  void _assignBudget() {
    // ... (Tu lógica de validación _assignBudget está perfecta) ...
    if (_selectedCategory == null) {
      _showSnackBar('Por favor, selecciona una categoría', Colors.red);
      return;
    }
    if (_selectedMonth == 'Mes - Año') {
      _showSnackBar('Por favor, selecciona un mes', Colors.red);
      return;
    }
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _showSnackBar('Por favor, ingresa el monto del presupuesto', Colors.red);
      return;
    }
    final double? amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showSnackBar('Por favor, ingresa un monto válido', Colors.red);
      return;
    }
    _showConfirmationDialog(amount);
  }

  // --- 👇 showConfirmationDialog CORREGIDO ---
  void _showConfirmationDialog(double amount) {
    showDialog(
      context: context,
      barrierDismissible: false, // Evita que se cierre al tocar fuera
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar asignación'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text(
                  '¿Estás seguro de que quieres asignar este presupuesto?',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                Text(
                  'Categoría: ${_selectedCategory!.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Mes: $_selectedMonth',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Monto: S/.${amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            // Botón "Cancelar" (CORREGIDO)
            TextButton(
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
              onPressed: () {
                // Solo cierra el diálogo
                Navigator.of(context).pop();
              },
            ),
            // Botón "Confirmar" (CORREGIDO)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
              onPressed: () {
                // 1. Pone la UI en modo "Guardando"
                setState(() {
                  _isSaving = true;
                });

                // 2. Cierra el diálogo
                Navigator.of(context).pop();

                // 3. Prepara los datos
                final parts = _selectedMonth.split(' ');
                final monthName = parts[0];
                final year = parts[1];
                final monthNumber = _getMonthNumber(monthName);
                final mes = '$year-$monthNumber-01';
                final body = {
                  'idcuenta': _idCuenta,
                  'idcategoria': _selectedCategory!.id,
                  'mes': mes,
                  'monto': amount,
                };

                // 4. Llama a la API DESPUÉS de cerrar el diálogo
                _sendBudgetToApi(body);
              },
            ),
          ],
        );
      },
    );
  }
  // --- FIN DE CORRECCIÓN ---

  String _getMonthNumber(String monthName) {
    // ... (Tu código es correcto) ...
    final months = {
      'Enero': '01', 'Febrero': '02', 'Marzo': '03', 'Abril': '04',
      'Mayo': '05', 'Junio': '06', 'Julio': '07', 'Agosto': '08',
      'Septiembre': '09', 'Octubre': '10', 'Noviembre': '11', 'Diciembre': '12',
    };
    return months[monthName] ?? '01';
  }

  void _showSnackBar(String message, Color color) {
    // ... (Tu código es correcto) ...
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      // --- 👇 AppBar CORREGIDO ---
      // (Usa _isLoading para el indicador)
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Asignar Presupuesto',
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
              child: _isLoading // <-- USA _isLoading (carga de página)
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
      // --- FIN DE CORRECCIÓN ---
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // --- 👇 _buildBody CORREGIDO ---
  // (Usa _isLoading para el indicador)
  Widget _buildBody() {
    if (_isLoading) { // <-- USA _isLoading (carga de página)
      return const Center(child: CircularProgressIndicator());
    }
    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            errorMessage!,
            style: TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    // El SingleChildScrollView ahora está envuelto en un 'GestureDetector'
    // para ocultar el teclado si el usuario toca fuera de un campo de texto
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(), // Oculta el teclado
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ... (Dropdown de Categoría)
            const Text(
              'Seleccionar categoría',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            _buildCategoryDropdown(),
            const SizedBox(height: 24),

            // ... (Dropdown de Mes)
            const Text(
              'Mes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            _buildMonthDropdown(),
            const SizedBox(height: 24),

            // ... (Campo de Monto)
            const Text(
              'Monto del presupuesto',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              decoration: InputDecoration(
                hintText: 'S/.',
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
                  borderSide: const BorderSide(color: Colors.green, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 40),

            // --- 👇 Botón de Guardar CORREGIDO ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                // Deshabilita si la página está cargando O si está guardando
                onPressed: _isLoading || _isSaving ? null : _assignBudget,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                // Muestra el indicador de carga si _isSaving es true
                child: _isSaving
                    ? const SizedBox(
                  height: 24, // Damos un tamaño al indicador
                  width: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
                    : const Text(
                  'Asignar Presupuesto',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            // --- FIN DE CORRECCIÓN ---
          ],
        ),
      ),
    );
  }
  // --- FIN DE CORRECCIÓN ---


  Widget _buildCategoryDropdown() {
    // ... (Tu código es correcto) ...
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<CategoryModel>(
          value: _selectedCategory,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
          hint: Text(
            'Seleccione una categoría',
            style: TextStyle(color: Colors.grey[400]),
          ),
          items: categories.map((CategoryModel category) {
            return DropdownMenuItem<CategoryModel>(
              value: category,
              child: Row(
                children: [
                  Text(
                    category.name,
                    style: const TextStyle(color: Colors.black),
                  ),
                  const Spacer(),
                  Text(
                    category.type,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: category.type.toLowerCase() == 'ingreso' ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (CategoryModel? newValue) {
            setState(() {
              _selectedCategory = newValue;
            });
          },
        ),
      ),
    );
  }

  Widget _buildMonthDropdown() {
    // ... (Tu código es correcto) ...
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String>(
        value: _selectedMonth,
        isExpanded: true,
        underline: const SizedBox(),
        icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
        items: months.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(
              value,
              style: TextStyle(
                color: value == 'Mes - Año' ? Colors.grey[400] : Colors.black,
                fontSize: 16,
              ),
            ),
          );
        }).toList(),
        onChanged: (String? newValue) {
          if (newValue != null) {
            setState(() {
              _selectedMonth = newValue;
            });
          }
        },
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    // ... (Tu código es correcto) ...
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
        currentIndex: 2,
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
            icon: Icon(Icons.category_outlined),
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
              break;
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
    _amountController.dispose();
    // NOTA: Tus otros controladores de 'compromises_create'
    // no existen aquí, así que los quité de dispose().
    super.dispose();
  }
} // Fin de _AssignBudgetScreenState