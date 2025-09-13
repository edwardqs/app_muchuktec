// lib/screens/assign_budget_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category_model.dart';

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

  // Variables para la carga de datos
  List<CategoryModel> categories = [];
  bool isLoading = true;
  String? errorMessage;
  String? _accessToken;
  int? _idCuenta;
  bool _isLoading = true;

  List<String> months = [];

  @override
  void initState() {
    super.initState();
    _loadUserDataAndFetchCategories();
    _generateMonthsList();
    _loadSelectedAccountAndFetchImage();
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
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      // **CAMBIO 1: Usar la clave correcta ('idCuenta') y el tipo de dato correcto (int)**
      final int? selectedAccountId = prefs.getInt('idCuenta');

      if (token == null) {
        if (mounted) {
          print('Token no encontrado, redirigiendo al login...');
          Navigator.of(context).pushReplacementNamed('/');
        }
        return;
      }

      if (selectedAccountId == null) {
        if (mounted) {
          print('No se ha seleccionado una cuenta, mostrando imagen por defecto.');
          setState(() {
            _profileImageUrl = null;
            _isLoading = false;
          });
        }
        return;
      }

      // **CAMBIO 2: Convertir el ID de int a String para la URL de la API**
      final url = Uri.parse('$apiUrl/accounts/${selectedAccountId.toString()}');
      print('Fetching account details from URL: $url');

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
            print('URL de la imagen construida: $_profileImageUrl');
          } else {
            _profileImageUrl = null;
          }
          _isLoading = false;
        });
      } else {
        print('Error al obtener los detalles de la cuenta. Status Code: ${response.statusCode}');
        print('Body de la respuesta de error: ${response.body}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        print('Excepción al obtener los detalles de la cuenta: $e');
        setState(() {
          _isLoading = false;
        });
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

  // Método para obtener las categorías desde la API
  Future<void> _fetchCategories() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$apiUrl/categorias/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);

        if (data is List) {
          setState(() {
            categories = data.map((json) => CategoryModel.fromJson(json)).toList();
            isLoading = false;
          });
        } else if (data is Map<String, dynamic>) {
          setState(() {
            categories = [CategoryModel.fromJson(data)];
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = 'Formato de datos inesperado del servidor.';
            isLoading = false;
          });
        }

      } else {
        setState(() {
          errorMessage = 'Error al cargar las categorías. Intente de nuevo.';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'No se pudo conectar al servidor. Revise su conexión.';
        isLoading = false;
      });
    }
  }

  // Nuevo método para enviar los datos del presupuesto a la API
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

    // Aquí iría la lógica para enviar los datos del presupuesto a la API.
    _showSnackBar(
      'Presupuesto asignado a ${_selectedCategory!.name} para $_selectedMonth con S/.${amount.toStringAsFixed(2)}',
      Colors.green,
    );

    // Preparar los datos
    final parts = _selectedMonth.split(' ');
    final monthName = parts[0];
    final year = parts[1];
    final monthNumber = _getMonthNumber(monthName);
    final mes = '$year-$monthNumber-01'; // Formato YYYY-MM-DD


    final body = {
      'idcuenta': _idCuenta,
      'idcategoria': _selectedCategory!.id,
      'mes': mes,
      'monto': amount,
    };

    _sendBudgetToApi(body);
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
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
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
            icon: Icon(Icons.notifications_outlined, color: Colors.black),
            onPressed: () {},
          ),
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.purple[100],
              child: Icon(Icons.person, color: Colors.purple, size: 20),
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
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seleccionar categoría',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 12),
          _buildCategoryDropdown(),
          SizedBox(height: 24),
          Text(
            'Mes',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 12),
          _buildMonthDropdown(),
          SizedBox(height: 24),
          Text(
            'Monto del presupuesto',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
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
                borderSide: BorderSide(color: Colors.green, width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _assignBudget,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(
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
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
              child: Text(
                category.name,
                style: const TextStyle(color: Colors.black),
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
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
            offset: Offset(0, -2),
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
        currentIndex: 2, // 'Presupuestos'
        items: [
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
            // Ya estás en esta pantalla, no hagas nada
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
