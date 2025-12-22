// lib/screens/assign_budget_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category_model.dart';
import 'package:flutter/services.dart';
import 'package:app_muchik/config/constants.dart';
import 'package:intl/intl.dart';

class AssignBudgetScreen extends StatefulWidget {
  const AssignBudgetScreen({super.key});

  @override
  State<AssignBudgetScreen> createState() => _AssignBudgetScreenState();
}

class _AssignBudgetScreenState extends State<AssignBudgetScreen> {
  // --- COLORES OFICIALES ---
  final Color cAzulPetroleo = const Color(0xFF264653);
  final Color cVerdeMenta = const Color(0xFF2A9D8F);
  final Color cGrisClaro = const Color(0xFFF4F4F4);
  final Color cBlanco = const Color(0xFFFFFFFF);

  final TextEditingController _amountController = TextEditingController();

  CategoryModel? _selectedCategory;
  String _selectedMonth = 'Mes - Año';
  String? _profileImageUrl;

  List<CategoryModel> categories = [];
  String? errorMessage;
  String? _accessToken;
  int? _idCuenta;

  // --- ESTADOS DE LÓGICA (INTACTOS) ---
  bool _isLoading = true;
  bool _isSaving = false;

  List<String> months = [];

  @override
  void initState() {
    super.initState();
    _generateMonthsList();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() {
      errorMessage = null;
    });

    await _loadUserDataAndFetchCategories();
    if (_accessToken != null) {
      await _loadSelectedAccountAndFetchImage();
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
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
      await _fetchCategories();
    } else {
      if (!mounted) return;
      setState(() {
        errorMessage = 'No se encontró un token de sesión. Por favor, inicie sesión.';
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

  Future<void> _sendBudgetToApi(Map<String, dynamic> budgetData) async {
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

      if (!mounted) return;

      if (response.statusCode == 201) {
        _showSnackBar('Presupuesto asignado exitosamente.', cVerdeMenta);
        Navigator.pushReplacementNamed(context, '/budgets');
      } else {
        final Map<String, dynamic> responseBody = json.decode(response.body);
        final String message = responseBody['message'] ?? 'Error al asignar el presupuesto.';
        _showSnackBar(message, Colors.red);
        setState(() {
          _isSaving = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('No se pudo conectar al servidor.', Colors.red);
      setState(() {
        _isSaving = false;
      });
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
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: cBlanco,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Confirmar asignación',
            style: TextStyle(color: cAzulPetroleo, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  '¿Estás seguro de que quieres asignar este presupuesto?',
                  style: TextStyle(fontSize: 14, color: cAzulPetroleo.withOpacity(0.8)),
                ),
                const SizedBox(height: 16),
                _buildConfirmRow('Categoría:', _selectedCategory!.name),
                const SizedBox(height: 8),
                _buildConfirmRow('Mes:', _selectedMonth),
                const SizedBox(height: 8),
                _buildConfirmRow('Monto:', 'S/.${amount.toStringAsFixed(2)}'),
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
                setState(() {
                  _isSaving = true;
                });
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

  // Widget auxiliar para las filas del modal
  Widget _buildConfirmRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.w500, color: cAzulPetroleo)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: cAzulPetroleo)),
      ],
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
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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
          'Asignar Presupuesto',
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
                color: cVerdeMenta.withOpacity(0.2), // Fondo suave para el avatar
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
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: cVerdeMenta));
    }
    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            errorMessage!,
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Seleccionar categoría',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cAzulPetroleo,
              ),
            ),
            const SizedBox(height: 12),
            _buildCategoryDropdown(),
            const SizedBox(height: 24),

            Text(
              'Mes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cAzulPetroleo,
              ),
            ),
            const SizedBox(height: 12),
            _buildMonthDropdown(),
            const SizedBox(height: 24),

            Text(
              'Monto del presupuesto',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cAzulPetroleo,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: cAzulPetroleo),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              decoration: InputDecoration(
                hintText: 'S/.',
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading || _isSaving ? null : _assignBudget,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cVerdeMenta,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  shadowColor: cVerdeMenta.withOpacity(0.4),
                ),
                child: _isSaving
                    ? SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: cBlanco,
                    strokeWidth: 3,
                  ),
                )
                    : Text(
                  'Asignar Presupuesto',
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
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: cBlanco,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<CategoryModel>(
          value: _selectedCategory,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: cAzulPetroleo),
          dropdownColor: cBlanco,
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
                    style: TextStyle(color: cAzulPetroleo),
                  ),
                  const Spacer(),
                  Text(
                    category.type,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: category.type.toLowerCase() == 'ingreso' ? cVerdeMenta : Colors.red[400],
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
        color: cBlanco,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedMonth,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: cAzulPetroleo),
          dropdownColor: cBlanco,
          items: months.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value,
                style: TextStyle(
                  color: value == 'Mes - Año' ? Colors.grey[400] : cAzulPetroleo,
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
      ),
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
        selectedItemColor: cAzulPetroleo, // Azul Petróleo para activo
        unselectedItemColor: Colors.grey[400],
        selectedFontSize: 12,
        unselectedFontSize: 12,
        currentIndex: 2,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Reportes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'Presupuestos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.category_outlined),
            activeIcon: Icon(Icons.category),
            label: 'Categorías',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
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