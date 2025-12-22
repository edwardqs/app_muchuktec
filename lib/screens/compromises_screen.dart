import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../models/cuota_compromiso_model.dart';
import '../models/pago_compromiso_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_muchik/config/constants.dart';

class CompromisesScreen extends StatefulWidget {
  const CompromisesScreen({super.key});

  @override
  State<CompromisesScreen> createState() => _CompromisesScreenState();
}

class _CompromisesScreenState extends State<CompromisesScreen> {
  // --- COLORES OFICIALES ---
  final Color cAzulPetroleo = const Color(0xFF264653);
  final Color cVerdeMenta = const Color(0xFF2A9D8F);
  final Color cGrisClaro = const Color(0xFFF4F4F4);
  final Color cBlanco = const Color(0xFFFFFFFF);

  List<CompromiseModel> compromises = [];
  bool isLoading = false;
  String? errorMessage;
  String? _accessToken;
  int? _idCuenta;

  String? _profileImageUrl;
  bool _isLoadingImage = true;

  String? _selectedStatus; // Ej: 'Pendiente', 'Pagado', 'Vencido'
  int? _selectedMonth;
  int? _selectedYear;

  @override
  void initState() {
    super.initState();
    _loadSelectedAccountAndFetchImage();
    _loadAccessTokenAndFetchCompromises();
  }

