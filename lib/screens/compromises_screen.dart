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
    // Se llama a ambos métodos para cargar datos
    _loadSelectedAccountAndFetchImage();
    _loadAccessTokenAndFetchCompromises();
  }

  /// Función para enviar la actualización a la API
  Future<void> _updateCompromise(String id, String newName) async {
    if (_accessToken == null) return; // Ya tienes _accessToken cargado

    setState(() {
      isLoading = true; // Muestra indicador general mientras guarda
    });

    try {
      final url = Uri.parse('$API_BASE_URL/compromisos/$id');
      final response = await http.put( // Usamos PUT
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
          const SnackBar(content: Text('Compromiso actualizado'), backgroundColor: Colors.green),
        );
        // Actualizamos la lista después de guardar exitosamente
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
          title: Text('Editar "${compromise.name}"'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nuevo Nombre'),
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
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final newName = nameController.text;
                  final newAmount = double.tryParse(amountController.text) ?? 0.0;
                  Navigator.pop(context);
                  _updateCompromise(compromise.id, newName);
                }
              },
              child: const Text('Guardar'),
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
          print('Token o ID de cuenta no encontrados. No se puede cargar la imagen.');
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
        print('Error al obtener los detalles de la cuenta. Status Code: ${response.statusCode}');
        setState(() {
          _isLoadingImage = false;
        });
      }
    } catch (e) {
      if (mounted) {
        print('Excepción al obtener los detalles de la cuenta: $e');
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
      // --- CONSTRUIR PARÁMETROS ---
      Map<String, String> queryParams = {
        'idcuenta': _idCuenta.toString(),
      };
      // Solo añadir el estado si está seleccionado y no es 'Todos'
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
        url, // Usar la nueva URL
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
      print('Excepción en _fetchCompromises: $e');
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
          const SnackBar(content: Text('Compromiso eliminado con éxito.'), backgroundColor: Colors.green),
        );
      } else if (response.statusCode == 404) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: El compromiso no fue encontrado.'), backgroundColor: Colors.orange),
        );
      } else if (response.statusCode == 401) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('accessToken');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Su sesión ha expirado. Por favor, inicie sesión de nuevo.'), backgroundColor: Colors.red),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar el compromiso: ${response.statusCode}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo conectar al servidor. Intente de nuevo.'), backgroundColor: Colors.red),
      );
    }
  }

  void _showDeleteConfirmation(CompromiseModel compromise) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Eliminar Compromiso',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          '¿Estás seguro de que quieres eliminar el compromiso "${compromise.name}"?',
          style: TextStyle(color: Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteCompromise(compromise.id);
            },
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // --- Método de Navegación a Detalles Actualizado ---
  void _navigateToDetail(CompromiseModel compromise) {
    Navigator.pushNamed(
      context,
      '/compromises_detail',
      arguments: compromise.id, // <-- ERROR: Pasando el objeto completo
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
                color: Colors.purple[100],
                shape: BoxShape.circle,
              ),
              child: _isLoadingImage
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
                  width: 32,
                  height: 32,
                  errorBuilder: (context, error, stackTrace) {
                    print('Error al cargar la imagen de red: $error');
                    return Icon(Icons.person, size: 20, color: Colors.purple[700]);
                  },
                ),
              )
                  : Icon(Icons.person, size: 20, color: Colors.purple[700]),
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
                  backgroundColor: Colors.indigo,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.people_alt, color: Colors.white),
                label: const Text(
                  'Ver mis terceros',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Pushes items apart
              crossAxisAlignment: CrossAxisAlignment.center, // Vertically align items
              children: [
                const Text(
                  'Mis compromisos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87, // Slightly softer black
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                  tooltip: 'Registrar Nuevo Compromiso', // Accessibility
                  onPressed: () {
                    // Same action as the old button
                    Navigator.pushNamed(context, '/compromises_create')
                        .then((_) => _fetchCompromises()); // Refresh list on return
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),
            _buildFiltersSection(),
            const SizedBox(height: 24),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (errorMessage != null)
              Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.red)))
            else if (compromises.isEmpty)
                const Center(child: Text('No hay compromisos registrados.'))
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
  // Coloca esta función dentro de tu clase _CompromisesScreenState

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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [ // Sombra sutil
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8.0, // Espacio horizontal
            runSpacing: 4.0, // Espacio vertical
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
                backgroundColor: Colors.grey[100],
                selectedColor: Colors.purple[100],
                labelStyle: TextStyle(
                  color: isSelected ? Colors.purple[800] : Colors.black87,
                  fontSize: 14, // Ligeramente más grande que antes
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isSelected ? Colors.purple[200]! : Colors.grey[300]!,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                showCheckmark: false,
              );
            }).toList(),
          ),
          const SizedBox(height: 16), // Espacio antes de Mes/Año

          // --- Fila para Mes y Año ---
          Row(
            children: [
              // --- Dropdown Mes ---
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedMonth ?? 0, // 0 representa 'Todos'
                  decoration: InputDecoration(
                    labelText: 'Mes Creación',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  items: monthOptions.entries.map((entry) {
                    // Capitalizar nombre del mes
                    String monthName = entry.value;
                    if (monthName != 'Todos') {
                      monthName = monthName[0].toUpperCase() + monthName.substring(1);
                    }
                    return DropdownMenuItem<int>(
                      value: entry.key, // El valor es el número (0 para 'Todos')
                      child: Text(monthName, overflow: TextOverflow.ellipsis), // Muestra el nombre, previene overflow
                    );
                  }).toList(),
                  onChanged: (int? newValue) {
                    setState(() {
                      _selectedMonth = (newValue == 0) ? null : newValue; // null si selecciona 'Todos'
                      _fetchCompromises();
                    });
                  },
                ),
              ),
              const SizedBox(width: 16), // Espacio entre dropdowns

              // --- Dropdown Año ---
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedYear ?? 0, // 0 representa 'Todos'
                  decoration: InputDecoration(
                    labelText: 'Año Creación',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  items: yearOptions.map((year) {
                    return DropdownMenuItem<int>(
                      value: year,
                      child: Text(year == 0 ? 'Todos' : year.toString()),
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

          // --- Botón Limpiar Filtros ---
          if (_selectedStatus != null || _selectedMonth != null || _selectedYear != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _selectedStatus = null;
                    _selectedMonth = null;
                    _selectedYear = null;
                    _fetchCompromises(); // Buscar sin filtros
                  });
                },
                child: const Text('Limpiar Filtros', style: TextStyle(color: Colors.blueAccent)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompromiseItem(CompromiseModel compromise) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  compromise.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Monto Total: S/ ${compromise.montoTotal?.toStringAsFixed(2) ?? compromise.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // Botón para ver el detalle
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.purple),
            onPressed: () => _navigateToDetail(compromise), // <-- Navegación por nombre
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.blue),
            onPressed: () {
              _showEditDialog(compromise);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outlined, color: Colors.red),
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