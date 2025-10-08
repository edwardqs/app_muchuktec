// lib/screens/assign_budget_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category_model.dart';
import 'package:flutter/services.dart';

const String apiUrl = 'http://10.0.2.2:8000/api';
const String STORAGE_BASE_URL = 'http://10.0.2.2:8000/storage';

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
  bool isLoading = true; // Renombrado de isLoading a _isLoading para evitar ambigüedad
  String? errorMessage;
  String? _accessToken;
  int? _idCuenta;
  bool _isLoading = true; // Mantenemos esta para el appbar

  List<String> months = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _generateMonthsList();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      isLoading = true; // Para la vista principal
      errorMessage = null;
    });

    await Future.wait([
      _loadUserDataAndFetchCategories(),
      _loadSelectedAccountAndFetchImage(),
    ]);

    setState(() {
      _isLoading = false;
      isLoading = false; // Para la vista principal
    });
  }

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

      final url = Uri.parse('$apiUrl/accounts/${selectedAccountId.toString()}');
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
      _fetchCategories();
    } else {
      if (!mounted) return;
      setState(() {
        errorMessage = 'No se encontró un token de sesión. Por favor, inicie sesión.';
        isLoading = false;
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
      final url = Uri.parse('$apiUrl/categorias').replace(
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

  Future<void> _sendBudgetToApi(Map<String, dynamic> budgetData) async {
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/presupuestos'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
          'Accept': 'application/json',
        },
        body: json.encode(budgetData),
      );

      if (response.statusCode == 201) {
        if (!mounted) return;
        _showSnackBar('Presupuesto asignado exitosamente.', Colors.green);
        _amountController.clear();
        setState(() {
          _selectedCategory = null;
          _selectedMonth = 'Mes - Año';
        });
      } else {
        final Map<String, dynamic> responseBody = json.decode(response.body);
        final String message = responseBody['message'] ?? 'Error al asignar el presupuesto. Intente de nuevo.';
        if (!mounted) return;
        _showSnackBar(message, Colors.red);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('No se pudo conectar al servidor. Revise su conexión.', Colors.red);
    }
  }

  void _assignBudget() {
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

  void _showConfirmationDialog(double amount) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar asignación de presupuesto'),
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
            TextButton(
              child: const Text('Cancelar', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.of(context).pop();
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
                _sendBudgetToApi(body);
              },
            ),
          ],
        );
      },
    );
  }

  String _getMonthNumber(String monthName) {
    final months = {
      'Enero': '01', 'Febrero': '02', 'Marzo': '03', 'Abril': '04',
      'Mayo': '05', 'Junio': '06', 'Julio': '07', 'Agosto': '08',
      'Septiembre': '09', 'Octubre': '10', 'Noviembre': '11', 'Diciembre': '12',
    };
    return months[monthName] ?? '01';
  }

  void _showSnackBar(String message, Color color) {
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
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _assignBudget,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Asignar Presupuesto',
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
    );
  }

  Widget _buildCategoryDropdown() {
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
    super.dispose();
  }
}