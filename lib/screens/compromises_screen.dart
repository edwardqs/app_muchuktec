// lib/screens/compromises_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
// Quité la importación de intl/intl.dart ya que solo se usaba en la clase de detalle movida.

const String STORAGE_BASE_URL = 'http://10.0.2.2:8000/storage';
const String API_BASE_URL = 'http://10.0.2.2:8000/api';

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


  @override
  void initState() {
    super.initState();
    // Se llama a ambos métodos para cargar datos
    _loadSelectedAccountAndFetchImage();
    _loadAccessTokenAndFetchCompromises();
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
            print('URL de la imagen construida: $_profileImageUrl');
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

    // Imprime para verificar que se está leyendo bien
    print('Cargando compromisos para la cuenta con ID: $_idCuenta');

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
    // La validación ahora está en el método anterior, pero mantenemos esta por seguridad
    if (!mounted || _accessToken == null || _idCuenta == null) {
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final url = Uri.parse('$API_BASE_URL/compromisos').replace(
        queryParameters: {
          'idcuenta': _idCuenta.toString(),
        },
      );

      print('Llamando a la URL de compromisos: $url'); // Para depurar

      final response = await http.get(
        url, // Usar la nueva URL
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
      );

      print('Respuesta del servidor: ${response.statusCode} - ${response.body}'); // Para depurar

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
      print('Excepción en _fetchCompromises: $e'); // Imprime la excepción real
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
    // Usamos pushNamed, asumiendo que la ruta se llama '/compromises_detail'
    Navigator.pushNamed(
      context,
      '/compromises_detail',
      arguments: compromise, // Pasamos el objeto CompromiseModel como argumento
    ).then((_) {
      // Recargar la lista al volver, por si se realizó alguna edición/acción
      _fetchCompromises();
    });
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
                  Navigator.pushNamed(context, '/compromises_create').then((_) => _fetchCompromises());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                label: const Text(
                  'Registrar Nuevo Compromiso',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
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
            const SizedBox(height: 32),
            const Text(
              'Mis compromisos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
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
                  // Muestra el monto total en lugar de la cuota como resumen
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
              // TODO: Navegar a la pantalla de edición de compromiso
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

// Modelo para los compromisos
class CompromiseModel {
  final String id;
  final String name;
  final double amount; // <-- Se espera un double
  final String date;
  final String? tipoCompromiso;
  final int? idusuario;
  final int? idcuenta;
  final int? idtercero;
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

  CompromiseModel({
    required this.id,
    required this.name,
    required this.amount, // <-- Se espera un double
    required this.date,
    this.tipoCompromiso,
    this.idusuario,
    this.idcuenta,
    this.idtercero,
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
  });

  factory CompromiseModel.fromJson(Map<String, dynamic> json) {
    // Helper para parsear de String o num a double
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is String) return double.tryParse(value);
      if (value is num) return value.toDouble();
      return null;
    }

    final double montoCuotaParsed = parseDouble(json['monto_cuota']) ?? 0.0;
    final double? montoTotalParsed = parseDouble(json['monto_total']);
    final double? tasaInteresParsed = parseDouble(json['tasa_interes']);

    return CompromiseModel(
      id: json['id']?.toString() ?? '',
      name: json['nombre'] as String,
      amount: montoCuotaParsed, // <-- Aquí se usa el valor de 'monto_cuota' como fallback
      date: json['fecha_inicio'] as String,
      tipoCompromiso: json['tipo_compromiso'] as String?,
      idusuario: json['idusuario'] as int?,
      idcuenta: json['idcuenta'] as int?,
      idtercero: json['idtercero'] as int?,
      idfrecuencia: json['idfrecuencia'] as int?,
      montoTotal: montoTotalParsed, // Usar el valor parseado
      cantidadCuotas: json['cantidad_cuotas'] as int?,
      montoCuota: montoCuotaParsed,
      cuotasPagadas: json['cuotas_pagadas'] as int?,
      tasaInteres: tasaInteresParsed, // Usar el valor parseado
      tipoInteres: json['tipo_interes'] as String?,
      fechaTermino: json['fecha_termino'] as String?,
      estado: json['estado'] as String?,
      estadoEliminar: json['estado_eliminar'] as int?,
    );
  }
}