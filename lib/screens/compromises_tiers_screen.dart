import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_muchik/config/constants.dart';

class TercerosScreen extends StatefulWidget {
  const TercerosScreen({super.key});

  @override
  State<TercerosScreen> createState() => _TercerosScreenState();
}

class _TercerosScreenState extends State<TercerosScreen> {
  // --- COLORES OFICIALES ---
  final Color cAzulPetroleo = const Color(0xFF264653);
  final Color cVerdeMenta = const Color(0xFF2A9D8F);
  final Color cGrisClaro = const Color(0xFFF4F4F4);
  final Color cBlanco = const Color(0xFFFFFFFF);

  final _nombreController = TextEditingController();
  String? _tipoSeleccionado;

  final List<String> _tipos = ['Banco', 'Prestamista', 'Persona', 'Servicio'];

  List<Map<String, dynamic>> tercerosList = [];
  String? errorMessage;
  String? _accessToken;
  int? _idCuenta;
  bool _isLoading = true;
  bool isLoading = true;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    setState(() {
      _isLoading = false;
      isLoading = false;
    });
    _loadSelectedAccountAndFetchImage();
    _loadAccessTokenAndFetchTerceros();

  }

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  Future<void> _loadAccessTokenAndFetchTerceros() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('accessToken');
    _idCuenta = prefs.getInt('idCuenta');

    if (_accessToken != null) {
      _fetchTerceros();
    } else {
      if (!mounted) return;
      setState(() {
        errorMessage = 'No se encontró un token de sesión. Por favor, inicie sesión.';
        isLoading = false;
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

  Future<void> _fetchTerceros() async {
    if (!mounted || _accessToken == null) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$API_BASE_URL/terceros'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          tercerosList = data.map((e) => e as Map<String, dynamic>).toList();
        });
      } else if (response.statusCode == 401) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('accessToken');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Su sesión ha expirado. Por favor, inicie sesión de nuevo.'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      } else {
        setState(() {
          errorMessage = 'Error al cargar terceros. Intente de nuevo.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'No se pudo conectar al servidor. Revise su conexión.';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _registrarTercero() async {
    if (_nombreController.text.isEmpty || _tipoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos'), backgroundColor: Colors.red),
      );
      return;
    }

    final nombreInput = _nombreController.text.trim();
    final tipoInput = _tipoSeleccionado!;

    bool existe = tercerosList.any((t) =>
    t['nombre'].toString().toLowerCase() == nombreInput.toLowerCase() &&
        t['tipo'].toString() == tipoInput
    );

    if (existe) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Ya existe "$nombreInput" como $tipoInput.'),
            backgroundColor: Colors.orange
        ),
      );
      return;
    }

    if (_accessToken == null || _idCuenta == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No se encontró el token de acceso. Por favor, reinicie la aplicación.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final body = {
      'nombre': _nombreController.text.trim(),
      'tipo': _tipoSeleccionado,
    };

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$API_BASE_URL/terceros'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
        body: json.encode(body),
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        final newTercero = json.decode(response.body);
        setState(() {
          tercerosList.add(newTercero);
          _nombreController.clear();
          _tipoSeleccionado = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Tercero registrado con éxito'), backgroundColor: cVerdeMenta),
        );
      } else {
        String errorMessage = 'Error al registrar el tercero: Código ${response.statusCode}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo conectar al servidor. Intente de nuevo.'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _actualizarTercero(int id, String nuevoNombre, String? nuevoTipo) async {
    if (_accessToken == null) return;

    final body = {
      'nombre': nuevoNombre.trim(),
      'tipo': nuevoTipo,
    };

    try {
      final response = await http.put(
        Uri.parse('$API_BASE_URL/terceros/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
        body: json.encode(body),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final updatedTercero = json.decode(response.body);
        setState(() {
          final index = tercerosList.indexWhere((t) => t['id'] == id);
          if (index != -1) tercerosList[index] = updatedTercero;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Tercero actualizado'), backgroundColor: cVerdeMenta),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar: ${response.statusCode}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo conectar al servidor'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _eliminarTercero(int id) async {
    if (_accessToken == null) return;

    try {
      final response = await http.delete(
        Uri.parse('$API_BASE_URL/terceros/$id'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 204) {
        setState(() {
          tercerosList.removeWhere((t) => t['id'] == id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Tercero eliminado'), backgroundColor: cVerdeMenta),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: ${response.statusCode}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo conectar al servidor'), backgroundColor: Colors.red),
      );
    }
  }

  void _mostrarConfirmacionEliminar(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cBlanco,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Eliminar Tercero', style: TextStyle(color: cAzulPetroleo, fontWeight: FontWeight.bold)),
        content: Text('¿Estás seguro de que quieres eliminar este tercero?', style: TextStyle(color: cAzulPetroleo.withOpacity(0.8))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () { Navigator.pop(context); _eliminarTercero(id); }, child: const Text('Eliminar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  void _mostrarModalEditar(Map<String, dynamic> tercero) {
    final TextEditingController editNombreController = TextEditingController(text: tercero['nombre']);
    String? editTipoSeleccionado = tercero['tipo'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cBlanco,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Editar Tercero', style: TextStyle(color: cAzulPetroleo, fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: editNombreController,
                maxLength: 30,
                decoration: InputDecoration(
                  labelText: 'Nombre del Tercero',
                  labelStyle: TextStyle(color: cAzulPetroleo.withOpacity(0.6)),
                  filled: true,
                  fillColor: cGrisClaro,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cVerdeMenta, width: 1.5)),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: editTipoSeleccionado,
                decoration: InputDecoration(
                  labelText: 'Tipo de Tercero',
                  labelStyle: TextStyle(color: cAzulPetroleo.withOpacity(0.6)),
                  filled: true,
                  fillColor: cGrisClaro,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                items: _tipos.map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(color: cAzulPetroleo)))).toList(),
                onChanged: (newValue) => editTipoSeleccionado = newValue,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _actualizarTercero(tercero['id'], editNombreController.text, editTipoSeleccionado); },
            style: ElevatedButton.styleFrom(backgroundColor: cVerdeMenta, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('Guardar', style: TextStyle(color: cBlanco, fontWeight: FontWeight.bold)),
          ),
        ],
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
        leading: IconButton(icon: Icon(Icons.arrow_back, color: cAzulPetroleo), onPressed: () => Navigator.pop(context)),
        title: Text('Gestión de Terceros', style: TextStyle(color: cAzulPetroleo, fontSize: 18, fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          IconButton(icon: Icon(Icons.notifications_outlined, color: cAzulPetroleo), onPressed: () {Navigator.pushNamed(context, '/notifications');}),
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
                color: cVerdeMenta.withOpacity(0.2),
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
                    print('Error al cargar la imagen de red: $error');
                    return Icon(Icons.person, size: 24, color: cAzulPetroleo);
                  },
                ),
              )
                  : Icon(Icons.person, size: 24, color: cAzulPetroleo),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sección Registro
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                  color: cBlanco,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), spreadRadius: 0, blurRadius: 10, offset: const Offset(0, 4))
                  ]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Registrar Nuevo Tercero', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cAzulPetroleo)),
                  const SizedBox(height: 16),
                  TextField(
                      controller: _nombreController,
                      maxLength: 30,
                      decoration: InputDecoration(
                        labelText: 'Nombre del Tercero',
                        labelStyle: TextStyle(color: cAzulPetroleo.withOpacity(0.6)),
                        filled: true,
                        fillColor: cGrisClaro,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cVerdeMenta)),
                      )
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _tipoSeleccionado,
                    decoration: InputDecoration(
                      labelText: 'Tipo de Tercero',
                      labelStyle: TextStyle(color: cAzulPetroleo.withOpacity(0.6)),
                      filled: true,
                      fillColor: cGrisClaro,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    items: _tipos.map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(color: cAzulPetroleo)))).toList(),
                    onChanged: (newValue) => setState(() { _tipoSeleccionado = newValue; }),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _registrarTercero,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: cVerdeMenta,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                          shadowColor: cVerdeMenta.withOpacity(0.4)
                      ),
                      child: Text('Registrar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cBlanco)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text('Lista de Terceros Registrados', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cAzulPetroleo)),
            const SizedBox(height: 16),
            isLoading
                ? Center(child: CircularProgressIndicator(color: cVerdeMenta))
                : tercerosList.isEmpty
                ? Center(child: Text(errorMessage ?? 'No hay terceros registrados', style: TextStyle(color: cAzulPetroleo.withOpacity(0.5))))
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tercerosList.length,
              itemBuilder: (context, index) => _buildTerceroItem(tercerosList[index]),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildTerceroItem(Map<String, dynamic> tercero) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: cBlanco,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), spreadRadius: 0, blurRadius: 5, offset: const Offset(0, 2))
          ]
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tercero['nombre'], style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cAzulPetroleo)),
              const SizedBox(height: 4),
              Text(tercero['tipo'], style: TextStyle(fontSize: 14, color: cAzulPetroleo.withOpacity(0.7))),
            ]),
          ),
          IconButton(icon: Icon(Icons.edit_outlined, color: cVerdeMenta), onPressed: () => _mostrarModalEditar(tercero), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          IconButton(icon: Icon(Icons.delete_outline, color: Colors.red[400]), onPressed: () => _mostrarConfirmacionEliminar(tercero['id']), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
          color: cBlanco,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), spreadRadius: 1, blurRadius: 10, offset: const Offset(0, -2))]
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: cBlanco,
        selectedItemColor: cAzulPetroleo, // Azul Petróleo para activo
        unselectedItemColor: Colors.grey[400],
        selectedFontSize: 12,
        unselectedFontSize: 12,
        currentIndex: 3,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), label: 'Reportes'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Presupuestos'),
          BottomNavigationBarItem(icon: Icon(Icons.category), label: 'Categorías'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Ajustes'),
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
}