import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:app_muchik/config/constants.dart';

class BudgetDetailScreen extends StatefulWidget {
  final int budgetId;

  const BudgetDetailScreen({super.key, required this.budgetId});

  @override
  State<BudgetDetailScreen> createState() => _BudgetDetailScreenState();
}

class _BudgetDetailScreenState extends State<BudgetDetailScreen> {
  // --- COLORES OFICIALES ---
  final Color cAzulPetroleo = const Color(0xFF264653);
  final Color cVerdeMenta = const Color(0xFF2A9D8F);
  final Color cGrisClaro = const Color(0xFFF4F4F4);
  final Color cBlanco = const Color(0xFFFFFFFF);

  final int _selectedIndex = 2;
  Map<String, dynamic>? _budget;
  List<dynamic> _budgetMovements = [];
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
    await _fetchBudgetDetailsAndMovements();
    await _loadSelectedAccountAndFetchImage();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _fetchBudgetDetailsAndMovements() async {
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

    try {
      final budgetUrl = Uri.parse('$API_BASE_URL/presupuestos/${widget.budgetId}');
      final budgetResponse = await http.get(
        budgetUrl,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (budgetResponse.statusCode == 200) {
        final budgetData = json.decode(budgetResponse.body);

        final int idCategoria = budgetData['idcategoria'];
        final int idCuenta = budgetData['idcuenta'];
        final DateTime budgetDate = DateTime.parse(budgetData['mes']);
        final String mes = budgetDate.month.toString();
        final String anio = budgetDate.year.toString();

        final movementsUrl = Uri.parse('$API_BASE_URL/movimientos').replace(
          queryParameters: {
            'idcuenta': idCuenta.toString(),
            'idcategoria': idCategoria.toString(),
            'mes': mes,
            'anio': anio,
          },
        );

        final movementsResponse = await http.get(
          movementsUrl,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        if (!mounted) return;

        if (movementsResponse.statusCode == 200) {
          final movementsData = json.decode(movementsResponse.body);
          setState(() {
            _budget = budgetData;
            _budgetMovements = movementsData as List;
          });
        } else {
          setState(() {
            _budget = budgetData;
            _errorMessage = 'Error al cargar movimientos: ${movementsResponse.statusCode}';
          });
        }

      } else if (budgetResponse.statusCode == 401) {
        await prefs.remove('accessToken');
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        }
      } else {
        setState(() {
          _errorMessage = 'Error al cargar el presupuesto: ${budgetResponse.statusCode}. ${budgetResponse.body}';
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
    final double spentAmount = double.tryParse(_budget!['monto_gastado']?.toString() ?? '0.0') ?? 0.0;

    final double remainingAmount = plannedAmount - spentAmount;
    final double progress = plannedAmount > 0 ? spentAmount / plannedAmount : 0.0;

    // ✅ CAMBIO: Locale 'en_US' para formato 1,234.56
    final currencyFormatter = NumberFormat.currency(
        locale: 'en_US',
        symbol: 'S/ ',
        decimalDigits: 2
    );

    return Card(
      elevation: 2, // Sombra más sutil
      margin: const EdgeInsets.symmetric(vertical: 16),
      color: cBlanco,
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
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: cAzulPetroleo, // Color oficial
                  ),
                ),
                Icon(
                  Icons.account_balance_wallet_outlined,
                  color: cVerdeMenta, // Color oficial
                  size: 32,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Gasto Planificado: ${currencyFormatter.format(plannedAmount)}',
              style: TextStyle(
                fontSize: 14,
                color: cAzulPetroleo.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Gasto Actual: ${currencyFormatter.format(spentAmount)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: cAzulPetroleo,
              ),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: cGrisClaro,
              color: cVerdeMenta, // Barra de progreso oficial
              borderRadius: BorderRadius.circular(8),
              minHeight: 12,
            ),
            const SizedBox(height: 8),
            Text(
              'Restante: ${currencyFormatter.format(remainingAmount)}',
              style: TextStyle(
                fontSize: 14,
                // Rojo si es negativo, Verde Menta si es positivo
                color: remainingAmount < 0 ? Colors.redAccent : cVerdeMenta,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovementsList() {
    final movementsToShow = _budgetMovements;

    if (movementsToShow.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'No hay movimientos registrados para este presupuesto.',
            style: TextStyle(color: cAzulPetroleo.withOpacity(0.5), fontStyle: FontStyle.italic),
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
              color: cAzulPetroleo,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: movementsToShow.length,
          itemBuilder: (context, index) {
            final movement = movementsToShow[index];

            // ✅ CAMBIO: Locale 'en_US' para formato 1,234.56
            final amount = NumberFormat.currency(
                locale: 'en_US',
                symbol: 'S/ ',
                decimalDigits: 2
            ).format(double.tryParse(movement['monto'].toString()) ?? 0.0);

            final bool isExpense = movement['tipo'] == 'gasto';
            final bool isIncome = movement['tipo'] == 'ingreso';

            Color backgroundColor = cGrisClaro;
            Color iconColor = Colors.grey[400]!;
            IconData iconData = Icons.not_interested;
            Color amountColor = Colors.black;

            if (isExpense) {
              backgroundColor = Colors.red[50]!;
              iconColor = Colors.red[400]!;
              iconData = Icons.arrow_upward;
              amountColor = Colors.red[600]!;
            } else if (isIncome) {
              backgroundColor = cVerdeMenta.withOpacity(0.1);
              iconColor = cVerdeMenta;
              iconData = Icons.arrow_downward;
              amountColor = cVerdeMenta;
            }

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              elevation: 0, // Diseño flat
              color: cBlanco,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: cGrisClaro) // Borde sutil
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: backgroundColor,
                  child: Icon(iconData, color: iconColor),
                ),
                title: Text(
                  movement['categoria_nombre'] ?? 'Sin categoría',
                  style: TextStyle(fontWeight: FontWeight.w600, color: cAzulPetroleo),
                ),
                subtitle: Text(
                  'Fecha: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(movement['fecha']))}',
                  style: TextStyle(color: cAzulPetroleo.withOpacity(0.5)),
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
          'Detalle del Presupuesto',
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
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: cVerdeMenta))
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
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