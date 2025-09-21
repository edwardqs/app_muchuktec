import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

const String STORAGE_BASE_URL = 'http://10.0.2.2:8000/storage';
const String API_BASE_URL = 'http://10.0.2.2:8000/api';

class BudgetDetailScreen extends StatefulWidget {
  final int budgetId;

  const BudgetDetailScreen({super.key, required this.budgetId});

  @override
  State<BudgetDetailScreen> createState() => _BudgetDetailScreenState();
}

class _BudgetDetailScreenState extends State<BudgetDetailScreen> {
  final int _selectedIndex = 2; // Índice para 'Presupuestos'
  Map<String, dynamic>? _budget;
  List<dynamic> _allMovements = [];
  bool _isLoading = true;
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
    await Future.wait([
      _fetchBudgetDetails(),
      _loadSelectedAccountAndFetchImage(),
    ]);
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _fetchBudgetDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    if (token == null) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se encontró el token de autenticación.';
        _isLoading = false;
      });
      return;
    }

    final budgetUrl = Uri.parse('$API_BASE_URL/presupuestos/${widget.budgetId}');
    final movementsUrl = Uri.parse('$API_BASE_URL/movimientos');

    try {
      final responses = await Future.wait([
        http.get(
          budgetUrl,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
        http.get(
          movementsUrl,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      ]);

      if (!mounted) return;

      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        final budgetData = json.decode(responses[0].body);
        final movementsData = json.decode(responses[1].body);

        if (budgetData['categoria_nombre'] == null && budgetData['idcategoria'] != null) {
          final categoryName = await _fetchCategoryName(budgetData['idcategoria'], token);
          budgetData['categoria_nombre'] = categoryName;
        }

        if (movementsData is List) {
          setState(() {
            _budget = budgetData;
            _allMovements = movementsData;
          });
        } else {
          setState(() {
            _errorMessage = 'Formato de datos de movimientos inesperado.';
          });
        }
      } else if (responses[0].statusCode == 401 || responses[1].statusCode == 401) {
        await prefs.remove('accessToken');
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        }
      } else {
        setState(() {
          _errorMessage =
          'Error al cargar los datos: ${responses[0].statusCode}. ${responses[0].body}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      print('Caught an error: $e');
      setState(() {
        _errorMessage = 'Ocurrió un error de conexión: $e';
      });
    }
  }

  Future<String> _fetchCategoryName(int categoryId, String token) async {
    final url = Uri.parse('$API_BASE_URL/categorias/$categoryId');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['nombre'] as String? ?? 'Sin categoría';
      } else {
        return 'Sin categoría';
      }
    } catch (e) {
      print('Error fetching category: $e');
      return 'Sin categoría';
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

  Widget _buildBudgetHeader() {
    if (_budget == null) return const SizedBox.shrink();

    final String budgetName = _budget!['categoria_nombre'] as String? ?? 'Sin categoría';
    final double plannedAmount = double.tryParse(_budget!['monto']?.toString() ?? '0.0') ?? 0.0;
    final double spentAmount = double.tryParse(_budget!['saldo_actual']?.toString() ?? '0.0') ?? 0.0;

    final double remainingAmount = plannedAmount - spentAmount;
    final double progress = plannedAmount > 0 ? spentAmount / plannedAmount : 0.0;

    final currencyFormatter = NumberFormat.currency(locale: 'es_ES', symbol: 'S/', decimalDigits: 2);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  budgetName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
                Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.purple[300],
                  size: 32,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Gasto Planificado: ${currencyFormatter.format(plannedAmount)}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            Text(
              'Gasto Actual: ${currencyFormatter.format(spentAmount)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.grey[300],
              color: Colors.deepPurple,
              borderRadius: BorderRadius.circular(8),
              minHeight: 12,
            ),
            const SizedBox(height: 8),
            Text(
              'Restante: ${currencyFormatter.format(remainingAmount)}',
              style: TextStyle(
                fontSize: 14,
                color: remainingAmount < 0 ? Colors.redAccent : Colors.green[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovementsList() {
    final movementsToShow = _allMovements.where((movement) {
      return movement['idcuenta'] == _budget?['idcuenta'] &&
          movement['categoria_nombre'] == _budget?['categoria_nombre'];
    }).toList();

    if (movementsToShow.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'No hay movimientos registrados para este presupuesto.',
            style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    movementsToShow.sort((a, b) => (b['fecha'] as String).compareTo(a['fecha'] as String));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
          child: Text(
            'Movimientos del Presupuesto',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: movementsToShow.length,
          itemBuilder: (context, index) {
            final movement = movementsToShow[index];
            final amount = NumberFormat.currency(locale: 'es_ES', symbol: 'S/', decimalDigits: 2).format(double.tryParse(movement['monto'].toString()) ?? 0.0);
            final bool isExpense = movement['tipo'] == 'gasto';
            final bool isIncome = movement['tipo'] == 'ingreso';

            Color backgroundColor = Colors.grey[50]!;
            Color iconColor = Colors.grey[400]!;
            IconData iconData = Icons.not_interested;
            Color amountColor = Colors.black;

            if (isExpense) {
              backgroundColor = Colors.red[50]!;
              iconColor = Colors.red[400]!;
              iconData = Icons.arrow_upward;
              amountColor = Colors.red[600]!;
            } else if (isIncome) {
              backgroundColor = Colors.green[50]!;
              iconColor = Colors.green[400]!;
              iconData = Icons.arrow_downward;
              amountColor = Colors.green[600]!;
            }

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: backgroundColor,
                  child: Icon(iconData, color: iconColor),
                ),
                title: Text(
                  movement['categoria_nombre'] ?? 'Sin categoría',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  'Fecha: ${movement['fecha']}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                trailing: Text(
                  amount,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: amountColor,
                  ),
                ),
              ),
            );
          },
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
            color: Colors.grey.withAlpha(26),
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
        currentIndex: _selectedIndex,
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
            icon: Icon(Icons.account_balance_wallet),
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
            // Ya estamos en una vista de presupuestos, no hacemos nada
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
          'Detalle del Presupuesto',
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBudgetHeader(),
              _buildMovementsList(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }
}