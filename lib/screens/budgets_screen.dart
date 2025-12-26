import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'budgets_detail_screen.dart';
import 'package:app_muchik/config/constants.dart';
import 'package:app_muchik/widgets/ad_banner_widget.dart';
// ✅ 1. Importamos tu modelo de categoría
import '../models/category_model.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  // --- COLORES OFICIALES ---
  final Color cAzulPetroleo = const Color(0xFF264653);
  final Color cVerdeMenta = const Color(0xFF2A9D8F);
  final Color cGrisClaro = const Color(0xFFF4F4F4);
  final Color cBlanco = const Color(0xFFFFFFFF);

  final int _selectedIndex = 2;
  bool _isLoading = true;
  List<Budget> budgets = [];
  String? _errorMessage;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await _fetchBudgets();
    await _loadSelectedAccountAndFetchImage();

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _fetchBudgets() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    final idCuenta = prefs.getInt('idCuenta');

    if (token == null || idCuenta == null) {
      if (!mounted) return;
      setState(() {
        _errorMessage = idCuenta == null
            ? 'No se ha seleccionado una cuenta para ver los presupuestos.'
            : 'No se encontró el token de autenticación. Por favor, inicie sesión de nuevo.';
      });
      return;
    }

    final uri = Uri.parse('$API_BASE_URL/presupuestos').replace(
      queryParameters: {
        'idcuenta': idCuenta.toString(),
      },
    );

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          budgets = data.map((json) => Budget.fromJson(json)).toList();
        });
      } else if (response.statusCode == 401) {
        await prefs.remove('accessToken');
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        }
      } else {
        setState(() {
          _errorMessage = 'Error al cargar presupuestos: ${response.statusCode}. ${response.body}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Ocurrió un error de conexión: $e';
      });
    }
  }

  Future<void> _loadSelectedAccountAndFetchImage() async {
    setState(() {
      _isLoading = true;
    });

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
            _isLoading = false;
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
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteBudgetOnServer(String budgetId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No se encontró el token de acceso.'), backgroundColor: Colors.red),
      );
      return;
    }

    final url = Uri.parse('$API_BASE_URL/presupuestos/$budgetId');

    try {
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Presupuesto eliminado con éxito.'), backgroundColor: cVerdeMenta),
        );
      } else if (response.statusCode == 401) {
        await prefs.remove('accessToken');
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: ${response.statusCode}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo conectar al servidor.'), backgroundColor: Colors.red),
      );
    }
  }

  Future<List<CategoryModel>> _fetchCategoriesForDropdown() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    final idCuenta = prefs.getInt('idCuenta');

    if (token == null || idCuenta == null) {
      throw Exception('Token o ID de cuenta no encontrados');
    }

    final uri = Uri.parse('$API_BASE_URL/categorias').replace(
      queryParameters: {'idcuenta': idCuenta.toString()},
    );

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data
          .map((json) => CategoryModel.fromJson(json))
          .where((cat) => cat.type == 'gasto')
          .toList();
    } else {
      throw Exception('Error al cargar categorías');
    }
  }

  Future<void> _updateBudget(String budgetId, int newCategoryId, double newMonto) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    final url = Uri.parse('$API_BASE_URL/presupuestos/$budgetId');

    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'idcategoria': newCategoryId,
          'monto': newMonto,
        }),
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Presupuesto actualizado con éxito.'), backgroundColor: cVerdeMenta),
        );
        _fetchBudgets();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar: ${response.statusCode}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de conexión al actualizar.'), backgroundColor: Colors.red),
      );
    }
  }

  void _showEditBudgetDialog(Budget budget) {
    final formKey = GlobalKey<FormState>();
    final montoController = TextEditingController(text: budget.budgetAmount.toStringAsFixed(2));
    int? selectedCategoryId = budget.categoryId;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Editar Presupuesto',
                style: TextStyle(color: cAzulPetroleo, fontWeight: FontWeight.bold),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Editando: "${budget.category}"',
                        style: TextStyle(color: cAzulPetroleo.withOpacity(0.7), fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: montoController,
                        decoration: InputDecoration(
                          labelText: 'Monto Presupuestado',
                          prefixText: 'S/ ',
                          labelStyle: TextStyle(color: cAzulPetroleo.withOpacity(0.6)),
                          filled: true,
                          fillColor: cGrisClaro,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cVerdeMenta)),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty || double.tryParse(value) == null || double.parse(value) <= 0) {
                            return 'Ingrese un monto válido.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<List<CategoryModel>>(
                        future: _fetchCategoriesForDropdown(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator(color: cVerdeMenta));
                          }
                          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                            return Text('No se pudieron cargar las categorías. ${snapshot.error}');
                          }

                          final categories = snapshot.data!;

                          if (!categories.any((cat) => int.parse(cat.id) == budget.categoryId)) {
                            categories.insert(0, CategoryModel(id: budget.categoryId.toString(), name: budget.category, type: 'gasto'));
                          }

                          return DropdownButtonFormField<int>(
                            value: selectedCategoryId,
                            decoration: InputDecoration(
                              labelText: 'Categoría',
                              labelStyle: TextStyle(color: cAzulPetroleo.withOpacity(0.6)),
                              filled: true,
                              fillColor: cGrisClaro,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            items: categories.map((CategoryModel category) {
                              return DropdownMenuItem<int>(
                                value: int.parse(category.id),
                                child: Text(category.name),
                              );
                            }).toList(),
                            onChanged: (int? newValue) {
                              setDialogState(() {
                                selectedCategoryId = newValue;
                              });
                            },
                            validator: (value) => value == null ? 'Seleccione una categoría.' : null,
                          );
                        },
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
                    if (formKey.currentState!.validate() && selectedCategoryId != null) {
                      final newMonto = double.parse(montoController.text);
                      _updateBudget(budget.id, selectedCategoryId!, newMonto);
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cVerdeMenta,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<Budget> _getBudgetsForCurrentMonth() {
    final now = DateTime.now();
    final currentYearMonth = DateFormat('yyyy-MM').format(now);

    return budgets.where((budget) {
      try {
        final budgetYearMonth = DateFormat('yyyy-MM').format(DateTime.parse(budget.month));
        return budgetYearMonth == currentYearMonth;
      } catch (e) {
        return false;
      }
    }).toList();
  }

  String _getCurrentMonthName() {
    final now = DateTime.now();
    final formatter = DateFormat('MMMM yyyy', 'es');
    return formatter.format(now).replaceRange(0, 1, formatter.format(now)[0].toUpperCase());
  }

  @override
  Widget build(BuildContext context) {
    final currentMonthBudgets = _getBudgetsForCurrentMonth();

    return Scaffold(
      backgroundColor: cGrisClaro, // Fondo oficial #F4F4F4
      appBar: AppBar(
        backgroundColor: cBlanco,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cAzulPetroleo),
          onPressed: () => Navigator.pushReplacementNamed(context, '/dashboard'),
        ),
        title: Text(
          'Mis Presupuestos',
          style: TextStyle(
            color: cAzulPetroleo,
            fontSize: 18,
            fontWeight: FontWeight.bold,
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
                color: cVerdeMenta.withOpacity(0.2), // Fondo suave
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
      body: RefreshIndicator(
        color: cVerdeMenta,
        onRefresh: _loadAllData,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: cVerdeMenta))
            : _errorMessage != null
            ? Center(child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red[700])),
        ))
            : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tarjeta Resumen con degradado oficial
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cAzulPetroleo, cVerdeMenta], // Gradiente oficial
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: cAzulPetroleo.withOpacity(0.3),
                      spreadRadius: 0,
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resumen de Presupuestos',
                      style: TextStyle(
                        color: cBlanco.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _getCurrentMonthName(),
                      style: TextStyle(
                        color: cBlanco,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Presupuestado',
                              style: TextStyle(
                                color: cBlanco.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'S/.${currentMonthBudgets.fold(0.0, (sum, item) => sum + item.budgetAmount).toStringAsFixed(2)}',
                              style: TextStyle(
                                color: cBlanco,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(width: 1, height: 40, color: cBlanco.withOpacity(0.2)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Gastado Real',
                              style: TextStyle(
                                color: cBlanco.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'S/.${currentMonthBudgets.fold(0.0, (sum, item) => sum + item.spentAmount).toStringAsFixed(2)}',
                              style: TextStyle(
                                color: cBlanco,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Presupuestos por Categoría',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: cAzulPetroleo,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add_circle_rounded, color: cVerdeMenta, size: 30),
                    onPressed: () {
                      Navigator.pushNamed(context, '/assign-budget');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              currentMonthBudgets.isEmpty
                  ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32.0),
                    child: Column(
                      children: [
                        Icon(Icons.account_balance_wallet_outlined, size: 48, color: cAzulPetroleo.withOpacity(0.3)),
                        const SizedBox(height: 8),
                        Text('No hay presupuestos este mes.', style: TextStyle(color: cAzulPetroleo.withOpacity(0.5))),
                      ],
                    ),
                  )
              )
                  : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: currentMonthBudgets.length,
                itemBuilder: (context, index) {
                  final budget = currentMonthBudgets[index];
                  return _buildBudgetCard(budget);
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min, // Vital para no ocupar toda la pantalla
        children: [
          const AdBannerWidget(), // El anuncio
          _buildBottomNavigationBar(), // Tu barra de navegación
        ],
      ),

    );
  }

  Widget _buildBudgetCard(Budget budget) {
    Color statusColor;
    String statusText;
    double percentage = budget.budgetAmount > 0 ? (budget.spentAmount / budget.budgetAmount) * 100 : 0;

    if (percentage >= 100) {
      statusColor = Colors.red;
      statusText = 'Excedido en S/.${(budget.spentAmount - budget.budgetAmount).toStringAsFixed(2)}';
    } else if (percentage >= 75) {
      statusColor = Colors.orange;
      statusText = '${(100 - percentage).toStringAsFixed(0)}% disponible';
    } else {
      statusColor = cVerdeMenta; // Verde oficial
      statusText = '${(100 - percentage).toStringAsFixed(0)}% disponible';
    }

    final monthName = getMonthName(budget.month);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BudgetDetailScreen(budgetId: int.parse(budget.id)),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cBlanco,
          borderRadius: BorderRadius.circular(16),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    budget.category,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: cAzulPetroleo,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: cAzulPetroleo.withOpacity(0.5)),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _showEditBudgetDialog(budget);
                        break;
                      case 'delete':
                        _deleteBudget(budget);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: cVerdeMenta, size: 20),
                          const SizedBox(width: 8),
                          Text('Editar', style: TextStyle(color: cAzulPetroleo)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: const [
                          Icon(Icons.delete, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Eliminar'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              monthName,
              style: TextStyle(
                fontSize: 12,
                color: cAzulPetroleo.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: cGrisClaro,
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (percentage / 100).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'S/.${budget.spentAmount.toStringAsFixed(2)} de S/.${budget.budgetAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cAzulPetroleo,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${percentage.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String getMonthName(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMMM yyyy', 'es').format(date).replaceRange(0, 1, DateFormat('MMMM yyyy', 'es').format(date)[0].toUpperCase());
    } catch (e) {
      return 'Mes desconocido';
    }
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
        currentIndex: _selectedIndex,
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

  void _deleteBudget(Budget budget) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Eliminar Presupuesto', style: TextStyle(color: cAzulPetroleo, fontWeight: FontWeight.bold)),
        content: Text('¿Estás seguro de que quieres eliminar el presupuesto de ${budget.category}?', style: TextStyle(color: cAzulPetroleo)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteBudgetOnServer(budget.id);
              if (mounted) {
                setState(() {
                  budgets.removeWhere((b) => b.id == budget.id);
                });
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class Budget {
  final String id;
  final int categoryId;
  final String category;
  final String month;
  final double budgetAmount;
  final double spentAmount;

  Budget({
    required this.id,
    required this.categoryId,
    required this.category,
    required this.month,
    required this.budgetAmount,
    required this.spentAmount,
  });

  factory Budget.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as int).toString();
    final categoryId = json['idcategoria'] as int;
    final month = json['mes'] as String? ?? '';
    final category = json['categoria_nombre'] as String? ?? 'Sin categoría';

    final budgetAmount = double.tryParse(json['monto'].toString()) ?? 0.0;
    final spentAmount = double.tryParse(json['monto_gastado'].toString()) ?? 0.0;

    return Budget(
      id: id,
      categoryId: categoryId,
      category: category,
      month: month,
      budgetAmount: budgetAmount,
      spentAmount: spentAmount,
    );
  }
}