  /// Función para enviar la actualización a la API
  Future<void> _updateCompromise(String id, String newName) async {
    if (_accessToken == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final url = Uri.parse('$API_BASE_URL/compromisos/$id');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
        body: json.encode({
          'nombre': newName,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Compromiso actualizado'), backgroundColor: cVerdeMenta),
        );
        _fetchCompromises();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar: ${response.body}'), backgroundColor: Colors.red),
        );
        setState(() { isLoading = false; });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión: $e'), backgroundColor: Colors.red),
      );
      setState(() { isLoading = false; });
    }
  }

  /// Función para mostrar el diálogo de edición
  void _showEditDialog(CompromiseModel compromise) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: compromise.name);
    final amountController = TextEditingController(text: compromise.montoTotal?.toStringAsFixed(2) ?? '0.00');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Editar "${compromise.name}"', style: TextStyle(color: cAzulPetroleo, fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Nuevo Nombre',
                      labelStyle: TextStyle(color: cAzulPetroleo.withOpacity(0.6)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: cVerdeMenta)),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'El nombre no puede estar vacío';
                      }
                      return null;
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
                if (formKey.currentState!.validate()) {
                  final newName = nameController.text;
                  Navigator.pop(context);
                  _updateCompromise(compromise.id, newName);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: cVerdeMenta),
              child: Text('Guardar', style: TextStyle(color: cBlanco)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadSelectedAccountAndFetchImage() async {
    setState(() {
      _isLoadingImage = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      final int? selectedAccountId = prefs.getInt('idCuenta');

      if (token == null || selectedAccountId == null) {
        if (mounted) {
          setState(() {
            _profileImageUrl = null;
            _isLoadingImage = false;
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
          _isLoadingImage = false;
        });
      } else {
        setState(() {
          _isLoadingImage = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingImage = false;
        });
      }
    }
  }

  Future<void> _loadAccessTokenAndFetchCompromises() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('accessToken');
    _idCuenta = prefs.getInt('idCuenta');

    if (_accessToken != null && _idCuenta != null) {
      _fetchCompromises();
    } else {
      if (!mounted) return;
      setState(() {
        errorMessage = 'No se encontró un token o una cuenta seleccionada.';
        isLoading = false;
      });
    }
  }

  Future<void> _fetchCompromises() async {
    if (!mounted || _accessToken == null || _idCuenta == null) return;
    setState(() { isLoading = true; errorMessage = null; });

    try {
      Map<String, String> queryParams = {
        'idcuenta': _idCuenta.toString(),
      };
      if (_selectedStatus != null && _selectedStatus != 'Todos') {
        queryParams['estado'] = _selectedStatus!;
      }
      if (_selectedMonth != null) {
        queryParams['mes'] = _selectedMonth.toString();
      }
      if (_selectedYear != null) {
        queryParams['anio'] = _selectedYear.toString();
      }

      final url = Uri.parse('$API_BASE_URL/compromisos').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          compromises = data.map((json) => CompromiseModel.fromJson(json)).toList();
        });
      } else {
        setState(() {
          errorMessage = 'Error al cargar los compromisos. Código: ${response.statusCode}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'No se pudo conectar al servidor. Revise su conexión.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _deleteCompromise(String compromiseId) async {
    if (_accessToken == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No se encontró el token de acceso.'), backgroundColor: Colors.red),
      );
      return;
    }

    final url = Uri.parse('$API_BASE_URL/compromisos/$compromiseId');

    try {
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Accept': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 204) {
        setState(() {
          compromises.removeWhere((compromise) => compromise.id == compromiseId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Compromiso eliminado con éxito.'), backgroundColor: cVerdeMenta),
        );
      } else if (response.statusCode == 404) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: El compromiso no fue encontrado.'), backgroundColor: Colors.orange),
        );
      } else if (response.statusCode == 401) {
        final prefs = await SharedPreferences.getInstance();
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

  void _showDeleteConfirmation(CompromiseModel compromise) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cBlanco,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Eliminar Compromiso',
          style: TextStyle(
            color: cAzulPetroleo,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '¿Estás seguro de que quieres eliminar el compromiso "${compromise.name}"?',
          style: TextStyle(color: cAzulPetroleo.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteCompromise(compromise.id);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _navigateToDetail(CompromiseModel compromise) {
    Navigator.pushNamed(
      context,
      '/compromises_detail',
      arguments: compromise.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cGrisClaro, // Fondo oficial #F4F4F4
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
            fontWeight: FontWeight.w700,
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
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: cVerdeMenta.withOpacity(0.2), // Fondo suave Mint
                shape: BoxShape.circle,
              ),
              child: _isLoadingImage
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
                  width: 32,
                  height: 32,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(Icons.person, size: 20, color: cAzulPetroleo);
                  },
                ),
              )
                  : Icon(Icons.person, size: 20, color: cAzulPetroleo),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/compromises_tiers');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: cAzulPetroleo, // Botón oficial Azul Petróleo
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  shadowColor: cAzulPetroleo.withOpacity(0.3),
                ),
                icon: Icon(Icons.people_alt, color: cBlanco),
                label: Text(
                  'Ver mis terceros',
                  style: TextStyle(
                    color: cBlanco,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Mis compromisos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: cAzulPetroleo,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add_circle_rounded, color: cVerdeMenta, size: 30),
                  tooltip: 'Registrar Nuevo Compromiso',
                  onPressed: () {
                    Navigator.pushNamed(context, '/compromises_create')
                        .then((_) => _fetchCompromises());
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),
            _buildFiltersSection(),
            const SizedBox(height: 24),
            if (isLoading)
              Center(child: CircularProgressIndicator(color: cVerdeMenta))
            else if (errorMessage != null)
              Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.red)))
            else if (compromises.isEmpty)
                Center(child: Text('No hay compromisos registrados.', style: TextStyle(color: cAzulPetroleo.withOpacity(0.6))))
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: compromises.length,
                  itemBuilder: (context, index) {
                    final compromise = compromises[index];
                    return _buildCompromiseItem(compromise);
                  },
                ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildFiltersSection() {
    final List<String> statusOptions = ['Todos', 'Pendiente', 'Pagado'];
    final Map<int, String> monthOptions = {
      0: 'Todos',
      for (var i = 1; i <= 12; i++) i: DateFormat('MMMM', 'es').format(DateTime(0, i))
    };
    final currentYear = DateTime.now().year;
    final List<int> yearOptions = [0] + List<int>.generate(7, (i) => currentYear - 5 + i);

    return Container(
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
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: statusOptions.map((status) {
              final bool isSelected = (_selectedStatus == null && status == 'Todos') || (_selectedStatus == status);
              return ChoiceChip(
                label: Text(status),
                selected: isSelected,
                onSelected: (bool selected) {
                  if (selected) {
                    setState(() {
                      _selectedStatus = (status == 'Todos') ? null : status;
                      _fetchCompromises();
                    });
                  }
                },
                backgroundColor: cGrisClaro,
                selectedColor: cVerdeMenta.withOpacity(0.2), // Fondo seleccionado
                labelStyle: TextStyle(
                  color: isSelected ? cAzulPetroleo : cAzulPetroleo.withOpacity(0.6),
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? cVerdeMenta : Colors.transparent,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                showCheckmark: false,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // --- Fila para Mes y Año ---
          Row(
            children: [
              // --- Dropdown Mes ---
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedMonth ?? 0,
                  decoration: InputDecoration(
                    labelText: 'Mes Creación',
                    labelStyle: TextStyle(color: cAzulPetroleo.withOpacity(0.6)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: cGrisClaro,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  items: monthOptions.entries.map((entry) {
                    String monthName = entry.value;
                    if (monthName != 'Todos') {
                      monthName = monthName[0].toUpperCase() + monthName.substring(1);
                    }
                    return DropdownMenuItem<int>(
                      value: entry.key,
                      child: Text(monthName, overflow: TextOverflow.ellipsis, style: TextStyle(color: cAzulPetroleo)),
                    );
                  }).toList(),
                  onChanged: (int? newValue) {
                    setState(() {
                      _selectedMonth = (newValue == 0) ? null : newValue;
                      _fetchCompromises();
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),

              // --- Dropdown Año ---
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedYear ?? 0,
                  decoration: InputDecoration(
                    labelText: 'Año Creación',
                    labelStyle: TextStyle(color: cAzulPetroleo.withOpacity(0.6)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: cGrisClaro,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  items: yearOptions.map((year) {
                    return DropdownMenuItem<int>(
                      value: year,
                      child: Text(year == 0 ? 'Todos' : year.toString(), style: TextStyle(color: cAzulPetroleo)),
                    );
                  }).toList(),
                  onChanged: (int? newValue) {
                    setState(() {
                      _selectedYear = (newValue == 0) ? null : newValue;
                      _fetchCompromises();
                    });
                  },
                ),
              ),
            ],
          ),

          if (_selectedStatus != null || _selectedMonth != null || _selectedYear != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _selectedStatus = null;
                    _selectedMonth = null;
                    _selectedYear = null;
                    _fetchCompromises();
                  });
                },
                child: Text('Limpiar Filtros', style: TextStyle(color: cVerdeMenta, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompromiseItem(CompromiseModel compromise) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: cBlanco,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  compromise.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: cAzulPetroleo,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Monto Total: S/ ${compromise.montoTotal?.toStringAsFixed(2) ?? compromise.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: cAzulPetroleo.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.info_outline, color: cAzulPetroleo),
            onPressed: () => _navigateToDetail(compromise),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.edit_outlined, color: cVerdeMenta),
            onPressed: () {
              _showEditDialog(compromise);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          IconButton(
            icon: Icon(Icons.delete_outlined, color: Colors.red[400]),
            onPressed: () => _showDeleteConfirmation(compromise),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
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
        selectedItemColor: cAzulPetroleo, // Color activo oficial
        unselectedItemColor: Colors.grey[400],
        selectedFontSize: 12,
        unselectedFontSize: 12,
        currentIndex: 0,
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
              Navigator.pushReplacementNamed(context, '/budgets');
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
    super.dispose();
  }
}

// Modelo para las frecuencias
class FrecuenciaModel {
  final int id;
  final String nombre;

  FrecuenciaModel({
    required this.id,
    required this.nombre,
  });

  factory FrecuenciaModel.fromJson(Map<String, dynamic> json) {
    return FrecuenciaModel(
      id: json['id'] ?? 0,
      nombre: json['nombre'] ?? 'Sin Nombre',
    );
  }
}

// Modelo para los compromisos
class CompromiseModel {
  final String id;
  final String name;
  final double amount;
  final String date;
  final String? tipoCompromiso;
  final int? idusuario;
  final int? idcuenta;
  final int? idtercero;
  final String? nombreTercero;
  final int? idfrecuencia;
  final double? montoTotal;
  final int? cantidadCuotas;
  final double? montoCuota;
  final int? cuotasPagadas;
  final double? tasaInteres;
  final String? tipoInteres;
  final String? fechaTermino;
  final String? estado;
  final int? estadoEliminar;
  final FrecuenciaModel? frecuencia;
  final double? montoTotalPagado;
  final List<CuotaCompromisoModel> cuotas;
  final List<PagoCompromisoModel> pagos;

  CompromiseModel({
    required this.id,
    required this.name,
    required this.amount, // <-- Se espera un double
    required this.date,
    this.tipoCompromiso,
    this.idusuario,
    this.idcuenta,
    this.idtercero,
    this.nombreTercero,
    this.idfrecuencia,
    this.montoTotal,
    this.cantidadCuotas,
    this.montoCuota,
    this.cuotasPagadas,
    this.tasaInteres,
    this.tipoInteres,
    this.fechaTermino,
    this.estado,
    this.estadoEliminar,
    this.frecuencia,
    this.montoTotalPagado,
    this.cuotas = const [],
    this.pagos = const [],
  });

  factory CompromiseModel.fromJson(Map<String, dynamic> json) {
    double? _toDouble(dynamic value) {
      if (value == null) return null;
      if (value is String) return double.tryParse(value);
      if (value is num) return value.toDouble();
      return null;
    }

    int? _toInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      return int.tryParse(value.toString());
    }

    List<CuotaCompromisoModel> parsedCuotas = [];
    if (json['cuotas'] != null && json['cuotas'] is List) {
      parsedCuotas = (json['cuotas'] as List)
          .map((cuotaJson) => CuotaCompromisoModel.fromJson(cuotaJson))
          .toList();
    }

    List<PagoCompromisoModel> parsedPagos = [];
    if (json['pagos'] != null && json['pagos'] is List) {
      parsedPagos = (json['pagos'] as List)
          .map((pagoJson) => PagoCompromisoModel.fromJson(pagoJson))
          .toList();
    }

    return CompromiseModel(
      id: json['id']?.toString() ?? '',
      name: json['nombre'] as String? ?? 'Sin Nombre',
      amount: _toDouble(json['monto_cuota']) ?? 0.0,
      date: json['fecha_inicio'] as String? ?? '',
      tipoCompromiso: json['tipo_compromiso'] as String?,
      idusuario: _toInt(json['idusuario']),
      idcuenta: _toInt(json['idcuenta']),
      idtercero: _toInt(json['idtercero']),
      nombreTercero: json['tercero'] != null ? json['tercero']['nombre'] : null,
      idfrecuencia: _toInt(json['idfrecuencia']),
      montoTotal: _toDouble(json['monto_total']),
      cantidadCuotas: _toInt(json['cantidad_cuotas']),
      montoCuota: _toDouble(json['monto_cuota']),
      cuotasPagadas: _toInt(json['cuotas_pagadas']),
      montoTotalPagado: _toDouble(json['pagos_sum_monto']),
      tasaInteres: _toDouble(json['tasa_interes']),
      tipoInteres: json['tipo_interes'] as String?,
      fechaTermino: json['fecha_termino'] as String?,
      estado: json['estado'] as String?,
      estadoEliminar: _toInt(json['estado_eliminar']),
      frecuencia: json['frecuencia'] != null
          ? FrecuenciaModel.fromJson(json['frecuencia'])
          : null,
      cuotas: parsedCuotas,
      pagos: parsedPagos,
    );
  }
}